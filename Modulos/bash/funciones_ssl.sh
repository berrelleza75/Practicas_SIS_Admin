#!/bin/bash

# funciones_ssl.sh
# Practica 7 - SSL/TLS + Cliente FTP dinamico + Orquestacion WEB/FTP
# Servicios Linux: vsftpd (FTPS), Apache (HTTPS), Nginx (HTTPS), Tomcat (HTTPS)

# ============================================================
# VARIABLES GLOBALES
# ============================================================

DOMINIO="reprobados.com"
IP_SERVIDOR="192.168.56.10"

# Repositorio FTP
REPO_ROOT="/srv/ftp/http"
REPO_USER="repoftp"
REPO_PASS="Repo.Ftp2026"

# Certificados PKI
CERT_DIR="/etc/ssl/practica7"
CERT_FILE="$CERT_DIR/${DOMINIO}.crt"
KEY_FILE="$CERT_DIR/${DOMINIO}.key"
CERT_DAYS=365

# Cliente FTP
DESCARGAS="/tmp/practica7_descargas"

# Resultado seleccion (variables globales para navegacion)
BINARIO_SELECCIONADO=""
RUTA_REMOTA_SELECCIONADA=""

# ============================================================
# BLOQUE 1: SETUP DEL REPOSITORIO FTP PRIVADO
# ============================================================

# Auto-instala vsftpd + dependencias minimas (openssl, curl) al iniciar.
# Genera /etc/vsftpd.conf base si no existe (chroot, sin escritura).
instalar_vsftpd_base() {
    echo "Verificando dependencias base..."

    # Sincroniza bases de pacman
    pacman -Sy --noconfirm >/dev/null 2>&1

    # vsftpd
    if pacman -Q vsftpd &>/dev/null; then
        echo "  vsftpd ya esta instalado."
    else
        echo "  Instalando vsftpd..."
        pacman -S --noconfirm vsftpd
    fi

    # openssl (para certificados)
    if ! pacman -Q openssl &>/dev/null; then
        echo "  Instalando openssl..."
        pacman -S --noconfirm openssl
    fi

    # curl (para cliente FTP)
    if ! pacman -Q curl &>/dev/null; then
        echo "  Instalando curl..."
        pacman -S --noconfirm curl
    fi

    # Configuracion base de vsftpd si no existe
    if [ ! -f /etc/vsftpd.conf ]; then
        echo "  Generando /etc/vsftpd.conf base..."
        cat > /etc/vsftpd.conf <<EOF
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=NO
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
allow_writeable_chroot=YES
userlist_enable=YES
userlist_file=/etc/vsftpd.userlist
userlist_deny=NO
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
EOF
        touch /etc/vsftpd.userlist
        mkdir -p /var/run/vsftpd/empty
    fi

    # Asegura que /bin/false este en /etc/shells (necesario para PAM)
    grep -q "/bin/false" /etc/shells || echo "/bin/false" >> /etc/shells

    # Habilita y arranca vsftpd
    systemctl enable vsftpd >/dev/null 2>&1
    systemctl start vsftpd

    if systemctl is-active --quiet vsftpd; then
        echo "  vsftpd activo."
    else
        echo "  ADVERTENCIA: vsftpd no arranco. Revisa journalctl -u vsftpd."
    fi
}

repo_inicializado() {
    [ -d "$REPO_ROOT/Linux/Apache" ] && \
    [ -d "$REPO_ROOT/Linux/Nginx" ] && \
    [ -d "$REPO_ROOT/Linux/Tomcat" ] && \
    id "$REPO_USER" &>/dev/null
}

crear_usuario_repo() {
    if id "$REPO_USER" &>/dev/null; then
        echo "Usuario $REPO_USER ya existe."
        return 0
    fi

    echo "Creando usuario $REPO_USER..."
    useradd -s /bin/false -d "$REPO_ROOT" -M "$REPO_USER"
    echo "$REPO_USER:$REPO_PASS" | chpasswd

    # Agrega al userlist de vsftpd (compatible con Practica 4)
    touch /etc/vsftpd.userlist
    if ! grep -q "^$REPO_USER$" /etc/vsftpd.userlist; then
        echo "$REPO_USER" >> /etc/vsftpd.userlist
    fi

    echo "Usuario $REPO_USER creado."
}

