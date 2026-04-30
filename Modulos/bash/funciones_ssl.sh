#!/bin/bash

# funciones_ssl.sh
# Modulo SSL/TLS para Practica 7
# Genera certificados autofirmados y configura HTTPS/FTPS en los servicios

# ── Variables globales del modulo ──

SSL_DOMINIO="reprobados.com"
SSL_DIR="/etc/ssl/reprobados"
SSL_CERT="$SSL_DIR/reprobados.crt"
SSL_KEY="$SSL_DIR/reprobados.key"
SSL_KEYSTORE="$SSL_DIR/reprobados.p12"
SSL_KEYSTORE_PASS="reprobados2025"

PUERTO_HTTPS=""
export PUERTO_HTTPS

# ── Preparacion del entorno PKI ──

preparar_entorno_ssl() {
    mkdir -p "$SSL_DIR"
    chmod 750 "$SSL_DIR"

    if ! command -v openssl &>/dev/null; then
        echo "[!] openssl no instalado, instalando..."
        pacman -Sy --noconfirm openssl &>/dev/null
    fi
}

# Agrega reprobados.com a /etc/hosts apuntando a la IP local de la VM
configurar_hosts() {
    local ip
    ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
    [[ -z "$ip" ]] && ip="127.0.0.1"

    if grep -q "$SSL_DOMINIO" /etc/hosts; then
        sed -i "/$SSL_DOMINIO/d" /etc/hosts
    fi

    echo "$ip $SSL_DOMINIO www.$SSL_DOMINIO" >> /etc/hosts
    echo "[OK] Dominio $SSL_DOMINIO mapeado a $ip en /etc/hosts"
}

# ── Generacion de certificado autofirmado ──

generar_certificado() {
    preparar_entorno_ssl
    configurar_hosts

    if [[ -f "$SSL_CERT" && -f "$SSL_KEY" ]]; then
        echo "  Certificado ya existe en $SSL_DIR"
        return 0
    fi

    echo "  Generando certificado autofirmado para $SSL_DOMINIO..."

    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$SSL_KEY" \
        -out "$SSL_CERT" \
        -subj "/C=MX/ST=Sinaloa/L=LosMochis/O=Reprobados/OU=IT/CN=$SSL_DOMINIO" \
        -addext "subjectAltName=DNS:$SSL_DOMINIO,DNS:www.$SSL_DOMINIO,IP:127.0.0.1" \
        &>/dev/null

    if [[ ! -s "$SSL_CERT" || ! -s "$SSL_KEY" ]]; then
        echo "[ERROR] Fallo la generacion del certificado"
        return 1
    fi

    chmod 644 "$SSL_CERT"
    chmod 600 "$SSL_KEY"

    echo "[OK] Certificado generado en $SSL_CERT"
    echo "[OK] Llave privada en $SSL_KEY"
    return 0
}

# ── Pedir puerto HTTPS ──

get_https_port() {
    local puerto
    while true; do
        read -rp "  Puerto HTTPS [1-65535]: " puerto
        if check_port "$puerto"; then
            PUERTO_HTTPS="$puerto"
            return 0
        fi
    done
}

# ── SSL en Apache ──

activar_ssl_apache() {
    local puerto_http=$1
    local puerto_https=$2
    local conf="/etc/httpd/conf/httpd.conf"
    local ssl_conf="/etc/httpd/conf/extra/httpd-ssl.conf"

    echo "  Activando SSL en Apache..."

    # Habilitar modulos SSL y socache
    sed -i 's|^#LoadModule ssl_module|LoadModule ssl_module|' "$conf"
    sed -i 's|^#LoadModule socache_shmcb_module|LoadModule socache_shmcb_module|' "$conf"
    sed -i 's|^#Include conf/extra/httpd-ssl.conf|Include conf/extra/httpd-ssl.conf|' "$conf"

    # Asegurar que se cargue mod_ssl si la linea no existia
    grep -q "^LoadModule ssl_module" "$conf" || \
        echo "LoadModule ssl_module modules/mod_ssl.so" >> "$conf"
    grep -q "^Include conf/extra/httpd-ssl.conf" "$conf" || \
        echo "Include conf/extra/httpd-ssl.conf" >> "$conf"

    # VirtualHost SSL
    cat > "$ssl_conf" <<EOF
Listen $puerto_https https

<VirtualHost *:$puerto_https>
    ServerName $SSL_DOMINIO:$puerto_https
    DocumentRoot "/srv/http"

    SSLEngine on
    SSLCertificateFile "$SSL_CERT"
    SSLCertificateKeyFile "$SSL_KEY"

    SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite HIGH:!aNULL:!MD5
    SSLHonorCipherOrder on

    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"

    <Directory "/srv/http">
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

    # Redireccion HTTP -> HTTPS en el VirtualHost por defecto
    if ! grep -q "RewriteEngine On" "$conf"; then
        sed -i 's|^#LoadModule rewrite_module|LoadModule rewrite_module|' "$conf"
        cat >> "$conf" <<EOF

<VirtualHost *:$puerto_http>
    ServerName $SSL_DOMINIO:$puerto_http
    RewriteEngine On
    RewriteCond %{HTTPS} off
    RewriteRule ^(.*)$ https://%{HTTP_HOST}:$puerto_https%{REQUEST_URI} [R=301,L]
</VirtualHost>
EOF
    fi

    set_firewall_rule "$puerto_https"
    systemctl restart httpd &>/dev/null

    if systemctl is-active httpd &>/dev/null; then
        echo "[OK] Apache con SSL activo en puerto $puerto_https"
        return 0
    else
        echo "[ERROR] Apache fallo al reiniciar con SSL"
        systemctl status httpd --no-pager | tail -10
        return 1
    fi
}

