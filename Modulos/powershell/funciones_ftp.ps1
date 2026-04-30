function validarContra {
    param ([string]$contra)
    if ($contra.Length -lt 8) { Write-Host "La contrasena debe tener al menos 8 caracteres."; return $false }
    if ($contra.Length -gt 15) { Write-Host "La contrasena no puede tener mas de 15 caracteres."; return $false }
    if ($contra -notmatch "[A-Z]") { Write-Host "La contrasena debe contener al menos una letra mayuscula."; return $false }
    if ($contra -notmatch "[a-z]") { Write-Host "La contrasena debe contener al menos una letra minuscula."; return $false }
    if ($contra -notmatch "\d") { Write-Host "La contrasena debe contener al menos un numero."; return $false }
    if ($contra -notmatch "[^a-zA-Z0-9]") { Write-Host "La contrasena debe contener al menos un caracter especial."; return $false }
    return $true
}

function capturarContra {
    $esValida = $false
    do {
        $contra = Read-Host "Ingrese la contrasena (min. 8, max 15, mayuscula, minuscula, numero, especial)"
        $esValida = validarContra -contra $contra
        if (-not $esValida) { Write-Host "La contrasena no cumple con los requisitos. Intentelo de nuevo." }
    } while (-not $esValida)
    return $contra
}

function capturarUsuarioFTPValido {
    param ([string]$mensaje)
    $caracteresPermitidos = '^[a-zA-Z0-9]+$'
    $longitudMaxima = 15
    $cadenaValida = $false
    do {
        $cadena = Read-Host $mensaje
        if (-not $cadena) { Write-Host "La cadena no puede estar vacia. Intentalo de nuevo." }
        elseif ($cadena -notmatch $caracteresPermitidos) { Write-Host "El nombre de usuario solo puede contener letras y numeros." }
        elseif ($cadena -match '^[0-9]') { Write-Host "El nombre de usuario no puede comenzar con un numero." }
        elseif ($cadena.Length -gt $longitudMaxima) { Write-Host "La cadena no puede exceder los $longitudMaxima caracteres." }
        elseif (UsuarioExiste -nombreUsuario $cadena) { Write-Host "El usuario '$cadena' ya existe. Por favor, elija otro nombre." }
        else { $cadenaValida = $true }
    } while (-not $cadenaValida)
    return $cadena
}

function UsuarioExiste {
    param ([string]$nombreUsuario)
    $ADSI = [ADSI]"WinNT://$env:ComputerName"
    $usuario = $ADSI.Children | Where-Object { $_.SchemaClassName -eq 'User' -and $_.Name -eq $nombreUsuario }
    if ($usuario) { return $true } else { return $false }
}

function capturarGrupoFTP {
    do {
        Write-Host "Ingrese el grupo del usuario 1)Reprobados  2)Recursadores: "
        $grupo = Read-Host
        if ($grupo -eq "1") { return "reprobados" }
        elseif ($grupo -eq "2") { return "recursadores" }
        else { Write-Host "Opcion no valida. Por favor, ingrese 1 o 2." }
    } while ($true)
}

