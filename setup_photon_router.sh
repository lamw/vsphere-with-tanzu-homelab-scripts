#!/bin/bash

PHOTON_ROUTER_IP=192.168.30.2
PHOTON_ROUTER_GW=192.168.30.1
PHOTON_ROUTER_DNS=192.168.30.1
SETUP_DNS_SERVER=1

tdnf -y update
if [ ${SETUP_DNS_SERVER} -eq 1 ]; then
    tdnf install -y unbound

    cat > /etc/unbound/unbound.conf << EOF
    server:
        interface: 0.0.0.0
        port: 53
        do-ip4: yes
        do-udp: yes
        access-control: 192.168.30.0/24 allow
        access-control: 10.10.0.0/24 allow
        access-control: 10.20.0.0/24 allow
        verbosity: 1

    local-zone: "tanzu.local." static

    local-data: "router.tanzu.local A 192.168.30.2"
    local-data-ptr: "192.168.30.2 router.tanzu.local"

    local-data: "vcsa.tanzu.local A 192.168.30.5"
    local-data-ptr: "192.168.30.5 vcsa.tanzu.local"

    local-data: "haproxy.tanzu.local A 192.168.30.6"
    local-data-ptr: "192.168.30.6 haproxy.tanzu.local"

    local-data: "esxi-01.tanzu.local A 192.168.30.227"
    local-data-ptr: "192.168.30.227 esxi-01.tanzu.local"

    forward-zone:
        name: "."
        forward-addr: ${PHOTON_ROUTER_DNS}
EOF
    systemctl enable unbound
    systemctl start unbound
fi

sed -i 's/net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/g' /etc/sysctl.d/50-security-hardening.conf
sysctl -w net.ipv4.ip_forward=1

rm -f /etc/systemd/network/99-dhcp-en.network

cat > /etc/systemd/network/10-static-eth0.network << EOF
[Match]
Name=eth0

[Network]
Address=${PHOTON_ROUTER_IP}/24
Gateway=${PHOTON_ROUTER_GW}
DNS=${PHOTON_ROUTER_DNS}
IPv6AcceptRA=no
EOF

cat > /etc/systemd/network/11-static-eth1.network << EOF
[Match]
Name=eth1

[Network]
Address=10.10.0.1/24
EOF

cat > /etc/systemd/network/12-static-eth2.network << EOF
[Match]
Name=eth2

[Network]
Address=10.20.0.1/24
EOF

chmod 655 /etc/systemd/network/*
systemctl restart systemd-networkd

iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -t nat -F
iptables -t mangle -F
iptables -F
iptables -X
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -i eth0 -o eth1 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth0 -o eth2 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth1 -o eth0 -j ACCEPT
iptables -A FORWARD -i eth2 -o eth0 -j ACCEPT
if [ ${SETUP_DNS_SERVER} -eq 1 ]; then
    iptables -A INPUT -i eth0 -p udp --dport 53 -j ACCEPT
    iptables -A INPUT -i eth1 -p udp --dport 53 -j ACCEPT
    iptables -A INPUT -i eth2 -p udp --dport 53 -j ACCEPT
fi
iptables-save > /etc/systemd/scripts/ip4save

systemctl restart iptables