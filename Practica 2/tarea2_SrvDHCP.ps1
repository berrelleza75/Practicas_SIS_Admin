# Funciones de validacion
function Validar-IP {
    param([string]$ip)
    
    if ($ip -notmatch '^(\d{1,3}\.){3}\d{1,3}$') {
        Write-Host "formato invalido, debe ser: X.X.X.X (ejemplo: 192.168.1.1)"
        return $false
    }
    
    $octetos = $ip -split '\.'
    foreach ($octeto in $octetos) {
        $num = [int]$octeto
        if ($num -lt 0 -or $num -gt 255) {
            Write-Host "Error: cada octeto debe estar entre 0 y 255"
            return $false
        }
    }
    
    return $true
}

function Validar-NoLoopback {
    param([string]$ip)
    
    $primerOcteto = ($ip -split '\.')[0]
    
    if ([int]$primerOcteto -eq 127) {
        Write-Host "Error no se puede usar la IP loopback (127.x.x.x)"
        return $false
    }
    
    return $true
}

function Validar-Rango {
    param([string]$ipInicial, [string]$ipFinal)
    
    $o1 = $ipInicial -split '\.'
    $o2 = $ipFinal -split '\.'
    
    $num1 = ([int]$o1[0] * 16777216) + ([int]$o1[1] * 65536) + ([int]$o1[2] * 256) + [int]$o1[3]
    $num2 = ([int]$o2[0] * 16777216) + ([int]$o2[1] * 65536) + ([int]$o2[2] * 256) + [int]$o2[3]
    
    if ($num1 -ge $num2) {
        Write-Host "Error: La IP inicial debe ser menor que la IP final"
        Write-Host "   IP inicial: $ipInicial"
        Write-Host "   IP final: $ipFinal"
        return $false
    }
    
    return $true
}

function Validar-Gateway {
    param([string]$gateway, [string]$ipInicial, [string]$ipFinal)
    
    $segmentoGateway = ($gateway -split '\.')[0..2] -join '.'
    $segmentoRango = ($ipInicial -split '\.')[0..2] -join '.'
    
    if ($segmentoGateway -ne $segmentoRango) {
        Write-Host "Error: El Gateway debe estar en el mismo segmento de red"
        Write-Host "   Gateway: $gateway (segmento: $segmentoGateway.X)"
        Write-Host "   Rango: $segmentoRango.X"
        return $false
    }
    
    $octetoGw = [int]($gateway -split '\.')[-1]
    $octetoIni = [int]($ipInicial -split '\.')[-1]
    $octetoFin = [int]($ipFinal -split '\.')[-1]
    
    if ($octetoGw -ge $octetoIni -and $octetoGw -le $octetoFin) {
        Write-Host "Error El Gateway no debe estar dentro del rango DHCP"
        Write-Host "   Gateway: $gateway"
        Write-Host "   Rango DHCP: $ipInicial - $ipFinal"
        return $false
    }
    
    return $true
}

function Validar-NoBroadcast {
    param([string]$ip)
    
    if ($ip -eq "255.255.255.255") {
        Write-Host "Error: No se puede usar la ip de broadcast"
        return $false
    }
    
    return $true
}

function Validar-MismoSegmento {
    param([string]$ip1, [string]$ip2)
    
    $segmento1 = ($ip1 -split '\.')[0..2] -join '.'
    $segmento2 = ($ip2 -split '\.')[0..2] -join '.'
    
    if ($segmento1 -ne $segmento2) {
        Write-Host "Error las IPs deben estar en el mismo segmento de red"
        Write-Host "   IP1: $ip1 (segmento: $segmento1.X)"
        Write-Host "   IP2: $ip2 (segmento: $segmento2.X)"
        return $false
    }
    
    return $true
}

function Validar-NoCero {
    param([string]$ip)
    
    if ($ip -eq "0.0.0.0") {
        Write-Host "Error: No se puede usar la IP 0.0.0.0"
        return $false
    }
    
    return $true
}

# Funciones de solicitud de datos
function Solicitar-ScopeName {
    Write-Host ""
    $script:scopeName = Read-Host "Ingrese el nombre del ambito"
    
    while ([string]::IsNullOrWhiteSpace($script:scopeName)) {
        Write-Host "El nombre del ambito no puede estar vacio"
        $script:scopeName = Read-Host "Ingrese el nombre del ambito"
    }
    
    Write-Host "Scope: $script:scopeName"
}