crear_estructura_repo() {
    echo "Creando estructura $REPO_ROOT..."

    mkdir -p "$REPO_ROOT/Linux/Apache"
    mkdir -p "$REPO_ROOT/Linux/Nginx"
    mkdir -p "$REPO_ROOT/Linux/Tomcat"
    mkdir -p "$REPO_ROOT/Windows/Apache"
    mkdir -p "$REPO_ROOT/Windows/Nginx"
    mkdir -p "$REPO_ROOT/Windows/Tomcat"

    # Raiz: root:root 755 obligatorio para chroot en vsftpd
    chown root:root "$REPO_ROOT"
    chmod 755 "$REPO_ROOT"
    find "$REPO_ROOT" -type d -exec chmod 755 {} \;

    echo "Estructura creada."
}

descargar_binario_pacman() {
    local servicio=$1
    local carpeta_repo=$2
    local cache_dir="/var/cache/pacman/pkg"

    echo "Descargando paquete $servicio con pacman -Sw..."
    pacman -Sw --noconfirm "$servicio" >/dev/null 2>&1

    local paquete
    paquete=$(ls -t "$cache_dir"/${servicio}-*.pkg.tar.zst 2>/dev/null | head -1)

    if [ -z "$paquete" ] || [ ! -f "$paquete" ]; then
        echo "  ERROR: No se descargo el paquete $servicio."
        return 1
    fi

    local nombre
    nombre=$(basename "$paquete")
    cp "$paquete" "$carpeta_repo/$nombre"

    (cd "$carpeta_repo" && sha256sum "$nombre" > "${nombre}.sha256")

    echo "  -> $carpeta_repo/$nombre"
    echo "  -> $carpeta_repo/${nombre}.sha256"
}

poblar_repo_linux() {
    echo "Poblando repositorio con binarios Linux..."
    pacman -Sy --noconfirm >/dev/null 2>&1

    descargar_binario_pacman "apache"   "$REPO_ROOT/Linux/Apache"
    descargar_binario_pacman "nginx"    "$REPO_ROOT/Linux/Nginx"
    descargar_binario_pacman "tomcat10" "$REPO_ROOT/Linux/Tomcat"

    chown -R root:root "$REPO_ROOT"
    find "$REPO_ROOT" -type d -exec chmod 755 {} \;
    find "$REPO_ROOT" -type f -exec chmod 644 {} \;
}

setup_repo_completo() {
    # Paso 0: asegura que vsftpd + dependencias esten instaladas
    instalar_vsftpd_base

    if repo_inicializado; then
        echo "Repositorio FTP ya inicializado en $REPO_ROOT."
        return 0
    fi

    echo "=== Inicializando repositorio FTP privado ==="
    crear_estructura_repo
    crear_usuario_repo
    poblar_repo_linux

    # Reinicia vsftpd para que tome el nuevo usuario y userlist
    systemctl restart vsftpd

    echo
    echo "=== Repositorio FTP listo ==="
    echo "  Servidor : ftp://$IP_SERVIDOR"
    echo "  Usuario  : $REPO_USER"
    echo "  Password : $REPO_PASS"
    echo "  Raiz     : $REPO_ROOT"
}

# ============================================================
# BLOQUE 2: CLIENTE FTP DINAMICO (curl no interactivo)
# ============================================================

listar_carpetas_ftp() {
    local ruta=$1
    curl -k --ssl-reqd -s --user "$REPO_USER:$REPO_PASS" \
        "ftp://$IP_SERVIDOR/$ruta/" 2>/dev/null | \
        awk '$1 ~ /^d/ {print $NF}' | grep -vE '^(\.|\.\.)$'
}

