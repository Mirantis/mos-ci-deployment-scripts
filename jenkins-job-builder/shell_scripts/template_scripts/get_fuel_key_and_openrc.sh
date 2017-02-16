export FUEL_KEY=fuel.key
SSH_OPTIONS='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

# Copy fuel key
sshpass -p r00tme scp $SSH_OPTIONS root@$FUEL_MASTER_IP:.ssh/id_rsa $FUEL_KEY

# Get some information
export CONTROLLER_IP=$(sshpass -p r00tme ssh $SSH_OPTIONS root@$FUEL_MASTER_IP \
    'fuel node | grep -m1 controller | awk "{ print \$9 }"')

OS_DASHBOARD_URL=$(sshpass -p r00tme ssh $SSH_OPTIONS -i $FUEL_KEY root@${CONTROLLER_IP} \
    'find /etc/haproxy/ -name "*horizon*" | xargs grep bind' | tr -d '[:space:]' | sed 's/bind//' | sed 's/:80//')

export OS_DASHBOARD_URL="http://${OS_DASHBOARD_URL}/horizon"

# Copy openrc
scp -i $FUEL_KEY $SSH_OPTIONS root@$CONTROLLER_IP:openrc .

. openrc

if [[ $MILESTONE == 10.* ]]; then
    virtualenv --clear venv
    . venv/bin/activate
    pip install git+git://github.com/openstack/python-openstackclient
    set +e

    openstack flavor create m1.tiny   --ram 512   --disk 1   --vcpus 1
    openstack flavor create m1.small  --ram 2048  --disk 20  --vcpus 1
    openstack flavor create m1.medium --ram 4096  --disk 40  --vcpus 2
    openstack flavor create m1.large  --ram 8192  --disk 80  --vcpus 4
    openstack flavor create m1.xlarge --ram 16384 --disk 160 --vcpus 8
    deactivate
fi

env >> "${ENV_INJECT_PATH}"