function Solicitar-RangoIPs {
    Write-Host ""
    Write-Host "Configuracion de rangos"
    
    while ($true) {
        $script:ipInicial = Read-Host "ingrese la IP inical del rango"
        
        if ([string]::IsNullOrWhiteSpace($script:ipInicial)) {
            Write-Host "la IP inical no puede estar vacia"
            continue
        }
        
        if (-not (Validar-IP $script:ipInicial)) { continue }
        if (-not (Validar-NoLoopback $script:ipInicial)) { continue }
        if (-not (Validar-NoBroadcast $script:ipInicial)) { continue }
        if (-not (Validar-NoCero $script:ipInicial)) { continue }
        
        Write-Host "IP INICIAL : $script:ipInicial"
        break
    }
    
    while ($true) {
        $script:ipFinal = Read-Host "Ingrese la IP final del rango"
        
        if ([string]::IsNullOrWhiteSpace($script:ipFinal)) {
            Write-Host "La IP final no puede estar vacia"
            continue
        }
        
        if (-not (Validar-IP $script:ipFinal)) { continue }
        if (-not (Validar-NoLoopback $script:ipFinal)) { continue }
        if (-not (Validar-NoBroadcast $script:ipFinal)) { continue }
        if (-not (Validar-MismoSegmento $script:ipInicial $script:ipFinal)) { continue }
        if (-not (Validar-Rango $script:ipInicial $script:ipFinal)) { continue }
        if (-not (Validar-NoCero $script:ipFinal)) { continue }
        
        Write-Host "IP final: $script:ipFinal"
        break
    }
}

function Solicitar-LeaseTime {
    Write-Host ""
    Write-Host "--- Tiempo de Concesion (Lease Time) ---"
    
    while ($true) {
        $input = Read-Host "Ingrese el tiempo de concesion en segundos"
        
        if ([string]::IsNullOrWhiteSpace($input)) {
            Write-Host "Error: el tiempo de concesion no puede estar vacio"
            continue
        }
        
        if ($input -notmatch '^\d+$') {
            Write-Host "Error debe ingresar un numero valido"
            continue
        }
        
        $script:leaseTime = [int]$input
        
        if ($script:leaseTime -le 0) {
            Write-Host "Error el tiempo debe ser mayor a 0 segundos"
            continue
        }
        
        Write-Host "Lease time: $script:leaseTime segundos"
        break
    }
}

function Solicitar-Gateway {
    Write-Host ""
    Write-Host "--- Gateway/Router (Opcional) ---"
    
    while ($true) {
        $script:gateway = Read-Host "Ingrese la direccion IP del Gateway [Enter para omitir]"
        
        if ([string]::IsNullOrWhiteSpace($script:gateway)) {
            $script:gateway = ""
            break
        }
        
        if (-not (Validar-IP $script:gateway)) { continue }
        if (-not (Validar-NoLoopback $script:gateway)) { continue }
        if (-not (Validar-NoBroadcast $script:gateway)) { continue }
        if (-not (Validar-Gateway $script:gateway $script:ipInicial $script:ipFinal)) { continue }
        if (-not (Validar-NoCero $script:gateway)) { continue }
        
        Write-Host "Gateway: $script:gateway"
        break
    }
}

function Solicitar-DNS {
    Write-Host ""
    Write-Host "--- Servidor DNS (Opcional) ---"
    Write-Host "Puede ingresar hasta 2 servidores DNS"
    
    while ($true) {
        $script:dns1 = Read-Host "Ingrese DNS primario [Enter para omitir]"
        
        if ([string]::IsNullOrWhiteSpace($script:dns1)) {
            $script:dns1 = ""
            $script:dns2 = ""
            Write-Host "Sin DNS configurado"
            break
        }
        
        if (-not (Validar-IP $script:dns1)) { continue }
        if (-not (Validar-NoLoopback $script:dns1)) { continue }
        if (-not (Validar-NoBroadcast $script:dns1)) { continue }
        if (-not (Validar-NoCero $script:dns1)) { continue }
        
        Write-Host "DNS primario: $script:dns1"
        break
    }
    
    if (-not [string]::IsNullOrWhiteSpace($script:dns1)) {
        while ($true) {
            $script:dns2 = Read-Host "Ingrese DNS secundario [Enter para omitir]"
            
            if ([string]::IsNullOrWhiteSpace($script:dns2)) {
                $script:dns2 = ""
                break
            }
            
            if (-not (Validar-IP $script:dns2)) { continue }
            if (-not (Validar-NoLoopback $script:dns2)) { continue }
            if (-not (Validar-NoBroadcast $script:dns2)) { continue }
            if (-not (Validar-NoCero $script:dns2)) { continue }
            
            if ($script:dns2 -eq $script:dns1) {
                Write-Host "Error: El DNS secundario debe ser diferente al primario"
                continue
            }
            
            Write-Host "DNS secundario: $script:dns2"
            break
        }
    }
}