listar_binarios_ftp() {
    local ruta=$1
    curl -k --ssl-reqd -s --user "$REPO_USER:$REPO_PASS" \
        "ftp://$IP_SERVIDOR/$ruta/" 2>/dev/null | \
        awk '$1 !~ /^d/ {print $NF}' | \
        grep -v '\.sha256$' | grep -v '^$'
}

descargar_ftp() {
    local ruta_remota=$1
    local archivo=$2

    mkdir -p "$DESCARGAS"
    echo "Descargando $archivo desde ftp://$IP_SERVIDOR/$ruta_remota/..."
    curl -k --ssl-reqd -s --user "$REPO_USER:$REPO_PASS" \
        -o "$DESCARGAS/$archivo" \
        "ftp://$IP_SERVIDOR/$ruta_remota/$archivo"

    if [ ! -s "$DESCARGAS/$archivo" ]; then
        echo "  ERROR: Descarga fallida o archivo vacio."
        return 1
    fi

    echo "  -> $DESCARGAS/$archivo"
    return 0
}

validar_sha256() {
    local archivo=$1

    echo "Validando SHA256 de $archivo..."
    (
        cd "$DESCARGAS" || exit 1
        if sha256sum -c "${archivo}.sha256" 2>/dev/null | grep -q "OK"; then
            echo "  Hash OK: archivo integro."
            return 0
        else
            echo "  ERROR: Hash NO coincide. Archivo corrupto."
            return 1
        fi
    )
}

descargar_y_validar() {
    local ruta_remota=$1
    local archivo=$2

    descargar_ftp "$ruta_remota" "$archivo" || return 1
    descargar_ftp "$ruta_remota" "${archivo}.sha256" || return 1
    validar_sha256 "$archivo" || return 1
    return 0
}

