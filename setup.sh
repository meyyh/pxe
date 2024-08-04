#!/bin/bash

# require root
if [ "$(id -u)" -ne 0 ]; then
    echo 'This script must be run by root' >&2
    exit 1
fi

WAN=""
LAN=""
DNS_SERVER=$(cat /etc/resolv.conf | grep nameserver | cut -d " " -f 2)

#get the wan and lan interface names
function interfaces()
{
    ip --color address
    INTERFACES=$(ip -o link show | awk -F': ' '{print $2}')

    echo "enter the name of the wan interface"
    read TEMP_WAN
    if echo "$INTERFACES" | grep -qw "$TEMP_WAN"; then
        #valid interface found
    else
        echo "not valid interface"
        interfaces
    fi

    echo "enter the name of the lan interface"
    read TEMP_LAN
    if echo "$INTERFACES" | grep -qw "$TEMP_LAN"; then
        #valid interface found
    else
        echo "not valid interface"
        interfaces
    fi

    if [ "$TEMP_WAN" = "$TEMP_LAN" ]; then
        echo "WAN and LAN interfaces cant be the same"
        interfaces
    fi

    WAN=$TEMP_WAN
    LAN=$TEMP_LAN
}

interfaces

read -p "Delete /pxe-boot : " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    rm -rf /pxe-boot
fi

mkdir -p /pxe-boot/menu
mkdir -p /pxe-boot/os/win
mkdir /pxe-boot/os/linux

apt-get install ipxe dnsmasq nginx git wget -y

wget google.com
if [ -f index.html ]; then
    #network is working
    rm index.html
else
    echo "cant wget google.com check internet connection\n"
    exit 1
fi

git clone https://github.com/meyyh/pxe

cp ./pxe/menu.ipxe /pxe-boot/menu/

cp /etc/dnsmasq.conf /etc/dnsmasq.conf.old

cat ./pxe/dnsmasq.conf > /etc/dnsmasq.conf

#replace values in dnsmasq.conf
sed -i "s/_rep-interface/$LAN/" /etc/dnsmasq.conf
sed -i "s/_rep-dns-server/$DNS_SERVER/" /etc/dnsmasq.conf


#start dnsmasq
systemctl enable dnsmasq && systemctl start dnsmasq
