#!/bin/bash

# main.sh - Practica 7
# Orquestador SSL/TLS + Cliente FTP dinamico
# Servicios: vsftpd (FTPS), Apache, Nginx, Tomcat (HTTPS)

MODULOS="$(dirname "$0")/../Modulos/bash"

source "$MODULOS/funciones_comunes.sh" 2>/dev/null
source "$MODULOS/funciones_ssl.sh"

# Verifica que se ejecute como root
if [ "$EUID" -ne 0 ]; then
    echo "Este script debe ejecutarse como root."
    exit 1
fi

# Setup inicial automatico del repo FTP
inicializacion() {
    echo "============================================================"
    echo "  PRACTICA 7 - SSL/TLS + ORQUESTADOR FTP"
    echo "  Dominio: $DOMINIO   Servidor: $IP_SERVIDOR"
    echo "============================================================"

    configurar_hosts
    setup_repo_completo

    # Activa FTPS automaticamente (es uno de los 4 servicios SSL requeridos)
    if ! grep -q "ssl_enable=YES" /etc/vsftpd.conf 2>/dev/null; then
        echo
        echo "Activando FTPS en vsftpd automaticamente..."
        activar_ssl_vsftpd
    fi

    echo
    echo "Inicializacion completa. El repositorio FTPS esta listo."
    echo "Conectate con FileZilla a ftp://$IP_SERVIDOR (TLS explicito)"
    echo "Usuario: $REPO_USER  Password: $REPO_PASS"
}

menu() {
    while true; do
        echo
        echo "============================================================"
        echo "  MENU PRACTICA 7"
        echo "============================================================"
        echo "  1) Instalar Apache (FTP + SSL automatico)"
        echo "  2) Instalar Nginx  (FTP + SSL automatico)"
        echo "  3) Instalar Tomcat (FTP + SSL automatico)"
        echo "  4) Instalar TODOS los servicios (Apache + Nginx + Tomcat)"
        echo "  5) Re-poblar repositorio FTP"
        echo "  6) Verificacion automatizada (resumen SSL)"
        echo "  7) Listar contenido del repositorio FTP"
        echo "  0) Salir"
        echo "------------------------------------------------------------"
        read -p "Opcion: " op

        case "$op" in
            1) instalar_servicio "apache" ;;
            2) instalar_servicio "nginx" ;;
            3) instalar_servicio "tomcat" ;;
            4) instalar_todos ;;
            5) poblar_repo_linux ;;
            6) resumen_servicios_ssl ;;
            7) listar_repo ;;
            0) echo "Saliendo..." ; exit 0 ;;
            *) echo "Opcion invalida." ;;
        esac
    done
}

instalar_todos() {
    echo
    echo "=== Instalacion automatica de los 3 servicios HTTP ==="
    instalar_servicio "apache"
    instalar_servicio "nginx"
    instalar_servicio "tomcat"
    echo
    resumen_servicios_ssl
}

listar_repo() {
    echo
    echo "--- Contenido del repositorio FTP ---"
    echo "URL: ftp://$IP_SERVIDOR/http/"
    echo
    find "$REPO_ROOT" -type f | sort
}

# === Ejecucion ===
inicializacion
menu