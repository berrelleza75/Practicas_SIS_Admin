# =============================================
# Gestor Servidor DNS - Windows PowerShell
# Equivalente al script dns.sh para Arch Linux
# Requiere ejecutarse como Administrador
# =============================================

# --- Funciones de validacion de IPs ---

function Validar-IP {
    # Verifica que la cadena tenga formato X.X.X.X con valores entre 0 y 255
    param([string]$ip)

    if ($ip -notmatch '^\d+\.\d+\.\d+\.\d+$') {
        Write-Host "Formato invalido, debe ser: X.X.X.X (ejemplo: 192.168.1.1)"
        return $false
    }

    $octetos = $ip -split '\.'
    foreach ($oct in $octetos) {
        $val = [int]$oct
        if ($val -lt 0 -or $val -gt 255) {
            Write-Host "Error: cada octeto debe estar entre 0 y 255"
            return $false
        }
    }
    return $true
}

function Validar-NoLoopback {
    # El rango 127.x.x.x esta reservado para la interfaz local del equipo
    param([string]$ip)
    $primerOcteto = ($ip -split '\.')[0]
    if ([int]$primerOcteto -eq 127) {
        Write-Host "Error: no se puede usar la IP loopback (127.x.x.x)"
        return $false
    }
    return $true
}

function Validar-NoBroadcast {
    # 255.255.255.255 es la direccion de broadcast general, no asignable
    param([string]$ip)
    if ($ip -eq "255.255.255.255") {
        Write-Host "Error: no se puede usar la IP de broadcast"
        return $false
    }
    return $true
}

function Validar-NoCero {
    # 0.0.0.0 representa una ruta por defecto, no una IP valida de host
    param([string]$ip)
    if ($ip -eq "0.0.0.0") {
        Write-Host "Error: no se puede usar la IP 0.0.0.0"
        return $false
    }
    return $true
}

function Validar-IPCompleta {
    # Agrupa todas las validaciones basicas para no repetirlas en cada funcion
    param([string]$ip)
    if (-not (Validar-IP $ip))          { return $false }
    if (-not (Validar-NoLoopback $ip))  { return $false }
    if (-not (Validar-NoBroadcast $ip)) { return $false }
    if (-not (Validar-NoCero $ip))      { return $false }
    return $true
}

# --- Funciones principales del menu ---

function Verificar-DNS {
    # Comprueba si el servicio DNS de Windows esta instalado y su estado actual
    Write-Host "-------------------------------------------"
    Write-Host "    Verificacion del servicio DNS          "
    Write-Host "-------------------------------------------"

    $servicio = Get-Service -Name "DNS" -ErrorAction SilentlyContinue
    if ($null -eq $servicio) {
        Write-Host "Servicio DNS: NO ENCONTRADO"
        Write-Host "Este equipo no tiene el rol de servidor DNS instalado"
        return
    }

    Write-Host "Servicio DNS: ENCONTRADO"
    Write-Host ""

    if ($servicio.Status -eq "Running") {
        Write-Host "Estado: ACTIVO"
    } else {
        Write-Host "Estado: INACTIVO"
    }

    # StartType indica si arranca automaticamente con Windows
    $inicio = (Get-Service -Name "DNS").StartType
    Write-Host "Inicio automatico: $inicio"
    Write-Host "-------------------------------------------"
}

function Instalar-DNS {
    # Instala el rol DNS de Windows Server via RSAT/Feature
    Write-Host "-------------------------------------------"
    Write-Host "    Instalacion del servidor DNS           "
    Write-Host "-------------------------------------------"

    $feature = Get-WindowsFeature -Name "DNS" -ErrorAction SilentlyContinue

    if ($null -ne $feature -and $feature.Installed) {
        Write-Host "El servidor DNS ya esta instalado"
        return
    }

    Write-Host "Instalando rol DNS..."
    Install-WindowsFeature -Name DNS -IncludeManagementTools

    # Verificamos que la instalacion haya sido exitosa antes de continuar
    $check = Get-WindowsFeature -Name "DNS"
    if ($check.Installed) {
        Write-Host ""
        Write-Host "-------------------------------------------"
        Write-Host "   DNS instalado correctamente             "
        Write-Host "-------------------------------------------"
        Start-Service -Name "DNS"
        Set-Service -Name "DNS" -StartupType Automatic
        Write-Host "Servicio iniciado y configurado para arranque automatico"
    } else {
        Write-Host "Error: La instalacion fallo"
    }
}