function Aplicar-Configuracion {
    Write-Host ""
    Write-Host "Aplicando configuracion..."
    
    if (-not (Calcular-Mascara $script:ipInicial $script:ipFinal)) {
        Write-Host "Error al calcular la mascara de red"
        return
    }
    
    Write-Host "Mascara calculada: $script:mascara (/$script:cidr)"
    Write-Host "Red base: $script:redBase"
    
    Write-Host "Configurando interfaz de red Ethernet 2..."
    
    try {
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
        $adapter = $adapters | Where-Object { $_.Name -like "*Ethernet*2*" }
        
        if (-not $adapter) {
            $adapter = $adapters[1]
        }
        
        if (-not $adapter) {
            Write-Host "Error: No se encontro un adaptador de red valido"
            return
        }
        
        Remove-NetIPAddress -InterfaceAlias $adapter.Name -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
        
        New-NetIPAddress -InterfaceAlias $adapter.Name -IPAddress ([ipaddress]$script:ipInicial) -PrefixLength $script:cidr -ErrorAction Stop | Out-Null
        
        Write-Host "Interfaz configurada con IP: $script:ipInicial/$script:cidr"
        
        Write-Host "Creando archivo de configuracion DHCP..."
        
        $octetos = $script:ipInicial -split '\.'
        $octeto4Inicial = [int]$octetos[-1]
        $octeto4RangoInicio = $octeto4Inicial + 1
        $segmento = $octetos[0..2] -join '.'
        $rangoInicio = [ipaddress]"$segmento.$octeto4RangoInicio"
        
        # ScopeId correcto y evitar scopes duplicados ---
        $scopeId = [ipaddress]$script:redBase
        $existingScope = Get-DhcpServerv4Scope -ErrorAction SilentlyContinue | Where-Object { $_.ScopeId -eq $scopeId }

        if ($existingScope) {
            Write-Host "El scope $($scopeId.IPAddressToString) ya existe. Activandolo/actualizandolo..."
            Set-DhcpServerv4Scope -ScopeId $scopeId -State Active -LeaseDuration (New-TimeSpan -Seconds $script:leaseTime) -ErrorAction Stop
        } else {
            Add-DhcpServerv4Scope -Name $script:scopeName `
                -StartRange $rangoInicio `
                -EndRange ([ipaddress]$script:ipFinal) `
                -SubnetMask $script:mascara `
                -State Active `
                -LeaseDuration (New-TimeSpan -Seconds $script:leaseTime) `
                -ErrorAction Stop
        }
        
        # Usar $scopeId para las opciones ---
        if (-not [string]::IsNullOrWhiteSpace($script:gateway)) {
            Set-DhcpServerv4OptionValue -ScopeId $scopeId -Router ([ipaddress]$script:gateway) -ErrorAction Stop
        }
        
        if (-not [string]::IsNullOrWhiteSpace($script:dns1)) {
            if (-not [string]::IsNullOrWhiteSpace($script:dns2)) {
                Set-DhcpServerv4OptionValue -ScopeId $scopeId -DnsServer ([ipaddress]$script:dns1),([ipaddress]$script:dns2) -ErrorAction Stop
            } else {
                Set-DhcpServerv4OptionValue -ScopeId $scopeId -DnsServer ([ipaddress]$script:dns1) -ErrorAction Stop
            }
        }
        
        Write-Host "Configuracion de interfaz creada"
        Write-Host "Servicio systemd configurado"
        Write-Host "Habilitando servicio DHCP..."
        Write-Host "Iniciando servicio DHCP..."
        
        Start-Sleep -Seconds 3
        
        $service = Get-Service -Name DHCPServer -ErrorAction SilentlyContinue
        
        if ($service -and $service.Status -eq 'Running') {
            Write-Host ""
            Write-Host "============================================"
            Write-Host "   Configuracion aplicada exitosamente      "
            Write-Host "============================================"
            Write-Host "Servidor DHCP activo y funcionando"
            Write-Host ""
            Write-Host "Detalles de la configuracion:"
            Write-Host "  - Interfaz: $($adapter.Name)"
            Write-Host "  - IP del servidor: $script:ipInicial/$script:cidr"
            Write-Host "  - Rango DHCP: $($rangoInicio.IPAddressToString) - $script:ipFinal"
            Write-Host "  - Mascara: $script:mascara"
            Write-Host "============================================"
        } else {
            Write-Host ""
            Write-Host "============================================"
            Write-Host "   ERROR: El servicio DHCP no inicio       "
            Write-Host "============================================"
        }
    } catch {
        Write-Host "Error: $($_.Exception.Message)"
    }

    # Dejar activo SOLO el scope actual (scopeId) y desactivar los demás
    $allScopes = Get-DhcpServerv4Scope -ErrorAction SilentlyContinue
    foreach ($s in $allScopes) {
        if ($s.ScopeId -ne $scopeId -and $s.State -eq 'Active') {
            Set-DhcpServerv4Scope -ScopeId $s.ScopeId -State Inactive -ErrorAction SilentlyContinue
            Write-Host "Scope desactivado: $($s.ScopeId)"
        }
    }
}

