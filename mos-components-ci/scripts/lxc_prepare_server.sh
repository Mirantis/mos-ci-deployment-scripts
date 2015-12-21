#!/bin/bash -e

#
# This script prepare ubuntu system to work with LXC deployment workers
#

GERRIT_USER=${GERRIT_USER:-mos-infra-ro}

if [ $(id -u) -gt 0 ]; then
    echo This script require root access
    exit 1
fi

# Check existence of file containing private SSH key
if [ ! -e ~/.ssh/id_rsa.${GERRIT_USER} ]; then
    echo "[ERROR] Missing ~/.ssh/id_rsa.${GERRIT_USER} file!"
    echo "        It must contain key with access to review.fuel-infra.org."
    exit 1
fi

# Restrict permissions to private key file
chmod 400 ~/.ssh/id_rsa.${GERRIT_USER}

# Create SSH config
cat > ~/.ssh/config <<EOF
Host review.fuel-infra.org
  User         ${GERRIT_USER}
  IdentityFile ~/.ssh/id_rsa.${GERRIT_USER}
  Port         29418
EOF

# Append keys of host review.fuel-infra.org to known_hosts
cat >> ~/.ssh/known_hosts <<EOF
|1|IkvJUwyZN2MbHSzkDPYEyWEeAmg=|Ju7lW+rCAKrAYkYpQZ2Nm9xP5WA= ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQCEuAw+SIIKXgIMHHDdNBm1q+L9Xm52MaPlp5Fvklw4VC0CMbg2i/QQqRBRq3sBbKYtDnw2PujajM6sLMtf2/S3v+87Y5cwG/zfZYqT2dxe74HWQ/Cdb5DVLvf5CrtN8HLy0+lKf+47ZrIf/aANSxoSDixBRJ3hAzczBRnS0DmVQQ==
|1|wCWv9IqFyYd+zhDqeLxAXNmwWOw=|Q2DvKjEegCyJA8kpGvJawm22A34= ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQCEuAw+SIIKXgIMHHDdNBm1q+L9Xm52MaPlp5Fvklw4VC0CMbg2i/QQqRBRq3sBbKYtDnw2PujajM6sLMtf2/S3v+87Y5cwG/zfZYqT2dxe74HWQ/Cdb5DVLvf5CrtN8HLy0+lKf+47ZrIf/aANSxoSDixBRJ3hAzczBRnS0DmVQQ==
EOF

apt-get install -y ubuntu-cloud-keyring
echo "deb http://ubuntu-cloud.archive.canonical.com/ubuntu" \
    "trusty-updates/kilo main" > /etc/apt/sources.list.d/cloudarchive-kilo.list
apt-get update
apt-get -y dist-upgrade

echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections
echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections

apt-get -y install \
    linux-lts-vivid-tools-common linux-image-generic-lts-vivid tcpdump vlan \
    lvm2 sysstat iftop mtr-tiny intel-microcode git git-review \
    iptables-persistent ntp debconf-utils apt-cacher-ng lxc cgmanager uidmap \
    cgmanager-utils squid3

apt-get --purge -y remove avahi-daemon

sed -i 's/ENABLED=.*/ENABLED="true"/' /etc/default/sysstat

# change default config
cat > /etc/lxc/default.conf <<EOF
lxc.network.type  = veth
lxc.network.link  = br-int
lxc.network.flags = up
lxc.network.mtu   = 9000
EOF

cat > /etc/network/interfaces.d/br-int.cfg << EOF
auto br-int
iface br-int inet static
    address 10.20.1.254
    netmask 255.255.255.0
    bridge_ports none
EOF

# load kvm
cat << EOF >>/etc/modules
kvm
kvm_intel
vhost_net
EOF

echo "options kvm_intel nested=1"                > /etc/modprobe.d/kvm.conf
echo "options vhost_net experimental_zcopytx=1" >> /etc/modprobe.d/kvm.conf

rmmod vhost_net vhost macvtap macvlan kvm_intel kvm || :

modprobe kvm_intel nested=1
modprobe vhost_net experimental_zcopytx=1

ifup br-int

service apt-cacher-ng restart

# Configure and restart squid
cp -f squid-host.conf /etc/squid3/squid.conf
service squid3 restart

iptables -t filter -F
iptables -t mangle -F
iptables -t nat    -F

iptables -t nat -A POSTROUTING -s 10.20.1.0/24 -m addrtype ! --dst-type LOCAL -j MASQUERADE
service iptables-persistent save
