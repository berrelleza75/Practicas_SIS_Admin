function Validar-IP {
    param([string]$ip)
    
    # Verificar formato básico IPv4
    if ($ip -notmatch '^(\d{1,3}\.){3}\d{1,3}$') {
        Write-Host "Formato inválido, debe ser: X.X.X.X (ejemplo: 192.168.1.1)" -ForegroundColor Red
        return $false
    }
    
    # Separar octetos y validar rango 0-255
    $octetos = $ip -split '\.'
    foreach ($octeto in $octetos) {
        $num = [int]$octeto
        if ($num -lt 0 -or $num -gt 255) {
            Write-Host "Error: cada octeto debe estar entre 0 y 255" -ForegroundColor Red
            return $false
        }
    }
    
    return $true
}

function Validar-NoLoopback {
    param([string]$ip)
    
    $primerOcteto = ($ip -split '\.')[0]
    
    if ([int]$primerOcteto -eq 127) {
        Write-Host "Error: No se puede usar la IP loopback (127.x.x.x)" -ForegroundColor Red
        return $false
    }
    
    return $true
}

function Validar-NoBroadcast {
    param([string]$ip)
    
    if ($ip -eq "255.255.255.255") {
        Write-Host "Error: No se puede usar la IP de broadcast" -ForegroundColor Red
        return $false
    }
    
    return $true
}

function Validar-NoCero {
    param([string]$ip)
    
    if ($ip -eq "0.0.0.0") {
        Write-Host "Error: No se puede usar la IP 0.0.0.0" -ForegroundColor Red
        return $false
    }
    
    return $true
}

function Validar-MismoSegmento {
    param(
        [string]$ip1,
        [string]$ip2
    )
    
    $segmento1 = ($ip1 -split '\.')[0..2] -join '.'
    $segmento2 = ($ip2 -split '\.')[0..2] -join '.'
    
    if ($segmento1 -ne $segmento2) {
        Write-Host "Error: Las IPs deben estar en el mismo segmento de red" -ForegroundColor Red
        Write-Host "   IP1: $ip1 (segmento: $segmento1.X)" -ForegroundColor Yellow
        Write-Host "   IP2: $ip2 (segmento: $segmento2.X)" -ForegroundColor Yellow
        return $false
    }
    
    return $true
}

function Validar-Rango {
    param(
        [string]$ipInicial,
        [string]$ipFinal
    )
    
    # Convertir IPs a números para comparar
    $octetos1 = $ipInicial -split '\.'
    $octetos2 = $ipFinal -split '\.'
    
    $num1 = ([int]$octetos1[0] * 16777216) + ([int]$octetos1[1] * 65536) + ([int]$octetos1[2] * 256) + [int]$octetos1[3]
    $num2 = ([int]$octetos2[0] * 16777216) + ([int]$octetos2[1] * 65536) + ([int]$octetos2[2] * 256) + [int]$octetos2[3]
    
    if ($num1 -ge $num2) {
        Write-Host "Error: La IP inicial debe ser menor que la IP final" -ForegroundColor Red
        Write-Host "   IP inicial: $ipInicial" -ForegroundColor Yellow
        Write-Host "   IP final: $ipFinal" -ForegroundColor Yellow
        return $false
    }
    
    return $true
}

function Validar-Gateway {
    param(
        [string]$gateway,
        [string]$ipInicial,
        [string]$ipFinal
    )
    
    # Validar mismo segmento
    $segmentoGW = ($gateway -split '\.')[0..2] -join '.'
    $segmentoRango = ($ipInicial -split '\.')[0..2] -join '.'
    
    if ($segmentoGW -ne $segmentoRango) {
        Write-Host "Error: El Gateway debe estar en el mismo segmento de red" -ForegroundColor Red
        Write-Host "   Gateway: $gateway (segmento: $segmentoGW.X)" -ForegroundColor Yellow
        Write-Host "   Rango: $segmentoRango.X" -ForegroundColor Yellow
        return $false
    }
    
    # Validar que NO esté dentro del rango DHCP
    $octetoGW = [int]($gateway -split '\.')[-1]
    $octetoIni = [int]($ipInicial -split '\.')[-1]
    $octetoFin = [int]($ipFinal -split '\.')[-1]
    
    if ($octetoGW -ge $octetoIni -and $octetoGW -le $octetoFin) {
        Write-Host "Error: El Gateway no debe estar dentro del rango DHCP" -ForegroundColor Red
        Write-Host "   Gateway: $gateway" -ForegroundColor Yellow
        Write-Host "   Rango DHCP: $ipInicial - $ipFinal" -ForegroundColor Yellow
        return $false
    }
    
    return $true
}


