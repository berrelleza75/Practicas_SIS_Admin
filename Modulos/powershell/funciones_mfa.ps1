function Invoke-InstalarMultiOTP {
    $multiotpPath  = "C:\multiOTP"
    $multiotpExe   = "$multiotpPath\windows\multiotp.exe"
    $zipUrl        = "https://download.multiotp.net/oss/update/multiotp_5.10.2.2.zip"
    $zipLocal      = "$env:TEMP\multiotp.zip"

    $cpZipUrl      = "https://download.multiotp.net/credential-provider/multiOTPCredentialProvider-5.10.2.2.zip"
    $cpZipLocal    = "$env:TEMP\multiOTPCredentialProvider.zip"
    $cpExtractDir  = "$env:TEMP\multiOTPCredentialProvider_extract"

    $serverSecret  = "P9_SecretoMFA_2026"

    $userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host " INSTALACION COMPLETA DE multiOTP" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan

    # =====================================================
    # PARTE 1: MOTOR multiOTP
    # =====================================================
    Write-Host "`n[1/2] Instalando motor multiOTP..." -ForegroundColor Yellow

    if (-not (Test-Path $multiotpPath)) {
        New-Item -ItemType Directory -Path $multiotpPath -Force | Out-Null
    }

    if (-not (Test-Path $multiotpExe)) {
        Write-Host "  Descargando motor (64 MB, tomara unos minutos)..." -ForegroundColor Yellow
        try {
            Invoke-WebRequest -Uri $zipUrl -OutFile $zipLocal -UseBasicParsing -UserAgent $userAgent
        } catch {
            Write-Host "  ERROR al descargar: $($_.Exception.Message)" -ForegroundColor Red
            return
        }

        Write-Host "  Descomprimiendo..." -ForegroundColor Yellow
        try {
            Expand-Archive -Path $zipLocal -DestinationPath $multiotpPath -Force
            Remove-Item $zipLocal -Force
        } catch {
            Write-Host "  ERROR al descomprimir: $($_.Exception.Message)" -ForegroundColor Red
            return
        }
    } else {
        Write-Host "  Motor ya instalado, saltando descarga." -ForegroundColor Yellow
    }

    if (-not (Test-Path $multiotpExe)) {
        Write-Host "  ERROR: no se encontro $multiotpExe tras la instalacion." -ForegroundColor Red
        return
    }

    Set-Location "$multiotpPath\windows"
    & $multiotpExe -config server-secret=$serverSecret | Out-Null
    & $multiotpExe -config default-request-prefix-pin=0 | Out-Null
    & $multiotpExe -config default-request-ldap-pwd=0 | Out-Null
    Write-Host "  Motor configurado correctamente." -ForegroundColor Green

    # =====================================================
    # PARTE 2: CREDENTIAL PROVIDER (ZIP con MSI adentro)
    # =====================================================
    Write-Host "`n[2/2] Instalando Credential Provider..." -ForegroundColor Yellow

    # --- Pre-requisito: Visual C++ Redistributable x64 ---
    $vcRedistUrl   = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
    $vcRedistLocal = "$env:TEMP\vc_redist.x64.exe"

    $vcInstalled = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" -ErrorAction SilentlyContinue
    if (-not $vcInstalled) {
        Write-Host "  Descargando Visual C++ Redistributable x64..." -ForegroundColor Yellow
        try {
            Invoke-WebRequest -Uri $vcRedistUrl -OutFile $vcRedistLocal -UseBasicParsing -UserAgent $userAgent
        } catch {
            Write-Host "  ERROR al descargar Visual C++: $($_.Exception.Message)" -ForegroundColor Red
            return
        }

        Write-Host "  Instalando Visual C++ Redistributable..." -ForegroundColor Yellow
        $vcProc = Start-Process -FilePath $vcRedistLocal -ArgumentList "/install","/quiet","/norestart" -Wait -PassThru
        if ($vcProc.ExitCode -eq 0 -or $vcProc.ExitCode -eq 3010) {
            Write-Host "  Visual C++ Redistributable instalado." -ForegroundColor Green
        } else {
            Write-Host "  ERROR: Visual C++ codigo de salida $($vcProc.ExitCode)" -ForegroundColor Red
            return
        }
    } else {
        Write-Host "  Visual C++ Redistributable ya esta instalado." -ForegroundColor Green
    }

    # --- Descargar ZIP del Credential Provider ---
    if (-not (Test-Path $cpZipLocal)) {
        Write-Host "  Descargando ZIP del Credential Provider (17 MB)..." -ForegroundColor Yellow
        try {
            Invoke-WebRequest -Uri $cpZipUrl -OutFile $cpZipLocal -UseBasicParsing -UserAgent $userAgent
            Write-Host "  Descarga completa." -ForegroundColor Green
        } catch {
            Write-Host "  ERROR al descargar ZIP: $($_.Exception.Message)" -ForegroundColor Red
            return
        }
    } else {
        Write-Host "  ZIP ya descargado previamente." -ForegroundColor Yellow
    }

    # --- Descomprimir ---
    Write-Host "  Descomprimiendo..." -ForegroundColor Yellow
    try {
        if (Test-Path $cpExtractDir) { Remove-Item $cpExtractDir -Recurse -Force }
        Expand-Archive -Path $cpZipLocal -DestinationPath $cpExtractDir -Force
    } catch {
        Write-Host "  ERROR al descomprimir: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    # --- Buscar el MSI dentro del ZIP ---
    $msiEncontrado = Get-ChildItem -Path $cpExtractDir -Filter "*.msi" -Recurse | Select-Object -First 1
    if (-not $msiEncontrado) {
        Write-Host "  ERROR: no se encontro ningun MSI dentro del ZIP." -ForegroundColor Red
        return
    }
    Write-Host "  MSI encontrado: $($msiEncontrado.Name)" -ForegroundColor Green

    Write-Host "`n  Ejecutando instalador del Credential Provider..." -ForegroundColor Yellow
    Write-Host "  (vera una barra de progreso)" -ForegroundColor Yellow

    $msiArgs = @(
        "/i", "`"$($msiEncontrado.FullName)`"",
        "/passive",
        "/norestart",
        "MULTIOTP_SERVICE_SERVER=127.0.0.1",
        "MULTIOTP_SERVICE_PORT=8112",
        "MULTIOTP_SERVICE_SHARED_SECRET=$serverSecret",
        "RDPONLY=0",
        "DEFAULTOTPPREFIX=0",
        "/L*v", "`"$env:TEMP\multiotp_install.log`""
    )

    $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru

    if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
        Write-Host "`n  Credential Provider instalado correctamente." -ForegroundColor Green
    } else {
        Write-Host "`n  ADVERTENCIA: codigo de salida $($proc.ExitCode)" -ForegroundColor Red
        Write-Host "  Revisa el log: $env:TEMP\multiotp_install.log" -ForegroundColor Red
        return
    }

    Write-Host "`n============================================" -ForegroundColor Cyan
    Write-Host " INSTALACION COMPLETA" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host " IMPORTANTE: No reinicies hasta registrar un usuario (opcion 8)" -ForegroundColor Yellow
}

