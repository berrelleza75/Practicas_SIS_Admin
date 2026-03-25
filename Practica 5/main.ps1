$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\..\Modulos\powershell\funciones_comunes.ps1"
. "$scriptDir\..\Modulos\powershell\funciones_ftp.ps1"

Test-Admin

do {
    Write-Host "`n--- MENU FTP ---"
    Write-Host "1. Instalar y configurar servidor FTP"
    Write-Host "2. Crear usuarios (masivo)"
    Write-Host "3. Crear un usuario individual"
    Write-Host "4. Cambiar grupo de un usuario"
    Write-Host "5. Consultar grupo actual de un usuario"
    Write-Host "6. Salir"

    $opcion = (Read-Host "Opcion").Trim()

    switch ($opcion) {
        "1" {
            Install-FTPServer
            Initialize-FTPDirectories
            Initialize-FTPGroups
            Initialize-FTPSite
            Set-AnonymousAccess
        }
        "2" {
            New-FTPUsersBulk
        }
        "3" {
            do {
                $nombre = (Read-Host "Nombre de usuario").Trim()
                if ($nombre -eq "") { Write-Host "No puede estar vacio." }
            } while ($nombre -eq "")

            # Leer como SecureString, no como string plano
            do {
                $pass = Read-Host "Contrasena" -AsSecureString
                $passCheck = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass))
                if ($passCheck -eq "") { Write-Host "No puede estar vacia." }
            } while ($passCheck -eq "")

            do {
                $grupo = (Read-Host "Grupo (reprobados / recursadores)").Trim().ToLower()
                if ($grupo -notin @("reprobados","recursadores")) { Write-Host "Grupo invalido." }
            } while ($grupo -notin @("reprobados","recursadores"))

            New-FTPUser -Nombre $nombre -Password $pass -Grupo $grupo
        }
        "4" {
            do {
                $nombre = (Read-Host "Nombre de usuario").Trim()
                if ($nombre -eq "") { Write-Host "No puede estar vacio." }
            } while ($nombre -eq "")

            if (-not (Get-LocalUser -Name $nombre -ErrorAction SilentlyContinue)) {
                Write-Host "[!] El usuario '$nombre' no existe."
            } else {
                $actual = Get-FTPUserGroup -Nombre $nombre
                if (-not $actual) {
                    Write-Host "[!] '$nombre' no pertenece a ningun grupo FTP conocido."
                    # Corregido: no usar break, simplemente no continuar con el cambio
                } else {
                    Write-Host "[i] Grupo actual de '$nombre': $actual"

                    do {
                        $grupoNuevo = (Read-Host "Nuevo grupo (reprobados / recursadores)").Trim().ToLower()
                        if ($grupoNuevo -notin @("reprobados","recursadores")) { Write-Host "Grupo invalido." }
                    } while ($grupoNuevo -notin @("reprobados","recursadores"))

                    Set-FTPUserGroup -Nombre $nombre -GrupoNuevo $grupoNuevo

                    $despues = Get-FTPUserGroup -Nombre $nombre
                    Write-Host "[i] Grupo actual de '$nombre': $despues"
                }
            }
        }
        "5" {
            do {
                $nombre = (Read-Host "Nombre de usuario").Trim()
                if ($nombre -eq "") { Write-Host "No puede estar vacio." }
            } while ($nombre -eq "")

            $grupo = Get-FTPUserGroup -Nombre $nombre
            if ($grupo) {
                Write-Host "[i] '$nombre' pertenece al grupo: $grupo"
            } else {
                Write-Host "[!] '$nombre' no pertenece a ningun grupo o no existe."
            }
        }
        "6" { Write-Host "Saliendo..." }
        default { Write-Host "Opcion no valida." }
    }

} while ($opcion -ne "6")