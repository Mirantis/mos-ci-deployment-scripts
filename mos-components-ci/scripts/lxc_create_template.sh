#!/bin/bash -e

#
# Create LXC worker template
#

TEMPLATE=${TEMPLATE:-worker}

GERRIT_USER=${GERRIT_USER:-mos-infra-ro}

if [ ! -e ~/env_defaults.sh ]; then
    cat << EOF
[ERROR] Missing ~/env_defaults.sh file, it must include user and password for testrail, example:
export TESTRAIL_USER=mos-infra-eng@mirantis.com
export TESTRAIL_PASSWORD=pass from credentials list
EOF
fi

source ~/env_defaults.sh

# Prepare shared source of scripts/code
if [ -d /opt/mos-components-ci ]; then
    git -C /opt/mos-components-ci reset --hard
    git -C /opt/mos-components-ci pull
else
    git -C /opt clone ssh://review.fuel-infra.org:29418/mos-infra/mos-components-ci
fi

# Prepare shared storage of ISO images
LXC_PATH=$(lxc-config lxc.lxcpath)
[ -d ${LXC_PATH}/images ] || mkdir ${LXC_PATH}/images
chown -R 1000:1000 ${LXC_PATH}/images

# Stop and destroy all workers because of using same root FS (overlayfs)
awk '{print $1}' lxc_workers_list | while read worker_name; do
    lxc-stop    -n ${worker_name} || :
    lxc-destroy -n ${worker_name} || :
done

# Stop and destroy template
lxc-stop    -n ${TEMPLATE} || :
lxc-destroy -n ${TEMPLATE} || :

# Create LXC container
lxc-create -t download -n ${TEMPLATE} -- -d ubuntu -r trusty -a amd64

LXC_PATH="$(lxc-config lxc.lxcpath)"
LXC_DIR="${LXC_PATH}/${TEMPLATE}"

# Prepare mount points for shared storages
test -d ${LXC_DIR}/rootfs/opt/mos-components-ci || mkdir -p ${LXC_DIR}/rootfs/opt/mos-components-ci
test -d ${LXC_DIR}/rootfs/home/jenkins/images   || mkdir -p ${LXC_DIR}/rootfs/home/jenkins/images
chown -R 1000:1000 ${LXC_DIR}/rootfs/home/jenkins

# Configure additional network interfaces for worker
cat > ${LXC_DIR}/rootfs/etc/network/interfaces << EOF
auto lo
iface lo inet loopback

auto br-admin
iface br-admin inet static
    address 10.20.0.1
    netmask 255.255.255.0
    bridge_ports none

auto br-public
iface br-public inet static
    address 172.16.0.1
    netmask 255.255.255.0
    bridge_ports none

auto vlan101
iface vlan101 inet static
    vlan_raw_device br-public
    address 192.168.0.1
    netmask 255.255.255.0
EOF

cat > ${LXC_DIR}/rootfs/etc/init/container-start.conf <<EOF
# fake some events needed for correct startup other services

description     "Container Upstart"

start on startup

