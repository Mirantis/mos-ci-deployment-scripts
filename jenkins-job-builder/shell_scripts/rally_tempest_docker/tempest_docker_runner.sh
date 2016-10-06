#!/usr/bin/env bash

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

wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/shell_scripts/rally_tempest_docker/rally_tempest_in_docker.sh

##### Copying script to master node, then to controller #####
sshpass -p 'r00tme' scp $SSH_OPTS run_tempest_in_docker.sh root@"$FUEL_MASTER_IP":/root/ssh_scr.sh
echo "scp /root/ssh_scr.sh node-$CONTROLLER_ID:/root/ssh_scr.sh" | sshpass -p 'r00tme' ssh $SSH_OPTS -T root@"$FUEL_MASTER_IP"

##### Executing script from admin node on controller node: #####
EXEC_CMD="echo 'bash -xe /root/ssh_scr.sh' | ssh -T node-$CONTROLLER_ID"
echo "$EXEC_CMD" | sshpass -p 'r00tme' ssh $SSH_OPTS -T root@"$FUEL_MASTER_IP"

##### Artifacts #####
GET_RES_CMD="scp node-$CONTROLLER_ID:/home/mount_dir/verification.xml /root/verification.xml"i
echo "$GET_RES_CMD" |  sshpass -p 'r00tme' ssh $SSH_OPTS -T root@"$FUEL_MASTER_IP"
sshpass -p 'r00tme' scp $SSH_OPTS root@"$FUEL_MASTER_IP":/root/verification.xml $REPORT_FILE

GET_LOG_CMD="scp node-$CONTROLLER_ID:/home/mount_dir/tests.log /root/tests.log"
echo "$GET_LOG_CMD" |  sshpass -p 'r00tme' ssh $SSH_OPTS -T root@"$FUEL_MASTER_IP"
sshpass -p 'r00tme' scp $SSH_OPTS root@"$FUEL_MASTER_IP":/root/log.log ./

GET_TEMPEST_CONF="scp node-$CONTROLLER_ID:/home/mount_dir/tempest.conf /root/tempest.conf"
echo "$GET_TEMPEST_CONF" |  sshpass -p 'r00tme' ssh $SSH_OPTS -T root@"$FUEL_MASTER_IP"
sshpass -p 'r00tme' scp $SSH_OPTS root@"$FUEL_MASTER_IP":/root/tempest.conf ./

GET_TEMPEST_LOG="scp node-$CONTROLLER_ID:/home/mount_dir/tempest.log /root/tempest.log"
echo "$GET_TEMPEST_LOG" |  sshpass -p 'r00tme' ssh $SSH_OPTS -T root@"$FUEL_MASTER_IP"
sshpass -p 'r00tme' scp $SSH_OPTS root@"$FUEL_MASTER_IP":/root/tempest.log ./

if [[ "$DESTROY_ENV_AFTER_TESTS" == 'TRUE' ]]; then
    # make snapshot for further investigation and disable env
    dos.py suspend ${ENV_NAME}
    dos.py snapshot "${ENV_NAME}" "${SNAPSHOT_NAME}_after_test"
    dos.py destroy "$ENV_NAME"
fi