function Invoke-RegistrarUsuarioMFA {
    $multiotpPath = "C:\multiOTP"
    $multiotpExe  = "$multiotpPath\windows\multiotp.exe"

    if (-not (Test-Path $multiotpExe)) {
        Write-Host "ERROR: multiOTP no esta instalado." -ForegroundColor Red
        Write-Host "Corre primero la opcion 7." -ForegroundColor Yellow
        return
    }

    $usuario = Read-Host "Nombre del usuario a registrar en MFA"
    if ([string]::IsNullOrWhiteSpace($usuario)) {
        Write-Host "Usuario invalido." -ForegroundColor Red
        return
    }

    $carpetaQR = "$PSScriptRoot\..\..\Practica 9\QRs"
    if (-not (Test-Path $carpetaQR)) {
        New-Item -ItemType Directory -Path $carpetaQR -Force | Out-Null
    }

    Set-Location "$multiotpPath\windows"

    # Paso 1: crear el usuario (si ya existe, salir con codigo 22)
    Write-Host "`nRegistrando $usuario en multiOTP..." -ForegroundColor Cyan
    & $multiotpExe -fastcreatenopin $usuario | Out-Null

    if ($LASTEXITCODE -eq 11) {
        Write-Host "Usuario creado correctamente." -ForegroundColor Green
    } elseif ($LASTEXITCODE -eq 22) {
        Write-Host "Usuario ya existia, se usara su configuracion actual." -ForegroundColor Yellow
    } else {
        Write-Host "ADVERTENCIA: codigo de salida $LASTEXITCODE" -ForegroundColor Red
    }

    # Paso 2: generar el QR
    $qrPath = "$carpetaQR\$usuario.png"
    Write-Host "Generando QR..." -ForegroundColor Cyan
    & $multiotpExe -qrcode $usuario $qrPath | Out-Null

    if (Test-Path $qrPath) {
        Write-Host "`nQR generado exitosamente:" -ForegroundColor Green
        Write-Host "  $qrPath" -ForegroundColor Green
        Write-Host "`nPasos siguientes:" -ForegroundColor Yellow
        Write-Host "  1. Abre el archivo $usuario.png desde tu maquina fisica" -ForegroundColor Yellow
        Write-Host "  2. Abre Google Authenticator en tu celular" -ForegroundColor Yellow
        Write-Host "  3. Pulsa '+' y elige 'Escanear QR'" -ForegroundColor Yellow
        Write-Host "  4. Apunta al QR en la pantalla" -ForegroundColor Yellow
    } else {
        Write-Host "ERROR: no se genero el QR." -ForegroundColor Red
    }
}

