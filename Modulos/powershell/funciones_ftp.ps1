$FTP_ROOT = "C:\inetpub\ftproot"
$FTP_SITE = "FTP_Escolar"
$FTP_PORT = 21
$GRUPOS   = @("reprobados", "recursadores")

function Install-FTPServer {
    $features = @("Web-Server", "Web-Ftp-Server", "Web-Ftp-Service")
    foreach ($feature in $features) {
        $state = (Get-WindowsFeature -Name $feature).InstallState
        if ($state -ne "Installed") {
            Install-WindowsFeature -Name $feature -IncludeManagementTools | Out-Null
            Write-Host "[+] $feature instalado."
        } else {
            Write-Host "[OK] $feature ya instalado."
        }
    }
    if (-not (Get-Module -Name WebAdministration)) {
        Import-Module WebAdministration -ErrorAction Stop
    }
}

function Initialize-FTPDirectories {
    $dirs = @(
        $FTP_ROOT,
        "$FTP_ROOT\general",
        "$FTP_ROOT\reprobados",
        "$FTP_ROOT\recursadores",
        # Carpeta requerida para usuarios anonimos con userIsolation = 3
        "$FTP_ROOT\LocalUser\Public"
    )
    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Host "[+] Carpeta creada: $dir"
        }
    }
}

function Initialize-FTPGroups {
    foreach ($grupo in $GRUPOS) {
        if (-not (Get-LocalGroup -Name $grupo -ErrorAction SilentlyContinue)) {
            New-LocalGroup -Name $grupo -Description "Grupo FTP $grupo" | Out-Null
            Write-Host "[+] Grupo creado: $grupo"
        }
    }
}

function Initialize-FTPSite {
    Import-Module WebAdministration -ErrorAction Stop

    if (-not (Get-WebSite -Name $FTP_SITE -ErrorAction SilentlyContinue)) {
        New-WebFtpSite -Name $FTP_SITE -Port $FTP_PORT -PhysicalPath $FTP_ROOT -Force | Out-Null
        Write-Host "[+] Sitio FTP '$FTP_SITE' creado en puerto $FTP_PORT"
    }

    Set-ItemProperty "IIS:\Sites\$FTP_SITE" -Name ftpServer.security.authentication.anonymousAuthentication.enabled -Value $true
    Set-ItemProperty "IIS:\Sites\$FTP_SITE" -Name ftpServer.security.authentication.basicAuthentication.enabled   -Value $true
    Set-ItemProperty "IIS:\Sites\$FTP_SITE" -Name ftpServer.security.ssl.controlChannelPolicy -Value 0
    Set-ItemProperty "IIS:\Sites\$FTP_SITE" -Name ftpServer.security.ssl.dataChannelPolicy    -Value 0
    Set-ItemProperty "IIS:\Sites\$FTP_SITE" -Name ftpServer.userIsolation.mode -Value 3

    Start-WebSite -Name $FTP_SITE -ErrorAction SilentlyContinue
    Write-Host "[OK] Sitio FTP configurado e iniciado."
}

function Set-AnonymousAccess {
    Import-Module WebAdministration -ErrorAction Stop

    $anonPath = "$FTP_ROOT\general"
    $acl  = Get-Acl $anonPath
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        "IUSR", "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow"
    )
    $acl.SetAccessRule($rule)
    Set-Acl -Path $anonPath -AclObject $acl

    # Permisos NTFS en LocalUser\Public para que el anonimo pueda navegar con userIsolation = 3
    $publicPath = "$FTP_ROOT\LocalUser\Public"
    if (Test-Path $publicPath) {
        $aclPub  = Get-Acl $publicPath
        $rulePub = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "IUSR", "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow"
        )
        $aclPub.SetAccessRule($rulePub)
        Set-Acl -Path $publicPath -AclObject $aclPub
    }

    # Virtual directory de /general dentro de LocalUser\Public para usuario anonimo
    $vdPublicGeneral = "IIS:\Sites\$FTP_SITE\LocalUser\Public\general"
    if (-not (Test-Path $vdPublicGeneral)) {
        New-Item $vdPublicGeneral -Type VirtualDirectory -PhysicalPath "$FTP_ROOT\general" | Out-Null
        Write-Host "[+] Virtual directory anonimo creado: LocalUser\Public\general"
    }

    $filter   = "system.ftpServer/security/authorization"
    $sitePath = "IIS:\Sites\$FTP_SITE"

    # Desbloquear solo si la seccion esta bloqueada, evita inconsistencias en ejecuciones repetidas
    $appcmd    = "$env:SystemRoot\system32\inetsrv\appcmd.exe"
    $lockCheck = & $appcmd list config /section:$filter 2>&1
    if ($lockCheck -match "locked") {
        & $appcmd unlock config /section:$filter | Out-Null
    }

    $yaExiste = (Get-WebConfiguration $filter $sitePath).Collection |
                Where-Object { $_.users -eq "?" -and $_.accessType -eq "Allow" }

    if (-not $yaExiste) {
        Add-WebConfiguration -Filter $filter -PSPath $sitePath -Value @{
            accessType  = "Allow"
            users       = "?"
            permissions = "Read"
        }
        Write-Host "[+] Acceso anonimo configurado (solo lectura en /general)."
    }
}