# ── SSL en Nginx ──

activar_ssl_nginx() {
    local puerto_http=$1
    local puerto_https=$2
    local webroot="/usr/share/nginx/html"

    echo "  Activando SSL en Nginx..."

    cat > /etc/nginx/nginx.conf <<EOF
user http;
worker_processes 1;

events {
    worker_connections 1024;
}

http {
    server_tokens off;
    include       mime.types;
    default_type  application/octet-stream;
    sendfile      on;
    keepalive_timeout 65;

    # Servidor HTTP que redirige todo a HTTPS
    server {
        listen $puerto_http;
        server_name $SSL_DOMINIO www.$SSL_DOMINIO;
        return 301 https://\$host:$puerto_https\$request_uri;
    }

    # Servidor HTTPS
    server {
        listen $puerto_https ssl;
        server_name $SSL_DOMINIO www.$SSL_DOMINIO;

        ssl_certificate     $SSL_CERT;
        ssl_certificate_key $SSL_KEY;
        ssl_protocols       TLSv1.2 TLSv1.3;
        ssl_ciphers         HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;

        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;

        location / {
            root $webroot;
            index index.html;
            limit_except GET POST HEAD { deny all; }
        }
    }
}
EOF

    set_firewall_rule "$puerto_https"
    systemctl restart nginx &>/dev/null

    if systemctl is-active nginx &>/dev/null; then
        echo "[OK] Nginx con SSL activo en puerto $puerto_https"
        return 0
    else
        echo "[ERROR] Nginx fallo al reiniciar con SSL"
        nginx -t
        return 1
    fi
}

# ── SSL en Tomcat ──