function Invoke-ConfigurarLockoutMFA {
    $multiotpPath = "C:\multiOTP"
    $multiotpExe  = "$multiotpPath\windows\multiotp.exe"

    # Verificar que multiOTP este instalado
    if (-not (Test-Path $multiotpExe)) {
        Write-Host "ERROR: multiOTP no esta instalado." -ForegroundColor Red
        Write-Host "Corre primero la opcion 7." -ForegroundColor Yellow
        return
    }

    Set-Location "$multiotpPath\windows"

    Write-Host "Configurando bloqueo por MFA fallido..." -ForegroundColor Cyan

    # 3 intentos fallidos permitidos
    & $multiotpExe -config max-delayed-failures=3 | Out-Null
    Write-Host "  OK - Maximo 3 intentos fallidos" -ForegroundColor Green

    # 30 minutos = 1800 segundos de bloqueo
    & $multiotpExe -config failure-delayed-time=1800 | Out-Null
    Write-Host "  OK - Bloqueo de 30 minutos (1800 seg)" -ForegroundColor Green

    # Ventana de tiempo para contar los intentos (tambien 30 min)
    & $multiotpExe -config max-time-window=1800 | Out-Null
    Write-Host "  OK - Ventana de conteo: 30 minutos" -ForegroundColor Green

    Write-Host "`nConfiguracion de lockout aplicada." -ForegroundColor Cyan
    Write-Host "Comportamiento: 3 tokens MFA incorrectos = 30 min bloqueado." -ForegroundColor Yellow
}

