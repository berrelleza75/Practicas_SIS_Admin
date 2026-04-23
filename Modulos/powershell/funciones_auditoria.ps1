function Invoke-ExportarReporteEventos {
    # Carpeta donde se guardan los reportes
    $carpetaReportes = "$PSScriptRoot\..\..\Practica 9\Reportes"
    if (-not (Test-Path $carpetaReportes)) {
        New-Item -ItemType Directory -Path $carpetaReportes -Force | Out-Null
    }

    $fecha = Get-Date -Format "yyyyMMdd_HHmmss"
    $archivoTxt = "$carpetaReportes\AccesosDenegados_$fecha.txt"
    $archivoCsv = "$carpetaReportes\AccesosDenegados_$fecha.csv"

    Write-Host "Extrayendo ultimos 10 eventos de Acceso Denegado..." -ForegroundColor Cyan

    # Event ID 4625 = An account failed to log on
    $eventos = Get-WinEvent -FilterHashtable @{
        LogName = 'Security'
        Id      = 4625
    } -MaxEvents 10 -ErrorAction SilentlyContinue

    if (-not $eventos) {
        Write-Host "No se encontraron eventos 4625 (acceso denegado)." -ForegroundColor Yellow
        Write-Host "Tip: para generar eventos de prueba, intenta iniciar sesion con password incorrecto." -ForegroundColor Yellow
        return
    }

    # --- Reporte TXT legible ---
    $contenido = @()
    $contenido += "=============================================="
    $contenido += " REPORTE DE ACCESOS DENEGADOS"
    $contenido += " Generado: $(Get-Date)"
    $contenido += " Servidor: $env:COMPUTERNAME"
    $contenido += "=============================================="
    $contenido += ""

    $i = 1
    foreach ($ev in $eventos) {
        $contenido += "--- Evento #$i ---"
        $contenido += "Fecha      : $($ev.TimeCreated)"
        $contenido += "Event ID   : $($ev.Id)"
        $contenido += "Usuario    : $($ev.Properties[5].Value)"
        $contenido += "Dominio    : $($ev.Properties[6].Value)"
        $contenido += "Origen IP  : $($ev.Properties[19].Value)"
        $contenido += "Motivo     : $($ev.Properties[8].Value)"
        $contenido += ""
        $i++
    }

    $contenido | Out-File -FilePath $archivoTxt -Encoding UTF8

    # --- Reporte CSV (para analisis rapido) ---
    $eventos | Select-Object `
        TimeCreated,
        Id,
        @{N='Usuario';    E={$_.Properties[5].Value}},
        @{N='Dominio';    E={$_.Properties[6].Value}},
        @{N='OrigenIP';   E={$_.Properties[19].Value}},
        @{N='MotivoCode'; E={$_.Properties[8].Value}} |
        Export-Csv -Path $archivoCsv -NoTypeInformation -Encoding UTF8

    Write-Host "Reportes generados:" -ForegroundColor Green
    Write-Host "  TXT: $archivoTxt" -ForegroundColor Green
    Write-Host "  CSV: $archivoCsv" -ForegroundColor Green
    Write-Host "`nTotal de eventos exportados: $($eventos.Count)" -ForegroundColor Cyan
}
function Invoke-HabilitarAuditoria {
    Write-Host "Habilitando auditoria de eventos..." -ForegroundColor Cyan

    # Auditoria de Logon (inicio de sesion)
    auditpol /set /subcategory:"Logon" /success:enable /failure:enable | Out-Null
    Write-Host "  OK - Logon (success + failure)" -ForegroundColor Green

    # Auditoria de Account Logon (autenticacion de cuenta)
    auditpol /set /subcategory:"Credential Validation" /success:enable /failure:enable | Out-Null
    Write-Host "  OK - Credential Validation (success + failure)" -ForegroundColor Green

    # Auditoria de Object Access (acceso a objetos)
    auditpol /set /subcategory:"File System" /success:enable /failure:enable | Out-Null
    Write-Host "  OK - File System access (success + failure)" -ForegroundColor Green

    # Auditoria de cambios en cuentas (util para detectar RBAC violations)
    auditpol /set /subcategory:"User Account Management" /success:enable /failure:enable | Out-Null
    Write-Host "  OK - User Account Management (success + failure)" -ForegroundColor Green

    # Auditoria de acceso a Directory Service (AD)
    auditpol /set /subcategory:"Directory Service Access" /success:enable /failure:enable | Out-Null
    Write-Host "  OK - Directory Service Access (success + failure)" -ForegroundColor Green

    Write-Host "`nAuditoria habilitada correctamente." -ForegroundColor Cyan
    Write-Host "Los eventos se guardaran en el Visor de Eventos > Security Log." -ForegroundColor Yellow
}