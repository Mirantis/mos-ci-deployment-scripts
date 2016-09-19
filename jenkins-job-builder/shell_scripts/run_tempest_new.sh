#!/usr/bin/env bash

##### Define SSH Opts #####
SSH_OPTS='-o UserKnownHostsFile=/dev/null \
          -o StrictHostKeyChecking=no'

##### Definig common job parameters #####
ISO_NAME=$(basename "$ISO_PATH")
ISO_ID=$(echo "$ISO_NAME" | cut -f4 -d-)
SNAPSHOT_NAME=$(dos.py snapshot-list "$ENV_NAME" | tail -1 | awk '{print $1}')
SNAPSHOT=$(echo $SNAPSHOT_NAME | sed 's/ha_deploy_//')

##### Generate file for wrapper plugin #####
echo "$ISO_ID"_CONF:"$SNAPSHOT" > build-name-setter.info

##### Get ID of controller via SSH to admin node #####
CONTROLLER_ID=$(echo 'fuel node | grep controller | awk '\''{print $1}'\'' | \
                     head -1' | sshpass -p 'r00tme' ssh -o UserKnownHostsFile=/dev/null \
                     -o StrictHostKeyChecking=no -T root@"$FUEL_MASTER_IP")



############################ add diff to keystone ########################
wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/shell_scripts/apply_diff
chmod +x apply_diff
sshpass -p 'r00tme' scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no apply_diff root@"$FUEL_MASTER_IP":/root/apply_diff
sshpass -p 'r00tme' ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -T root@"$FUEL_MASTER_IP" "./apply_diff"

##########################################################################

###################################################################
##### Generate ssh file, which will be executed on controller #####
###################################################################

##### For Ironic ##### https://bugs.launchpad.net/mos/+bug/1570864
echo 'set +e' > ssh_scr.sh
echo 'source /root/openrc && ironic node-create -d fake' >> ssh_scr.sh
echo 'set -e' >> ssh_scr.sh

wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/shell_scripts/run_tempest_without_docker.sh

cat run_tempest_without_docker.sh >> ssh_scr.sh

chmod +x ssh_scr.sh

##### Copying script to master node, then to controller #####
sshpass -p 'r00tme' scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ssh_scr.sh root@"$FUEL_MASTER_IP":/root/ssh_scr.sh
echo "scp /root/ssh_scr.sh node-$CONTROLLER_ID:/root/ssh_scr.sh" | sshpass -p 'r00tme' ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -T root@"$FUEL_MASTER_IP"

##### Executing script from admin node on controller node: #####
EXEC_CMD="echo 'chmod +x /root/ssh_scr.sh && /bin/bash -xe /root/ssh_scr.sh | ssh -T node-$CONTROLLER_ID"
echo "$EXEC_CMD" | sshpass -p 'r00tme' ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -T root@"$FUEL_MASTER_IP"

GET_RES_CMD="scp node-$CONTROLLER_ID:/root/rally/verification.xml /root/verification.xml"
echo "$GET_RES_CMD" |  sshpass -p 'r00tme' ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -T root@"$FUEL_MASTER_IP"
sshpass -p 'r00tme' scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@"$FUEL_MASTER_IP":/root/verification.xml $REPORT_FILE

GET_LOG_CMD="scp node-$CONTROLLER_ID:/root/rally/log.log /root/log.log"
echo "$GET_LOG_CMD" |  sshpass -p 'r00tme' ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -T root@"$FUEL_MASTER_IP"
sshpass -p 'r00tme' scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@"$FUEL_MASTER_IP":/root/log.log ./

GET_TEMPEST_CONF="scp node-$CONTROLLER_ID:/root/rally/tempest.conf /root/tempest.conf"
echo "$GET_LOG_CMD" |  sshpass -p 'r00tme' ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -T root@"$FUEL_MASTER_IP"
sshpass -p 'r00tme' scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@"$FUEL_MASTER_IP":/root/tempest.conf ./

GET_TEMPEST_LOG="scp node-$CONTROLLER_ID:/root/rally/tempest.log /root/tempest.log"
echo "$GET_LOG_CMD" |  sshpass -p 'r00tme' ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -T root@"$FUEL_MASTER_IP"
sshpass -p 'r00tme' scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@"$FUEL_MASTER_IP":/root/tempest.log ./
