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

# Verificar permisos de root
if [ "$EUID" -ne 0 ]; then
    echo "Este script debe ejecutarse como root"
    echo "Usa: sudo bash dns.sh"
    exit 1
fi

verificar_bind(){
    echo "-------------------------------------------"
    echo "    Verificacion de BIND9                  "
    echo "-------------------------------------------"
    
    # Verificamos si el paquete bind está instalado
    # pacman -Q consulta paquetes instalados
    # si no está instalado, pacman devuelve error
    if pacman -Q bind >/dev/null 2>&1; then
        echo "Paquete bind: INSTALADO"
    else
        echo "Paquete bind: NO INSTALADO"
        echo "Use la opcion 2 para instalarlo"
        return 1
    fi

    echo ""

    # Verificamos si el servicio named está corriendo
    # named es el proceso de BIND9 en Arch Linux
    if systemctl is-active --quiet named; then
        echo "Servicio named: ACTIVO"
    else
        echo "Servicio named: INACTIVO"
    fi

    echo ""

    # Verificamos si está habilitado para iniciar con el sistema
    if systemctl is-enabled --quiet named 2>/dev/null; then
        echo "Inicio automatico: HABILITADO"
    else
        echo "Inicio automatico: DESHABILITADO"
    fi

    echo "-------------------------------------------"
}

