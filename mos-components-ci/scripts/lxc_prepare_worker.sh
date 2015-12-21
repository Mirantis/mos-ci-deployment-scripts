#!/bin/bash -e

#
# This script prepare LXC container to work with deployment tests
#

if [ $(id -u) -gt 0 ]; then
    echo This script require root access
    exit 1
fi

if [[ ! $(hostname) =~ worker.* ]]; then
    echo Please execute only on workerX hosts
    exit 1
fi

# add tun
set +e
mkdir /dev/net
mknod -m 666 /dev/net/tun c 10 200

# add fuse
mknod -m 666 /dev/fuse c 10 229
set -e

# Install, configure and restart squid
apt-get -y install squid3
cp -f /opt/mos-components-ci/scripts/squid-worker.conf /etc/squid3/squid.conf
service squid3 restart

# Install, configure and restart dnsmasq
apt-get -y install dnsmasq
sed -ri 's/^#?(IGNORE_RESOLVCONF).+$/\1=yes/' /etc/default/dnsmasq
echo 'DNSMASQ_EXCEPT=lo' >> /etc/default/dnsmasq
service dnsmasq restart

echo "deb http://ubuntu-cloud.archive.canonical.com/ubuntu" \
    "trusty-updates/kilo main" > /etc/apt/sources.list.d/cloudarchive-kilo.list
apt-get -y install ubuntu-cloud-keyring debconf-utils

apt-get -u update

# install libguestfs
echo "libguestfs-tools libguestfs/update-appliance boolean true" | debconf-set-selections
DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y libguestfs-tools linux-image-virtual-lts-vivid

# disable modprobe
#dpkg-divert --local --rename --add /sbin/modprobe
#ln -s /bin/true /sbin/modprobe

DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y kvm git git-review screen sshpass libvirt-bin ipmitool uuid uuid-runtime telnet vlan \
    createrepo rpm python-pip python-dev e2fsprogs libmysqlclient-dev libpq-dev libffi-dev python-jenkinsapi \
    python-libtorrent python-joblib python-launchpadlib python-requests python-subunit python-testrepository \
    python-yaml wget bridge-utils virtinst python-keystoneclient python-glanceclient python-novaclient python-neutronclient \
    iptables-persistent openssh-server openjdk-7-jre-headless libyaml-dev pkg-config libvirt-dev build-essential curl \
    sssd libpam-modules libpam-sss libnss-sss

# packages for rally
apt-get install --no-install-recommends -y git wget python-minimal python-boto python-cffi python-crypto python-decorator \
    python-jinja2 python-lxml python-msgpack python-netifaces python-pbr python-psycopg2 python-pycparser \
    python-requests python-simplejson python-sqlalchemy python-subunit python-tox python-virtualenv \
    libxml2-dev libxslt1-dev

# disable zfs
sed -i 's/ENABLE_ZFS=.*/ENABLE_ZFS=no/' /etc/default/zfs-fuse
service zfs-fuse stop

# enable hugepages
#sed -i 's/KVM_HUGEPAGES=.*/KVM_HUGEPAGES=1/' /etc/default/qemu-kvm

# prepare libvirt
# delete default net
#virsh net-destroy default
virsh net-undefine default

# add default storage
virsh pool-define-as --name default --type dir --target /var/lib/libvirt/images
virsh pool-autostart default
virsh pool-start default

# add networks
virsh net-define etc/helper_xmls/networks/net_admin.xml
virsh net-autostart net-admin
virsh net-start net-admin

virsh net-define etc/helper_xmls/networks/net_public.xml
virsh net-autostart net-public
virsh net-start net-public

sed -ri \
    -e '/^#?(spice|vnc)_listen/      s/^#?(.+_listen).+$/\1 = "0.0.0.0"/' \
    -e '/^#?security_driver/         s/^#?(security_driver).+$/\1 = "none"/' \
    /etc/libvirt/qemu.conf

service libvirt-bin restart
usermod -a -G libvirtd jenkins

# firewall
iptables -t nat -A PREROUTING -m addrtype --dst-type LOCAL -m tcp -p tcp --dport 8000 -j DNAT --to-destination 10.20.0.2:8000
iptables -t nat -A PREROUTING -m addrtype --dst-type LOCAL -m tcp -p tcp --dport 8443 -j DNAT --to-destination 10.20.0.2:8443
iptables -t nat -A PREROUTING -m addrtype --dst-type LOCAL -m tcp -p tcp --dport 80 -j DNAT --to-destination 172.16.0.2:80
iptables -t nat -A PREROUTING -m addrtype ! --dst-type LOCAL -m tcp -p tcp --dport 80 -j REDIRECT --to-ports 8080
iptables -t nat -A POSTROUTING -m addrtype ! --dst-type LOCAL -j MASQUERADE
iptables-save > /etc/iptables/rules.v4

# Enable PAM module mkhomedir
cp -f /opt/mos-components-ci/scripts/mkhomedir /usr/share/pam-configs/
/usr/sbin/pam-auth-update --package --force

# Enable sssd
cp -f /opt/mos-components-ci/scripts/sssd.conf /etc/sssd/
chmod 0600 /etc/sssd/sssd.conf
service sssd restart

# Reconfigure SSH to use keys stored in LDAP (via sssd)
sed -ri \
    -e '/^#AuthorizedKeysFile/ a\AuthorizedKeysCommand     /usr/bin/sss_ssh_authorizedkeys\nAuthorizedKeysCommandUser root' \
    /etc/ssh/sshd_config
service ssh restart

# Create sudo rules
cat > /etc/sudoers.d/mos-infra <<EOF
%mos-infra     ALL=(ALL) NOPASSWD: ALL
%mos-infra-all ALL=(ALL) NOPASSWD: ALL
%mos-infra-eng ALL=(ALL) NOPASSWD: ALL
EOF