# Selecciona automaticamente el binario mas reciente del servicio
# Establece: BINARIO_SELECCIONADO, RUTA_REMOTA_SELECCIONADA
seleccionar_binario_repo() {
    local servicio_filtro=$1  # "Apache", "Nginx" o "Tomcat"
    # repoftp tiene chroot a /srv/ftp/http, asi que la raiz FTP es Linux/...
    local ruta_servicio="Linux/$servicio_filtro"

    echo "Conectando al repositorio FTP $IP_SERVIDOR..."
    echo "Navegando $ruta_servicio..."

    local binarios
    mapfile -t binarios < <(listar_binarios_ftp "$ruta_servicio")

    if [ ${#binarios[@]} -eq 0 ]; then
        echo "ERROR: No hay binarios en $ruta_servicio."
        return 1
    fi

    # Toma el primero (mas reciente)
    BINARIO_SELECCIONADO="${binarios[0]}"
    RUTA_REMOTA_SELECCIONADA="$ruta_servicio"
    echo "  Binario seleccionado: $BINARIO_SELECCIONADO"
    return 0
}

# ============================================================
# BLOQUE 3: CERTIFICADOS PKI (self-signed)
# ============================================================

generar_certificado() {
    if [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then
        echo "Certificado ya existe en $CERT_DIR."
        return 0
    fi

    echo "Generando certificado self-signed para $DOMINIO..."
    mkdir -p "$CERT_DIR"

    openssl req -x509 -nodes -days $CERT_DAYS -newkey rsa:2048 \
        -keyout "$KEY_FILE" \
        -out "$CERT_FILE" \
        -subj "/C=MX/ST=Sinaloa/L=LosMochis/O=Practica7/OU=SysAdmin/CN=$DOMINIO" \
        -addext "subjectAltName=DNS:$DOMINIO,DNS:www.$DOMINIO,IP:$IP_SERVIDOR" \
        2>/dev/null

    chmod 600 "$KEY_FILE"
    chmod 644 "$CERT_FILE"

    echo "  -> $CERT_FILE"
    echo "  -> $KEY_FILE"
}

configurar_hosts() {
    if ! grep -q "$DOMINIO" /etc/hosts; then
        echo "$IP_SERVIDOR  $DOMINIO  www.$DOMINIO" >> /etc/hosts
        echo "Entrada agregada a /etc/hosts."
    fi
}

# ============================================================
# BLOQUE 4: ACTIVAR SSL POR SERVICIO
# ============================================================

# --- FTPS (vsftpd) ---
activar_ssl_vsftpd() {
    echo "Activando FTPS en vsftpd..."
    generar_certificado

    local conf="/etc/vsftpd.conf"

    # Quita config SSL previa si existe
    sed -i '/^# === SSL Practica 7 ===/,/^# === FIN SSL ===/d' "$conf"

    cat >> "$conf" <<EOF

# === SSL Practica 7 ===
ssl_enable=YES
allow_anon_ssl=NO
force_local_data_ssl=YES
force_local_logins_ssl=YES
ssl_tlsv1=YES
ssl_sslv2=NO
ssl_sslv3=NO
require_ssl_reuse=NO
ssl_ciphers=HIGH
rsa_cert_file=$CERT_FILE
rsa_private_key_file=$KEY_FILE
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40100
# === FIN SSL ===
EOF

    systemctl restart vsftpd
    echo "  vsftpd reiniciado con FTPS activo."
}

# --- HTTPS Apache ---
activar_ssl_apache() {
    echo "Activando HTTPS en Apache (httpd)..."
    generar_certificado

    local conf="/etc/httpd/conf/httpd.conf"
    local ssl_conf="/etc/httpd/conf/extra/httpd-ssl.conf"
    local vhosts_conf="/etc/httpd/conf/extra/httpd-vhosts.conf"

    # Activa modulos SSL y socache
    sed -i 's|^#LoadModule ssl_module|LoadModule ssl_module|' "$conf"
    sed -i 's|^#LoadModule socache_shmcb_module|LoadModule socache_shmcb_module|' "$conf"
    sed -i 's|^#Include conf/extra/httpd-ssl.conf|Include conf/extra/httpd-ssl.conf|' "$conf"
    sed -i 's|^#Include conf/extra/httpd-vhosts.conf|Include conf/extra/httpd-vhosts.conf|' "$conf"

    # Configura certificado en httpd-ssl.conf
    sed -i "s|^SSLCertificateFile.*|SSLCertificateFile \"$CERT_FILE\"|" "$ssl_conf"
    sed -i "s|^SSLCertificateKeyFile.*|SSLCertificateKeyFile \"$KEY_FILE\"|" "$ssl_conf"

    # VirtualHost de redireccion HTTP -> HTTPS + HSTS
    cat > "$vhosts_conf" <<EOF
<VirtualHost *:80>
    ServerName $DOMINIO
    ServerAlias www.$DOMINIO
    Redirect permanent / https://$DOMINIO/
</VirtualHost>

<VirtualHost *:443>
    ServerName $DOMINIO
    ServerAlias www.$DOMINIO
    DocumentRoot "/srv/http"
    SSLEngine on
    SSLCertificateFile "$CERT_FILE"
    SSLCertificateKeyFile "$KEY_FILE"
    Header always set Strict-Transport-Security "max-age=63072000"
</VirtualHost>
EOF

    # Modulo headers para HSTS
    sed -i 's|^#LoadModule headers_module|LoadModule headers_module|' "$conf"

    systemctl restart httpd
    echo "  Apache reiniciado con HTTPS (443) y redirect 80->443."
}

# --- HTTPS Nginx ---
# Nota: Nginx usa 8080 (HTTP) y 8444 (HTTPS) para coexistir con Apache en 80/443.
activar_ssl_nginx() {
    echo "Activando HTTPS en Nginx (puertos 8080 y 8444)..."
    generar_certificado

    local conf="/etc/nginx/nginx.conf"

    # Backup una sola vez
    [ ! -f "${conf}.orig" ] && cp "$conf" "${conf}.orig"

    cat > "$conf" <<EOF
worker_processes  1;
events { worker_connections 1024; }

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    # Redirect HTTP -> HTTPS (8080 -> 8444)
    server {
        listen 8080;
        server_name $DOMINIO www.$DOMINIO;
        return 301 https://\$host:8444\$request_uri;
    }

    # HTTPS en 8444 (Apache ya usa 443)
    server {
        listen 8444 ssl;
        server_name $DOMINIO www.$DOMINIO;

        ssl_certificate     $CERT_FILE;
        ssl_certificate_key $KEY_FILE;
        ssl_protocols       TLSv1.2 TLSv1.3;
        ssl_ciphers         HIGH:!aNULL:!MD5;

        add_header Strict-Transport-Security "max-age=63072000" always;

        location / {
            root   /usr/share/nginx/html;
            index  index.html;
        }
    }
}
EOF

    nginx -t >/dev/null 2>&1 && systemctl restart nginx
    echo "  Nginx reiniciado con HTTPS (8444) y redirect 8080->8444."
}

# --- HTTPS Tomcat ---
activar_ssl_tomcat() {
    echo "Activando HTTPS en Tomcat (puerto 8443)..."
    generar_certificado

    local tomcat_home="/usr/share/tomcat10"
    local server_xml="/etc/tomcat10/server.xml"
    local keystore="$tomcat_home/conf/keystore.p12"

    [ -d "/etc/tomcat10" ] || mkdir -p /etc/tomcat10

    # Genera keystore PKCS12 desde el cert PEM
    if [ ! -f "$keystore" ]; then
        openssl pkcs12 -export \
            -in "$CERT_FILE" \
            -inkey "$KEY_FILE" \
            -out "$keystore" \
            -name "tomcat" \
            -password pass:changeit 2>/dev/null
        chown tomcat:tomcat "$keystore" 2>/dev/null
        chmod 640 "$keystore"
    fi

    # Backup
    [ ! -f "${server_xml}.orig" ] && [ -f "$server_xml" ] && cp "$server_xml" "${server_xml}.orig"

    # Inserta conector HTTPS si no existe
    if ! grep -q 'port="8443"' "$server_xml" 2>/dev/null; then
        sed -i "/<\/Service>/i\\
    <Connector port=\"8443\" protocol=\"org.apache.coyote.http11.Http11NioProtocol\"\\
               maxThreads=\"150\" SSLEnabled=\"true\" scheme=\"https\" secure=\"true\">\\
        <SSLHostConfig>\\
            <Certificate certificateKeystoreFile=\"$keystore\"\\
                         certificateKeystorePassword=\"changeit\"\\
                         type=\"RSA\" />\\
        </SSLHostConfig>\\
    </Connector>" "$server_xml"
    fi

    systemctl restart tomcat10 2>/dev/null
    echo "  Tomcat reiniciado con HTTPS en :8443."
}

# Dispatcher: activa SSL en el servicio elegido
activar_ssl_servicio() {
    local servicio=$1
    case "$servicio" in
        vsftpd) activar_ssl_vsftpd ;;
        apache) activar_ssl_apache ;;
        nginx)  activar_ssl_nginx ;;
        tomcat) activar_ssl_tomcat ;;
        *) echo "Servicio desconocido: $servicio" ;;
    esac
}

