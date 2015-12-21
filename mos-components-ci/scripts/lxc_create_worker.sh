#!/bin/bash -e

#
# Create LXC worker for deployment tests
#

TEMPLATE=${TEMPLATE:-worker}

GERRIT_USER=${GERRIT_USER:-mos-infra-ro}

if [ -z "${1}" ]; then
    echo "Missing deploy number"
    exit
fi

NAME_LXC=worker${1}
IP=`awk -v NAME=${NAME_LXC} '$1 == NAME {print $2}' lxc_workers_list`

# Stop and destroy worker
lxc-stop -n ${NAME_LXC} || :
lxc-destroy -n ${NAME_LXC} || :

# Create LXC container
lxc-clone -s -B overlayfs ${TEMPLATE} ${NAME_LXC}

LXC_PATH="$(lxc-config lxc.lxcpath)"
LXC_DIR="${LXC_PATH}/${NAME_LXC}"

# Reconfigure network
sed -ri \
    -e '/^lxc\.network\.ipv4\.gateway/ d' \
    -e "s|10\.20\.1\.199|10.20.1.${1}|" \
    -e "/^lxc\.mount\.entry/ s|/${TEMPLATE}/|/${NAME_LXC}/|g" \
    ${LXC_DIR}/config

cat >> ${LXC_DIR}/config <<EOF

lxc.network.type         = veth
lxc.network.link         = br-ex
lxc.network.flags        = up
lxc.network.ipv4         = ${IP}/24
lxc.network.ipv4.gateway = 172.16.48.1

lxc.start.auto           = 1
EOF

# Start container
# All following actions will be done on running container
lxc-start -d -n ${NAME_LXC}

# Replace hosts entry
lxc-attach -n ${NAME_LXC} -- lxc-attach -n ${NAME_LXC} -- \
    sed -ri \
    -e "s/(\s)${TEMPLATE}($|\s)/\1${NAME_LXC}\2/g" \
    -e "s/(\s)${TEMPLATE}(\.)/\1${NAME_LXC}\2/g" \
    /etc/hosts

cat << EOF2 | lxc-attach -n ${NAME_LXC} -- bash -c "cat >>/home/jenkins/worker_motd.sh"
#!/bin/bash

cat << EOF
######################################################
         Fuel WEB UI: http://${IP}:8000
 Openstack dashboard: http://${IP}
######################################################
EOF
EOF2
lxc-attach -n ${NAME_LXC} -- chmod +x /home/jenkins/worker_motd.sh
