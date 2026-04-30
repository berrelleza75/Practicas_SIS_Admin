$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\..\Modulos\powershell\funciones_comunes.ps1"
. "$scriptDir\..\Modulos\powershell\funciones_ftp.ps1"

function VerificarInstalacion {
    Write-Host ""
    Write-Host "=================================================="
    Write-Host " VERIFICACION DEL SERVIDOR FTP"
    Write-Host "=================================================="
    
    $todoOK = $true

    # Verificar caracteristicas de Windows
    $ftpFeature = Get-WindowsFeature -Name Web-FTP-Server
    if ($ftpFeature.InstallState -eq "Installed") {
        Write-Host "[OK] Servicio FTP de IIS instalado"
    } else {
        Write-Host "[FALTA] Servicio FTP de IIS NO instalado"
        $todoOK = $false
    }

    # Verificar carpetas base
    $rutas = @("C:\FTP", "C:\FTP\grupos", "C:\FTP\grupos\reprobados", "C:\FTP\grupos\recursadores", "C:\FTP\LocalUser\Public\general")
    foreach ($r in $rutas) {
        if (Test-Path $r) {
            Write-Host "[OK] Carpeta existe: $r"
        } else {
            Write-Host "[FALTA] Carpeta no existe: $r"
            $todoOK = $false
        }
    }

    # Verificar grupos
    $ADSI = [ADSI]"WinNT://$env:ComputerName"
    foreach ($g in @("reprobados", "recursadores")) {
        if ($ADSI.Children | Where-Object { $_.SchemaClassName -eq 'Group' -and $_.Name -eq $g }) {
            Write-Host "[OK] Grupo existe: $g"
        } else {
            Write-Host "[FALTA] Grupo no existe: $g"
            $todoOK = $false
        }
    }

    # Verificar firewall
    if (Get-NetFirewallRule -DisplayName "FTP_Practica" -ErrorAction SilentlyContinue) {
        Write-Host "[OK] Regla de firewall FTP_Practica existe"
    } else {
        Write-Host "[FALTA] Regla de firewall FTP_Practica no existe"
        $todoOK = $false
    }
    if (Get-NetFirewallRule -DisplayName "FTP_Pasivo" -ErrorAction SilentlyContinue) {
        Write-Host "[OK] Regla de firewall FTP_Pasivo existe"
    } else {
        Write-Host "[FALTA] Regla de firewall FTP_Pasivo no existe"
        $todoOK = $false
    }

    # Verificar sitio FTP en IIS
    Import-Module WebAdministration -ErrorAction SilentlyContinue
    if (Get-WebSite -Name "FTP" -ErrorAction SilentlyContinue) {
        Write-Host "[OK] Sitio FTP existe en IIS"
        $estado = (Get-WebSite -Name "FTP").State
        Write-Host "     Estado del sitio: $estado"
    } else {
        Write-Host "[FALTA] Sitio FTP no existe en IIS"
        $todoOK = $false
    }

    # Verificar servicio FTP corriendo
    $ftpsvc = Get-Service ftpsvc -ErrorAction SilentlyContinue
    if ($ftpsvc -and $ftpsvc.Status -eq "Running") {
        Write-Host "[OK] Servicio ftpsvc esta corriendo"
    } else {
        Write-Host "[FALTA] Servicio ftpsvc no esta corriendo"
        $todoOK = $false
    }

    Write-Host "=================================================="
    if ($todoOK) {
        Write-Host " RESULTADO: Todo esta instalado y configurado correctamente"
    } else {
        Write-Host " RESULTADO: Hay elementos faltantes. Use la opcion 2 para configurar."
    }
    Write-Host "=================================================="
}