# ============================================================
# BLOQUE 5: INSTALACION WEB vs FTP
# ============================================================

# Mapea nombre logico a paquete real de Arch
paquete_arch() {
    case "$1" in
        apache) echo "apache" ;;
        nginx)  echo "nginx" ;;
        tomcat) echo "tomcat10" ;;
    esac
}

# Mapea nombre logico a servicio systemd
servicio_systemd() {
    case "$1" in
        apache) echo "httpd" ;;
        nginx)  echo "nginx" ;;
        tomcat) echo "tomcat10" ;;
        vsftpd) echo "vsftpd" ;;
    esac
}

# Mapea nombre logico a carpeta del repo
carpeta_repo_servicio() {
    case "$1" in
        apache) echo "Apache" ;;
        nginx)  echo "Nginx" ;;
        tomcat) echo "Tomcat" ;;
    esac
}

instalar_servicio_web() {
    local servicio=$1
    local paquete
    paquete=$(paquete_arch "$servicio")

    echo "Instalando $servicio desde WEB (pacman -Sy)..."
    pacman -Sy --noconfirm "$paquete"

    local svc
    svc=$(servicio_systemd "$servicio")
    systemctl enable "$svc" 2>/dev/null
    systemctl start "$svc" 2>/dev/null

    echo "$servicio instalado via WEB."
}

