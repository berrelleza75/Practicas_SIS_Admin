# funciones_fsrm.ps1
# Cuotas de disco y file screening por grupo

$dcPath     = "DC=practica8,DC=local"
$ouCuates   = "OU=Cuates,$dcPath"
$ouNoCuates = "OU=NoCuates,$dcPath"
$rutaBase   = "C:\Usuarios"

function Invoke-InstalarFSRM {
    if (-not (Get-WindowsFeature -Name FS-Resource-Manager).Installed) {
        Write-Host "Instalando rol FSRM..."
        Install-WindowsFeature -Name FS-Resource-Manager -IncludeManagementTools | Out-Null
        Write-Host "FSRM instalado"
    } else {
        Write-Host "FSRM ya esta instalado"
    }
}

function New-CarpetaUsuario {
    param([string]$usuario)

    $ruta = "$rutaBase\$usuario"

    if (-not (Test-Path $ruta)) {
        New-Item -ItemType Directory -Path $ruta | Out-Null

        # Asignar permisos solo al usuario dueno de la carpeta
        $acl    = Get-Acl $ruta
        $regla  = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "$netbios\$usuario", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
        )
        $acl.SetAccessRule($regla)
        Set-Acl -Path $ruta -AclObject $acl
    }

    return $ruta
}

function New-PlantillasCuota {
    # 10 MB para Cuates
    if (-not (Get-FsrmQuotaTemplate -Name "Cuota10MB" -ErrorAction SilentlyContinue)) {
        New-FsrmQuotaTemplate -Name "Cuota10MB" -Size 10MB -SoftLimit:$false
        Write-Host "Plantilla Cuota10MB creada"
    }

    # 5 MB para NoCuates
    if (-not (Get-FsrmQuotaTemplate -Name "Cuota5MB" -ErrorAction SilentlyContinue)) {
        New-FsrmQuotaTemplate -Name "Cuota5MB" -Size 5MB -SoftLimit:$false
        Write-Host "Plantilla Cuota5MB creada"
    }
}

function New-GrupoArchivosProhibidos {
    $extensiones = @("*.mp3", "*.mp4", "*.exe", "*.msi")

    if (-not (Get-FsrmFileGroup -Name "ArchivosProhibidos" -ErrorAction SilentlyContinue)) {
        New-FsrmFileGroup -Name "ArchivosProhibidos" -IncludePattern $extensiones
        Write-Host "Grupo de archivos prohibidos creado"
    } else {
        Set-FsrmFileGroup -Name "ArchivosProhibidos" -IncludePattern $extensiones
        Write-Host "Grupo de archivos prohibidos actualizado"
    }
}

function New-PlantillaScreening {
    if (-not (Get-FsrmFileScreenTemplate -Name "BloqueoMultimedia" -ErrorAction SilentlyContinue)) {
        New-FsrmFileScreenTemplate `
            -Name "BloqueoMultimedia" `
            -Active `
            -IncludeGroup @("ArchivosProhibidos")
        Write-Host "Plantilla de screening creada"
    }
}

function Invoke-AplicarCuotaYScreening {
    param(
        [string]$ruta,
        [string]$plantillaCuota
    )

    # Aplicar cuota
    if (Get-FsrmQuota -Path $ruta -ErrorAction SilentlyContinue) {
        Set-FsrmQuota -Path $ruta -Template $plantillaCuota
    } else {
        New-FsrmQuota -Path $ruta -Template $plantillaCuota
    }

    # Aplicar file screening activo
    if (Get-FsrmFileScreen -Path $ruta -ErrorAction SilentlyContinue) {
        Set-FsrmFileScreen -Path $ruta -Template "BloqueoMultimedia"
    } else {
        New-FsrmFileScreen -Path $ruta -Template "BloqueoMultimedia"
    }
}

function Invoke-ConfigurarFSRM {
    Write-Host ""
    Write-Host "--- Configuracion de FSRM ---"

    Invoke-InstalarFSRM

    if (-not (Test-Path $rutaBase)) {
        New-Item -ItemType Directory -Path $rutaBase | Out-Null
        Write-Host "Carpeta base $rutaBase creada"
    }

    New-PlantillasCuota
    New-GrupoArchivosProhibidos
    New-PlantillaScreening

    # Aplicar a usuarios Cuates (10 MB)
    $usuariosCuates = Get-ADUser -Filter * -SearchBase $ouCuates
    foreach ($u in $usuariosCuates) {
        $ruta = New-CarpetaUsuario -usuario $u.SamAccountName
        Invoke-AplicarCuotaYScreening -ruta $ruta -plantillaCuota "Cuota10MB"
        Write-Host "FSRM aplicado a $($u.SamAccountName) (10MB)"
    }

    # Aplicar a usuarios NoCuates (5 MB)
    $usuariosNoCuates = Get-ADUser -Filter * -SearchBase $ouNoCuates
    foreach ($u in $usuariosNoCuates) {
        $ruta = New-CarpetaUsuario -usuario $u.SamAccountName
        Invoke-AplicarCuotaYScreening -ruta $ruta -plantillaCuota "Cuota5MB"
        Write-Host "FSRM aplicado a $($u.SamAccountName) (5MB)"
    }

    Write-Host "Configuracion de FSRM completada"
}