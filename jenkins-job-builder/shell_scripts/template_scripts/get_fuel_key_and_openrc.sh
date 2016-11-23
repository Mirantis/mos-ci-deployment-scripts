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

env >> "${ENV_INJECT_PATH}"
