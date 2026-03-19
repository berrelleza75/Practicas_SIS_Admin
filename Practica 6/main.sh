#!/bin/bash

MODULOS="$(dirname "$0")/../Modulos/bash"

source "$MODULOS/funciones_comunes.sh"
source "$MODULOS/funciones_http.sh"

if [[ "$EUID" -ne 0 ]]; then
    echo "[ERROR] Ejecuta el script como root"
    exit 1
fi

for cmd in curl ss systemctl pacman; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "[ERROR] Dependencia faltante: $cmd"
        exit 1
    fi
done

get_status() {
    local servicio=$1
    local estado
    estado=$(systemctl is-active "$servicio" 2>/dev/null)
    case $estado in
        active)  echo "[active]"   ;;
        failed)  echo "[failed]"   ;;
        *)       echo "[inactivo]" ;;
    esac
}

# Retorna 0 si el paquete esta instalado
check_installed() {
    pacman -Q "$1" &>/dev/null
}

ACCION_SERVICIO=""

ask_reinstall_or_port() {
    local servicio=$1
    echo ""
    echo "  $servicio ya esta instalado."
    echo ""
    echo "  1) Cambiar puerto"
    echo "  2) Reinstalar limpio"
    echo "  3) Cancelar"
    echo ""
    read -rp "  Opcion [1-3]: " ACCION_SERVICIO
}

run_apache_menu() {
    clear
    echo "====================================="
    echo "   APACHE2 - Configuracion"
    echo "====================================="
    echo ""

    if check_installed apache; then
        ask_reinstall_or_port "Apache2"
        case $ACCION_SERVICIO in
            1)
                local puerto
                puerto=$(get_port)
                [[ $? -ne 0 ]] && return 1
                set_apache_port "$puerto"
                create_apache_index "$puerto"
                set_firewall_rule "$puerto"
                systemctl restart httpd &>/dev/null
                echo "[OK] Puerto de Apache actualizado a $puerto"
                return 0
                ;;
            2)
                pacman -R --noconfirm apache &>/dev/null
                ;;
            *)
                return 0
                ;;
        esac
    fi

    get_apache_versions || return 1

    local opcion
    read -rp "  Elige version: " opcion
    check_input "$opcion" "numero" || return 1

    local puerto
    puerto=$(get_port)
    [[ $? -ne 0 ]] && return 1

    install_apache "$puerto"
}

run_nginx_menu() {
    clear
    echo "====================================="
    echo "   NGINX - Configuracion"
    echo "====================================="
    echo ""

    if check_installed nginx; then
        ask_reinstall_or_port "Nginx"
        case $ACCION_SERVICIO in
            1)
                local puerto
                puerto=$(get_port)
                [[ $? -ne 0 ]] && return 1
                set_nginx_config "$puerto"
                create_nginx_index "$puerto"
                set_firewall_rule "$puerto"
                systemctl restart nginx &>/dev/null
                echo "[OK] Puerto de Nginx actualizado a $puerto"
                return 0
                ;;
            2)
                pacman -R --noconfirm nginx &>/dev/null
                ;;
            *)
                return 0
                ;;
        esac
    fi

    get_nginx_versions || return 1

    local opcion
    read -rp "  Elige version: " opcion
    check_input "$opcion" "numero" || return 1

    local puerto
    puerto=$(get_port)
    [[ $? -ne 0 ]] && return 1

    install_nginx "$puerto"
}

run_tomcat_menu() {
    clear
    echo "====================================="
    echo "   TOMCAT - Configuracion"
    echo "====================================="
    echo ""

    if [[ -d /opt/tomcat ]]; then
        ask_reinstall_or_port "Tomcat"
        case $ACCION_SERVICIO in
            1)
                local puerto
                puerto=$(get_port)
                [[ $? -ne 0 ]] && return 1
                set_tomcat_port "$puerto" /opt/tomcat
                create_tomcat_index "$(cat /opt/tomcat/RELEASE-NOTES 2>/dev/null | grep -m1 'Apache Tomcat Version' | awk '{print $NF}')" "$puerto" /opt/tomcat
                set_firewall_rule "$puerto"
                systemctl restart tomcat &>/dev/null
                echo "[OK] Puerto de Tomcat actualizado a $puerto"
                return 0
                ;;
            2)
                systemctl stop tomcat &>/dev/null
                rm -rf /opt/tomcat
                systemctl disable tomcat &>/dev/null
                rm -f /etc/systemd/system/tomcat.service
                systemctl daemon-reload
                ;;
            *)
                return 0
                ;;
        esac
    fi

    if ! command -v java &>/dev/null && ! pacman -Q jre17-openjdk-headless &>/dev/null; then
        echo "[!] Java no encontrado. Instalando JRE..."
        pacman -S --noconfirm jre17-openjdk-headless &>/dev/null
    fi

    get_tomcat_versions || return 1

    local opcion
    read -rp "  Elige rama Tomcat [1-$TOMCAT_TOTAL]: " opcion
    if ! check_input "$opcion" "numero" || [[ "$opcion" -lt 1 || "$opcion" -gt "$TOMCAT_TOTAL" ]]; then
        echo "[ERROR] Opcion invalida"
        return 1
    fi

    local seleccion="${TOMCAT_RAMAS[$opcion]}"
    local rama="${seleccion%%:*}"
    local version="${seleccion##*:}"

    echo "  Seleccionado: Tomcat $rama - Version $version"

    local puerto
    puerto=$(get_port)
    [[ $? -ne 0 ]] && return 1

    install_tomcat "$rama" "$version" "$puerto"
}

run_main_menu() {
    while true; do
        clear
        echo "====================================="
        echo "   APROVISIONAMIENTO SERVIDORES HTTP"
        echo "   Sistema: Arch Linux"
        echo "====================================="
        echo ""
        printf "  1) Apache2  %s\n" "$(get_status httpd)"
        printf "  2) Nginx    %s\n" "$(get_status nginx)"
        printf "  3) Tomcat   %s\n" "$(get_status tomcat)"
        echo "  4) Salir"
        echo ""
        read -rp "  Opcion [1-4]: " opcion

        case $opcion in
            1) run_apache_menu ;;
            2) run_nginx_menu ;;
            3) run_tomcat_menu ;;
            4) exit 0 ;;
            *) echo "[!] Opcion invalida" ;;
        esac

        read -rp "  Presiona Enter para continuar..."
    done
}

run_main_menu