function Agregar-Zona {
    # Crea una zona DNS primaria con un registro A apuntando a la IP indicada
    Write-Host "-------------------------------------------"
    Write-Host "    Agregar Zona DNS                       "
    Write-Host "-------------------------------------------"

    $servicio = Get-Service -Name "DNS" -ErrorAction SilentlyContinue
    if ($null -eq $servicio -or $servicio.Status -ne "Running") {
        Write-Host "Error: El servicio DNS no esta activo"
        Write-Host "Use la opcion 2 para instalarlo"
        return
    }

    # Pedimos el nombre del dominio a crear
    do {
        $dominio = Read-Host "Ingrese el dominio (ejemplo: reprobados.com)"
        if ([string]::IsNullOrEmpty($dominio)) {
            Write-Host "Error: el dominio no puede estar vacio"
            continue
        }
        if ($dominio -notmatch '^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') {
            Write-Host "Error: formato invalido, ejemplo: reprobados.com"
            continue
        }
        # Verificamos que la zona no exista previamente
        $zonaExistente = Get-DnsServerZone -Name $dominio -ErrorAction SilentlyContinue
        if ($null -ne $zonaExistente) {
            Write-Host "Error: la zona $dominio ya existe"
            continue
        }
        break
    } while ($true)

    # Pedimos la IP a la que resolvera el dominio
    do {
        $ipDestino = Read-Host "Ingrese la IP destino del dominio"
        if ([string]::IsNullOrEmpty($ipDestino)) {
            Write-Host "Error: la IP no puede estar vacia"
            continue
        }
        if (-not (Validar-IPCompleta $ipDestino)) { continue }
        break
    } while ($true)

    Write-Host ""
    Write-Host "Creando zona $dominio..."

    # Add-DnsServerPrimaryZone crea la zona autoritativa en este servidor
    Add-DnsServerPrimaryZone -Name $dominio -ZoneFile "$dominio.dns" -ErrorAction Stop

    # El registro A raiz (@) apunta el dominio base a la IP destino
    Add-DnsServerResourceRecordA -ZoneName $dominio -Name "@" -IPv4Address $ipDestino

    # El registro CNAME www redirige www.dominio al dominio raiz
    Add-DnsServerResourceRecordCName -ZoneName $dominio -Name "www" -HostNameAlias "$dominio."

    Write-Host ""
    Write-Host "-------------------------------------------"
    Write-Host "   Zona configurada exitosamente           "
    Write-Host "-------------------------------------------"
    Write-Host "Dominio   : $dominio"
    Write-Host "IP destino: $ipDestino"
    Write-Host "-------------------------------------------"
}