function Solicitar-ScopeName {
    Write-Host ""
    $script:scopeName = Read-Host "Ingrese el nombre del ámbito"
    
    while ([string]::IsNullOrWhiteSpace($script:scopeName)) {
        Write-Host "El nombre del ámbito no puede estar vacío" -ForegroundColor Red
        $script:scopeName = Read-Host "Ingrese el nombre del ámbito"
    }
    
    Write-Host "Scope: $script:scopeName" -ForegroundColor Green
}

function Solicitar-RangoIPs {
    Write-Host ""
    Write-Host "Configuración de rangos" -ForegroundColor Cyan
    
    # Solicitar IP inicial
    do {
        $script:ipInicial = Read-Host "Ingrese la IP inicial del rango"
        
        if ([string]::IsNullOrWhiteSpace($script:ipInicial)) {
            Write-Host "La IP inicial no puede estar vacía" -ForegroundColor Red
            continue
        }
        
        if (-not (Validar-IP $script:ipInicial)) { continue }
        if (-not (Validar-NoLoopback $script:ipInicial)) { continue }
        if (-not (Validar-NoBroadcast $script:ipInicial)) { continue }
        if (-not (Validar-NoCero $script:ipInicial)) { continue }
        
        Write-Host "IP INICIAL: $script:ipInicial" -ForegroundColor Green
        break
    } while ($true)
    
    # Solicitar IP final
    do {
        $script:ipFinal = Read-Host "Ingrese la IP final del rango"
        
        if ([string]::IsNullOrWhiteSpace($script:ipFinal)) {
            Write-Host "La IP final no puede estar vacía" -ForegroundColor Red
            continue
        }
        
        if (-not (Validar-IP $script:ipFinal)) { continue }
        if (-not (Validar-NoLoopback $script:ipFinal)) { continue }
        if (-not (Validar-NoBroadcast $script:ipFinal)) { continue }
        if (-not (Validar-NoCero $script:ipFinal)) { continue }
        if (-not (Validar-MismoSegmento $script:ipInicial $script:ipFinal)) { continue }
        if (-not (Validar-Rango $script:ipInicial $script:ipFinal)) { continue }
        
        Write-Host "IP FINAL: $script:ipFinal" -ForegroundColor Green
        break
    } while ($true)
}

function Solicitar-LeaseTime {
    Write-Host ""
    Write-Host "--- Tiempo de Concesión (Lease Time) ---" -ForegroundColor Cyan
    
    do {
        $input = Read-Host "Ingrese el tiempo de concesión en segundos"
        
        if ([string]::IsNullOrWhiteSpace($input)) {
            Write-Host "Error: el tiempo de concesión no puede estar vacío" -ForegroundColor Red
            continue
        }
        
        if ($input -notmatch '^\d+$') {
            Write-Host "Error: debe ingresar un número válido" -ForegroundColor Red
            continue
        }
        
        $script:leaseTime = [int]$input
        
        if ($script:leaseTime -le 0) {
            Write-Host "Error: el tiempo debe ser mayor a 0 segundos" -ForegroundColor Red
            continue
        }
        
        Write-Host "Lease time: $script:leaseTime segundos" -ForegroundColor Green
        break
    } while ($true)
}

function Solicitar-Gateway {
    Write-Host ""
    Write-Host "--- Gateway/Router (Opcional) ---" -ForegroundColor Cyan
    
    do {
        $script:gateway = Read-Host "Ingrese la dirección IP del Gateway [Enter para omitir]"
        
        if ([string]::IsNullOrWhiteSpace($script:gateway)) {
            $script:gateway = ""
            break
        }
        
        if (-not (Validar-IP $script:gateway)) { continue }
        if (-not (Validar-NoLoopback $script:gateway)) { continue }
        if (-not (Validar-NoBroadcast $script:gateway)) { continue }
        if (-not (Validar-NoCero $script:gateway)) { continue }
        if (-not (Validar-Gateway $script:gateway $script:ipInicial $script:ipFinal)) { continue }
        
        Write-Host "Gateway: $script:gateway" -ForegroundColor Green
        break
    } while ($true)
}

