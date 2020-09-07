#!/bin/bash

# SIGTERM-handler this funciton will be executed when the container receives the SIGTERM signal (when stopping)
term_handler(){
	echo "Stopping..."
	ifdown wlan0
	ip link set wlan0 down
	ip addr flush dev wlan0
	exit 0
}

# Setup signal handlers
trap 'term_handler' SIGTERM

echo "Starting..."

echo "Set nmcli managed no"
nmcli dev set wlan0 managed no

CONFIG_PATH=/data/options.json

SSID=$(jq --raw-output ".ssid" $CONFIG_PATH)
WPA_PASSPHRASE=$(jq --raw-output ".wpa_passphrase" $CONFIG_PATH)
CHANNEL=$(jq --raw-output ".channel" $CONFIG_PATH)
ADDRESS=$(jq --raw-output ".address" $CONFIG_PATH)
NETMASK=$(jq --raw-output ".netmask" $CONFIG_PATH)
BROADCAST=$(jq --raw-output ".broadcast" $CONFIG_PATH)

# Enforces required env variables
required_vars=(SSID WPA_PASSPHRASE CHANNEL ADDRESS NETMASK BROADCAST)
for required_var in "${required_vars[@]}"; do
    if [[ -z ${!required_var} ]]; then
        error=1
        echo >&2 "Error: $required_var env variable not set."
    fi
done

if [[ -n $error ]]; then
    exit 1
fi

# In /etc/default/udhcp, comment the line that says DHCPD_ENABLED="no"

# Setup hostapd.conf
#echo "Setup hostapd ..."
#echo "ssid=$SSID"$'\n' >> /hostapd.conf
#echo "wpa_passphrase=$WPA_PASSPHRASE"$'\n' >> /hostapd.conf
#echo "channel=$CHANNEL"$'\n' >> /hostapd.conf

# Setup interface
#echo "Setup interface ..."

#ip link set wlan0 down
#ip addr flush dev wlan0
#ip addr add ${IP_ADDRESS}/24 dev wlan0
#ip link set wlan0 up

#echo "address $ADDRESS"$'\n' >> /etc/network/interfaces
#echo "netmask $NETMASK"$'\n' >> /etc/network/interfaces
#echo "broadcast $BROADCAST"$'\n' >> /etc/network/interfaces

#ifdown wlan0
#ifup wlan0

#echo "Starting HostAP daemon ..."
#hostapd -d /hostapd.conf & wait ${!}

echo "Stopping network manager ..."
service network-manager stop
sleep 1

pkill -15 nm-applet
sleep 1

echo "Bringing interface wlan0 down ..."
ifconfig wlan0 down             #wlan0 - the name of your wireless adapter
sleep 1

echo "Adding new interface new0 as STA"
iw phy phy0 interface add new0 type station

echo "Adding new interface new1 as AP"
iw phy phy0 interface add new1 type __ap
sleep 2

ifconfig new0 down
macchanger --mac 00:11:22:33:44:55 new0
ifconfig new1 down
macchanger --mac 00:11:22:33:44:66 new1
ifconfig new0 up
ifconfig new1 up

ifconfig new1 10.0.0.101 up  #192.168.0.101 - the same IP defined for router in 'udhcpd.conf' file 
hostapd /etc/hostapd.conf &
sleep 2

service udhcpd start

wpa_supplicant -i new0 -c /etc/wpa_supplicant.conf &
sleep 10

udhcpc -i new0

echo "1" > /proc/sys/net/ipv4/ip_forward
iptables --table nat --append POSTROUTING --out-interface new0 -j MASQUERADE
iptables --append FORWARD --in-interface new1 -j ACCEPT
