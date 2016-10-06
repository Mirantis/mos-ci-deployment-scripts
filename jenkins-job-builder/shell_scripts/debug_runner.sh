#!/usr/bin/env bash
### need fix
##### Define SSH Opts #####
export SSH_OPTS='-o UserKnownHostsFile=/dev/null  -o StrictHostKeyChecking=no'

##### Definig common job parameters #####
ISO_NAME=$(basename "$ISO_PATH")
ISO_ID=$(echo "$ISO_NAME" | cut -f4 -d-)
SNAPSHOT_NAME=$(dos.py snapshot-list "$ENV_NAME" | tail -1 | awk '{print $1}')
SNAPSHOT=$(echo $SNAPSHOT_NAME | sed 's/ha_deploy_//')

##### Generate file for wrapper plugin #####
echo "$ISO_ID"_CONF:"$SNAPSHOT" > build-name-setter.info

##### Get ID of controller via SSH to admin node #####
CONTROLLER_ID=$(echo 'fuel node | grep controller | awk '\''{print $1}'\'' | \
                      head -1' | sshpass -p 'r00tme' ssh $SSH_OPTS -T root@"$FUEL_MASTER_IP")

############################ add diff to keystone ########################
wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/shell_scripts/apply_diff
sshpass -p 'r00tme' scp $SSH_OPTS ./apply_diff root@"$FUEL_MASTER_IP":/root/apply_diff
sshpass -p 'r00tme' ssh $SSH_OPTS -T root@"$FUEL_MASTER_IP" "bash apply_diff"
##########################################################################

wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/shell_scripts/debug.sh

##### Copying script to master node, then to controller #####
sshpass -p 'r00tme' scp $SSH_OPTS debug.sh root@"$FUEL_MASTER_IP":/root/debug.sh
echo "scp /root/debug.sh node-$CONTROLLER_ID:/root/debug.sh" | sshpass -p 'r00tme' ssh $SSH_OPTS -T root@"$FUEL_MASTER_IP"

##### Executing script from admin node on controller node: #####
EXEC_CMD="echo 'bash -xe /root/debug.sh' | ssh -T node-$CONTROLLER_ID"
echo "$EXEC_CMD" | sshpass -p 'r00tme' ssh $SSH_OPTS -T root@"$FUEL_MASTER_IP"
