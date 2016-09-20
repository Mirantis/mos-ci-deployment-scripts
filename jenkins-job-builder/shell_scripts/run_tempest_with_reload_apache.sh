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
                      head -1' | sshpass -p 'r00tme' ssh $SSH_OPTS -T root@"$FUEL_MASTER_IP")

############################ apache_reload  ########################
wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/shell_scripts/apache_reload
sshpass -p 'r00tme' scp $SSH_OPTS ./apache_reload root@"$FUEL_MASTER_IP":/root/apache_reload
sshpass -p 'r00tme' ssh $SSH_OPTS -T root@"$FUEL_MASTER_IP" "bash apache_reload"

##########################################################################

wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/shell_scripts/run_tempest_without_docker.sh

##### Copying script to master node, then to controller #####
sshpass -p 'r00tme' scp $SSH_OPTS run_tempest_without_docker.sh root@"$FUEL_MASTER_IP":/root/ssh_scr.sh
echo "scp /root/ssh_scr.sh node-$CONTROLLER_ID:/root/ssh_scr.sh" | sshpass -p 'r00tme' ssh $SSH_OPTS -T root@"$FUEL_MASTER_IP"

##### Executing script from admin node on controller node: #####
EXEC_CMD="echo 'bash -xe /root/ssh_scr.sh' | ssh -T node-$CONTROLLER_ID"
echo "$EXEC_CMD" | sshpass -p 'r00tme' ssh $SSH_OPTS -T root@"$FUEL_MASTER_IP"
##### Artifacts #####
GET_RES_CMD="scp node-$CONTROLLER_ID:/root/rally/verification.xml /root/verification.xml"
echo "$GET_RES_CMD" |  sshpass -p 'r00tme' ssh $SSH_OPTS -T root@"$FUEL_MASTER_IP"
sshpass -p 'r00tme' scp $SSH_OPTS root@"$FUEL_MASTER_IP":/root/verification.xml $REPORT_FILE

GET_LOG_CMD="scp node-$CONTROLLER_ID:/root/rally/log.log /root/log.log"
echo "$GET_LOG_CMD" |  sshpass -p 'r00tme' ssh $SSH_OPTS -T root@"$FUEL_MASTER_IP"
sshpass -p 'r00tme' scp $SSH_OPTS root@"$FUEL_MASTER_IP":/root/log.log ./

GET_TEMPEST_CONF="scp node-$CONTROLLER_ID:/root/rally/tempest.conf /root/tempest.conf"
echo "$GET_TEMPEST_CONF" |  sshpass -p 'r00tme' ssh $SSH_OPTS -T root@"$FUEL_MASTER_IP"
sshpass -p 'r00tme' scp $SSH_OPTS root@"$FUEL_MASTER_IP":/root/tempest.conf ./

GET_TEMPEST_LOG="scp node-$CONTROLLER_ID:/root/rally/tempest.log /root/tempest.log"
echo "$GET_TEMPEST_LOG" |  sshpass -p 'r00tme' ssh $SSH_OPTS -T root@"$FUEL_MASTER_IP"
sshpass -p 'r00tme' scp $SSH_OPTS root@"$FUEL_MASTER_IP":/root/tempest.log ./
