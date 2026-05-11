#!/bin/bash

PRACTICA_DIR="/media/sf_Semestre_6_IS/SIS-ADMIN-PRACTICAS/Practica 11"

RESET='\033[0m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BOLD='\033[1m'

banner() {
    clear
    echo -e "${CYAN}"
    echo "================================================================"
    echo "       PRACTICA 11 - GESTION DEL STACK"
    echo "================================================================"
    echo -e "${RESET}"
}

pausa() {
    echo ""
    echo -e "${YELLOW}Presiona ENTER para volver al menu...${RESET}"
    read
}

menu() {
    banner
    echo ""
    echo "  1) Levantar stack"
    echo "  2) Detener stack"
    echo "  3) Reiniciar stack"
    echo "  4) Ver estado del stack"
    echo "  5) Ver logs en vivo"
    echo ""
    echo "  0) Salir"
    echo ""
    echo -n "Opcion: "
}

levantar() {
    banner
    cd "$PRACTICA_DIR"
    docker compose up -d
    pausa
}

detener() {
    banner
    cd "$PRACTICA_DIR"
    docker compose down
    pausa
}

reiniciar() {
    banner
    cd "$PRACTICA_DIR"
    docker compose restart
    pausa
}

estado() {
    banner
    cd "$PRACTICA_DIR"
    docker compose ps
    echo ""
    pausa
}

logs() {
    banner
    cd "$PRACTICA_DIR"
    echo "Ctrl+C para salir"
    sleep 1
    docker compose logs -f
}

while true; do
    menu
    read opcion
    case $opcion in
        1) levantar ;;
        2) detener ;;
        3) reiniciar ;;
        4) estado ;;
        5) logs ;;
        0) clear; exit 0 ;;
        *) echo -e "${RED}Opcion invalida${RESET}"; sleep 1 ;;
    esac
done