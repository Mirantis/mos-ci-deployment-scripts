#!/usr/bin/env bash
# Get the docker config.
# TBD need to prepare config with all needed settings
# to avoid the 'sed' operations below
rm -rf dockerfiles
git clone https://review.fuel-infra.org/fuel-infra/dockerfiles
### TEST ###
sed -i 's|rally verify install --source /var/lib/tempest --system-wide|rally verify install --source /var/lib/tempest|g' \
       dockerfiles/rally-tempest/latest/setup_tempest.sh
sed -i 's|git clone https://git.openstack.org/openstack/tempest && \\|git clone https://git.openstack.org/openstack/tempest|g' \
       dockerfiles/rally-tempest/latest/Dockerfile
sed -i '/pip install tempest/d' \
       dockerfiles/rally-tempest/latest/Dockerfile
########################################################################
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

##### Workaround for rally docker files #####
sed -i 's|FROM rallyforge/rally:latest|FROM rallyforge/rally:0.6.0|g' \
       dockerfiles/rally-tempest/latest/Dockerfile

##### Get ID of controller via SSH to admin node #####
CONTROLLER_ID=$(echo 'fuel node | grep controller | awk '\''{print $1}'\'' | \
                     head -1' | sshpass -p 'r00tme' ssh -o UserKnownHostsFile=/dev/null \
                     -o StrictHostKeyChecking=no -T root@"$FUEL_MASTER_IP")

##### Generating docker file and copying it to admin node,#####
##### and then to controller node                         #####
sudo docker build -no-cache -t rally-tempest dockerfiles/rally-tempest/latest
sudo docker save -o ./dimage rally-tempest
sshpass -p 'r00tme' scp -o UserKnownHostsFile=/dev/null \
                        -o StrictHostKeyChecking=no dimage root@"$FUEL_MASTER_IP":/root/rally
echo "scp /root/rally node-$CONTROLLER_ID:/root/rally" | \
      sshpass -p 'r00tme' ssh -o UserKnownHostsFile=/dev/null \
                              -o StrictHostKeyChecking=no \
                              -T root@"$FUEL_MASTER_IP"

# remove docker build
sudo docker rmi rally-tempest

###################################################################
##### Generate ssh file, which will be executed on controller #####
###################################################################

##### For Ironic ##### https://bugs.launchpad.net/mos/+bug/1570864
echo 'set +e' > ssh_scr.sh
echo 'source /root/openrc && ironic node-create -d fake' >> ssh_scr.sh
echo 'set -e' >> ssh_scr.sh

echo 'apt-get install -y docker.io cgroup-bin' >> ssh_scr.sh

wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/shell_scripts/prepare_controller.sh
cat prepare_controller.sh >> ssh_scr.sh
echo '' >> ssh_scr.sh

echo 'docker load -i /root/rally' >> ssh_scr.sh

echo 'docker images | grep rally > temp.txt' >> ssh_scr.sh
echo 'awk '\''{print $3}'\'' temp.txt > ans' >> ssh_scr.sh
echo 'ID=$(cat ans)' >> ssh_scr.sh
echo 'echo $ID' >> ssh_scr.sh
echo 'docker run --net host -v /var/lib/rally-tempest-container-home-dir:/home/rally -i -u root "$ID"' >> ssh_scr.sh

echo 'docker ps -a |grep latest > temp1.txt' >> ssh_scr.sh
echo 'awk '\''{print $1}'\'' temp1.txt > dock.id' >> ssh_scr.sh
echo 'DOCK_ID=$(cat dock.id)' >> ssh_scr.sh
echo 'echo $DOCK_ID' >> ssh_scr.sh
echo 'docker start $DOCK_ID' >> ssh_scr.sh
echo 'sed -i "s|:5000|:5000/v2.0|g" /var/lib/rally-tempest-container-home-dir/openrc' >> ssh_scr.sh
echo 'docker exec "$DOCK_ID" bash -c "apt-get install -y iputils-ping"' >> ssh_scr.sh
echo 'docker exec "$DOCK_ID" bash -c "sed -i 's|\#swift_operator_role = Member|swift_operator_role=SwiftOperator|g' /etc/rally/rally.conf"' >> ssh_scr.sh
echo 'docker exec "$DOCK_ID" bash -c "setup-tempest"' >> ssh_scr.sh

echo 'file=$(find / -name tempest.conf)' >> ssh_scr.sh

###Taking a list of available scheduler filters from controller's nova.conf to resolve the bug: https://bugs.launchpad.net/mos/+bug/1623862
NOVA_FLTR=$(sshpass -p 'r00tme' ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -T root@"$FUEL_MASTER_IP" ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no node-"$CONTROLLER_ID" 'sed -n '/scheduler_default_filters=/p' /etc/nova/nova.conf | cut -f2 -d=')
echo 'FILTERS='$NOVA_FLTR >> ssh_scr.sh

echo 'o_n=$(grep -n "\[orchestration\]" $file | cut -d':' -f1)' >> ssh_scr.sh
echo 'o_n=$(($o_n+1))' >> ssh_scr.sh
echo 'sed -e $o_n"s/^/max_json_body_size = 10880000\n/" -i  $file' >> ssh_scr.sh
echo 'sed -e $o_n"s/^/max_resources_per_stack = 20000\n/" -i  $file' >> ssh_scr.sh
echo 'sed -e $o_n"s/^/max_template_size = 5440000\n/" -i  $file' >> ssh_scr.sh

echo 'c_n=$(grep -n "\[compute\]" $file | cut -d':' -f1)' >> ssh_scr.sh
echo 'c_n=$(($c_n+1))' >> ssh_scr.sh
echo 'sed -e $c_n"s/^/volume_device_name = vdc\n/" -i $file' >> ssh_scr.sh
echo 'sed -e $c_n"s/^/min_microversion = 2.1\n/" -i $file' >> ssh_scr.sh
echo 'sed -e $c_n"s/^/max_microversion = latest\n/" -i $file' >> ssh_scr.sh
echo 'sed -e $c_n"s/^/min_compute_nodes = 2\n/" -i $file' >> ssh_scr.sh

echo 'cfe_n=$(grep -n "\[compute-feature-enabled\]" $file | cut -d':' -f1)' >> ssh_scr.sh
echo 'cfe_n=$(($cfe_n+1))' >> ssh_scr.sh
echo 'sed -e $cfe_n"s/^/scheduler_available_filters = $FILTERS\n/" -i $file' >> ssh_scr.sh
echo 'sed -e $cfe_n"s/^/block_migration_for_live_migration = True\n/" -i $file' >> ssh_scr.sh
echo 'sed -e $cfe_n"s/^/nova_cert = True\n/" -i $file' >> ssh_scr.sh
echo 'sed -e $cfe_n"s/^/personality = True\n/" -i $file' >> ssh_scr.sh

echo 'sed -i "s|live_migration = False|live_migration = True|g" $file' >> ssh_scr.sh

#echo 'test_vm=$(source /root/openrc && glance image-list |grep TestVM | awk {'print $2'})' >> ssh_scr.sh
#echo 'sed -i "s|image_ref_alt = |image_ref_alt = $test_vm|g" $file' >> ssh_scr.sh

if [[ "$CEPH_RADOS" == 'TRUE' ]]; then
    echo 'sed -i "s|block_migration_for_live_migration = True|block_migration_for_live_migration = False|g" $file' >> ssh_scr.sh
    echo 'echo "[volume]" >> $file' >> ssh_scr.sh
    echo 'echo "build_timeout = 300" >> $file' >> ssh_scr.sh
    echo 'echo "storage_protocol = ceph" >> $file' >> ssh_scr.sh
fi

if [[ "$LVM_CINDER_FIX" == 'TRUE' ]]; then
    echo 'echo "[volume]" >> $file' >> ssh_scr.sh
    echo 'echo "build_timeout = 300" >> $file' >> ssh_scr.sh
    echo 'echo "storage_protocol = iSCSI" >> $file' >> ssh_scr.sh
fi

# ballot stuffing for tempest test results
if [[ "$CEPH_RADOS" == 'TRUE' ]]; then
    echo 'docker exec "$DOCK_ID" bash -c "wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/shell_scripts/skip.list"' >> ssh_scr.sh
    echo 'docker exec "$DOCK_ID" bash -c "source /home/rally/openrc && rally verify start --skip-list skip.list"' >> ssh_scr.sh
else
    echo 'docker exec "$DOCK_ID" bash -c "source /home/rally/openrc && rally verify start"' >> ssh_scr.sh
fi

echo 'docker exec "$DOCK_ID" bash -c "rally verify results --json --output-file output.json" ' >> ssh_scr.sh
echo 'docker exec "$DOCK_ID" bash -c "rm -rf rally_json2junit && git clone https://github.com/EduardFazliev/rally_json2junit && python rally_json2junit/rally_json2junit/results_parser.py output.json" ' >> ssh_scr.sh
chmod +x ssh_scr.sh

##### Copying script to master node, then to controller #####
sshpass -p 'r00tme' scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ssh_scr.sh root@"$FUEL_MASTER_IP":/root/ssh_scr.sh
echo "scp /root/ssh_scr.sh node-$CONTROLLER_ID:/root/ssh_scr.sh" | sshpass -p 'r00tme' ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -T root@"$FUEL_MASTER_IP"

##### Executing script from admin node on controller node: #####
EXEC_CMD="echo 'chmod +x /root/ssh_scr.sh && /bin/bash -xe /root/ssh_scr.sh > /root/log.log' | ssh -T node-$CONTROLLER_ID"
echo "$EXEC_CMD" | sshpass -p 'r00tme' ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -T root@"$FUEL_MASTER_IP"

GET_RES_CMD="scp node-$CONTROLLER_ID:/var/lib/rally-tempest-container-home-dir/verification.xml /root/verification.xml"
echo "$GET_RES_CMD" |  sshpass -p 'r00tme' ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -T root@"$FUEL_MASTER_IP"
sshpass -p 'r00tme' scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@"$FUEL_MASTER_IP":/root/verification.xml $REPORT_FILE

GET_LOG_CMD="scp node-$CONTROLLER_ID:/root/log.log /root/log.log"
echo "$GET_LOG_CMD" |  sshpass -p 'r00tme' ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -T root@"$FUEL_MASTER_IP"
sshpass -p 'r00tme' scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@"$FUEL_MASTER_IP":/root/log.log ./

if [[ "$DESTROY_ENV_AFTER_TESTS" == 'TRUE' ]]; then
    # make snapshot for further investigation and disable env
    dos.py suspend ${ENV_NAME}
    dos.py snapshot "${ENV_NAME}" "${SNAPSHOT_NAME}_after_test"
    dos.py destroy "$ENV_NAME"
fi
