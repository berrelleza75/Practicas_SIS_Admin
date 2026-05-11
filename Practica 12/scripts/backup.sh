#!/bin/bash
# Respaldo diario de buzones de correo - Practica 12

BACKUP_DIR="/opt/practica12/backups"
MAIL_DATA="/opt/practica12/dms/mail-data"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/mail_backup_$TIMESTAMP.tar.gz"

mkdir -p "$BACKUP_DIR"

tar -czf "$BACKUP_FILE" -C "$MAIL_DATA" .

if [ $? -eq 0 ]; then
    echo "[$(date)] Respaldo exitoso: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))"
else
    echo "[$(date)] ERROR en respaldo"
    exit 1
fi

# Mantener solo los ultimos 7 respaldos
ls -t "$BACKUP_DIR"/mail_backup_*.tar.gz 2>/dev/null | tail -n +8 | xargs -r rm -f