function Calcular-Mascara {
    param([string]$ip1, [string]$ip2)
    
    $o1 = $ip1 -split '\.'
    $o2 = $ip2 -split '\.'
    
    if ($o1[0] -eq $o2[0] -and $o1[1] -eq $o2[1] -and $o1[2] -eq $o2[2]) {
        $script:mascara = "255.255.255.0"
        $script:cidr = "24"
        $script:redBase = "$($o1[0]).$($o1[1]).$($o1[2]).0"
    }
    elseif ($o1[0] -eq $o2[0] -and $o1[1] -eq $o2[1]) {
        $script:mascara = "255.255.0.0"
        $script:cidr = "16"
        $script:redBase = "$($o1[0]).$($o1[1]).0.0"
    }
    elseif ($o1[0] -eq $o2[0]) {
        $script:mascara = "255.0.0.0"
        $script:cidr = "8"
        $script:redBase = "$($o1[0]).0.0.0"
    }
    else {
        Write-Host "Error: Las IPs no estan en la misma red"
        return $false
    }
    
    return $true
}

# Funcion para mostrar el menu
function Menu {
    Clear-Host
    Write-Host "____________________________________________"
    Write-Host "          Gestor Servidor DHCP             "
    Write-Host "____________________________________________"
    Write-Host " 1. Verificar instalacion                  "
    Write-Host " 2. Instalar servidor                      "
    Write-Host " 3. Configurar DHCP                        "
    Write-Host " 4. Monitorear Concesiones activas         "
    Write-Host " 5. Monitorear estado del servidor         "
    Write-Host " 6. Apagar servidor DHCP                   "
    Write-Host " 0. Salir del menu                         "
    Write-Host "____________________________________________"
}

function Verificar-DHCP {
    Write-Host "Verificando servidor DHCP"
    
    $dhcp = Get-WindowsFeature -Name DHCP -ErrorAction SilentlyContinue
    
    if ($dhcp -and $dhcp.Installed) {
        Write-Host "El servidor DHCP esta instalado"
        Write-Host ""
        $respuesta = Read-Host "Desea reinstalarlo y eliminar configuracion actual? (s/n)"
        
        if ($respuesta -ne "s" -and $respuesta -ne "S") {
            Write-Host "Reinstalacion cancelada"
            return
        }
        
        Write-Host "Procediendo con la reinstalacion"
        
        Stop-Service -Name DHCPServer -Force -ErrorAction SilentlyContinue
        Get-DhcpServerv4Scope | Remove-DhcpServerv4Scope -Force -ErrorAction SilentlyContinue
        Uninstall-WindowsFeature -Name DHCP -IncludeManagementTools -ErrorAction SilentlyContinue | Out-Null
        
        Get-WindowsFeature -Name DHCP
    } else {
        Write-Host "el servidor DHCP no esta instalado"
    }
}

