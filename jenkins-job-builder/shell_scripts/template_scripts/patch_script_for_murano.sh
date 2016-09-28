#!/usr/bin/env bash

FUEL_KEY=fuel.key
SSH_OPTIONS='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
SOURCE_PORT_PATH=/home/jenkins/port.py
DEST_PORT_PATH=/usr/lib/python2.7/dist-packages/heat/engine/resources/openstack/neutron/port.py

# Copy fuel key
sshpass -p r00tme scp $SSH_OPTIONS root@$FUEL_MASTER_IP:.ssh/id_rsa $FUEL_KEY

# Get some information
CONTROLLER_IPS=$(sshpass -p r00tme ssh $SSH_OPTIONS root@$FUEL_MASTER_IP \
    'fuel node | grep controller | awk "{ print \$9 }"')

for CONTROLLER_IP in $CONTROLLER_IPS; do
    # Copy patched file to all controllers
    scp -i $FUEL_KEY $SSH_OPTIONS $SOURCE_PORT_PATH root@$CONTROLLER_IP:$DEST_PORT_PATH
    ssh -i $FUEL_KEY $SSH_OPTIONS root@$CONTROLLER_IP 'service heat-api restart'
done

ssh -i $FUEL_KEY $SSH_OPTIONS root@$CONTROLLER_IP 'pcs resource restart clone_p_heat-engine'
