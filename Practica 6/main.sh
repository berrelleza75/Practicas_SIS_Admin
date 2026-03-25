#!/bin/bash

MODULOS="$(dirname "$0")/../Modulos/bash"

source "$MODULOS/funciones_comunes.sh" 2>/dev/null
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
                get_port
                set_apache_port "$PUERTO_ELEGIDO"
                create_apache_index "$PUERTO_ELEGIDO"
                set_firewall_rule "$PUERTO_ELEGIDO"
                systemctl restart httpd &>/dev/null
                echo "[OK] Puerto de Apache actualizado a $PUERTO_ELEGIDO"
                return 0
                ;;
            2) pacman -R --noconfirm apache &>/dev/null ;;
            *) return 0 ;;
        esac
    fi

    get_apache_versions || return 1

    local opcion
    read -rp "  Elige version: " opcion
    check_input "$opcion" "numero" || return 1

    get_port
    [[ -z "$PUERTO_ELEGIDO" ]] && { echo "[ERROR] Puerto no valido"; return 1; }

    install_apache "$PUERTO_ELEGIDO"
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
                get_port
                set_nginx_config "$PUERTO_ELEGIDO"
                create_nginx_index "$PUERTO_ELEGIDO"
                set_firewall_rule "$PUERTO_ELEGIDO"
                systemctl restart nginx &>/dev/null
                echo "[OK] Puerto de Nginx actualizado a $PUERTO_ELEGIDO"
                return 0
                ;;
            2) pacman -R --noconfirm nginx &>/dev/null ;;
            *) return 0 ;;
        esac
    fi

    get_nginx_versions || return 1

    local opcion
    read -rp "  Elige version: " opcion
    check_input "$opcion" "numero" || return 1

    get_port
    [[ -z "$PUERTO_ELEGIDO" ]] && { echo "[ERROR] Puerto no valido"; return 1; }

    install_nginx "$PUERTO_ELEGIDO"
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
                get_port
                set_tomcat_port "$PUERTO_ELEGIDO" /opt/tomcat
                create_tomcat_index "$(grep -m1 'Apache Tomcat Version' /opt/tomcat/RELEASE-NOTES 2>/dev/null | awk '{print $NF}')" "$PUERTO_ELEGIDO" /opt/tomcat
                set_firewall_rule "$PUERTO_ELEGIDO"
                systemctl restart tomcat &>/dev/null
                echo "[OK] Puerto de Tomcat actualizado a $PUERTO_ELEGIDO"
                return 0
                ;;
            2) uninstall_tomcat ;;
            *) return 0 ;;
        esac
    fi

    check_jdk || return 1

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

    get_port
    [[ -z "$PUERTO_ELEGIDO" ]] && { echo "[ERROR] Puerto no valido"; return 1; }

    install_tomcat "$rama" "$version" "$PUERTO_ELEGIDO"
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