function Solicitar-DNS {
    Write-Host ""
    Write-Host "--- Servidor DNS (Opcional) ---" -ForegroundColor Cyan
    Write-Host "Puede ingresar hasta 2 servidores DNS"
    
    # DNS Primario
    do {
        $script:dns1 = Read-Host "Ingrese DNS primario [Enter para omitir]"
        
        if ([string]::IsNullOrWhiteSpace($script:dns1)) {
            $script:dns1 = ""
            $script:dns2 = ""
            Write-Host "Sin DNS configurado" -ForegroundColor Yellow
            break
        }
        
        if (-not (Validar-IP $script:dns1)) { continue }
        if (-not (Validar-NoLoopback $script:dns1)) { continue }
        if (-not (Validar-NoBroadcast $script:dns1)) { continue }
        if (-not (Validar-NoCero $script:dns1)) { continue }
        
        Write-Host "DNS primario: $script:dns1" -ForegroundColor Green
        break
    } while ($true)
    
    # DNS Secundario (solo si ingresó el primario)
    if (-not [string]::IsNullOrWhiteSpace($script:dns1)) {
        do {
            $script:dns2 = Read-Host "Ingrese DNS secundario [Enter para omitir]"
            
            if ([string]::IsNullOrWhiteSpace($script:dns2)) {
                $script:dns2 = ""
                break
            }
            
            if (-not (Validar-IP $script:dns2)) { continue }
            if (-not (Validar-NoLoopback $script:dns2)) { continue }
            if (-not (Validar-NoBroadcast $script:dns2)) { continue }
            if (-not (Validar-NoCero $script:dns2)) { continue }
            
            if ($script:dns2 -eq $script:dns1) {
                Write-Host "Error: El DNS secundario debe ser diferente al primario" -ForegroundColor Red
                continue
            }
            
            Write-Host "DNS secundario: $script:dns2" -ForegroundColor Green
            break
        } while ($true)
    }
}


function Calcular-Mascara {
    param(
        [string]$ip1,
        [string]$ip2
    )
    
    $octetos1 = $ip1 -split '\.'
    $octetos2 = $ip2 -split '\.'
    
    # Comparar octetos para determinar la máscara
    if ($octetos1[0] -eq $octetos2[0] -and $octetos1[1] -eq $octetos2[1] -and $octetos1[2] -eq $octetos2[2]) {
        # Clase C - /24
        $script:mascara = "255.255.255.0"
        $script:cidr = "24"
        $script:redBase = "$($octetos1[0]).$($octetos1[1]).$($octetos1[2]).0"
    }
    elseif ($octetos1[0] -eq $octetos2[0] -and $octetos1[1] -eq $octetos2[1]) {
        # Clase B - /16
        $script:mascara = "255.255.0.0"
        $script:cidr = "16"
        $script:redBase = "$($octetos1[0]).$($octetos1[1]).0.0"
    }
    elseif ($octetos1[0] -eq $octetos2[0]) {
        # Clase A - /8
        $script:mascara = "255.0.0.0"
        $script:cidr = "8"
        $script:redBase = "$($octetos1[0]).0.0.0"
    }
    else {
        Write-Host "Error: Las IPs no están en la misma red" -ForegroundColor Red
        return $false
    }
    
    return $true
}

#==================================================
# FUNCIÓN PARA APLICAR CONFIGURACIÓN
#==================================================

