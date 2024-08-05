#!/bin/bash

# require root
if [ "$(id -u)" -ne 0 ]; then
    echo 'This script must be run by root' >&2
    exit 1
fi

WAN=""
LAN=""
DNS_SERVER=$(cat /etc/resolv.conf | grep nameserver | cut -d " " -f 2)
PXE_DIR=/pxe


# Display network interfaces with colors
ip --color address
INTERFACES=$(ip -o link show | awk -F': ' '{print $2}')

while true; do
    echo "Enter the name of the WAN interface:"
    read TEMP_WAN
    if echo "$INTERFACES" | grep -qw "$TEMP_WAN"; then
        # Valid WAN interface found
        break
    else
        echo "Not a valid interface. Please try again."
    fi
done

while true; do
    echo "Enter the name of the LAN interface:"
    read TEMP_LAN
    if echo "$INTERFACES" | grep -qw "$TEMP_LAN"; then
        # Valid LAN interface found
        break
    else
        echo "Not a valid interface. Please try again."
    fi
done

if [ "$TEMP_WAN" = "$TEMP_LAN" ]; then
    echo "WAN and LAN interfaces can't be the same. Please try again."
    exit 1
fi

WAN=$TEMP_WAN
LAN=$TEMP_LAN

ip addr flush dev $LAN
ip addr add 123.123.0.1/16 dev $LAN

read -p "Delete $PXE_DIR : " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    rm -rf $PXE_DIR
fi

apt-get install ipxe dnsmasq nginx git iptables wget -y

wget -q google.com
if [ -f index.html ]; then
    #network is working
    rm index.html
else
    echo "cant wget google.com check internet connection\n"
    exit 1
fi

mkdir    $PXE_DIR
mkdir    $PXE_DIR/menu
mkdir -p $PXE_DIR/os/win
mkdir    $PXE_DIR/os/linux

cp ./pxe/menu.ipxe $PXE_DIR/menu/
cp /usr/lib/ipxe/undionly.kpxe $PXE_DIR
cp /usr/lib/ipxe/ipxe.efi $PXE_DIR
cp /etc/dnsmasq.conf /etc/dnsmasq.conf.old
cat ./pxe/dnsmasq.conf > /etc/dnsmasq.conf

#replace values in dnsmasq.conf
sed -i "s/_rep-interface/$LAN/" /etc/dnsmasq.conf
sed -i "s/_rep-dns-server/$DNS_SERVER/" /etc/dnsmasq.conf

#setup routing from lan to wan and back
# enable ip forwarding in the kernel
echo 1 > /proc/sys/net/ipv4/ip_forward

# flush rules and delete chains
iptables -F
iptables -X

# enable masquerading to allow LAN internet access
iptables -t nat -A POSTROUTING -o $LAN -j MASQUERADE
iptables -A FORWARD -i $LAN -o $WAN -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $WAN -o $LAN -j ACCEPT

iptables -t nat -A POSTROUTING -o $WAN -j MASQUERADE
iptables -A FORWARD -i $WAN -o $LAN -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $LAN -o $WAN -j ACCEPT

iptables -A INPUT -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT

#start dnsmasq
systemctl enable dnsmasq && systemctl start dnsmasq

ip link set $LAN down
ip link set $LAN up
