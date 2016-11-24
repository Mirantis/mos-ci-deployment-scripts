export MK22_KEY=mk22.key
SSH_OPTIONS='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

# Copy mk22 key
sshpass -p r00tme scp $SSH_OPTIONS root@$MK22_CFG01_IP:.ssh/id_rsa $MK22_KEY

# Get controller ip
export CONTROLLER_IP=$(sshpass -p r00tme ssh $SSH_OPTIONS root@$MK22_CFG01_IP \
    "salt 'ctl01*' network.interface_ip eth1 | sed -n '2p' | xargs")

# Copy keystonercv3
scp -i $MK22_KEY $SSH_OPTIONS root@$CONTROLLER_IP:keystonercv3 .

. keystonercv3

env >> "${ENV_INJECT_PATH}"