function Listar-Zonas {
    # Muestra todas las zonas DNS configuradas en este servidor
    Write-Host "-------------------------------------------"
    Write-Host "    Zonas DNS Configuradas                 "
    Write-Host "-------------------------------------------"

    $servicio = Get-Service -Name "DNS" -ErrorAction SilentlyContinue
    if ($null -eq $servicio) {
        Write-Host "Error: el servicio DNS no esta instalado"
        return
    }

    # Filtramos zonas de busqueda directa (excluye zonas inversas y de sistema)
    $zonas = Get-DnsServerZone | Where-Object {
        $_.IsAutoCreated -eq $false -and $_.ZoneType -eq "Primary"
    }

    if ($null -eq $zonas -or $zonas.Count -eq 0) {
        Write-Host "No hay zonas configuradas aun"
        Write-Host "Use la opcion 3 para agregar una zona"
        return
    }

    Write-Host ""
    Write-Host "Zonas encontradas:"
    Write-Host ""

    $contador = 1
    foreach ($zona in $zonas) {
        # Buscamos el registro A raiz para mostrar la IP destino de cada zona
        $registroA = Get-DnsServerResourceRecord -ZoneName $zona.ZoneName -RRType A -Name "@" -ErrorAction SilentlyContinue
        $ip = if ($registroA) { $registroA.RecordData.IPv4Address } else { "(sin registro A)" }
        Write-Host " $contador) $($zona.ZoneName) -> $ip"
        $contador++
    }

    Write-Host ""
    Write-Host "Total de zonas: $($contador - 1)"
    Write-Host "-------------------------------------------"
}

function Validar-Configuracion {
    # Prueba que una zona resuelva correctamente con nslookup
    Write-Host "-------------------------------------------"
    Write-Host "    Validacion de Configuracion DNS        "
    Write-Host "-------------------------------------------"

    $servicio = Get-Service -Name "DNS" -ErrorAction SilentlyContinue
    if ($null -eq $servicio -or $servicio.Status -ne "Running") {
        Write-Host "Error: el servicio DNS no esta activo"
        return
    }

    $zonas = Get-DnsServerZone | Where-Object {
        $_.IsAutoCreated -eq $false -and $_.ZoneType -eq "Primary"
    }

    if ($null -eq $zonas -or $zonas.Count -eq 0) {
        Write-Host "No hay zonas configuradas"
        return
    }

    Write-Host "Zonas disponibles:"
    Write-Host ""
    $lista = @()
    $contador = 1
    foreach ($zona in $zonas) {
        Write-Host " $contador) $($zona.ZoneName)"
        $lista += $zona.ZoneName
        $contador++
    }

    Write-Host ""

    do {
        $sel = Read-Host "Seleccione el numero del dominio a probar"
        if ($sel -notmatch '^\d+$' -or [int]$sel -lt 1 -or [int]$sel -gt $lista.Count) {
            Write-Host "Error: seleccione un numero entre 1 y $($lista.Count)"
            continue
        }
        break
    } while ($true)

    $dominioElegido = $lista[[int]$sel - 1]

    # Obtenemos la IP esperada del registro A para compararla con el resultado
    $registroA = Get-DnsServerResourceRecord -ZoneName $dominioElegido -RRType A -Name "@" -ErrorAction SilentlyContinue
    $ipEsperada = $registroA.RecordData.IPv4Address.ToString()

    # Obtenemos la IP del servidor DNS local para usarla como referencia en nslookup
    $ipServidor = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" } | Select-Object -First 1).IPAddress

    Write-Host ""
    Write-Host "Probando resolucion DNS..."
    Write-Host ""

    # nslookup sin www
    $resultado = Resolve-DnsName -Name $dominioElegido -Server $ipServidor -ErrorAction SilentlyContinue
    $ipObtenida = ($resultado | Where-Object { $_.Type -eq "A" } | Select-Object -First 1).IPAddress
    if ($ipObtenida -eq $ipEsperada) {
        Write-Host "nslookup $dominioElegido -> $ipObtenida OK"
    } else {
        Write-Host "nslookup $dominioElegido -> FALLO (esperada: $ipEsperada, obtenida: $ipObtenida)"
    }

    # nslookup con www
    $resultadoWWW = Resolve-DnsName -Name "www.$dominioElegido" -Server $ipServidor -ErrorAction SilentlyContinue
    $ipWWW = ($resultadoWWW | Where-Object { $_.Type -eq "A" } | Select-Object -First 1).IPAddress
    if ($ipWWW -eq $ipEsperada) {
        Write-Host "nslookup www.$dominioElegido -> $ipWWW OK"
    } else {
        Write-Host "nslookup www.$dominioElegido -> FALLO (esperada: $ipEsperada, obtenida: $ipWWW)"
    }

    Write-Host ""
    Write-Host "Probando ping..."
    Write-Host ""

    # Test-Connection es el equivalente de ping en PowerShell
    if (Test-Connection -ComputerName $dominioElegido -Count 3 -Quiet) {
        Write-Host "ping $dominioElegido -> OK"
    } else {
        Write-Host "ping $dominioElegido -> FALLO"
        Write-Host "Nota: puede fallar si el host destino no responde ICMP"
    }

    if (Test-Connection -ComputerName "www.$dominioElegido" -Count 3 -Quiet) {
        Write-Host "ping www.$dominioElegido -> OK"
    } else {
        Write-Host "ping www.$dominioElegido -> FALLO"
        Write-Host "Nota: puede fallar si el host destino no responde ICMP"
    }

    Write-Host ""
    Write-Host "-------------------------------------------"
    Write-Host "   Validacion completada                   "
    Write-Host "-------------------------------------------"
}

