#!/bin/bash
# unir_dominio.sh
# Une Arch Linux al dominio practica8.local

DOMINIO="practica8.local"
DOMINIO_UPPER="PRACTICA8.LOCAL"
ADMIN_USER="Administrador"

# Verificar que se ejecute como root
if [ "$EUID" -ne 0 ]; then
    echo "Este script debe ejecutarse como root"
    echo "Usa: sudo bash unir_dominio.sh"
    exit 1
fi

# Pedir IP del servidor
read -p "IP del servidor (DC): " IP_SERVIDOR

# Pedir contrasena del administrador del dominio
read -s -p "Contrasena del administrador del dominio: " ADMIN_PASS
echo ""

echo "--- Quitando proteccion de resolv.conf si existe ---"
chattr -i /etc/resolv.conf 2>/dev/null || true

echo "--- Instalando paquetes base ---"
pacman -Sy --noconfirm git base-devel sssd samba krb5 ntp

echo "--- Instalando yay para acceder al AUR ---"
if ! command -v yay &>/dev/null; then
    useradd -m -G wheel aurbuilder 2>/dev/null || true
    echo "aurbuilder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/aurbuilder

    cd /tmp
    rm -rf yay
    git clone https://aur.archlinux.org/yay.git
    chown -R aurbuilder:aurbuilder /tmp/yay
    cd /tmp/yay
    sudo -u aurbuilder makepkg -si --noconfirm

    userdel -r aurbuilder 2>/dev/null || true
    rm -f /etc/sudoers.d/aurbuilder
    cd /
fi

echo "--- Instalando realmd y adcli desde AUR ---"
if ! command -v realm &>/dev/null; then
    useradd -m -G wheel aurbuilder 2>/dev/null || true
    echo "aurbuilder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/aurbuilder

    sudo -u aurbuilder yay -S --noconfirm realmd adcli

    userdel -r aurbuilder 2>/dev/null || true
    rm -f /etc/sudoers.d/aurbuilder
fi

echo "--- Configurando DNS hacia el DC ---"
cat > /etc/resolv.conf << EOF
nameserver $IP_SERVIDOR
search $DOMINIO
EOF

chattr +i /etc/resolv.conf

echo "--- Sincronizando tiempo con el DC ---"
cat > /etc/systemd/timesyncd.conf << EOF
[Time]
NTP=$IP_SERVIDOR
FallbackNTP=pool.ntp.org
EOF

systemctl enable systemd-timesyncd
systemctl restart systemd-timesyncd

# Forzar sincronizacion inmediata y verificar
sleep 3
timedatectl status
echo "Esperando sincronizacion de tiempo..."
sleep 5

echo "--- Uniendo al dominio $DOMINIO ---"
RESULTADO=$(echo "$ADMIN_PASS" | realm join --user=$ADMIN_USER $DOMINIO 2>&1)

if echo "$RESULTADO" | grep -q "Already joined"; then
    echo "Ya estaba unido al dominio, continuando..."
elif echo "$RESULTADO" | grep -q "Failed\|Error\|error"; then
    echo "Error al unirse al dominio: $RESULTADO"
    exit 1
fi

echo "--- Configurando sssd.conf ---"
cat > /etc/sssd/sssd.conf << EOF
[sssd]
domains = $DOMINIO
config_file_version = 2
services = nss, pam

[domain/$DOMINIO]
ad_domain = $DOMINIO
krb5_realm = $DOMINIO_UPPER
realmd_tags = manages-system joined-with-adcli
cache_credentials = True
id_provider = ad
krb5_store_password_if_offline = True
default_shell = /bin/bash
ldap_id_mapping = True
use_fully_qualified_names = True
fallback_homedir = /home/%u@%d
access_provider = ad
EOF

chmod 600 /etc/sssd/sssd.conf

echo "--- Habilitando y arrancando sssd ---"
systemctl enable sssd
systemctl restart sssd

echo "--- Configurando creacion automatica de carpeta home ---"
for PAM_FILE in /etc/pam.d/system-auth /etc/pam.d/password-auth; do
    if ! grep -q "pam_mkhomedir" $PAM_FILE; then
        echo "session required pam_mkhomedir.so skel=/etc/skel umask=0077" >> $PAM_FILE
    fi
done

echo "--- Configurando sudo para usuarios de AD ---"
cat > /etc/sudoers.d/ad-admins << EOF
%Domain\ Admins@$DOMINIO ALL=(ALL) ALL
EOF

chmod 440 /etc/sudoers.d/ad-admins

echo "--- Verificando union al dominio ---"
realm list

echo ""
echo "Union al dominio completada"
echo "Prueba con: id muega@$DOMINIO"
echo "Los usuarios pueden iniciar sesion como: su - usuario@$DOMINIO"