function Instalar-DHCP {
    Write-Host "Instalacion Servidor DHCP"
    
    $dhcp = Get-WindowsFeature -Name DHCP -ErrorAction SilentlyContinue
    
    if ($dhcp -and $dhcp.Installed) {
        Write-Host "El servidor DHCP ya esta instalado"
        return
    }
    
    Write-Host "Realizando instalacion"
    
    Install-WindowsFeature -Name DHCP -IncludeManagementTools | Out-Null
    
    $dhcp = Get-WindowsFeature -Name DHCP -ErrorAction SilentlyContinue
    
    if ($dhcp -and $dhcp.Installed) {
        Write-Host "Instalacion Completada"
    } else {
        Write-Host "Error: Instalacion Fallida"
    }
}

function Configurar-DHCP {
    Write-Host "============================================"
    Write-Host "    Configuracion del servidor DHCP        "
    Write-Host "============================================"
    
    Solicitar-ScopeName
    Solicitar-RangoIPs
    Solicitar-LeaseTime
    Solicitar-Gateway
    Solicitar-DNS
    
    if (-not (Calcular-Mascara $script:ipInicial $script:ipFinal)) {
        Write-Host "Error al calcular la mascara de red"
        return
    }
    
    Write-Host ""
    Write-Host "============================================"
    Write-Host "    RESUMEN DE CONFIGURACION               "
    Write-Host "============================================"
    Write-Host "Scope: $script:scopeName"
    Write-Host "IP del servidor: $script:ipInicial/$script:cidr"
    Write-Host "Mascara de red: $script:mascara"
    Write-Host "Red base: $script:redBase"
    Write-Host "Rango DHCP: $script:ipInicial - $script:ipFinal"
    Write-Host "Lease time: $script:leaseTime segundos"
    
    if (-not [string]::IsNullOrWhiteSpace($script:gateway)) {
        Write-Host "Gateway: $script:gateway"
    } else {
        Write-Host "Gateway: (no configurado)"
    }
    
    if (-not [string]::IsNullOrWhiteSpace($script:dns1)) {
        Write-Host "DNS primario: $script:dns1"
        if (-not [string]::IsNullOrWhiteSpace($script:dns2)) {
            Write-Host "DNS secundario: $script:dns2"
        }
    } else {
        Write-Host "DNS: (no configurado)"
    }
    
    Write-Host "============================================"
    Write-Host ""
    
    $confirmar = Read-Host "Desea aplicar esta configuracion? (s/n)"
    
    if ($confirmar -ne "s" -and $confirmar -ne "S") {
        Write-Host "Configuracion cancelada"
        return
    }
    
    Aplicar-Configuracion
    
    Write-Host "-------------------------------------------"
}

function Monitorear-Concesiones {
    Write-Host "-------------------------------------------"
    Write-Host "    Monitoreo de Concesiones Activas       "
    Write-Host "-------------------------------------------"
    
    $service = Get-Service -Name DHCPServer -ErrorAction SilentlyContinue
    
    if (-not $service -or $service.Status -ne 'Running') {
        Write-Host "Error: El servicio DHCP no esta activo"
        Write-Host "Inicie el servicio primero (opcion 3)"
        return
    }
    
    Write-Host ""
    Write-Host "Concesiones activas:"
    Write-Host "--------------------------------------------"
    
    try {
        $scopes = Get-DhcpServerv4Scope -ErrorAction Stop
        
        if ($scopes.Count -eq 0) {
            Write-Host "No hay concesiones activas en este momento"
            Write-Host "============================================"
            return
        }
        
        $total = 0
        
        foreach ($scope in $scopes) {
            $leases = Get-DhcpServerv4Lease -ScopeId $scope.ScopeId -ErrorAction SilentlyContinue
            
            if ($leases) {
                foreach ($lease in $leases) {
                    Write-Host "IP asignada: $($lease.IPAddress)"
                    $total++
                }
            }
        }
        
        Write-Host "--------------------------------------------"
        Write-Host " Total de concesiones activas: $total"
        Write-Host "--------------------------------------------"
    } catch {
        Write-Host "No hay concesiones activas en este momento"
        Write-Host "============================================"
    }
}

