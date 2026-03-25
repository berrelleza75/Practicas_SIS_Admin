#!/bin/bash

# main.sh - Práctica 5: Servidor FTP

MODULOS="$(dirname "$0")/../Modulos/bash"

source "$MODULOS/funciones_comunes.sh"
source "$MODULOS/funciones_ftp.sh"

verificar_root

menu(){
    clear
    echo "____________________________________________"
    echo "        Administracion Servidor FTP         "
    echo "____________________________________________"
    echo ""
    echo "  FTP"
    echo "   1. Verificar instalacion"
    echo "   2. Instalar servidor"
    echo "   3. Configurar servidor"
    echo "   4. Gestionar usuarios"
    echo "   5. Cambiar grupo de usuario"
    echo "   6. Eliminar usuario"
    echo ""
    echo "   0. Salir"
    echo "____________________________________________"
}

while true; do
    menu
    read -rp "Seleccione una opcion: " opcion

    case $opcion in
        1) verificar_vsftpd ;;
        2) instalar_vsftpd ;;
        3) configurar_vsftpd ;;
        4) gestionar_usuarios ;;
        5) cambiar_grupo_usuario ;;
        6) eliminar_usuario ;;
        0) echo "Saliendo..."; exit 0 ;;
        *) echo "Opcion invalida" ;;
    esac

    read -rp "Presiona Enter para continuar..."
done