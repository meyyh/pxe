#!/bin/bash

# require root
if [ "$(id -u)" -ne 0 ]; then
    echo 'This script must be run by root' >&2
    exit 1
fi

INTERFACE=""
PXE_DIR=/pxe
GIT_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ip --color address
INTERFACES=$(ip -o link show | awk -F': ' '{print $2}')

while true; do
    echo "Enter the name of the interface:"
    read INTERFACE
    if echo "$INTERFACES" | grep -qw "$INTERFACE"; then
        # Valid interface found
        break
    else
        echo -e "\033[31mNot a valid interface. Please try again.\033[0m"
    fi
done

read -p "Delete $PXE_DIR : " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    rm -rf $PXE_DIR
fi

mkdir    $PXE_DIR
mkdir    $PXE_DIR/menu
mkdir -p $PXE_DIR/os/win
mkdir    $PXE_DIR/os/linux

apt-get install dnsmasq nginx iptables wget git nfs-server -y

#for building ipxe
apt-get install make gcc binutils perl mtools liblzma-dev -y

#configure and build ipxe
cd $GIT_REPO
git clone https://github.com/ipxe/ipxe.git
cd ipxe/src/config
sed -i 's/#undef\sDOWNLOAD_PROTO_NFS/#define DOWNLOAD_PROTO_NFS/' general.h
sed -i 's/#undef\sDOWNLOAD_PROTO_HTTPS/#define DOWNLOAD_PROTO_HTTPS/' general.h
sed -i 's|^//\(.*#define\s*REBOOT_CMD\)|\1|' general.h
sed -i 's|^//\(.*#define\s*POWEROFF_CMD\)|\1|' general.h
sed -i 's|^//\(.*#define\s*PING_CMD\)|\1|' general.h
sed -i 's|^//\(.*#define\s*NSLOOKUP_CMD\)|\1|' general.h
sed -i 's|^//\(.*#define\s*CONSOLE_CMD\)|\1|' general.h
sed -i 's|^//\(.*#define\s*CONSOLE_CMD\)|\1|' general.h
sed -i 's|^//\(.*#define\s*CONSOLE_FRAMEBUFFER\)|\1|' console.h
cd ..
make bin-x86_64-pcbios/undionly.kpxe
make bin-x86_64-efi/ipxe.efi

cp bin-x86_64-pcbios/undionly.kpxe $PXE_DIR/undionly.kpxe
cp bin-x86_64-efi/ipxe.efi $PXE_DIR/ipxe.efi

#wget https://github.com/ipxe/wimboot/releases/latest/download/wimboot
#mv wimboot /pxe/os/win/

cp $GIT_REPO/x.png $PXE_DIR/
cp $GIT_REPO/menu.ipxe $PXE_DIR/autoexec.ipxe #sometime it looks for this instead of menu.ipxe idk why
cp $GIT_REPO/menu.ipxe $PXE_DIR/menu/menu.ipxe
cp /etc/dnsmasq.conf /etc/dnsmasq.conf.old
cat $GIT_REPO/dnsmasq.conf > /etc/dnsmasq.conf

#replace values in dnsmasq.conf
sed -i "s/_rep-interface/$INTERFACE/" /etc/dnsmasq.conf

#setup nginx config (idk why I made it a string)
NGINX_CONFIG="user www-data;\nworker_processes 1;\npid /run/nginx.pid;\nevents {\nworker_connections 1024;\n}\nhttp {\ndefault_type application/octet-stream;\nsendfile on;\ntcp_nopush on;\ntcp_nodelay on;\nkeepalive_timeout 65;\nserver {\nlisten 80 default_server;\nlisten [::]:80 default_server;\nroot /pxe/;\nindex index.html index.htm index.nginx-debian.html;\nserver_name _;\nlocation / {\nautoindex on;\n}\n}\n}"
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.orig
echo -e $NGINX_CONFIG > /etc/nginx/nginx.conf

#start dnsmasq
systemctl enable dnsmasq && systemctl start dnsmasq
systemctl enable nginx && systemctl start nginx
