# funciones_activedirectory.ps1
# Instalacion de AD, creacion de OUs/usuarios y configuracion de horarios

$dominio     = "practica8.local"
$netbios     = "PRACTICA8"
$dcPath      = "DC=practica8,DC=local"
$ouCuates    = "OU=Cuates,$dcPath"
$ouNoCuates  = "OU=NoCuates,$dcPath"

# Recibe un arreglo de horas permitidas y genera los 21 bytes que AD entiende
function Convert-LogonHours {
    param([int[]]$horas)

    $bytes = New-Object byte[] 21

    foreach ($hora in $horas) {
        for ($dia = 0; $dia -lt 7; $dia++) {
            $bitPos  = ($dia * 24) + $hora
            $byteIdx = [math]::Floor($bitPos / 8)
            $bitIdx  = $bitPos % 8
            $bytes[$byteIdx] = $bytes[$byteIdx] -bor (1 -shl $bitIdx)
        }
    }

    return $bytes
}

function Invoke-InstalarAD {
    Write-Host ""
    Write-Host "--- Instalacion de Active Directory ---"

    # Pedir y validar IP
    do {
        $ip = Read-Host "Ingresa la IP fija del servidor"
    } while (-not (Test-IPCompleta -ip $ip))

    # Pedir gateway
    $gateway = Read-Host "Ingresa la puerta de enlace (gateway)"

    # Pedir contrasena DSRM
    $dsrmPass = Read-Host "Contrasena para el modo de recuperacion (DSRM)" -AsSecureString

    Write-Host "Adaptadores disponibles:"
    Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Format-Table Name, ifIndex -AutoSize

    $nombreAdaptador = Read-Host "Nombre del adaptador de red interna (ej. Ethernet 2)"
    $adaptador = Get-NetAdapter -Name $nombreAdaptador

    if ($null -eq $adaptador) {
        Write-Host "Adaptador no encontrado"
        return
    }

    Write-Host "Configurando IP estatica en $nombreAdaptador..."
    New-NetIPAddress -InterfaceIndex $adaptador.ifIndex -IPAddress $ip -PrefixLength 24 -DefaultGateway $gateway | Out-Null
    Set-DnsClientServerAddress -InterfaceIndex $adaptador.ifIndex -ServerAddresses $ip | Out-Null

    Write-Host "Instalando rol de Active Directory..."
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools | Out-Null

    Write-Host "Promoviendo servidor a controlador de dominio..."
    Install-ADDSForest `
        -DomainName $dominio `
        -DomainNetbiosName $netbios `
        -SafeModeAdministratorPassword $dsrmPass `
        -InstallDns `
        -Force

    Write-Host "El servidor se reiniciara para completar la instalacion"
}

function Invoke-CrearOUsUsuarios {
    param([string]$CsvPath)

    Write-Host ""
    Write-Host "--- Creacion de OUs y Usuarios ---"

    if (-not (Test-Path $CsvPath)) {
        Write-Host "No se encontro el archivo CSV en: $CsvPath"
        return
    }

    # Crear OU Cuates
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ouCuates'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name "Cuates" -Path $dcPath
        Write-Host "OU Cuates creada"
    } else {
        Write-Host "OU Cuates ya existe"
    }

    # Crear OU NoCuates
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ouNoCuates'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name "NoCuates" -Path $dcPath
        Write-Host "OU NoCuates creada"
    } else {
        Write-Host "OU NoCuates ya existe"
    }

    # Crear grupos si no existen
    foreach ($grupo in @("Cuates", "NoCuates")) {
        if (-not (Get-ADGroup -Filter "Name -eq '$grupo'" -ErrorAction SilentlyContinue)) {
            $ouGrupo = if ($grupo -eq "Cuates") { $ouCuates } else { $ouNoCuates }
            New-ADGroup -Name $grupo -GroupScope Global -GroupCategory Security -Path $ouGrupo
            Write-Host "Grupo $grupo creado"
        }
    }

    $usuarios = Import-Csv -Path $CsvPath

    foreach ($u in $usuarios) {
        $ouDestino = if ($u.Grupo -eq "Cuates") { $ouCuates } else { $ouNoCuates }
        $passSegura = ConvertTo-SecureString $u.Password -AsPlainText -Force

        if (Get-ADUser -Filter "SamAccountName -eq '$($u.Usuario)'" -ErrorAction SilentlyContinue) {
            Write-Host "Usuario $($u.Usuario) ya existe, omitiendo"
            continue
        }

        New-ADUser `
            -Name "$($u.Nombre) $($u.Apellido)" `
            -GivenName $u.Nombre `
            -Surname $u.Apellido `
            -SamAccountName $u.Usuario `
            -UserPrincipalName "$($u.Usuario)@$dominio" `
            -Path $ouDestino `
            -AccountPassword $passSegura `
            -Enabled $true

        Add-ADGroupMember -Identity $u.Grupo -Members $u.Usuario
        Write-Host "Usuario $($u.Usuario) creado en OU $($u.Grupo)"
    }

    Write-Host "Creacion de OUs y usuarios completada"
}

function Invoke-ConfigurarLogonHours {
    Write-Host ""
    Write-Host "--- Configuracion de Horarios de Acceso ---"

    # Cuates: 8:00 AM - 3:00 PM (UTC-7, se suma 7 horas)
    $horasCuates   = 15..21
    $bytesCuates   = Convert-LogonHours -horas $horasCuates

    # NoCuates: 3:00 PM - 2:00 AM (UTC-7, se suma 7 horas)
    $horasNoCuates = @(22,23,0,1,2,3,4,5,6,7,8)
    $bytesNoCuates = Convert-LogonHours -horas $horasNoCuates

    $usuariosCuates   = Get-ADUser -Filter * -SearchBase $ouCuates
    $usuariosNoCuates = Get-ADUser -Filter * -SearchBase $ouNoCuates

    foreach ($u in $usuariosCuates) {
        Set-ADUser -Identity $u.SamAccountName -Replace @{ logonHours = [byte[]]$bytesCuates }
        Write-Host "Horario aplicado a $($u.SamAccountName) (Cuates: 8AM-3PM)"
    }

    foreach ($u in $usuariosNoCuates) {
        Set-ADUser -Identity $u.SamAccountName -Replace @{ logonHours = [byte[]]$bytesNoCuates }
        Write-Host "Horario aplicado a $($u.SamAccountName) (NoCuates: 3PM-2AM)"
    }

    # GPO para forzar cierre de sesion al expirar horario
    $gpoNombre = "ForzarCierreSecion"

    if (-not (Get-GPO -Name $gpoNombre -ErrorAction SilentlyContinue)) {
        New-GPO -Name $gpoNombre | Out-Null
        Write-Host "GPO $gpoNombre creada"
    }

    Set-GPRegistryValue `
        -Name $gpoNombre `
        -Key "HKLM\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters" `
        -ValueName "EnableForcedLogOff" `
        -Type DWord `
        -Value 1 | Out-Null

    New-GPLink -Name $gpoNombre -Target $dcPath -ErrorAction SilentlyContinue | Out-Null

    Write-Host "GPO de cierre de sesion forzado aplicada al dominio"
    Write-Host "Configuracion de horarios completada"
}