activar_ssl_tomcat() {
    local puerto_http=$1
    local puerto_https=$2
    local directorio="/opt/tomcat"
    local conf="$directorio/conf/server.xml"

    echo "  Activando SSL en Tomcat..."

    # Convertir cert + key a keystore PKCS12 (Java requiere este formato)
    openssl pkcs12 -export \
        -in "$SSL_CERT" \
        -inkey "$SSL_KEY" \
        -out "$SSL_KEYSTORE" \
        -name tomcat \
        -password pass:"$SSL_KEYSTORE_PASS" &>/dev/null

    chown tomcat:tomcat "$SSL_KEYSTORE"
    chmod 640 "$SSL_KEYSTORE"

    # Eliminar Connector SSL previo si existe
    sed -i '/<Connector port=".*" protocol="org.apache.coyote.http11.Http11NioProtocol".*SSLEnabled="true"/,/\/>/d' "$conf"

    # Agregar Connector HTTPS antes del cierre de </Service>
    local connector_ssl="    <Connector port=\"$puerto_https\" protocol=\"org.apache.coyote.http11.Http11NioProtocol\"\n               maxThreads=\"150\" SSLEnabled=\"true\" scheme=\"https\" secure=\"true\"\n               keystoreFile=\"$SSL_KEYSTORE\" keystorePass=\"$SSL_KEYSTORE_PASS\"\n               keystoreType=\"PKCS12\" clientAuth=\"false\" sslProtocol=\"TLS\" />"

    sed -i "/<\/Service>/i\\$connector_ssl" "$conf"

    # Forzar redireccion del Connector HTTP al HTTPS
    sed -i "s|redirectPort=\"[0-9]*\"|redirectPort=\"$puerto_https\"|g" "$conf"

    # web.xml: forzar transport-guarantee CONFIDENTIAL para redirigir HTTP->HTTPS
    local webxml="$directorio/conf/web.xml"
    if ! grep -q "<security-constraint>" "$webxml"; then
        sed -i 's|</web-app>||' "$webxml"
        cat >> "$webxml" <<EOF

<security-constraint>
    <web-resource-collection>
        <web-resource-name>Todo</web-resource-name>
        <url-pattern>/*</url-pattern>
    </web-resource-collection>
    <user-data-constraint>
        <transport-guarantee>CONFIDENTIAL</transport-guarantee>
    </user-data-constraint>
</security-constraint>
</web-app>
EOF
    fi

    set_firewall_rule "$puerto_https"
    systemctl restart tomcat &>/dev/null
    sleep 3

    if systemctl is-active tomcat &>/dev/null; then
        echo "[OK] Tomcat con SSL activo en puerto $puerto_https"
        return 0
    else
        echo "[ERROR] Tomcat fallo al reiniciar con SSL"
        return 1
    fi
}

# ── FTPS en vsftpd ──

activar_ssl_vsftpd() {
    local conf="/etc/vsftpd.conf"

    echo "  Activando FTPS en vsftpd..."

    # Eliminar lineas SSL previas si existen
    sed -i '/^ssl_enable=/d' "$conf"
    sed -i '/^rsa_cert_file=/d' "$conf"
    sed -i '/^rsa_private_key_file=/d' "$conf"
    sed -i '/^allow_anon_ssl=/d' "$conf"
    sed -i '/^force_local_data_ssl=/d' "$conf"
    sed -i '/^force_local_logins_ssl=/d' "$conf"
    sed -i '/^ssl_tlsv1=/d' "$conf"
    sed -i '/^ssl_sslv2=/d' "$conf"
    sed -i '/^ssl_sslv3=/d' "$conf"
    sed -i '/^require_ssl_reuse=/d' "$conf"
    sed -i '/^ssl_ciphers=/d' "$conf"

    # Agregar configuracion FTPS
    cat >> "$conf" <<EOF

# FTPS - Practica 7
ssl_enable=YES
rsa_cert_file=$SSL_CERT
rsa_private_key_file=$SSL_KEY
allow_anon_ssl=NO
force_local_data_ssl=YES
force_local_logins_ssl=YES
ssl_tlsv1=YES
ssl_sslv2=NO
ssl_sslv3=NO
require_ssl_reuse=NO
ssl_ciphers=HIGH
EOF

    set_firewall_rule 21
    systemctl restart vsftpd &>/dev/null

    if systemctl is-active vsftpd &>/dev/null; then
        echo "[OK] vsftpd con FTPS activo"
        return 0
    else
        echo "[ERROR] vsftpd fallo al reiniciar con FTPS"
        return 1
    fi
}

# ── Verificacion automatizada ──

verificar_ssl_http() {
    local puerto=$1
    local servicio=$2

    echo ""
    echo "  --- Verificando $servicio en puerto $puerto ---"

    # Prueba 1: el puerto responde
    if ! ss -tlnp | grep -q ":$puerto "; then
        echo "  [FAIL] Puerto $puerto no esta escuchando"
        return 1
    fi
    echo "  [OK] Puerto $puerto escuchando"

    # Prueba 2: respuesta HTTPS
    local codigo
    codigo=$(curl -k -s -o /dev/null -w "%{http_code}" "https://$SSL_DOMINIO:$puerto" --max-time 5)
    if [[ "$codigo" == "200" || "$codigo" == "301" || "$codigo" == "302" ]]; then
        echo "  [OK] HTTPS responde con codigo $codigo"
    else
        echo "  [FAIL] HTTPS respondio codigo $codigo"
        return 1
    fi

    # Prueba 3: el certificado entrega el dominio correcto
    local cn
    cn=$(echo | openssl s_client -connect "$SSL_DOMINIO:$puerto" -servername "$SSL_DOMINIO" 2>/dev/null \
        | openssl x509 -noout -subject 2>/dev/null | grep -oP 'CN\s*=\s*\K[^,]+')
    if [[ "$cn" == "$SSL_DOMINIO" ]]; then
        echo "  [OK] Certificado emitido a CN=$cn"
    else
        echo "  [WARN] CN del certificado: $cn (esperado: $SSL_DOMINIO)"
    fi

    return 0
}

verificar_ssl_ftps() {
    echo ""
    echo "  --- Verificando FTPS en puerto 21 ---"

    if ! ss -tlnp | grep -q ":21 "; then
        echo "  [FAIL] Puerto 21 no esta escuchando"
        return 1
    fi
    echo "  [OK] Puerto 21 escuchando"

    # Probar AUTH TLS
    local respuesta
    respuesta=$(curl -k -s --ftp-ssl --max-time 5 "ftp://localhost/" -u "anonymous:" 2>&1 | head -5)
    if [[ -n "$respuesta" ]]; then
        echo "  [OK] FTPS acepta conexion cifrada"
    else
        echo "  [WARN] No se pudo confirmar FTPS via curl"
    fi

    return 0
}

mostrar_resumen_ssl() {
    local servicio=$1
    local puerto_http=$2
    local puerto_https=$3
    local origen=$4

    echo ""
    echo "================================================="
    echo "         RESUMEN DE INSTALACION"
    echo "================================================="
    echo "  Servicio:         $servicio"
    echo "  Origen:           $origen"
    echo "  Puerto HTTP:      $puerto_http (redirige a HTTPS)"
    echo "  Puerto HTTPS:     $puerto_https"
    echo "  Dominio:          $SSL_DOMINIO"
    echo "  Certificado:      $SSL_CERT"
    echo "  Llave privada:    $SSL_KEY"
    echo "  Vigencia cert:    365 dias"
    echo ""
    echo "  Pruebas manuales:"
    echo "    curl -k https://$SSL_DOMINIO:$puerto_https"
    echo "    openssl s_client -connect $SSL_DOMINIO:$puerto_https"
    echo "================================================="
}