function CrearUsuarioFTP {
    param (
        [string]$FTPUserName,
        [string]$FTPPassword,
        [string]$FTPUserGroupName
    )

    $ADSI = [ADSI]"WinNT://$env:ComputerName"
    $CreateUserFTPUser = $ADSI.Create("User", "$FTPUserName")
    $CreateUserFTPUser.SetPassword("$FTPPassword")
    $CreateUserFTPUser.SetInfo()

    # Marcar contrasena para que no expire y no pida cambio en primer login
    $CreateUserFTPUser.UserFlags = 0x10000
    $CreateUserFTPUser.SetInfo()
    $CreateUserFTPUser.Put("PasswordExpired", 0)
    $CreateUserFTPUser.SetInfo()

    # Forzar PasswordRequired = True
    $userObj = [ADSI]"WinNT://$env:ComputerName/$FTPUserName,user"
    $userObj.PasswordRequired = $true
    $userObj.SetInfo()

    # Asignar al grupo
    $group = [ADSI]"WinNT://$env:ComputerName/$FTPUserGroupName,group"
    $group.Invoke("Add", "WinNT://$env:ComputerName/$FTPUserName,user")

    # IIS aisla a los usuarios autenticados en C:\FTP\<NombreEquipo>\<usuario>
    $UserPath = "C:\FTP\$env:ComputerName\$FTPUserName"
    mkdir $UserPath -Force | Out-Null
    mkdir "$UserPath\$FTPUserName" -Force | Out-Null

    # Permisos NTFS para el usuario en su carpeta padre (para que IIS pueda atravesarla)
    $AclParent = Get-Acl $UserPath
    $AccessRuleParent = New-Object System.Security.AccessControl.FileSystemAccessRule($FTPUserName, "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")
    $AclParent.SetAccessRule($AccessRuleParent)
    Set-Acl $UserPath $AclParent

    # Permisos NTFS para que el usuario pueda escribir en su carpeta personal
    $Acl = Get-Acl "$UserPath\$FTPUserName"
    $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($FTPUserName, "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
    $Acl.SetAccessRule($AccessRule)
    Set-Acl "$UserPath\$FTPUserName" $Acl

    # Enlaces simbolicos a general y al grupo
    cmd /c mklink /D "$UserPath\general" "C:\FTP\LocalUser\Public\general" | Out-Null
    cmd /c mklink /D "$UserPath\$FTPUserGroupName" "C:\FTP\grupos\$FTPUserGroupName" | Out-Null

    Write-Host "Usuario $FTPUserName creado correctamente en el grupo $FTPUserGroupName."
}

function CambiarGrupoFTP {
    $FTPUserName = Read-Host "Ingrese el nombre del usuario a modificar"
    if (-not (UsuarioExiste -nombreUsuario $FTPUserName)) { Write-Host "El usuario no existe."; return }

    $ADSI = [ADSI]"WinNT://$env:ComputerName"
    $userADSI = [ADSI]"WinNT://$env:ComputerName/$FTPUserName,user"

    $gruposActuales = $userADSI.Groups() | ForEach-Object { $_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null) }
    $viejoGrupo = ""
    if ($gruposActuales -contains "reprobados") { $viejoGrupo = "reprobados" }
    elseif ($gruposActuales -contains "recursadores") { $viejoGrupo = "recursadores" }

    Write-Host "El usuario pertenece actualmente a: $viejoGrupo"
    $nuevoGrupo = capturarGrupoFTP

    if ($viejoGrupo -eq $nuevoGrupo) { Write-Host "El usuario ya pertenece a ese grupo."; return }

    if ($viejoGrupo -ne "") {
        $oldGroupADSI = [ADSI]"WinNT://$env:ComputerName/$viejoGrupo,group"
        $oldGroupADSI.Invoke("Remove", "WinNT://$env:ComputerName/$FTPUserName,user")
    }
    $newGroupADSI = [ADSI]"WinNT://$env:ComputerName/$nuevoGrupo,group"
    $newGroupADSI.Invoke("Add", "WinNT://$env:ComputerName/$FTPUserName,user")

    # Ruta correcta de aislamiento (con nombre del equipo)
    $UserPath = "C:\FTP\$env:ComputerName\$FTPUserName"
    if ($viejoGrupo -ne "") {
        $linkViejo = "$UserPath\$viejoGrupo"
        if (Test-Path $linkViejo) { cmd /c rmdir /Q $linkViejo 2>$null }
    }

    cmd /c mklink /D "$UserPath\$nuevoGrupo" "C:\FTP\grupos\$nuevoGrupo" | Out-Null

    Write-Host "Actualizando permisos en tiempo real..."
    Restart-Service ftpsvc -Force

    Write-Host "Cambio completado. El usuario $FTPUserName ahora tiene acceso a $nuevoGrupo."
}

function EliminarUsuarioFTP {
    $FTPUserName = Read-Host "Ingrese el nombre del usuario a eliminar"
    if (-not (UsuarioExiste -nombreUsuario $FTPUserName)) { Write-Host "El usuario no existe."; return }

    $ADSI = [ADSI]"WinNT://$env:ComputerName"
    $ADSI.Delete("User", $FTPUserName)

    $UserPath = "C:\FTP\$env:ComputerName\$FTPUserName"
    if (Test-Path $UserPath) {
        # Borrar enlaces simbolicos primero
        cmd /c rmdir /Q "$UserPath\general" 2>$null
        cmd /c rmdir /Q "$UserPath\reprobados" 2>$null
        cmd /c rmdir /Q "$UserPath\recursadores" 2>$null
        Remove-Item $UserPath -Recurse -Force
    }

    # Reiniciar FTP para limpiar cache
    Restart-Service ftpsvc -Force

    Write-Host "Usuario $FTPUserName eliminado completamente del servidor."
}