function New-FTPUser {
    param(
        [string]$Nombre,
        [SecureString]$Password,
        [string]$Grupo
    )

    # Validar que Password sea realmente un SecureString con contenido
    if ($null -eq $Password) {
        Write-Host "[!] La contrasena no puede ser nula para '$Nombre'."
        return
    }
    $passCheck = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
    if ($passCheck -eq "") {
        Write-Host "[!] La contrasena no puede estar vacia para '$Nombre'."
        return
    }

    if (-not (Get-LocalUser -Name $Nombre -ErrorAction SilentlyContinue)) {
        New-LocalUser -Name $Nombre -Password $Password -PasswordNeverExpires -UserMayNotChangePassword | Out-Null
        Write-Host "[+] Usuario '$Nombre' creado."
    }

    $enGrupo = (Get-LocalGroupMember -Group $Grupo -ErrorAction SilentlyContinue) |
               Where-Object { $_.Name -like "*\$Nombre" -or $_.Name -eq $Nombre }
    if (-not $enGrupo) {
        Add-LocalGroupMember -Group $Grupo -Member $Nombre | Out-Null
        Write-Host "[+] '$Nombre' agregado al grupo '$Grupo'."
    }

    Set-FTPUserDirectories    -Nombre $Nombre -Grupo $Grupo
    Set-FTPVirtualDirectories -Nombre $Nombre -Grupo $Grupo
    Set-FTPUserPermissions    -Nombre $Nombre -Grupo $Grupo
    Set-FTPAuthorizationRule  -Nombre $Nombre
}

function Set-FTPUserDirectories {
    param([string]$Nombre, [string]$Grupo)

    $dirs = @(
        "$FTP_ROOT\LocalUser\$Nombre",
        "$FTP_ROOT\LocalUser\$Nombre\general",
        "$FTP_ROOT\LocalUser\$Nombre\$Grupo",
        "$FTP_ROOT\LocalUser\$Nombre\$Nombre"
    )
    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
}

function Set-FTPVirtualDirectories {
    param([string]$Nombre, [string]$Grupo)

    Import-Module WebAdministration -ErrorAction Stop

    $vdGeneral  = "IIS:\Sites\$FTP_SITE\LocalUser\$Nombre\general"
    $vdGrupo    = "IIS:\Sites\$FTP_SITE\LocalUser\$Nombre\$Grupo"
    $vdPersonal = "IIS:\Sites\$FTP_SITE\LocalUser\$Nombre\$Nombre"

    if (-not (Test-Path $vdGeneral)) {
        New-Item $vdGeneral -Type VirtualDirectory -PhysicalPath "$FTP_ROOT\general" | Out-Null
    }
    if (-not (Test-Path $vdGrupo)) {
        New-Item $vdGrupo -Type VirtualDirectory -PhysicalPath "$FTP_ROOT\$Grupo" | Out-Null
    }
    if (-not (Test-Path $vdPersonal)) {
        New-Item $vdPersonal -Type VirtualDirectory -PhysicalPath "$FTP_ROOT\LocalUser\$Nombre\$Nombre" | Out-Null
    }
}

function Set-FTPUserPermissions {
    param([string]$Nombre, [string]$Grupo)

    $inherit   = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit,ObjectInherit"
    $propagate = [System.Security.AccessControl.PropagationFlags]::None
    $tipo      = [System.Security.AccessControl.AccessControlType]::Allow

    # Solo lectura en /general, no Modify, para evitar que usuarios borren archivos compartidos
    $readRights   = [System.Security.AccessControl.FileSystemRights]"ReadAndExecute"
    $modifyRights = [System.Security.AccessControl.FileSystemRights]"Modify"

    $permisosPorRuta = @{
        "$FTP_ROOT\general"                      = $readRights
        "$FTP_ROOT\$Grupo"                       = $modifyRights
        "$FTP_ROOT\LocalUser\$Nombre\$Nombre"    = $modifyRights
    }

    foreach ($entry in $permisosPorRuta.GetEnumerator()) {
        if (Test-Path $entry.Key) {
            $acl  = Get-Acl $entry.Key
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $Nombre, $entry.Value, $inherit, $propagate, $tipo
            )
            $acl.AddAccessRule($rule)
            Set-Acl -Path $entry.Key -AclObject $acl
        }
    }
}

function Set-FTPAuthorizationRule {
    param([string]$Nombre)

    Import-Module WebAdministration -ErrorAction Stop

    $filter   = "system.ftpServer/security/authorization"
    $sitePath = "IIS:\Sites\$FTP_SITE"

    $yaExiste = (Get-WebConfiguration $filter $sitePath).Collection |
                Where-Object { $_.users -eq $Nombre -and $_.accessType -eq "Allow" }

    if (-not $yaExiste) {
        Add-WebConfiguration -Filter $filter -PSPath $sitePath -Value @{
            accessType  = "Allow"
            users       = $Nombre
            permissions = "Read,Write"
        }
    }
}