instalar_servicio_ftp() {
    local servicio=$1
    local carpeta
    carpeta=$(carpeta_repo_servicio "$servicio")

    echo "Instalando $servicio desde FTP privado..."

    # Navegacion dinamica del repo
    seleccionar_binario_repo "$carpeta" || return 1

    # Descarga + valida SHA256
    descargar_y_validar "$RUTA_REMOTA_SELECCIONADA" "$BINARIO_SELECCIONADO" || {
        echo "ERROR: Validacion de integridad fallida. Instalacion abortada."
        return 1
    }

    # Instalacion local con pacman -U
    echo "Instalando paquete local..."
    pacman -U --noconfirm "$DESCARGAS/$BINARIO_SELECCIONADO"

    local svc
    svc=$(servicio_systemd "$servicio")
    systemctl enable "$svc" 2>/dev/null
    systemctl start "$svc" 2>/dev/null

    echo "$servicio instalado via FTP."
}

# Instalacion automatica: siempre FTP + siempre SSL (sin preguntar)
instalar_servicio() {
    local servicio=$1

    echo
    echo "--- Instalacion automatica de $servicio ---"
    echo "  Origen: FTP (repositorio privado)"
    echo "  SSL   : Activado automaticamente"

    instalar_servicio_ftp "$servicio" || return 1
    activar_ssl_servicio "$servicio"
}

# ============================================================
# BLOQUE 6: VERIFICACION AUTOMATIZADA
# ============================================================

verificar_puerto() {
    local puerto=$1
    ss -tln 2>/dev/null | grep -q ":$puerto " && return 0 || return 1
}

verificar_ssl_servicio() {
    local servicio=$1
    local puerto=$2
    local protocolo=$3  # https o ftps

    local instalado="NO"
    local activo="NO"
    local ssl_ok="NO"
    local svc
    svc=$(servicio_systemd "$servicio")

    if pacman -Q "$(paquete_arch "$servicio" 2>/dev/null || echo "$servicio")" &>/dev/null 2>&1 || \
       pacman -Q "$servicio" &>/dev/null; then
        instalado="SI"
    fi

    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        activo="SI"
    fi

    if verificar_puerto "$puerto"; then
        if [ "$protocolo" = "https" ]; then
            if curl -k -s -o /dev/null -w "%{http_code}" "https://$IP_SERVIDOR:$puerto" \
                --connect-timeout 3 | grep -qE "^(200|301|302|403)$"; then
                ssl_ok="SI"
            fi
        elif [ "$protocolo" = "ftps" ]; then
            # Prueba FTPS haciendo login real con curl
            if curl -k --ssl-reqd -s --user "$REPO_USER:$REPO_PASS" \
                "ftp://$IP_SERVIDOR/" --connect-timeout 3 -o /dev/null 2>/dev/null; then
                ssl_ok="SI"
            fi
        fi
    fi

    printf "  %-10s | Instalado: %-3s | Activo: %-3s | Puerto %s: %-3s\n" \
        "$servicio" "$instalado" "$activo" "$puerto" "$ssl_ok"
}

resumen_servicios_ssl() {
    echo
    echo "============================================================"
    echo "  RESUMEN DE VERIFICACION SSL/TLS - PRACTICA 7"
    echo "============================================================"
    echo "  Dominio  : $DOMINIO"
    echo "  Servidor : $IP_SERVIDOR"
    echo "------------------------------------------------------------"
    verificar_ssl_servicio "vsftpd" "21"   "ftps"
    verificar_ssl_servicio "apache" "443"  "https"
    verificar_ssl_servicio "nginx"  "8444" "https"
    verificar_ssl_servicio "tomcat" "8443" "https"
    echo "============================================================"
}