instalar_bind(){
    echo "-------------------------------------------"
    echo "    Instalacion y configuracion de BIND9   "
    echo "-------------------------------------------"

    if pacman -Q bind >/dev/null 2>&1; then
        echo "BIND9 ya esta instalado"
        return 0
    fi

    echo "Instalando BIND9..."
    pacman -S --noconfirm bind >/dev/null 2>&1

    if ! pacman -Q bind >/dev/null 2>&1; then
        echo "Error: La instalacion fallo"
        return 1
    fi

    echo "Paquete bind instalado correctamente"
    echo ""

    echo "Detectando IP del servidor..."
    ip_servidor=$(ip -4 addr show enp0s8 | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+')

    if [ -z "$ip_servidor" ]; then
        echo "Error: enp0s8 no tiene IP asignada"
        return 1
    fi

    echo "IP detectada: $ip_servidor"
    echo ""

    mkdir -p /var/named
    chown named:named /var/named
    chmod 770 /var/named

    echo "Descargando zona raiz..."
    curl -o /var/named/root.hints https://www.internic.net/domain/named.root 2>/dev/null
    chown named:named /var/named/root.hints
    echo "Zona raiz descargada"
    echo ""

    echo "Generando named.conf..."
    cat > /etc/named.conf << EOF
options {
    listen-on { 127.0.0.1; $ip_servidor; };
    directory "/var/named";
    allow-query { any; };
    recursion yes;
};

zone "." IN {
    type hint;
    file "root.hints";
};
EOF

    echo "Aplicando fix para jemalloc..."
    mkdir -p /etc/systemd/system/named.service.d
    cat > /etc/systemd/system/named.service.d/fix.conf << EOF
[Service]
LD_PRELOAD=
Environment=MALLOC_CONF=
ExecStart=
ExecStart=/usr/bin/named -f -4 -u named
EOF

    systemctl daemon-reload
    echo ""

    echo "Habilitando e iniciando named..."
    systemctl enable named >/dev/null 2>&1
    systemctl start named
    sleep 2

    if systemctl is-active --quiet named; then
        echo ""
        echo "-------------------------------------------"
        echo "   BIND9 instalado y configurado           "
        echo "-------------------------------------------"
        echo "Servicio named: ACTIVO"
        echo "IP del servidor: $ip_servidor"
        echo "-------------------------------------------"
    else
        echo ""
        echo "-------------------------------------------"
        echo "   ERROR: El servicio named no inicio      "
        echo "-------------------------------------------"
        journalctl -xeu named -n 20 --no-pager
        return 1
    fi
}


agregar_zona(){
    echo "-------------------------------------------"
    echo "    Agregar Zona DNS                       "
    echo "-------------------------------------------"

    # Verificamos que BIND9 esté instalado antes de continuar
    if ! pacman -Q bind >/dev/null 2>&1; then
        echo "Error: BIND9 no esta instalado"
        echo "Use la opcion 2 para instalarlo"
        return 1
    fi

    # Detectamos la IP del servidor automáticamente
    ip_servidor=$(ip -4 addr show enp0s8 | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+')

    if [ -z "$ip_servidor" ]; then
        echo "Error: enp0s8 no tiene IP asignada"
        echo "Configura primero el servidor DHCP"
        return 1
    fi

    echo "IP del servidor detectada: $ip_servidor"
    echo ""

    # Pedimos el dominio al usuario
    while true; do
        read -rp "Ingrese el dominio (ejemplo: reprobados.com): " dominio

        if [ -z "$dominio" ]; then
            echo "Error: el dominio no puede estar vacio"
            continue
        fi

        # Validamos formato del dominio
        # debe tener al menos una letra, un punto y una extension
        if [[ ! "$dominio" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            echo "Error: formato invalido, ejemplo: reprobados.com"
            continue
        fi

        # Verificamos que la zona no exista ya
        if [ -f "/var/named/db.$dominio" ]; then
            echo "Error: la zona $dominio ya existe"
            echo "Use la opcion 4 para ver las zonas configuradas"
            continue
        fi

        echo "Dominio: $dominio"
        break
    done

    echo ""

    # Pedimos la IP destino (a donde apunta el dominio)
    while true; do
        read -rp "Ingrese la IP destino del dominio: " ip_destino

        if [ -z "$ip_destino" ]; then
            echo "Error: la IP no puede estar vacia"
            continue
        fi

        if ! validar_ip "$ip_destino"; then
            continue
        fi

        if ! validar_no_loopback "$ip_destino"; then
            continue
        fi

        if ! validar_no_broadcast "$ip_destino"; then
            continue
        fi

        if ! validar_no_cero "$ip_destino"; then
            continue
        fi

        echo "IP destino: $ip_destino"
        break
    done

    echo ""

    # Creamos el archivo de zona
    echo "Creando archivo de zona /var/named/db.$dominio..."

    cat > "/var/named/db.$dominio" << EOF
\$TTL 86400
@   IN  SOA ns1.$dominio. admin.$dominio. (
            2024010101  ; Serial
            3600        ; Refresh
            1800        ; Retry
            604800      ; Expire
            86400 )     ; Minimum TTL

; Servidor de nombres
@   IN  NS  ns1.$dominio.

; Registro A del servidor de nombres
ns1 IN  A   $ip_servidor

; Registro A del dominio raiz
@   IN  A   $ip_destino

; Registro CNAME para www
www IN  CNAME   @
EOF

    echo "Archivo de zona creado"
    echo ""

    # Agregamos la zona al named.conf
    echo "Agregando zona al named.conf..."

    cat >> /etc/named.conf << EOF

zone "$dominio" {
    type master;
    file "/var/named/db.$dominio";
};
EOF

    echo "Zona agregada al named.conf"
    echo ""

    # Reiniciamos named para que tome los cambios
    echo "Reiniciando servicio named..."
    systemctl restart named

    sleep 2

    if systemctl is-active --quiet named; then
        echo ""
        echo "-------------------------------------------"
        echo "   Zona configurada exitosamente           "
        echo "-------------------------------------------"
        echo "Dominio: $dominio"
        echo "IP destino: $ip_destino"
        echo "Servidor DNS: $ip_servidor"
        echo "Archivo de zona: /var/named/db.$dominio"
        echo "-------------------------------------------"
    else
        echo ""
        echo "-------------------------------------------"
        echo "   ERROR: named no reinicio               "
        echo "-------------------------------------------"
        journalctl -xeu named -n 20 --no-pager
        return 1
    fi
}

listar_zonas(){
    echo "-------------------------------------------"
    echo "    Zonas DNS Configuradas                 "
    echo "-------------------------------------------"

    # Verificamos que BIND9 esté instalado
    if ! pacman -Q bind >/dev/null 2>&1; then
        echo "Error: BIND9 no esta instalado"
        echo "Use la opcion 2 para instalarlo"
        return 1
    fi

    # Verificamos que exista la carpeta de zonas
    if [ ! -d "/var/named" ]; then
        echo "No hay zonas configuradas aun"
        echo "Use la opcion 3 para agregar una zona"
        return 0
    fi

    # Buscamos archivos de zona en /var/named
    # los archivos de zona siempre empiezan con db.
    zonas=$(ls /var/named/db.* 2>/dev/null)

    if [ -z "$zonas" ]; then
        echo "No hay zonas configuradas aun"
        echo "Use la opcion 3 para agregar una zona"
        return 0
    fi

    echo ""
    echo "Zonas encontradas:"
    echo ""

    # Contador para numerar las zonas
    contador=1

    # Recorremos cada archivo de zona
    for archivo in /var/named/db.*; do

        # Extraemos el nombre del dominio quitando /var/named/db.
        dominio=$(basename "$archivo" | sed 's/db\.//')

        # Buscamos la IP destino dentro del archivo de zona
        ip_destino=$(grep "^@" "$archivo" | grep "IN  A" | awk '{print $4}')

        echo " $contador) $dominio → $ip_destino"
        contador=$((contador + 1))
    done

    echo ""
    echo "Total de zonas: $((contador - 1))"
    echo "-------------------------------------------"
}

validar_configuracion(){
    echo "-------------------------------------------"
    echo "    Validacion de Configuracion DNS        "
    echo "-------------------------------------------"

    if ! pacman -Q bind >/dev/null 2>&1; then
        echo "Error: BIND9 no esta instalado"
        echo "Use la opcion 2 para instalarlo"
        return 1
    fi

    # Verificar sintaxis de named.conf
    echo "Verificando sintaxis de named.conf..."
    echo ""

    if named-checkconf /etc/named.conf; then
        echo "Sintaxis de named.conf: OK"
    else
        echo "Error: named.conf tiene errores de sintaxis"
        echo "Revise el archivo /etc/named.conf"
        return 1
    fi

    echo ""

    # Buscar zonas configuradas en /var/named
    echo "Buscando zonas configuradas..."
    echo ""

    zonas=$(ls /var/named/db.* 2>/dev/null)

    if [ -z "$zonas" ]; then
        echo "No hay zonas configuradas"
        echo "Use la opcion 3 para agregar una zona"
        return 0
    fi

    echo "Zonas disponibles:"
    echo ""

    declare -a lista_dominios

    contador=1
    for archivo in /var/named/db.*; do
        dominio=$(basename "$archivo" | sed 's/db\.//')
        lista_dominios[$contador]=$dominio
        echo " $contador) $dominio"
        contador=$((contador + 1))
    done

    echo ""

    # El usuario elige qué dominio probar
    while true; do
        read -rp "Seleccione el numero del dominio a probar: " seleccion

        if [ -z "$seleccion" ]; then
            echo "Error: debe seleccionar una opcion"
            continue
        fi

        if ! [[ "$seleccion" =~ ^[0-9]+$ ]]; then
            echo "Error: ingrese un numero valido"
            continue
        fi

        if [ "$seleccion" -lt 1 ] || [ "$seleccion" -ge "$contador" ]; then
            echo "Error: seleccione un numero entre 1 y $((contador - 1))"
            continue
        fi

        dominio_elegido=${lista_dominios[$seleccion]}
        echo "Dominio seleccionado: $dominio_elegido"
        break
    done

    echo ""

    # Verificar sintaxis del archivo de zona especifico
    echo "Verificando sintaxis del archivo de zona..."
    echo ""

    if named-checkzone "$dominio_elegido" "/var/named/db.$dominio_elegido"; then
        echo "Sintaxis del archivo de zona: OK"
    else
        echo "Error: el archivo de zona tiene errores"
        return 1
    fi

    echo ""

    # Probar resolucion DNS con nslookup para ambos casos
    echo "Probando resolucion DNS..."
    echo ""

    # Obtenemos la IP esperada y la IP del servidor
    ip_esperada=$(grep "^@" "/var/named/db.$dominio_elegido" | grep "IN  A" | awk '{print $4}')
    ip_servidor=$(ip -4 addr show enp0s8 | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+')

    # Probar sin www
    resultado_sin_www=$(nslookup "$dominio_elegido" "$ip_servidor" 2>/dev/null | grep "Address" | tail -1 | awk '{print $2}')

    if [ "$resultado_sin_www" = "$ip_esperada" ]; then
        echo "nslookup $dominio_elegido → $resultado_sin_www OK"
    else
        echo "nslookup $dominio_elegido → FALLO"
        echo "IP esperada: $ip_esperada"
        echo "IP obtenida: $resultado_sin_www"
    fi

    # Probar con www
    resultado_con_www=$(nslookup "www.$dominio_elegido" "$ip_servidor" 2>/dev/null | grep "Address" | tail -1 | awk '{print $2}')

    if [ "$resultado_con_www" = "$ip_esperada" ]; then
        echo "nslookup www.$dominio_elegido → $resultado_con_www OK"
    else
        echo "nslookup www.$dominio_elegido → FALLO"
        echo "IP esperada: $ip_esperada"
        echo "IP obtenida: $resultado_con_www"
    fi

    echo ""

    # Probar ping a ambos
    echo "Probando ping..."
    echo ""

    # Ping sin www
    if ping -c 3 "$dominio_elegido" >/dev/null 2>&1; then
        echo "ping $dominio_elegido → OK"
    else
        echo "ping $dominio_elegido → FALLO"
        echo "Nota: el ping puede fallar si el cliente no esta encendido"
    fi

    # Ping con www
    if ping -c 3 "www.$dominio_elegido" >/dev/null 2>&1; then
        echo "ping www.$dominio_elegido → OK"
    else
        echo "ping www.$dominio_elegido → FALLO"
        echo "Nota: el ping puede fallar si el cliente no esta encendido"
    fi

    echo ""
    echo "-------------------------------------------"
    echo "   Validacion completada                   "
    echo "-------------------------------------------"
}

monitorear_estado(){
    echo "-------------------------------------------"
    echo "    Estado del Servidor DNS                "
    echo "-------------------------------------------"

    # Verificar si el paquete está instalado
    if ! pacman -Q bind >/dev/null 2>&1; then
        echo "El servidor DNS NO esta instalado"
        echo "Use la opcion 2 para instalarlo"
        return 1
    fi

    echo "Paquete bind: INSTALADO"
    echo ""

    # Verificar estado del servicio
    echo "Estado del servicio:"
    echo "-------------------------------------------"

    if systemctl is-active --quiet named; then
        echo "Estado: ACTIVO"
        echo "El servidor DNS esta funcionando correctamente"
    else
        echo "Estado: INACTIVO"
        echo "El servidor DNS NO esta corriendo"
    fi

    echo ""

    # Verificar inicio automatico
    if systemctl is-enabled --quiet named 2>/dev/null; then
        echo "Inicio automatico: HABILITADO"
    else
        echo "Inicio automatico: DESHABILITADO"
    fi

    echo ""

    # Mostrar informacion detallada del servicio
    echo "-------------------------------------------"
    echo "Informacion detallada del servicio:"
    echo ""
    systemctl status named --no-pager

    echo "-------------------------------------------"
}

menu(){
    clear
    echo "____________________________________________"
    echo "        Gestor Servidor DNS - BIND9         "
    echo "____________________________________________"
    echo " 1. Verificar instalacion                  "
    echo " 2. Instalar y configurar BIND9            "
    echo " 3. Agregar zona DNS                       "
    echo " 4. Listar zonas configuradas              "
    echo " 5. Validar configuracion                  "
    echo " 6. Monitorear estado del servidor         "
    echo " 0. Salir                                  "
    echo "____________________________________________"
}

# Bucle principal para las opciones del menu
while true; do
    menu
    read -rp "Seleccione una opcion: " opcion

    case $opcion in
        1) verificar_bind ;;
        2) instalar_bind ;;
        3) agregar_zona ;;
        4) listar_zonas ;;
        5) validar_configuracion ;;
        6) monitorear_estado ;;
        0) echo "Saliendo..."; exit 0 ;;
        *) echo "Opcion invalida" ;;
    esac

    read -rp "Presiona Enter para continuar..."
done