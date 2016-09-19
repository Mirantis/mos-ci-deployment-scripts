SSH_OPTIONS='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

controllers_list=$(sshpass -p r00tme ssh $SSH_OPTIONS root@$FUEL_MASTER_IP \
                   'fuel node | grep controller | awk "{ print \$9 }"')

for node in $controllers_list
do
    ssh $SSH_OPTIONS -T $node \
    echo "sed -i 's/revoke_by_id =.*/revoke_by_id = False/' /etc/keystone/keystone.conf" |\
    sshpass -p r00tme ssh $SSH_OPTIONS root@$FUEL_MASTER_IP

    ssh $SSH_OPTIONS -T $node echo "service apache2 reload" | \
    sshpass -p r00tme ssh $SSH_OPTIONS root@$FUEL_MASTER_IP
done