function Invoke-InstalarCredentialProviderCliente {
    param(
        [string]$ServidorIP = "200.1.1.1"
    )

    $cpZipUrl      = "https://download.multiotp.net/credential-provider/multiOTPCredentialProvider-5.10.2.2.zip"
    $cpZipLocal    = "$env:TEMP\multiOTPCredentialProvider.zip"
    $cpExtractDir  = "$env:TEMP\multiOTPCredentialProvider_extract"
    $serverSecret  = "P9_SecretoMFA_2026"
    $excludedAccount = "SRV-WINDOWS10-S\Berrelleza"
    $multiOTPUrl   = "http://${ServidorIP}:8112"

    $userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host " INSTALACION CREDENTIAL PROVIDER (CLIENTE)" -ForegroundColor Cyan
    Write-Host " Servidor multiOTP: $multiOTPUrl" -ForegroundColor Cyan
    Write-Host " Usuario excluido (recovery): $excludedAccount" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan

    # --- Verificar que estamos en PowerShell 64-bit ---
    if (-not [Environment]::Is64BitProcess) {
        Write-Host "ERROR: Debes ejecutar este script en PowerShell 64-bit, no en x86." -ForegroundColor Red
        return
    }

    # --- Pre-requisito: Visual C++ Redistributable x64 ---
    $vcRedistUrl   = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
    $vcRedistLocal = "$env:TEMP\vc_redist.x64.exe"

    $vcInstalled = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" -ErrorAction SilentlyContinue
    if (-not $vcInstalled) {
        Write-Host "`n[1/4] Instalando Visual C++ Redistributable x64..." -ForegroundColor Yellow
        try {
            $webClient = New-Object System.Net.WebClient
            $webClient.Headers.Add("User-Agent", $userAgent)
            $webClient.DownloadFile($vcRedistUrl, $vcRedistLocal)
        } catch {
            Write-Host "  ERROR al descargar Visual C++: $($_.Exception.Message)" -ForegroundColor Red
            return
        }

        $vcProc = Start-Process -FilePath $vcRedistLocal -ArgumentList "/install","/quiet","/norestart" -Wait -PassThru
        if ($vcProc.ExitCode -eq 0 -or $vcProc.ExitCode -eq 3010) {
            Write-Host "  Visual C++ Redistributable instalado." -ForegroundColor Green
        } else {
            Write-Host "  ERROR: Visual C++ codigo $($vcProc.ExitCode)" -ForegroundColor Red
            return
        }
    } else {
        Write-Host "`n[1/4] Visual C++ Redistributable ya esta instalado." -ForegroundColor Green
    }

    # --- Obtener ZIP del Credential Provider ---
    Write-Host "`n[2/4] Obteniendo Credential Provider..." -ForegroundColor Yellow

    $cpZipCompartido = "$PSScriptRoot\..\..\Practica 9\multiOTPCredentialProvider.zip"

    if (Test-Path $cpZipLocal) {
        $tamActual = (Get-Item $cpZipLocal).Length
        if ($tamActual -lt 10MB) {
            Write-Host "  ZIP previo corrupto, eliminando..." -ForegroundColor Yellow
            Remove-Item $cpZipLocal -Force
        }
    }

    if (-not (Test-Path $cpZipLocal)) {
        if (Test-Path $cpZipCompartido) {
            Write-Host "  Copiando ZIP desde carpeta compartida..." -ForegroundColor Yellow
            Copy-Item $cpZipCompartido $cpZipLocal -Force
        } else {
            Write-Host "  Descargando desde internet..." -ForegroundColor Yellow
            try {
                $webClient = New-Object System.Net.WebClient
                $webClient.Headers.Add("User-Agent", $userAgent)
                $webClient.DownloadFile($cpZipUrl, $cpZipLocal)
            } catch {
                Write-Host "  ERROR al descargar: $($_.Exception.Message)" -ForegroundColor Red
                return
            }
        }
    }

    $tamFinal = (Get-Item $cpZipLocal).Length
    if ($tamFinal -lt 10MB) {
        Write-Host "  ERROR: archivo incompleto ($([math]::Round($tamFinal/1MB,2)) MB)" -ForegroundColor Red
        return
    }
    Write-Host "  ZIP listo ($([math]::Round($tamFinal/1MB,2)) MB)." -ForegroundColor Green

    # --- Descomprimir ---
    try {
        if (Test-Path $cpExtractDir) { Remove-Item $cpExtractDir -Recurse -Force }
        Expand-Archive -Path $cpZipLocal -DestinationPath $cpExtractDir -Force
    } catch {
        Write-Host "  ERROR al descomprimir: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    $msiEncontrado = Get-ChildItem -Path $cpExtractDir -Filter "*.msi" -Recurse | Select-Object -First 1
    if (-not $msiEncontrado) {
        Write-Host "  ERROR: MSI no encontrado." -ForegroundColor Red
        return
    }

    # --- Instalar el MSI con parametros CORRECTOS segun README oficial ---
    Write-Host "`n[3/4] Instalando Credential Provider via MSI..." -ForegroundColor Yellow
    Write-Host "  Modo: 0e (MFA obligatorio local + remoto, sin puertas traseras)" -ForegroundColor Yellow

    $msiArgs = @(
        "/i", "`"$($msiEncontrado.FullName)`"",
        "/passive",
        "/norestart",
        "MULTIOTP_URL=$multiOTPUrl",
        "MULTIOTP_SECRET=$serverSecret",
        "MULTIOTP_CPUSLOGON=0e",
        "MULTIOTP_CPUSUNLOCK=0e",
        "MULTIOTP_CPUSCREDUI=0e",
        "MULTIOTP_EXCLUDED_ACCOUNT=$excludedAccount",
        "MULTIOTP_TIMEOUT=10",
        "MULTIOTP_CACHE=1",
        "MULTIOTP_TWO_STEP_HIDE_OTP=1",
        "/L*v", "`"$env:TEMP\multiotp_install.log`""
    )

    $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru

    if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
        Write-Host "  MSI instalado correctamente." -ForegroundColor Green
    } else {
        Write-Host "  ERROR codigo $($proc.ExitCode). Revisa: $env:TEMP\multiotp_install.log" -ForegroundColor Red
        return
    }

    # Dar tiempo al MSI de terminar de aplicar todo
    Start-Sleep -Seconds 3

    # --- Verificar que el registro quedo bien ---
    Write-Host "`n[4/4] Verificando configuracion del registro..." -ForegroundColor Yellow

    $clsid = "HKLM:\SOFTWARE\Classes\CLSID\{FCEFDFAB-B0A1-4C4D-8B2B-4FF4E0A3D978}"

    if (-not (Test-Path $clsid)) {
        Write-Host "  ERROR: La clave del registro no existe. El MSI fallo." -ForegroundColor Red
        return
    }

    $reg = Get-ItemProperty -Path $clsid

    $expectativas = @{
        "multiOTPServers"      = $multiOTPUrl
        "multiOTPSharedSecret" = $serverSecret
        "cpus_logon"           = "0e"
        "cpus_unlock"          = "0e"
        "cpus_credui"          = "0e"
        "excluded_account"     = $excludedAccount
    }

    $todoOK = $true
    foreach ($key in $expectativas.Keys) {
        $valorActual = $reg.$key
        $valorEsperado = $expectativas[$key]
        if ($valorActual -eq $valorEsperado) {
            Write-Host "  OK  $key = $valorActual" -ForegroundColor Green
        } else {
            Write-Host "  BAD $key esperado '$valorEsperado', actual '$valorActual' -> corrigiendo..." -ForegroundColor Yellow
            Set-ItemProperty -Path $clsid -Name $key -Value $valorEsperado -Type String -Force
            $verificacion = (Get-ItemProperty -Path $clsid).$key
            if ($verificacion -eq $valorEsperado) {
                Write-Host "       OK $key corregido a $verificacion" -ForegroundColor Green
            } else {
                Write-Host "       FAIL $key sigue mal tras corregir" -ForegroundColor Red
                $todoOK = $false
            }
        }
    }

    # --- Prueba de conectividad al servidor multiOTP ---
    Write-Host "`nVerificando conectividad al servidor multiOTP..." -ForegroundColor Yellow
    try {
        $test = Invoke-WebRequest -Uri $multiOTPUrl -UseBasicParsing -TimeoutSec 10
        if ($test.StatusCode -eq 200) {
            Write-Host "  OK  Servidor multiOTP responde en $multiOTPUrl" -ForegroundColor Green
        } else {
            Write-Host "  WARN Servidor respondio con codigo $($test.StatusCode)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ERROR: No se pudo contactar al servidor: $($_.Exception.Message)" -ForegroundColor Red
        $todoOK = $false
    }

    Write-Host "`n============================================" -ForegroundColor Cyan
    if ($todoOK) {
        Write-Host " INSTALACION EXITOSA" -ForegroundColor Green
        Write-Host " Usuarios excluidos de MFA: $excludedAccount" -ForegroundColor Cyan
        Write-Host " Reinicia el Win10 para activar el MFA." -ForegroundColor Yellow
    } else {
        Write-Host " INSTALACION CON ERRORES" -ForegroundColor Red
        Write-Host " Revisa los mensajes arriba antes de reiniciar." -ForegroundColor Yellow
    }
    Write-Host "============================================" -ForegroundColor Cyan
}