script
        rm -rf /var/run/*.pid
        rm -rf /var/run/network/*
        /sbin/initctl emit stopped JOB=udevtrigger --no-wait
        /sbin/initctl emit started JOB=udev --no-wait
end script
EOF

chroot ${LXC_DIR}/rootfs bash <<EOF
update-rc.d -f ondemand remove
cd /etc/init
rm tty[2-6].conf plymouth* hwclock* kmod* udev* upstart* console-font.conf

mkdir /dev/net
mknod -m 666 /dev/net/tun c 10 200
mknod -m 666 /dev/fuse c 10 229
EOF

cat >> ${LXC_DIR}/rootfs/etc/resolvconf/resolv.conf.d/base <<EOF
nameserver 172.16.48.85
nameserver 172.16.48.86
#nameserver 10.20.1.254
EOF

cat >> ${LXC_DIR}/config <<EOF
lxc.cgroup.devices.allow = c 1:1 rwm
lxc.cgroup.devices.allow = c 10:232 rwm

lxc.autodev    = 0

lxc.mount.entry = /opt/mos-components-ci ${LXC_DIR}/rootfs/opt/mos-components-ci none bind,ro 0.0
lxc.mount.entry = ${LXC_PATH}/images ${LXC_DIR}/rootfs/home/jenkins/images none bind,rw 0.0

lxc.aa_profile = unconfined

lxc.network.ipv4 = 10.20.1.199/24
lxc.network.ipv4.gateway = 10.20.1.254
EOF

# Start container
# All following actions will be done on running container
lxc-start -d -n ${TEMPLATE}

lxc-attach -n ${TEMPLATE} -- update-rc.d -f ondemand remove
lxc-attach -n ${TEMPLATE} -- deluser --remove-home ubuntu

# Create jenkins user and permit it use sudo
lxc-attach -n ${TEMPLATE} -- adduser --disabled-password --gecos jenkins --uid 1000 jenkins
echo "jenkins ALL=(ALL:ALL) NOPASSWD: ALL" | lxc-attach -n ${TEMPLATE} -- bash -c "cat >/etc/sudoers.d/jenkins"

# Generate SSH keypair
lxc-attach -n ${TEMPLATE} -- su - jenkins <<EOF
test -d ~/.ssh || mkdir ~/.ssh
ssh-keygen -f ~/.ssh/id_rsa -N ''
EOF

# Configure SSH access for user jenkins to gerrit hosts
lxc-attach -n ${TEMPLATE} -- bash -c "cat >/home/jenkins/.ssh/config" <<EOF
UserKnownHostsFile=/dev/null
StrictHostKeyChecking=no
LogLevel=ERROR

Host review.fuel-infra.org
    IdentityFile ~/.ssh/id_rsa.${GERRIT_USER}
    User ${GERRIT_USER}
    Port 29418

Host gerrit.mirantis.com
    IdentityFile ~/.ssh/id_rsa.${GERRIT_USER}
    User ${GERRIT_USER}
    Port 29418
EOF

cat << 'EOF' | lxc-attach -n ${TEMPLATE} -- bash -c "cat >/home/jenkins/.ssh/authorized_keys"
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCYCgDh1JKqIimGfQndhkrwwhyiKdbwDfZBc3psoK4E0Z5f+6pHqRiEInLR34Yi1TWdG5P6hHvwycNqAlvVlBpnWLAQbdW1X5CDO+t6uSjnUi4gRJcBbvJHA+LukcBg2zxKtTK4rOsJBW41tMrTkkS+sxd3xF/9kaK6zNtylxwy68xVrsFGvZm5+JJOoMg2Q505y2l7MbUkKt5hTxVRCqXNKsOKmYe5thjozgPmqs9oSDE1I5OCcvfCkjdJh+FanEsmUzwqhSBpZwWi/aPRsJ2ova4muujAIcGzVysSktGcqm35H0g15MCZa5bGc054fzasS7Ra8CMeK1AJMHTjnJ/L
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAsFK5a5KhS+q5L8pUIS9/lMAh2Qm0mAJtzh19CekRezbDnpnAXIJOO09nqFxdhsxzrbrFo+NLLbi7EFKC8yL3ZvtD8IE6zx8Zs+SHuoK42BrhI/m/5IN/k1T4A5mJ9vVEpa+C/LqGgkFaWadbNWHbSCv4lqDBMbMRzAyFaVmLNQowiAvVsYwC7xAyM9lCOXLKmAv7P5QDB8kRxgPtX6VKx5zEr74+gGyHxm8/2RA8naeFzhIljNZraz5usthfdadG8zUCe05hj8vzGrQIWRqH0pAdsuAi3lD7l2nLrQ7l3S64/qFs40H1DGWBDe/ooOP0kFYkhMqJubGKRHy4Ak69yw== artur
EOF

[ -f ~/.ssh/id_rsa.${GERRIT_USER} ] && \
    cat ~/.ssh/id_rsa.${GERRIT_USER} | lxc-attach -n ${TEMPLATE} -- bash -c "cat >/home/jenkins/.ssh/id_rsa.${GERRIT_USER}"
lxc-attach -n ${TEMPLATE} -- chmod 600 /home/jenkins/.ssh/id_rsa.${GERRIT_USER}

cat << EOF | lxc-attach -n ${TEMPLATE} -- bash -c "cat >/home/jenkins/env_variables.sh"
export TESTRAIL_USER=${TESTRAIL_USER:-}
export TESTRAIL_PASSWORD=${TESTRAIL_PASSWORD:-}
EOF

# Configure PYPI mirror
lxc-attach -n ${TEMPLATE} -- su - jenkins <<PYPI
mkdir /home/jenkins/.pip
cat >/home/jenkins/.pip/pip.conf <<EOF
[global]
index-url = http://pypi.mosi.mirantis.net/simple
trusted-host = pypi.mosi.mirantis.net
EOF

cat >/home/jenkins/.pydistutils.cfg <<EOF
[easy_install]
index_url = http://pypi.mosi.mirantis.net/simple
EOF
PYPI

# Change owner on all files and subdirectories in jenkins home directory
lxc-attach -n ${TEMPLATE} -- chown -R jenkins /home/jenkins

# Enable apt-cacher
echo 'Acquire::http { Proxy "http://10.20.1.254:3142"; };' >${LXC_DIR}/rootfs/etc/apt/apt.conf.d/01proxy

lxc-attach -n ${TEMPLATE} -- apt-get -y install vlan bridge-utils
lxc-attach -n ${TEMPLATE} -- ifup br-admin
lxc-attach -n ${TEMPLATE} -- ifup br-public
lxc-attach -n ${TEMPLATE} -- ifup vlan101

lxc-attach -n ${TEMPLATE} -- bash -c "cd /opt/mos-components-ci; ./scripts/lxc_prepare_worker.sh"

lxc-stop -n ${TEMPLATE}
