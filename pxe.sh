#!/bin/bash

# require root
if [ "$(id -u)" -ne 0 ]; then
		       echo 'This script must be run by root' >&2
    exit 1
fi

interface_exists() {
    local input=$1
    ip -o link show | awk -F': ' '{print $2}' | grep -q "$input"
}


ip -c a
while true; do
	read -p "Enter the WAN Ethernet port: " wan_port

	if interface_exists "$wan_port"; then
		break
	else
        	echo "Invalid WAN interface."
    	fi
done

while true; do
	read -p "Enter the LAN Ethernet port: " lan_port

	if interface_exists "$lan_port"; then
		break
	else
        	echo "Invalid LAN interface."
    	fi
done

echo "denyinterfaces $eth1" >> /etc/dhcpcd.conf
systemctl restart dhcpcd

ip addr add 192.168.33.1/24 dev $lan_port
ip route add 192.168.33.0/24 via 192.168.33.1 dev $lan_port

apt-get -y update && apt-get -y upgrade
apt-get -y install ipxe dnsmasq git iptables wget

rm -rf pxe
git clone https://github.com/meyyh/pxe
cp pxe/dnsmasq.conf /etc/dnsmasq.conf

# Use sed to replace "interface=" with "interface=$lan_port"
sed -i "s/interface=/interface=$lan_port/g" /etc/dnsmasq.conf

#get the first dns server from resolv and give it to the clints
dns_server=$(awk '/^nameserver/{print $2; exit}' /etc/resolv.conf)
sed -i "s/\(dhcp-option=option:dns-server\)\(.*\)/\1\2,$dns_server/" /etc/dnsmasq.conf


mkdir -p /tftp/menu

#copy over the bios and uefi "boot" files
cp /usr/lib/ipxe/undionly.kpxe /tftp
cp /usr/lib/ipxe/ipxe.efi /tftp

cp pxe/boot.ipxe /tftp/menu

#enable packet forwarding
sysctl net.ipv4.ip_forward=1
sysctl -p

#allow port forwarding
iptables -A FORWARD -j ACCEPT

#allow NAT over all traffic
iptables -t nat -A POSTROUTING -j MASQUERADE

ip link set $lan_port up



systemctl stop systemd-resolved
systemctl disable systemd-resolved

systemctl restart dnsmasq
