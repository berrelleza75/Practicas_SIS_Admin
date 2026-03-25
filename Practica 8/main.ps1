# main.ps1
# Menu principal Practica 8 - GPO y FSRM

$modulosPath = "$PSScriptRoot\..\Modulos\powershell"

. "$modulosPath\funciones_comunes.ps1"
. "$modulosPath\funciones_activedirectory.ps1"
. "$modulosPath\funciones_fsrm.ps1"
. "$modulosPath\funciones_applocker.ps1"

Test-Admin

function Show-Menu {
    Clear-Host
    Write-Host "================================="
    Write-Host "   PRACTICA 8 - MENU PRINCIPAL   "
    Write-Host "================================="
    Write-Host "1. Instalar Active Directory"
    Write-Host "2. Post-reinicio AD (fijar contrasena admin)"
    Write-Host "3. Crear OUs y usuarios desde CSV"
    Write-Host "4. Configurar horarios de acceso"
    Write-Host "5. Configurar FSRM"
    Write-Host "6. Configurar AppLocker"
    Write-Host "7. Salir"
    Write-Host "================================="
    Write-Host ""
}

do {
    Show-Menu
    $opcion = Read-Host "Elige una opcion"

    switch ($opcion) {
        "1" { Invoke-InstalarAD }
        "2" { Invoke-PostReinicio }
        "3" {
            $csvPath = Read-Host "Ruta del archivo CSV (Enter para usar usuarios.csv en la misma carpeta)"
            if ([string]::IsNullOrWhiteSpace($csvPath)) {
                $csvPath = "$PSScriptRoot\usuarios.csv"
            }
            Invoke-CrearOUsUsuarios -CsvPath $csvPath
        }
        "4" { Invoke-ConfigurarLogonHours }
        "5" { Invoke-ConfigurarFSRM }
        "6" { Invoke-ConfigurarAppLocker }
        "7" { Write-Host "Saliendo..."; break }
        default { Write-Host "Opcion invalida" }
    }

    if ($opcion -ne "7") {
        Write-Host ""
        Read-Host "Presiona Enter para continuar"
    }

} while ($opcion -ne "7")