function ConfigurarEInstalarServidor {
    Write-Host ""
    Write-Host "=================================================="
    Write-Host " CONFIGURACION INICIAL DEL SERVIDOR FTP (IIS)"
    Write-Host "=================================================="

    # 1. Instalar FTP
    Write-Host "Instalando IIS y Servicio FTP..."
    Install-WindowsFeature Web-Server, Web-FTP-Server -IncludeManagementTools | Out-Null

    # 2. Crear carpetas base
    Write-Host "Creando estructura de directorios..."
    $rutas = @(
        "C:\FTP",
        "C:\FTP\grupos",
        "C:\FTP\grupos\recursadores",
        "C:\FTP\grupos\reprobados",
        "C:\FTP\LocalUser",
        "C:\FTP\LocalUser\Public",
        "C:\FTP\LocalUser\Public\general"
    )
    foreach ($ruta in $rutas) {
        if (-not (Test-Path $ruta)) {
            New-Item -Path $ruta -ItemType Directory -Force | Out-Null
        }
    }

    # 3. Crear grupos del sistema
    Write-Host "Verificando grupos del sistema..."
    $ADSI = [ADSI]"WinNT://$env:ComputerName"
    $gruposNecesarios = @("reprobados", "recursadores")
    foreach ($g in $gruposNecesarios) {
        if (-not ($ADSI.Children | Where-Object { $_.SchemaClassName -eq 'Group' -and $_.Name -eq $g })) {
            $nuevoGrupo = $ADSI.Create("Group", $g)
            $nuevoGrupo.SetInfo()
        }
    }

    # 4. Permisos NTFS
    Write-Host "Configurando llaves de acceso para los grupos..."
    $grupos = @("reprobados", "recursadores")
    $sidAdministradores = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
    $sidUsuarios = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-545")

    $AclRoot = Get-Acl "C:\FTP"
    $AccessRuleRoot = New-Object System.Security.AccessControl.FileSystemAccessRule($sidUsuarios, "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")
    $AclRoot.SetAccessRule($AccessRuleRoot)
    Set-Acl "C:\FTP" $AclRoot

    foreach ($g in $grupos) {
        $rutaGrupo = "C:\FTP\grupos\$g"
        $acl = Get-Acl $rutaGrupo
        $acl.SetAccessRuleProtection($true, $false)
        $adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule($sidAdministradores, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        $acl.AddAccessRule($adminRule)
        $groupRule = New-Object System.Security.AccessControl.FileSystemAccessRule($g, "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
        $acl.AddAccessRule($groupRule)
        Set-Acl $rutaGrupo $acl
    }
    Write-Host "Seguridad NTFS aplicada correctamente."

    $AclGeneral = Get-Acl "C:\FTP\LocalUser\Public\general"
    $AccessRuleGen = New-Object System.Security.AccessControl.FileSystemAccessRule($sidUsuarios, "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
    $AclGeneral.SetAccessRule($AccessRuleGen)
    Set-Acl "C:\FTP\LocalUser\Public\general" $AclGeneral

    # 5. Firewall
    Write-Host "Configurando Firewall..."
    if (-not (Get-NetFirewallRule -DisplayName "FTP_Practica" -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName "FTP_Practica" -Direction Inbound -Protocol TCP -LocalPort 21 -Action Allow | Out-Null
    }
    if (-not (Get-NetFirewallRule -DisplayName "FTP_Pasivo" -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName "FTP_Pasivo" -Direction Inbound -Protocol TCP -LocalPort 50000-50100 -Action Allow | Out-Null
    }

    # 6. Crear sitio FTP
    Write-Host "Configurando Sitio FTP en IIS..."
    Import-Module WebAdministration
    if (-not (Get-WebSite -Name "FTP" -ErrorAction SilentlyContinue)) {
        New-WebFtpSite -Name "FTP" -Port 21 -PhysicalPath "C:\FTP" -Force | Out-Null
    }

    Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/siteDefaults/ftpServer/userIsolation" -Name "mode" -Value "IsolateAllDirectories"

    Set-WebConfigurationProperty -Filter "/system.ftpServer/firewallSupport" -Name "lowDataChannelPort" -Value 50000 -PSPath "MACHINE/WEBROOT/APPHOST"
    Set-WebConfigurationProperty -Filter "/system.ftpServer/firewallSupport" -Name "highDataChannelPort" -Value 50100 -PSPath "MACHINE/WEBROOT/APPHOST"

    # 7. Reglas de autorizacion y autenticacion
    Write-Host "Aplicando reglas de seguridad IIS..."
    Remove-WebConfigurationProperty -Filter "/system.ftpServer/security/authorization" -Name "." -Location "FTP" -ErrorAction SilentlyContinue

    Add-WebConfiguration "/system.ftpServer/security/authorization" -PSPath "IIS:\" -Value @{ accessType = "Allow"; users = "IUSR"; permissions = 1 } -Location "FTP"
    Add-WebConfiguration "/system.ftpServer/security/authorization" -PSPath "IIS:\" -Value @{ accessType = "Allow"; roles = "reprobados,recursadores"; permissions = 3 } -Location "FTP"

    Set-ItemProperty -Path "IIS:\Sites\FTP" -Name ftpServer.security.authentication.anonymousAuthentication.enabled -Value $true
    Set-ItemProperty -Path "IIS:\Sites\FTP" -Name ftpServer.security.authentication.anonymousAuthentication.userName -Value "IUSR"
    Set-ItemProperty -Path "IIS:\Sites\FTP" -Name ftpServer.security.authentication.anonymousAuthentication.password -Value ""

    Set-ItemProperty -Path "IIS:\Sites\FTP" -Name ftpServer.security.authentication.basicAuthentication.enabled -Value $true
    Set-ItemProperty -Path "IIS:\Sites\FTP" -Name "ftpServer.security.ssl.controlChannelPolicy" -Value 0
    Set-ItemProperty -Path "IIS:\Sites\FTP" -Name "ftpServer.security.ssl.dataChannelPolicy" -Value 0

    Restart-Service ftpsvc -Force
    Restart-WebItem "IIS:\Sites\FTP"
    Write-Host "Servidor FTP configurado exitosamente."
    Write-Host "=================================================="
}

# Menu interactivo
while ($true) {
    Write-Host ""
    Write-Host "--- GESTOR DE USUARIOS FTP (WINDOWS) ---"
    Write-Host "1. Verificar Instalacion"
    Write-Host "2. Configurar e Instalar Servidor"
    Write-Host "3. Agregar Usuarios"
    Write-Host "4. Cambiar de Grupo"
    Write-Host "5. Eliminar Usuario"
    Write-Host "6. Salir"
    $opcion = Read-Host "Elige una opcion (1-6)"

    switch ($opcion) {
        "1" { VerificarInstalacion }
        "2" { ConfigurarEInstalarServidor }
        "3" {
            $num = Read-Host "Cuantos usuarios deseas agregar?"
            for ($i = 1; $i -le [int]$num; $i++) {
                Write-Host "--- Creando usuario $i de $num ---"
                $FTPUserName = capturarUsuarioFTPValido "Coloque el nombre del usuario: "
                $FTPPassword = capturarContra
                $FTPUserGroupName = capturarGrupoFTP
                CrearUsuarioFTP -FTPUserName $FTPUserName -FTPPassword $FTPPassword -FTPUserGroupName $FTPUserGroupName
            }
        }
        "4" { CambiarGrupoFTP }
        "5" { EliminarUsuarioFTP }
        "6" {
            Write-Host "Cerrando el script. Exito con la practica."
            exit
        }
        default { Write-Host "Opcion no valida. Intenta de nuevo." }
    }
}