function Monitorear-Estado {
    # Muestra el estado detallado del servicio DNS de Windows
    Write-Host "-------------------------------------------"
    Write-Host "    Estado del Servidor DNS                "
    Write-Host "-------------------------------------------"

    $servicio = Get-Service -Name "DNS" -ErrorAction SilentlyContinue
    if ($null -eq $servicio) {
        Write-Host "El servidor DNS NO esta instalado"
        Write-Host "Use la opcion 2 para instalarlo"
        return
    }

    Write-Host "Servicio DNS: ENCONTRADO"
    Write-Host ""

    if ($servicio.Status -eq "Running") {
        Write-Host "Estado: ACTIVO"
        Write-Host "El servidor DNS esta funcionando correctamente"
    } else {
        Write-Host "Estado: INACTIVO"
        Write-Host "El servidor DNS NO esta corriendo"
    }

    Write-Host ""
    Write-Host "Inicio automatico: $($servicio.StartType)"
    Write-Host ""
    Write-Host "-------------------------------------------"
    Write-Host "Informacion detallada:"
    Write-Host ""

    # Get-Service muestra informacion basica del proceso del servicio
    Get-Service -Name "DNS" | Format-List *

    Write-Host "-------------------------------------------"
}

function Mostrar-Menu {
    Clear-Host
    Write-Host "____________________________________________"
    Write-Host "        Gestor Servidor DNS - Windows       "
    Write-Host "____________________________________________"
    Write-Host " 1. Verificar instalacion                  "
    Write-Host " 2. Instalar servidor DNS                  "
    Write-Host " 3. Agregar zona DNS                       "
    Write-Host " 4. Listar zonas configuradas              "
    Write-Host " 5. Validar configuracion                  "
    Write-Host " 6. Monitorear estado del servidor         "
    Write-Host " 0. Salir                                  "
    Write-Host "____________________________________________"
}

# --- Verificacion de privilegios antes de iniciar ---
# Sin permisos de administrador no se pueden gestionar servicios ni zonas DNS
$esAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $esAdmin) {
    Write-Host "Este script debe ejecutarse como Administrador"
    Write-Host "Haz clic derecho en PowerShell y selecciona 'Ejecutar como administrador'"
    exit 1
}

# --- Bucle principal del menu ---
while ($true) {
    Mostrar-Menu
    $opcion = Read-Host "Seleccione una opcion"

    switch ($opcion) {
        "1" { Verificar-DNS }
        "2" { Instalar-DNS }
        "3" { Agregar-Zona }
        "4" { Listar-Zonas }
        "5" { Validar-Configuracion }
        "6" { Monitorear-Estado }
        "0" { Write-Host "Saliendo..."; exit 0 }
        default { Write-Host "Opcion invalida" }
    }

    Read-Host "Presiona Enter para continuar"
}