function Aplicar-Configuracion {
    Write-Host ""
    Write-Host "Aplicando configuración..." -ForegroundColor Cyan
    
    # Calcular la máscara de red
    if (-not (Calcular-Mascara $script:ipInicial $script:ipFinal)) {
        Write-Host "Error al calcular la máscara de red" -ForegroundColor Red
        return
    }
    
    Write-Host "Máscara calculada: $script:mascara (/$script:cidr)" -ForegroundColor Green
    Write-Host "Red base: $script:redBase" -ForegroundColor Green
    
    try {
        # 1. Agregar el scope DHCP
        Write-Host "Creando scope DHCP..." -ForegroundColor Cyan
        
        # Calcular IP inicial del rango DHCP (ipInicial + 1)
        $octetos = $script:ipInicial -split '\.'
        $octetoFinal = [int]$octetos[-1] + 1
        $segmento = $octetos[0..2] -join '.'
        $rangoInicio = "$segmento.$octetoFinal"
        
        Add-DhcpServerv4Scope -Name $script:scopeName `
                              -StartRange $rangoInicio `
                              -EndRange $script:ipFinal `
                              -SubnetMask $script:mascara `
                              -State Active `
                              -LeaseDuration (New-TimeSpan -Seconds $script:leaseTime) `
                              -ErrorAction Stop
        
        Write-Host "Scope creado exitosamente" -ForegroundColor Green
        
        # 2. Configurar opciones de Gateway
        if (-not [string]::IsNullOrWhiteSpace($script:gateway)) {
            Write-Host "Configurando Gateway..." -ForegroundColor Cyan
            Set-DhcpServerv4OptionValue -ScopeId $script:redBase `
                                        -Router $script:gateway `
                                        -ErrorAction Stop
            Write-Host "Gateway configurado" -ForegroundColor Green
        }
        
        # 3. Configurar opciones de DNS
        if (-not [string]::IsNullOrWhiteSpace($script:dns1)) {
            Write-Host "Configurando DNS..." -ForegroundColor Cyan
            
            if (-not [string]::IsNullOrWhiteSpace($script:dns2)) {
                # Ambos DNS
                Set-DhcpServerv4OptionValue -ScopeId $script:redBase `
                                            -DnsServer $script:dns1,$script:dns2 `
                                            -ErrorAction Stop
            } else {
                # Solo DNS primario
                Set-DhcpServerv4OptionValue -ScopeId $script:redBase `
                                            -DnsServer $script:dns1 `
                                            -ErrorAction Stop
            }
            Write-Host "DNS configurado" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "Configuración aplicada exitosamente" -ForegroundColor Green
        Write-Host "Servidor DHCP activo y funcionando" -ForegroundColor Green
        
    } catch {
        Write-Host ""
        Write-Host "Error: No se pudo aplicar la configuración" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

#==================================================
# FUNCIONES DEL MENÚ
#==================================================

function Mostrar-Menu {
    Clear-Host
    Write-Host "____________________________________________" -ForegroundColor Cyan
    Write-Host "          Gestor Servidor DHCP             " -ForegroundColor Cyan
    Write-Host "____________________________________________" -ForegroundColor Cyan
    Write-Host " 1. Verificar instalación                  "
    Write-Host " 2. Instalar servidor                      "
    Write-Host " 3. Configurar DHCP                        "
    Write-Host " 4. Monitorear Concesiones activas         "
    Write-Host " 5. Monitorear estado del servidor         "
    Write-Host " 6. Apagar servidor DHCP                   "
    Write-Host " 0. Salir del menú                         "
    Write-Host "____________________________________________" -ForegroundColor Cyan
}

function Verificar-DHCP {
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "    Verificando Servidor DHCP              " -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    
    try {
        $dhcpServer = Get-WindowsFeature -Name DHCP -ErrorAction Stop
        
        if ($dhcpServer.Installed) {
            Write-Host "El servidor DHCP está INSTALADO" -ForegroundColor Green
            Write-Host "Estado: $($dhcpServer.InstallState)" -ForegroundColor Yellow
        } else {
            Write-Host "El servidor DHCP NO está instalado" -ForegroundColor Yellow
            Write-Host "Use la opción 2 para instalarlo" -ForegroundColor Cyan
        }
    } catch {
        Write-Host "Error al verificar el servidor DHCP" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
    
    Write-Host "============================================" -ForegroundColor Cyan
}

function Instalar-DHCP {
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "    Instalando Servidor DHCP               " -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    
    try {
        $dhcpServer = Get-WindowsFeature -Name DHCP -ErrorAction Stop
        
        if ($dhcpServer.Installed) {
            Write-Host "El servidor DHCP ya está instalado" -ForegroundColor Yellow
            
            $respuesta = Read-Host "¿Desea reinstalarlo y eliminar configuración actual? (s/n)"
            
            if ($respuesta -ne "s" -and $respuesta -ne "S") {
                Write-Host "Operación cancelada" -ForegroundColor Yellow
                return
            }
            
            Write-Host "Procediendo con la reinstalación..." -ForegroundColor Cyan
            
            # Eliminar scopes existentes
            Get-DhcpServerv4Scope | Remove-DhcpServerv4Scope -Force -ErrorAction SilentlyContinue
            
            # Desinstalar
            Uninstall-WindowsFeature -Name DHCP -IncludeManagementTools -ErrorAction Stop
            Write-Host "Desinstalación completada" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "Realizando instalación..." -ForegroundColor Cyan
        
        # Instalar DHCP Server
        Install-WindowsFeature -Name DHCP -IncludeManagementTools -ErrorAction Stop
        
        Write-Host "Instalación completada exitosamente" -ForegroundColor Green
        
    } catch {
        Write-Host "Error: La instalación falló" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
    
    Write-Host "============================================" -ForegroundColor Cyan
}

function Configurar-DHCP {
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "    Configuración del Servidor DHCP        " -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    
    # Solicitar todos los datos
    Solicitar-ScopeName
    Solicitar-RangoIPs
    Solicitar-LeaseTime
    Solicitar-Gateway
    Solicitar-DNS
    
    # Calcular la máscara ANTES de mostrar el resumen
    if (-not (Calcular-Mascara $script:ipInicial $script:ipFinal)) {
        Write-Host "Error al calcular la máscara de red" -ForegroundColor Red
        return
    }
    
    # Mostrar resumen de configuración
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "    RESUMEN DE CONFIGURACIÓN               " -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "Scope: $script:scopeName"
    Write-Host "IP del servidor: $script:ipInicial/$script:cidr"
    Write-Host "Máscara de red: $script:mascara"
    Write-Host "Red base: $script:redBase"
    Write-Host "Rango DHCP: $script:ipInicial - $script:ipFinal"
    Write-Host "Lease time: $script:leaseTime segundos"
    
    if (-not [string]::IsNullOrWhiteSpace($script:gateway)) {
        Write-Host "Gateway: $script:gateway"
    } else {
        Write-Host "Gateway: (no configurado)"
    }
    
    if (-not [string]::IsNullOrWhiteSpace($script:dns1)) {
        Write-Host "DNS primario: $script:dns1"
        if (-not [string]::IsNullOrWhiteSpace($script:dns2)) {
            Write-Host "DNS secundario: $script:dns2"
        }
    } else {
        Write-Host "DNS: (no configurado)"
    }
    
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Confirmar antes de aplicar
    $confirmar = Read-Host "¿Desea aplicar esta configuración? (s/n)"
    
    if ($confirmar -ne "s" -and $confirmar -ne "S") {
        Write-Host "Configuración cancelada" -ForegroundColor Yellow
        return
    }
    
    # Aplicar la configuración
    Aplicar-Configuracion
    
    Write-Host "============================================" -ForegroundColor Cyan
}

function Monitorear-Concesiones {
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "    Monitoreo de Concesiones Activas       " -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    
    try {
        $scopes = Get-DhcpServerv4Scope -ErrorAction Stop
        
        if ($scopes.Count -eq 0) {
            Write-Host "No hay scopes configurados" -ForegroundColor Yellow
            return
        }
        
        Write-Host ""
        Write-Host "Concesiones activas:" -ForegroundColor Cyan
        Write-Host "--------------------------------------------"
        
        $totalLeases = 0
        
        foreach ($scope in $scopes) {
            $leases = Get-DhcpServerv4Lease -ScopeId $scope.ScopeId -ErrorAction SilentlyContinue
            
            if ($leases) {
                foreach ($lease in $leases) {
                    Write-Host "IP asignada: $($lease.IPAddress) - Cliente: $($lease.HostName)" -ForegroundColor Green
                    $totalLeases++
                }
            }
        }
        
        if ($totalLeases -eq 0) {
            Write-Host "No hay concesiones activas en este momento" -ForegroundColor Yellow
        }
        
        Write-Host "--------------------------------------------"
        Write-Host "Total de concesiones activas: $totalLeases" -ForegroundColor Green
        
    } catch {
        Write-Host "Error al obtener concesiones" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
    
    Write-Host "============================================" -ForegroundColor Cyan
}

function Monitorear-Estado {
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "    Estado del Servidor DHCP               " -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    
    try {
        $dhcpServer = Get-WindowsFeature -Name DHCP -ErrorAction Stop
        
        if (-not $dhcpServer.Installed) {
            Write-Host "El servidor DHCP NO está instalado" -ForegroundColor Red
            Write-Host "Use la opción 2 para instalarlo" -ForegroundColor Cyan
            return
        }
        
        Write-Host "Paquete: DHCP Server - INSTALADO" -ForegroundColor Green
        Write-Host ""
        
        # Verificar estado del servicio
        Write-Host "Estado del servicio:" -ForegroundColor Cyan
        Write-Host "--------------------------------------------"
        
        $service = Get-Service -Name DHCPServer -ErrorAction SilentlyContinue
        
        if ($service) {
            if ($service.Status -eq 'Running') {
                Write-Host "Estado: ACTIVO" -ForegroundColor Green
                Write-Host "El servidor DHCP está funcionando correctamente"
            } else {
                Write-Host "Estado: INACTIVO" -ForegroundColor Yellow
                Write-Host "El servidor DHCP NO está corriendo"
            }
            
            Write-Host ""
            Write-Host "Inicio automático: $($service.StartType)" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "--------------------------------------------"
            Write-Host "Información detallada del servicio:" -ForegroundColor Cyan
            Write-Host ""
            $service | Format-List Name, DisplayName, Status, StartType
        } else {
            Write-Host "No se pudo obtener información del servicio" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "Error al verificar el estado" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
    
    Write-Host "============================================" -ForegroundColor Cyan
}

function Apagar-Servidor {
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "    Apagar Servidor DHCP                   " -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    
    try {
        $service = Get-Service -Name DHCPServer -ErrorAction Stop
        
        if ($service.Status -ne 'Running') {
            Write-Host "El servidor DHCP ya está detenido" -ForegroundColor Yellow
            return
        }
        
        Write-Host ""
        $confirmar = Read-Host "¿Está seguro que desea detener el servidor DHCP? (s/n)"
        
        if ($confirmar -ne "s" -and $confirmar -ne "S") {
            Write-Host "Operación cancelada" -ForegroundColor Yellow
            return
        }
        
        Write-Host ""
        Write-Host "Deteniendo servidor DHCP..." -ForegroundColor Cyan
        
        Stop-Service -Name DHCPServer -Force -ErrorAction Stop
        
        Write-Host "Servidor DHCP detenido exitosamente" -ForegroundColor Green
        
        Write-Host ""
        $deshabilitar = Read-Host "¿Desea deshabilitar el inicio automático? (s/n)"
        
        if ($deshabilitar -eq "s" -or $deshabilitar -eq "S") {
            Set-Service -Name DHCPServer -StartupType Manual -ErrorAction Stop
            Write-Host "Inicio automático deshabilitado" -ForegroundColor Green
        }
        
    } catch {
        Write-Host "Error: No se pudo detener el servidor DHCP" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
    
    Write-Host "============================================" -ForegroundColor Cyan
}

#==================================================
# BUCLE PRINCIPAL
#==================================================

# Variables globales
$script:scopeName = ""
$script:ipInicial = ""
$script:ipFinal = ""
$script:leaseTime = 0
$script:gateway = ""
$script:dns1 = ""
$script:dns2 = ""
$script:mascara = ""
$script:cidr = ""
$script:redBase = ""

# Verificar si se está ejecutando como Administrador
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Este script debe ejecutarse como Administrador" -ForegroundColor Red
    Write-Host "Presione Enter para salir..."
    Read-Host
    exit
}

# Bucle principal del menú
do {
    Mostrar-Menu
    $opcion = Read-Host "Seleccione una opción"
    
    switch ($opcion) {
        "1" { Verificar-DHCP }
        "2" { Instalar-DHCP }
        "3" { Configurar-DHCP }
        "4" { Monitorear-Concesiones }
        "5" { Monitorear-Estado }
        "6" { Apagar-Servidor }
        "0" { 
            Write-Host "Saliendo..." -ForegroundColor Cyan
            exit 
        }
        default { Write-Host "Opción inválida" -ForegroundColor Red }
    }
    
    Write-Host ""
    Write-Host "Presione Enter para continuar..." -ForegroundColor Yellow
    Read-Host
    
} while ($true)