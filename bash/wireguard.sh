#!/usr/bin/env bash

if ! grep -q "Ubuntu" /etc/os-release || ! grep -q "Debian" /etc/os-release; then
   echo 'This script only works with Ubuntu or Debian related distros.'
   exit 1
fi

CONFIG_FILE="/etc/sysctl.d/99-ip-forward.conf"

read -p "Enter the name of the network interface: " NET_INTERFACE
read -p "Enter the IP of this Wireguard peer: " WG_IP_ADDRESS

#sudo apt-get update && sudo apt-get upgrade -y

if [[ -f /var/run/reboot-required ]]; then
   REBOOT_NEEDED=true
fi

# Enabling IP forwarding
sudo echo 1 > /proc/sys/net/ipv4/ip_forward
sudo echo "net.ipv4.ip_forward = 1" > "$CONFIG_FILE"
sudo sysctl -p "$CONFIG_FILE"

# Install the wireguard tools
sudo apt install wireguard -y

# Configure firewall
sudo cat << EOF > /etc/rules/iptables
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]

# Service rules

# basic global accept rules - ICMP, loopback, traceroute, established all accepted
-A INPUT -s 127.0.0.0/8 -d 127.0.0.0/8 -i lo -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -m conntrack --state ESTABLISHED -j ACCEPT

# Enable our custom Wireguard port
-A INPUT -p udp --dport 444 -j ACCEPT

# enable traceroute rejections to get sent out
-A INPUT -p udp -m udp --dport 33434:33523 -j REJECT --reject-with icmp-port-unreachable

# SSH - accept from LAN
-A INPUT -i $NET_INTERFACE -p tcp --dport 22 -j ACCEPT

# DHCP client requests - accept from LAN
-A INPUT -i $NET_INTERFACE -p udp --dport 67:68 -j ACCEPT

# drop all other inbound traffic
-A INPUT -j DROP

COMMIT
EOF

sudo cat << EOF /etc/networkd-dispatcher/routable.d/reload-iptables.sh
#!/bin/sh

iptables-restore < /etc/rules/iptables

EOF

sudo chmod +x /etc/networkd-dispatcher/routable.d/reload-iptables.sh

(cd /etc/wireguard

sudo wg-genkey | tee privatekey | wg pubkey > publickey

PRIV_KEY=(cat /etc/wireguard/privatekey)

sudo cat << EOF > /etc/wireguard/wg0.conf

[Interface]  
Address = $WG_IP_ADDRESS/24  
SaveConfig = true  
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $NET_INTERFACE -j MASQUERADE; iptables -A FORWARD -o %i -j ACCEPT  
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $NET_INTERFACE -j MASQUERADE; iptables -D FORWARD -o %i -j ACCEPT  
ListenPort = 444  
PrivateKey = $PRIV_KEY
EOF
)

cat << EOF
"This has done most of the setup work for you.
Now go create some clients."
EOF
