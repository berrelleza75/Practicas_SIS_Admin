# ============================================
# Practica 10 - Respaldo Automatizado PostgreSQL
# Genera un dump de la BD y lo guarda en backups/
# ============================================

# Configuracion
$CONTAINER_NAME = "postgres_db"
$DB_USER = "admin_practica"
$DB_NAME = "usuarios_db"
$BACKUP_DIR = "$PSScriptRoot\..\backups"

# Crear timestamp para el nombre del archivo
$TIMESTAMP = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$BACKUP_FILE = "$BACKUP_DIR\backup_${DB_NAME}_${TIMESTAMP}.sql"

Write-Host "=================================================="
Write-Host "  Iniciando respaldo de PostgreSQL"
Write-Host "=================================================="
Write-Host "Contenedor: $CONTAINER_NAME"
Write-Host "Base de datos: $DB_NAME"
Write-Host "Usuario: $DB_USER"
Write-Host "Destino: $BACKUP_FILE"
Write-Host ""

# Verificar que el contenedor este corriendo
$running = docker ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}"
if ($running -ne $CONTAINER_NAME) {
    Write-Host "ERROR: El contenedor '$CONTAINER_NAME' no esta corriendo." -ForegroundColor Red
    exit 1
}

# Crear carpeta backups si no existe
if (-not (Test-Path $BACKUP_DIR)) {
    New-Item -ItemType Directory -Path $BACKUP_DIR | Out-Null
    Write-Host "Carpeta de respaldos creada: $BACKUP_DIR"
}

# Ejecutar pg_dump dentro del contenedor y redirigir salida al archivo del host
Write-Host "Generando respaldo..."
docker exec $CONTAINER_NAME pg_dump -U $DB_USER -d $DB_NAME | Out-File -FilePath $BACKUP_FILE -Encoding UTF8

# Verificar que el respaldo se creo correctamente
if (Test-Path $BACKUP_FILE) {
    $size = (Get-Item $BACKUP_FILE).Length
    Write-Host ""
    Write-Host "Respaldo completado exitosamente" -ForegroundColor Green
    Write-Host "Archivo: $BACKUP_FILE"
    Write-Host "Tamano: $size bytes"
} else {
    Write-Host "ERROR: No se pudo generar el respaldo." -ForegroundColor Red
    exit 1
}

Write-Host "=================================================="