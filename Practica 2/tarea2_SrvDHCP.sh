#!/bin/bash

#Funciones de validacion
validar_ip(){
    local ip=$1
    
    # Verificar formato basico 4 números separados por puntos
    if [[ ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "formato invalido, debe ser: X.X.X.X (ejemplo: 192.168.1.1)"
        return 1
    fi
    
    # Separar los 4 octetos
    IFS='.' read -r octeto1 octeto2 octeto3 octeto4 <<< "$ip"
    
    # Validar que cada octeto esté entre 0 y 255
    for octeto in $octeto1 $octeto2 $octeto3 $octeto4; do
        if [ "$octeto" -lt 0 ] || [ "$octeto" -gt 255 ]; then
            echo "Error: cada octeto debe estar entre 0 y 255"
            return 1
        fi
    done
    
    # Si pasa todas las validaciones
    return 0
}

validar_no_loopback(){
    local ip
    ip=$1
    
    # Extraer el primer octeto
    local primer_octeto
    primer_octeto=$(echo "$ip" | cut -d'.' -f1)
    
    # Validar que no sea 127 que es la ip local
    if [ "$primer_octeto" -eq 127 ]; then
        echo "Error no se puede usar la IP loopback (127.x.x.x)"
        return 1
    fi
    
    # Si no es loopback
    return 0
}

validar_rango(){
    local ip_inicial
    local ip_final
    ip_inicial="$1"
    ip_final="$2"
    
    # Extraer octetos de IP inicial
    local o1_1
    local o1_2
    local o1_3
    local o1_4
    o1_1=$(echo "$ip_inicial" | cut -d'.' -f1)
    o1_2=$(echo "$ip_inicial" | cut -d'.' -f2)
    o1_3=$(echo "$ip_inicial" | cut -d'.' -f3)
    o1_4=$(echo "$ip_inicial" | cut -d'.' -f4)
    
    # Extraer octetos de IP final
    local o2_1
    local o2_2
    local o2_3
    local o2_4
    o2_1=$(echo "$ip_final" | cut -d'.' -f1)
    o2_2=$(echo "$ip_final" | cut -d'.' -f2)
    o2_3=$(echo "$ip_final" | cut -d'.' -f3)
    o2_4=$(echo "$ip_final" | cut -d'.' -f4)
    
    # Convertir a numero unico
    local num_inicial
    local num_final
    num_inicial=$(( o1_1 * 16777216 + o1_2 * 65536 + o1_3 * 256 + o1_4 ))
    num_final=$(( o2_1 * 16777216 + o2_2 * 65536 + o2_3 * 256 + o2_4 ))
    
    # Validar que IP_inicial < IP_final
    if [ "$num_inicial" -ge "$num_final" ]; then
        echo "Error: La IP inicial debe ser menor que la IP final"
        echo "   IP inicial: $ip_inicial"
        echo "   IP final: $ip_final"
        return 1
    fi
    
    return 0
}

validar_gateway(){
    local gateway
    local ip_inicial
    local ip_final
    gateway="$1"
    ip_inicial="$2"
    ip_final="$3"
    
    # Extraer primeros 3 octetos del gateway
    local segmento_gateway
    segmento_gateway=$(echo "$gateway" | cut -d'.' -f1-3)
    
    # Extraer primeros 3 octetos del rango
    local segmento_rango
    segmento_rango=$(echo "$ip_inicial" | cut -d'.' -f1-3)
    
    # 1. Validar que esté en el mismo segmento
    if [ "$segmento_gateway" != "$segmento_rango" ]; then
        echo "Error: El Gateway debe estar en el mismo segmento de red"
        echo "   Gateway: $gateway (segmento: $segmento_gateway.X)"
        echo "   Rango: $segmento_rango.X"
        return 1
    fi
    
    # 2. Extraer ultimo octeto del gateway, ip_inicial e ip_final
    local octeto_gw
    local octeto_ini
    local octeto_fin
    octeto_gw=$(echo "$gateway" | cut -d'.' -f4)
    octeto_ini=$(echo "$ip_inicial" | cut -d'.' -f4)
    octeto_fin=$(echo "$ip_final" | cut -d'.' -f4)
    
    # 3. Validar que NO esté dentro del rango DHCP
    if [ "$octeto_gw" -ge "$octeto_ini" ] && [ "$octeto_gw" -le "$octeto_fin" ]; then
        echo "Error El Gateway no debe estar dentro del rango DHCP"
        echo "   Gateway: $gateway"
        echo "   Rango DHCP: $ip_inicial - $ip_final"
        return 1
    fi
    
    # Si pasa todas las validaciones
    return 0
}

validar_no_broadcast(){
    local ip
    ip=$1
    
    # Validar que no sea 255.255.255.255
    if [ "$ip" = "255.255.255.255" ]; then
        echo "Error: No se puede usar la ip de broadcast"
        return 1
    fi
    
    # Si no es broadcast
    return 0
}

validar_mismo_segmento(){
    local ip1
    local ip2
    ip1=$1
    ip2=$2
    
    # Extraer los primeros 3 octetos de cada IP
    local segmento1
    local segmento2
    segmento1=$(echo "$ip1" | cut -d'.' -f1-3)
    segmento2=$(echo "$ip2" | cut -d'.' -f1-3)
    
    # Comparar si están en el mismo segmento
    if [ "$segmento1" != "$segmento2" ]; then
        echo "Error las IPs deben estar en el mismo segmento de red"
        echo "   IP1: $ip1 (segmento: $segmento1.X)"
        echo "   IP2: $ip2 (segmento: $segmento2.X)"
        return 1
    fi

    return 0
}

validar_no_cero(){
    local ip
    ip=$1
    
    # Validar que no sea 0.0.0.0
    if [ "$ip" = "0.0.0.0" ]; then
        echo "Error: No se puede usar la IP 0.0.0.0"
        return 1
    fi
    
    # Si no es 0.0.0.0
    return 0
}

#Funciones de solicitud de datos
solicitar_scope_name(){
    echo ""
    read -rp "Ingrese el nombre del ambito: " scope_name
    
    while [ -z "$scope_name" ]; do
        echo "El nombre del ambito no puede estar vacío"
        read -rp "Ingrese el nombre del ámbito" scope_name
    done
    
    echo "Scope: $scope_name"
}

solicitar_rango_ips(){
    echo ""
    echo "Configuracion de rangos"

    while true; do
        read -rp "ingrese la IP inical del rango: " ip_inicial

        #validar que no este vacia
        if [ -z "$ip_inicial" ]; then 
            echo "la IP inical no puede estar vacia"
            continue
        fi

        # Validar formato IPv4 (llamar función de validación)
        if ! validar_ip "$ip_inicial"; then
            continue
        fi
        
        # Validar que no sea loopback
        if ! validar_no_loopback "$ip_inicial"; then
            continue
        fi
        
        # Validar que no sea broadcast
        if ! validar_no_broadcast "$ip_inicial"; then
            continue
        fi

        # Validar que no sea 0.0.0.0
        if ! validar_no_cero "$ip_inicial"; then
            continue
        fi

        echo "IP INICIAL : $ip_inicial"
        break
    done 

    #Solicitar IP final
    while true; do
        read -rp "Ingrese la IP final del rango: " ip_final
        
        # Validar que no esté vacía
        if [ -z "$ip_final" ]; then
            echo "La IP final no puede estar vacía"
            continue
        fi
        
        # Validar formato IPv4
        if ! validar_ip "$ip_final"; then
            continue
        fi
        
        # Validar que no sea loopback
        if ! validar_no_loopback "$ip_final"; then
            continue
        fi
        
        # Validar que no sea broadcast
        if ! validar_no_broadcast "$ip_final"; then
            continue
        fi
        
        # Validar que esté en el mismo segmento que ip_inicial
        if ! validar_mismo_segmento "$ip_inicial" "$ip_final"; then
            continue
        fi
        
        # Validar que IP_final > IP_inicial
        if ! validar_rango "$ip_inicial" "$ip_final"; then
            continue
        fi
        
        # Validar que no sea 0.0.0.0
        if ! validar_no_cero "$ip_inicial"; then
            continue
        fi

        # Si pasa todas las validaciones
        echo "IP final: $ip_final"
        break
    done
}

solicitar_lease_time(){
    echo ""
    echo "--- Tiempo de Concesion (Lease Time) ---"
    
    while true; do
        read -rp "Ingrese el tiempo de concesion en segundos: " lease_time
        
        # Validar que no esté vacío
        if [ -z "$lease_time" ]; then
            echo "Error: el tiempo de concesion no puede estar vacio"
            continue
        fi
        
        # Validar que sea un número
        if ! [[ "$lease_time" =~ ^[0-9]+$ ]]; then
            echo "Error debe ingresar un numero valido"
            continue
        fi
        
        # Validar que sea mayor a 0
        if [ "$lease_time" -le 0 ]; then
            echo "Error el tiempo debe ser mayor a 0 segundos"
            continue
        fi
        
        # Si pasa todas las validaciones
        echo "Lease time: $lease_time segundos"
        break
    done
}

solicitar_gateway(){
    echo ""
    echo "--- Gateway/Router (Opcional) ---"
    
    while true; do
        read -rp "Ingrese la direccion IP del Gateway [Enter para omitir]: " gateway
        
        # Si está vacío, omitir (opcional)
        if [ -z "$gateway" ]; then
            gateway=""
            break
        fi
        
        # Validar formato IPv4
        if ! validar_ip "$gateway"; then
            continue
        fi
        
        # Validar que no sea loopback
        if ! validar_no_loopback "$gateway"; then
            continue
        fi
        
        # Validar que no sea broadcast
        if ! validar_no_broadcast "$gateway"; then
            continue
        fi
        
        # Validar que esté en mismo segmento y fuera del rango
        if ! validar_gateway "$gateway" "$ip_inicial" "$ip_final"; then
            continue
        fi

        # Validar que no sea 0.0.0.0
        if ! validar_no_cero "$gateway"; then  # ✅ Validar el gateway
            continue
        fi
        
        # Si pasa todas las validaciones
        echo "Gateway: $gateway"
        break
    done
}

solicitar_dns(){
    echo ""
    echo "--- Servidor DNS (Opcional) ---"
    echo "Puede ingresar hasta 2 servidores DNS"
    
    # DNS Primario
    while true; do
        read -rp "Ingrese DNS primario [Enter para omitir]: " dns1
        
        # Si está vacío, omitir ambos DNS
        if [ -z "$dns1" ]; then
            dns1=""
            dns2=""
            echo "Sin DNS configurado"
            break
        fi
        
        # Validar formato IPv4
        if ! validar_ip "$dns1"; then
            continue
        fi
        
        # Validar que no sea loopback
        if ! validar_no_loopback "$dns1"; then
            continue
        fi
        
        # Validar que no sea broadcast
        if ! validar_no_broadcast "$dns1"; then
            continue
        fi

        # Validar que no sea 0.0.0.0
        if ! validar_no_cero "$dns1"; then
            continue
        fi
        
        echo "DNS primario: $dns1"
        break
    done
    
    # DNS Secundario (solo si ingresó el primario)
    if [ -n "$dns1" ]; then
        while true; do
            read -rp "Ingrese DNS secundario [Enter para omitir]: " dns2
            
            # Si está vacío, omitir
            if [ -z "$dns2" ]; then
                dns2=""
                break
            fi
            
            # Validar formato IPv4
            if ! validar_ip "$dns2"; then
                continue
            fi
            
            # Validar que no sea loopback
            if ! validar_no_loopback "$dns2"; then
                continue
            fi
            
            # Validar que no sea broadcast
            if ! validar_no_broadcast "$dns2"; then
                continue
            fi

            # Validar que no sea 0.0.0.0
            if ! validar_no_cero "$dns2"; then
                continue
            fi
            
            # Validar que no sea igual al DNS primario
            if [ "$dns2" = "$dns1" ]; then
                echo "Error: El DNS secundario debe ser diferente al primario"
                continue
            fi
            
            echo "DNS secundario: $dns2"
            break
        done
    fi
}

aplicar_configuracion(){
    echo ""
    echo "Aplicando configuracion..."
    
    # Calcular la máscara de red
    if ! calcular_mascara "$ip_inicial" "$ip_final"; then
        echo "Error al calcular la mascara de red"
        return 1
    fi
    
    echo "Mascara calculada: $mascara (/$cidr)"
    echo "Red base: $red_base"
    
    # 1. Configurar IP estatica del servidor en la interfaz
    echo "Configurando interfaz de red enp0s8..."
    
    # Crear archivo de configuracion de red
    cat > /etc/systemd/network/20-wired.network << EOF
[Match]
Name=enp0s8

[Network]
Address=$ip_inicial/$cidr
EOF
    
    # Reiniciar el servicio de red
    systemctl restart systemd-networkd
    
    echo "Interfaz configurada con IP: $ip_inicial/$cidr"
    
    # 2. Crear archivo de configuracion DHCP
    echo "Creando archivo de configuracion DHCP..."
    
    # Calcular IP inicial del rango DHCP (ip_inicial + 1)
    local octeto4_inicial
    octeto4_inicial=$(echo "$ip_inicial" | cut -d'.' -f4)
    local octeto4_rango_inicio=$((octeto4_inicial + 1))
    
    local segmento
    segmento=$(echo "$ip_inicial" | cut -d'.' -f1-3)
    
    local rango_inicio="$segmento.$octeto4_rango_inicio"
    
    # Crear configuracion dhcpd.conf
    cat > /etc/dhcp/dhcpd.conf << EOF
# Configuracion DHCP - $scope_name
default-lease-time $lease_time;
max-lease-time $lease_time;

subnet $red_base netmask $mascara {
    range $rango_inicio $ip_final;
EOF
    
    # Agregar gateway si fue configurado
    if [ -n "$gateway" ]; then
        echo "    option routers $gateway;" >> /etc/dhcp/dhcpd.conf
    fi
    
    # Agregar DNS si fueron configurados
    if [ -n "$dns1" ] && [ -n "$dns2" ]; then
        # Ambos DNS configurados
        echo "    option domain-name-servers $dns1, $dns2;" >> /etc/dhcp/dhcpd.conf
    elif [ -n "$dns1" ]; then
        # Solo DNS primario
        echo "    option domain-name-servers $dns1;" >> /etc/dhcp/dhcpd.conf
    fi
    
    # Cerrar el bloque subnet
    echo '}' >> /etc/dhcp/dhcpd.conf
    
    echo "Archivo dhcpd.conf creado"
    
    # Crear archivo de leases si no existe
    if [ ! -f /var/lib/dhcp/dhcpd.leases ]; then
        touch /var/lib/dhcp/dhcpd.leases
        echo "Archivo de concesiones creado"
    fi
    
    # Configurar la interfaz en el servicio DHCP
    echo "Configurando servicio DHCP..."
    
    # Crear directorio si no existe
    mkdir -p /etc/systemd/system/dhcpd4.service.d
    
    # Editar el archivo de servicio para especificar la interfaz
    cat > /etc/systemd/system/dhcpd4.service.d/override.conf << EOF
[Service]
ExecStart=
ExecStart=/usr/bin/dhcpd -4 -q -cf /etc/dhcp/dhcpd.conf -pf /run/dhcpd4.pid enp0s8
EOF
    
    # Recargar systemd
    systemctl daemon-reload
    
    # 5. Iniciar y habilitar el servicio DHCP
    echo "Iniciando servicio DHCP..."
    systemctl enable dhcpd4.service
    systemctl restart dhcpd4.service
    
    # Verificar estado
    if systemctl is-active --quiet dhcpd4.service; then
        echo ""
        echo "Configuracion aplicada exitosamente"
        echo "Servidor DHCP activo y funcionando"
    else
        echo ""
        echo "Error: El servicio DHCP no pudo iniciarse"
        echo "Verifique los logs con: journalctl -xeu dhcpd4.service"
        return 1
    fi
}

calcular_mascara(){
    local ip1
    local ip2
    ip1="$1"
    ip2="$2"
    
    # Separar octetos
    local o1_1 o1_2 o1_3 o1_4
    local o2_1 o2_2 o2_3 o2_4
    
    o1_1=$(echo "$ip1" | cut -d'.' -f1)
    o1_2=$(echo "$ip1" | cut -d'.' -f2)
    o1_3=$(echo "$ip1" | cut -d'.' -f3)
    o1_4=$(echo "$ip1" | cut -d'.' -f4)
    
    o2_1=$(echo "$ip2" | cut -d'.' -f1)
    o2_2=$(echo "$ip2" | cut -d'.' -f2)
    o2_3=$(echo "$ip2" | cut -d'.' -f3)
    o2_4=$(echo "$ip2" | cut -d'.' -f4)
    
    # Comparar octetos para determinar la máscara
    if [ "$o1_1" = "$o2_1" ] && [ "$o1_2" = "$o2_2" ] && [ "$o1_3" = "$o2_3" ]; then
        # Clase C - /24
        mascara="255.255.255.0"
        cidr="24"
        red_base="$o1_1.$o1_2.$o1_3.0"
    elif [ "$o1_1" = "$o2_1" ] && [ "$o1_2" = "$o2_2" ]; then
        # Clase B - /16
        mascara="255.255.0.0"
        cidr="16"
        red_base="$o1_1.$o1_2.0.0"
    elif [ "$o1_1" = "$o2_1" ]; then
        # Clase A - /8
        mascara="255.0.0.0"
        cidr="8"
        red_base="$o1_1.0.0.0"
    else
        echo "Error: Las IPs no estan en la misma red"
        return 1
    fi
    
    # Las variables se exportan para usarlas después
    export mascara
    export cidr
    export red_base
    
    return 0
}

#Funcion para mostrar el menu
menu(){
    clear
    echo "____________________________________________"
    echo "          Gestor Servidor DHCP             "
    echo "____________________________________________"
    echo " 1. Verificar instalacion                  "
    echo " 2 .Instalar servidor                      "
    echo " 3. Configurar DHCP                        "
    echo " 4. Monitorear Concesiones activas         "
    echo " 5. Monitorear estado del servidor         "
    echo " 6. Apagar servidor DHCP                   "
    echo " 0. Salir del menu                         "
    echo "____________________________________________"
}

verificar_dhcp(){
    echo "Verificando servidor DHCP"

    #verificar si el paquete esta instalado o la idempotencia

    if pacman -Q isc-dhcp-server &>/dev/null; then
        echo "El servidor DHCP esta instalado"
        echo ""
        read -rp "¿Desea reinstalarlo y eliminar configuracion actual? (s/n): " respuesta

        if [[ "$respuesta" != "s" && "$respuesta" != "S" ]]; then 
            echo "Reinstalacion cancelada"
            return 0
        fi

        echo "Procediendo con la reinstalacion"

        #detener el servicio de dhcp
        sudo systemctl stop dhcp4.service &>/dev/null
        #desinstalar el paquete dhcp
        sudo pacman -Rns --noconfirm isc-dhcp-server
        #eliminar archivos de configuracion
        sudo rm -f /etc/dhcp/dhcpd.conf
        sudo rm -f /var/lib/dhcp/dhcpd.leases

        pacman -Q isc-dhcp-server

    else 
        echo "el servidor DHCP no esta instalado"
    fi
}

instalar_dhcp(){
    echo "Instalacion Servidor DHCP"

    if pacman -Q isc-dhcp-server &>/dev/null; then
        echo "El servidor DHCP ya esta instalado"
        return 0
    fi

    echo "Realizando instalacion"

    #Instalar de forma destendida
    sudo pacman -S --noconfirm isc-dhcp-server

    if pacman -Q isc-dhcp-server &>/dev/null; then
        echo "Instalacion Completada"
    else
        echo "Error: Instalacion Fallida"
        return 1
    fi
}

configurar_dhcp(){
    echo "============================================"
    echo "    Configuracion del servidor DHCP        "
    echo "============================================"
    
    # Solicitar todos los datos
    solicitar_scope_name
    solicitar_rango_ips
    solicitar_lease_time
    solicitar_gateway
    solicitar_dns
    
    # Calcular la máscara ANTES de mostrar el resumen
    if ! calcular_mascara "$ip_inicial" "$ip_final"; then
        echo "Error al calcular la mascara de red"
        return 1
    fi
    
    # Mostrar resumen de configuración
    echo ""
    echo "============================================"
    echo "    RESUMEN DE CONFIGURACION               "
    echo "============================================"
    echo "Scope: $scope_name"
    echo "IP del servidor: $ip_inicial/$cidr"
    echo "Mascara de red: $mascara"
    echo "Red base: $red_base"
    echo "Rango DHCP: $ip_inicial - $ip_final"
    echo "Lease time: $lease_time segundos"
    
    if [ -n "$gateway" ]; then
        echo "Gateway: $gateway"
    else
        echo "Gateway: (no configurado)"
    fi
    
    if [ -n "$dns1" ]; then
        echo "DNS primario: $dns1"
        if [ -n "$dns2" ]; then
            echo "DNS secundario: $dns2"
        fi
    else
        echo "DNS: (no configurado)"
    fi
    
    echo "============================================"
    echo ""
    
    # Confirmar antes de aplicar
    read -rp "Desea aplicar esta configuracion? (s/n): " confirmar
    
    if [[ "$confirmar" != "s" && "$confirmar" != "S" ]]; then
        echo "Configuracion cancelada"
        return 0
    fi
    
    # Aplicar la configuración
    aplicar_configuracion
    
    echo "-------------------------------------------"
}

monitorear_consesiones(){
    echo "-------------------------------------------"
    echo "    Monitoreo de Concesiones Activas       "
    echo "-------------------------------------------"
    
    # Verificar si el servicio está corriendo
    if ! systemctl is-active --quiet dhcpd4.service 2>/dev/null; then
        echo "Error: El servicio DHCP no esta activo"
        echo "Inicie el servicio primero (opcion 3)"
        return 1
    fi
    
    # Verificar si existe el archivo de leases
    if [ ! -f /var/lib/dhcp/dhcpd.leases ]; then
        echo "No hay archivo de concesiones disponible"
        return 1
    fi
    
    echo ""
    echo "Concesiones activas:"
    echo "--------------------------------------------"
    
    # Intentar leer las concesiones con manejo de errores
    if ! grep -q "^lease" /var/lib/dhcp/dhcpd.leases 2>/dev/null; then
        echo "No hay concesiones activas en este momento"
        echo "============================================"
        return 0
    fi
    
    # Leer y mostrar las concesiones activas
    grep "^lease" /var/lib/dhcp/dhcpd.leases 2>/dev/null | awk '{print $2}' | sort -u | while read -r ip; do
        if [ -n "$ip" ]; then
            echo "IP asignada: $ip"
        fi
    done
    
    # Contar total de concesiones
    local total
    total=$(grep "^lease" /var/lib/dhcp/dhcpd.leases 2>/dev/null | awk '{print $2}' | sort -u | wc -l)
    
    echo "--------------------------------------------"
    echo " Total de concesiones activas: $total"
    echo "--------------------------------------------"
}

monitorear_estado(){
    echo "-------------------------------------------"
    echo "    Estado del Servidor DHCP               "
    echo "-------------------------------------------"
    
    # Verificar si el paquete está instalado
    if ! pacman -Q isc-dhcp-server &>/dev/null; then
        echo "El servidor DHCP NO esta instalado"
        echo "Use la opcion 2 para instalarlo"
        return 1
    fi
    
    echo "Paquete: isc-dhcp-server - INSTALADO"
    echo ""
    
    # Verificar estado del servicio
    echo "Estado del servicio:"
    echo "--------------------------------------------"
    
    if systemctl is-active --quiet dhcpd4.service; then
        echo "Estado: ACTIVO"
        echo "El servidor DHCP esta funcionando correctamente"
    else
        echo "Estado: INACTIVO"
        echo "El servidor DHCP NO esta corriendo"
    fi
    
    echo ""
    
    # Verificar si está habilitado para iniciar al arranque
    if systemctl is-enabled --quiet dhcpd4.service 2>/dev/null; then
        echo "Inicio automatico: HABILITADO"
    else
        echo "Inicio automatico: DESHABILITADO"
    fi
    
    echo ""
    echo "--------------------------------------------"
    echo "Informacion detallada del servicio:"
    echo ""
    systemctl status dhcpd4.service --no-pager
    
    echo "--------------------------------------------"
}

apagar_servidor(){
    echo "============================================"
    echo "    Apagar Servidor DHCP                   "
    echo "============================================"
    
    # Verificar si el servicio está corriendo
    if ! systemctl is-active --quiet dhcpd4.service; then
        echo "El servidor DHCP ya esta detenido"
        return 0
    fi
    
    echo ""
    read -rp "Esta seguro que desea detener el servidor DHCP? (s/n): " confirmar
    
    if [[ "$confirmar" != "s" && "$confirmar" != "S" ]]; then
        echo "Operacion cancelada"
        return 0
    fi
    
    echo ""
    echo "Deteniendo servidor DHCP..."
    
    # Detener el servicio
    systemctl stop dhcpd4.service
    
    # Verificar que se detuvo
    if ! systemctl is-active --quiet dhcpd4.service; then
        echo "Servidor DHCP detenido exitosamente"
        
        # Preguntar si quiere deshabilitar el inicio automático
        echo ""
        read -rp "Desea deshabilitar el inicio automatico? (s/n): " deshabilitar
        
        if [[ "$deshabilitar" = "s" || "$deshabilitar" = "S" ]]; then
            systemctl disable dhcpd4.service
            echo "Inicio automatico deshabilitado"
        fi
    else
        echo "Error: No se pudo detener el servidor DHCP"
        return 1
    fi
    
    echo "============================================"
}

while true; do
    menu
    read -rp "Selecione una opcion: " opcion
    
    case $opcion in
        1) verificar_dhcp;;
        2) instalar_dhcp;;
        3) configurar_dhcp;;
        4) monitorear_consesiones;;
        5) monitorear_estado;;
        6) apagar_servidor;;
        0) echo "saliendo" ; exit 0;;
        *) echo "opcion invalida";;
    esac
    
    read -rp "presiona enter para continuar"
done