function Invoke-PostReinicio {
    Write-Host ""
    Write-Host "--- Configuracion Post-Reinicio de AD ---"

    # Esperar a que el servicio de AD este listo
    Write-Host "Esperando que Active Directory este listo..."
    do {
        Start-Sleep -Seconds 5
    } while (-not (Get-Service -Name "NTDS" -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Running" }))

    # Fijar contrasena del Administrador sin forzar cambio
    $nuevaPass = Read-Host "Ingresa la contrasena definitiva del Administrador" -AsSecureString
    Set-ADAccountPassword -Identity "Administrador" -Reset -NewPassword $nuevaPass
    Set-ADUser -Identity "Administrador" -ChangePasswordAtLogon $false -PasswordNeverExpires $true

    Write-Host "Contrasena del Administrador configurada correctamente"
    Write-Host "Ya puedes unir los clientes al dominio"
}

function Invoke-CambiarHorarioUsuario {
    Write-Host ""
    Write-Host "--- Cambiar Horario de Usuario Individual ---"

    $usuario = Read-Host "Ingresa el nombre de usuario (ej. cmendoza)"

    if (-not (Get-ADUser -Filter "SamAccountName -eq '$usuario'" -ErrorAction SilentlyContinue)) {
        Write-Host "Usuario $usuario no encontrado"
        return
    }

    Write-Host "Selecciona el horario:"
    Write-Host "1. Cuates     (8:00 AM - 3:00 PM)"
    Write-Host "2. NoCuates   (3:00 PM - 2:00 AM)"
    Write-Host "3. Sin restriccion (24 horas)"

    $opcion = Read-Host "Elige una opcion"

    switch ($opcion) {
        "1" {
            $bytes = Convert-LogonHours -horas (8..14)
            Set-ADUser -Identity $usuario -Replace @{ logonHours = [byte[]]$bytes }
            Write-Host "Horario Cuates aplicado a $usuario (8AM-3PM)"
        }
        "2" {
            $bytes = Convert-LogonHours -horas @(15,16,17,18,19,20,21,22,23,0,1)
            Set-ADUser -Identity $usuario -Replace @{ logonHours = [byte[]]$bytes }
            Write-Host "Horario NoCuates aplicado a $usuario (3PM-2AM)"
        }
        "3" {
            $bytes = [byte[]](,0xFF * 21)
            Set-ADUser -Identity $usuario -Replace @{ logonHours = [byte[]]$bytes }
            Write-Host "Horario sin restriccion aplicado a $usuario"
        }
        default { Write-Host "Opcion invalida" }
    }
}