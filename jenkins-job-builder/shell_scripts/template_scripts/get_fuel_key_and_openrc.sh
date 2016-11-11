export FUEL_KEY=fuel.key
SSH_OPTIONS='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

# Copy fuel key
sshpass -p r00tme scp $SSH_OPTIONS root@$FUEL_MASTER_IP:.ssh/id_rsa $FUEL_KEY

# Get some information
export CONTROLLER_IP=$(sshpass -p r00tme ssh $SSH_OPTIONS root@$FUEL_MASTER_IP \
    'fuel node | grep -m1 controller | awk "{ print \$9 }"')

# Copy openrc
scp -i $FUEL_KEY $SSH_OPTIONS root@$CONTROLLER_IP:openrc .

. openrc

env >> "${ENV_INJECT_PATH}"
