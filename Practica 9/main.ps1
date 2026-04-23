# Practica 9 - Hardening AD, RBAC, FGPP, Auditoria y MFA

$modulosPath = "$PSScriptRoot\..\Modulos\powershell"

. "$modulosPath\funciones_comunes.ps1"
. "$modulosPath\funciones_rbac.ps1"
. "$modulosPath\funciones_fgpp.ps1"
. "$modulosPath\funciones_auditoria.ps1"
. "$modulosPath\funciones_mfa.ps1"

Test-Admin

function Show-Menu {
    Clear-Host
    Write-Host "====================================="
    Write-Host "   PRACTICA 9 - HARDENING AD        "
    Write-Host "====================================="
    Write-Host "--- RBAC / Delegacion ---"
    Write-Host "1. Crear usuarios admin delegados"
    Write-Host "2. Aplicar ACLs de delegacion por rol"
    Write-Host "3. Verificar permisos delegados"
    Write-Host ""
    Write-Host "--- FGPP (Politicas de Contrasena) ---"
    Write-Host "4. Crear Fine-Grained Password Policies"
    Write-Host ""
    Write-Host "--- Auditoria ---"
    Write-Host "5. Habilitar auditoria (auditpol)"
    Write-Host "6. Exportar reporte de eventos denegados"
    Write-Host ""
    Write-Host "--- MFA ---"
    Write-Host "7. Instalar multiOTP Credential Provider (Server)"
    Write-Host "8. Registrar usuario MFA (generar QR)"
    Write-Host "9. Configurar bloqueo por MFA fallido"
    Write-Host "10. Instalar Credential Provider en cliente Win10"
    Write-Host ""
    Write-Host "0. Salir"
    Write-Host "====================================="
}

do {
    Show-Menu
    $opcion = Read-Host "Elige una opcion"

    switch ($opcion) {
        "1" { Invoke-CrearAdminsDelegados }
        "2" { Invoke-AplicarACLsDelegacion }
        "3" { Invoke-VerificarDelegacion }
        "4" { Invoke-CrearFGPP }
        "5" { Invoke-HabilitarAuditoria }
        "6" { Invoke-ExportarReporteEventos }
        "7" { Invoke-InstalarMultiOTP }
        "8" { Invoke-RegistrarUsuarioMFA }
        "9" { Invoke-ConfigurarLockoutMFA }
        "10" { Invoke-InstalarCredentialProviderCliente }
        "0" { Write-Host "Saliendo..."; break }
        default { Write-Host "Opcion invalida" }
    }

    if ($opcion -ne "0") {
        Write-Host ""
        Read-Host "Presiona Enter para continuar"
    }
} while ($opcion -ne "0")