function Get-FTPUserGroup {
    param([string]$Nombre)

    foreach ($g in $GRUPOS) {
        $miembros = Get-LocalGroupMember -Group $g -ErrorAction SilentlyContinue
        $es = $miembros | Where-Object { $_.Name -like "*\$Nombre" -or $_.Name -eq $Nombre }
        if ($es) { return $g }
    }
    return $null
}

function Revoke-FTPGroupPermission {
    param([string]$Nombre, [string]$Grupo)

    $ruta = "$FTP_ROOT\$Grupo"
    if (-not (Test-Path $ruta)) { return }

    $acl     = Get-Acl $ruta
    $maquina = $env:COMPUTERNAME

    # Traduccion a SID dentro de try/catch para evitar que falle silenciosamente
    try {
        $sid = (New-Object System.Security.Principal.NTAccount("$maquina\$Nombre")).Translate(
                   [System.Security.Principal.SecurityIdentifier])
    } catch {
        Write-Host "[!] No se pudo resolver el SID de '$Nombre'. Verifica que la cuenta exista."
        return
    }

    $aEliminar = $acl.Access | Where-Object {
        try {
            $_.IdentityReference.Translate(
                [System.Security.Principal.SecurityIdentifier]).Value -eq $sid.Value
        } catch { $false }
    }
    foreach ($regla in $aEliminar) {
        $acl.RemoveAccessRule($regla) | Out-Null
    }
    Set-Acl -Path $ruta -AclObject $acl
    Write-Host "[-] Permisos de '$Nombre' revocados en '$ruta'."
}

function Set-FTPUserGroup {
    param([string]$Nombre, [string]$GrupoNuevo)

    Import-Module WebAdministration -ErrorAction Stop

    $grupoActual = Get-FTPUserGroup -Nombre $Nombre

    if (-not $grupoActual) {
        Write-Host "[!] '$Nombre' no pertenece a ningun grupo FTP conocido."
        return
    }
    if ($grupoActual -eq $GrupoNuevo) {
        Write-Host "[!] '$Nombre' ya esta en '$GrupoNuevo'."
        return
    }

    Remove-LocalGroupMember -Group $grupoActual -Member $Nombre -ErrorAction SilentlyContinue
    Write-Host "[-] Removido del grupo '$grupoActual'."

    Revoke-FTPGroupPermission -Nombre $Nombre -Grupo $grupoActual

    $vdAnterior = "IIS:\Sites\$FTP_SITE\LocalUser\$Nombre\$grupoActual"
    if (Test-Path $vdAnterior) {
        Remove-Item $vdAnterior -Recurse -Force
    }

    Add-LocalGroupMember -Group $GrupoNuevo -Member $Nombre | Out-Null
    Write-Host "[+] Agregado al grupo '$GrupoNuevo'."

    $vdNuevo = "IIS:\Sites\$FTP_SITE\LocalUser\$Nombre\$GrupoNuevo"
    if (-not (Test-Path $vdNuevo)) {
        New-Item $vdNuevo -Type VirtualDirectory -PhysicalPath "$FTP_ROOT\$GrupoNuevo" | Out-Null
    }

    $rights    = [System.Security.AccessControl.FileSystemRights]"Modify"
    $inherit   = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit,ObjectInherit"
    $propagate = [System.Security.AccessControl.PropagationFlags]::None
    $type      = [System.Security.AccessControl.AccessControlType]::Allow

    $acl  = Get-Acl "$FTP_ROOT\$GrupoNuevo"
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $Nombre, $rights, $inherit, $propagate, $type
    )
    $acl.AddAccessRule($rule)
    Set-Acl -Path "$FTP_ROOT\$GrupoNuevo" -AclObject $acl

    Write-Host "[OK] Grupo actual de '$Nombre': $GrupoNuevo"
    Write-Host "[i]  Los archivos en '$grupoActual' se conservaron pero '$Nombre' ya no tiene permisos sobre ellos."
}

function New-FTPUsersBulk {
    do {
        $nInput = Read-Host "Cuantos usuarios desea crear"
        $n = 0
        [int]::TryParse($nInput, [ref]$n) | Out-Null
        if ($n -lt 1) { Write-Host "Ingrese un numero mayor a 0." }
    } while ($n -lt 1)

    for ($i = 1; $i -le $n; $i++) {
        Write-Host "`n--- Usuario $i de $n ---"

        do {
            $nombre = (Read-Host "Nombre de usuario").Trim()
            if ($nombre -eq "") { Write-Host "No puede estar vacio." }
        } while ($nombre -eq "")

        do {
            $pass = Read-Host "Contrasena" -AsSecureString
            $passCheck = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass))
            if ($passCheck -eq "") { Write-Host "No puede estar vacia." }
        } while ($passCheck -eq "")

        do {
            $grupo = (Read-Host "Grupo (reprobados / recursadores)").Trim().ToLower()
            if ($grupo -notin $GRUPOS) { Write-Host "Grupo invalido." }
        } while ($grupo -notin $GRUPOS)

        New-FTPUser -Nombre $nombre -Password $pass -Grupo $grupo
    }
    Write-Host "`n[OK] Creacion masiva finalizada."
}