function Monitorear-Estado {
    Write-Host "-------------------------------------------"
    Write-Host "    Estado del Servidor DHCP               "
    Write-Host "-------------------------------------------"
    
    $dhcp = Get-WindowsFeature -Name DHCP -ErrorAction SilentlyContinue
    
    if (-not $dhcp -or -not $dhcp.Installed) {
        Write-Host "El servidor DHCP NO esta instalado"
        Write-Host "Use la opcion 2 para instalarlo"
        return
    }
    
    Write-Host "Paquete: dhcp - INSTALADO"
    Write-Host ""
    
    Write-Host "Estado del servicio:"
    Write-Host "--------------------------------------------"
    
    $service = Get-Service -Name DHCPServer -ErrorAction SilentlyContinue
    
    if ($service -and $service.Status -eq 'Running') {
        Write-Host "Estado: ACTIVO"
        Write-Host "El servidor DHCP esta funcionando correctamente"
    } else {
        Write-Host "Estado: INACTIVO"
        Write-Host "El servidor DHCP NO esta corriendo"
    }
    
    Write-Host ""
    
    if ($service -and $service.StartType -eq 'Automatic') {
        Write-Host "Inicio automatico: HABILITADO"
    } else {
        Write-Host "Inicio automatico: DESHABILITADO"
    }
    
    Write-Host ""
    Write-Host "--------------------------------------------"
    Write-Host "Informacion detallada del servicio:"
    Write-Host ""
    
    if ($service) {
        $service | Format-List Name, Status, StartType
    }
    
    Write-Host "--------------------------------------------"
}

function Apagar-Servidor {
    Write-Host "============================================"
    Write-Host "    Apagar Servidor DHCP                   "
    Write-Host "============================================"
    
    $service = Get-Service -Name DHCPServer -ErrorAction SilentlyContinue
    
    if (-not $service -or $service.Status -ne 'Running') {
        Write-Host "El servidor DHCP ya esta detenido"
        return
    }
    
    Write-Host ""
    $confirmar = Read-Host "Esta seguro que desea detener el servidor DHCP? (s/n)"
    
    if ($confirmar -ne "s" -and $confirmar -ne "S") {
        Write-Host "Operacion cancelada"
        return
    }
    
    Write-Host ""
    Write-Host "Deteniendo servidor DHCP..."
    
    Stop-Service -Name DHCPServer -Force
    
    $service = Get-Service -Name DHCPServer -ErrorAction SilentlyContinue
    
    if ($service.Status -ne 'Running') {
        Write-Host "Servidor DHCP detenido exitosamente"
        
        Write-Host ""
        $deshabilitar = Read-Host "Desea deshabilitar el inicio automatico? (s/n)"
        
        if ($deshabilitar -eq "s" -or $deshabilitar -eq "S") {
            Set-Service -Name DHCPServer -StartupType Manual
            Write-Host "Inicio automatico deshabilitado"
        }
    } else {
        Write-Host "Error: No se pudo detener el servidor DHCP"
    }
    
    Write-Host "============================================"
}

# Variables globales
$script:scopeName = ""
$script:ipInicial = ""
$script:ipFinal = ""
$script:leaseTime = 0
$script:gateway = ""
$script:dns1 = ""
$script:dns2 = ""
$script:mascara = ""
$script:cidr = ""
$script:redBase = ""

# Verificar permisos de administrador
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Este script debe ejecutarse como Administrador"
    Read-Host "Presione Enter para salir"
    exit
}

# Bucle principal
while ($true) {
    Menu
    $opcion = Read-Host "Selecione una opcion"
    
    switch ($opcion) {
        "1" { Verificar-DHCP }
        "2" { Instalar-DHCP }
        "3" { Configurar-DHCP }
        "4" { Monitorear-Concesiones }
        "5" { Monitorear-Estado }
        "6" { Apagar-Servidor }
        "0" { Write-Host "saliendo"; exit 0 }
        default { Write-Host "opcion invalida" }
    }
    
    Read-Host "presiona enter para continuar"
}