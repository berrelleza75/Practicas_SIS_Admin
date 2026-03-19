# main_http.ps1 - Punto de entrada del sistema de aprovisionamiento HTTP
# Uso: powershell -ExecutionPolicy Bypass -File .\main_http.ps1

# $PSScriptRoot = carpeta donde vive este script (Z:\Practica 6)
# Subimos un nivel con .. para llegar a Z:\Modulos\powershell\
. "$PSScriptRoot\..\Modulos\powershell\funciones_comunes.ps1"
. "$PSScriptRoot\..\Modulos\powershell\funciones_https.ps1"

Test-Admin
Show-Banner

# Menu principal - toda la navegacion vive aqui
while ($true) {
    Write-Host ""
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "    PRACTICA 6 - Servidores HTTP      " -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "  [1] Instalar IIS"
    Write-Host "  [2] Instalar Apache Win64"
    Write-Host "  [3] Instalar Nginx para Windows"
    Write-Host "  [4] Ver estado de servicios"
    Write-Host "  [0] Salir"
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Seleccione una opcion: " -ForegroundColor White -NoNewline

    $opcion = Read-Host

    if (-not (Test-EntradaValida -Valor $opcion -Campo "Opcion")) { continue }

    switch ($opcion) {
        "1" { Install-IIS }
        "2" { Install-Apache }
        "3" { Install-Nginx }
        "4" { Show-EstadoServicios }
        "0" { Write-Info "Saliendo..."; exit 0 }
        default { Write-Err "Opcion invalida. Ingrese un numero del 0 al 4." }
    }
}