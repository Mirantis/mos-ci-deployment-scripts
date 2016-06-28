#!/usr/bin/env bash

rm -rf dockerfiles
git clone https://review.fuel-infra.org/fuel-infra/dockerfiles
git checkout master
cd dockerfiles

##### Define SSH Opts #####
SSH_OPTS='-o UserKnownHostsFile=/dev/null \
          -o StrictHostKeyChecking=no'
##### Definig common job parameters #####
ISO_NAME=`basename "$ISO_PATH"`
ISO_ID=`echo "$ISO_NAME" | cut -f4 -d-`

SNAPSHOT_NAME=`dos.py snapshot-list "$ENV_NAME" | tail -1 | awk '{print $1}'`

SNAPSHOT=`echo $SNAPSHOT_NAME | sed 's/ha_deploy_//'`

##### Generate file for wrapper plugin #####
echo "$ISO_ID"_CONF:"$SNAPSHOT" > build-name-setter.info

dos.py revert-resume "$ENV_NAME" "$SNAPSHOT_NAME"

##### Generation Report Path for copying report files #####
REPORT_PATH="$REPORT_PREFIX"/"$ENV_NAME"_"$SNAPSHOT_NAME"
echo "BUILD=$BUILD_URL" >> "$ENV_INJECT_PATH"
echo "REPORT_PATH=$REPORT_PATH" >> "$ENV_INJECT_PATH"
echo "$REPORT_PATH" > ./param.pm

##### Workaround for rally docker files #####
sed -i 's|rally verify install --source /var/lib/tempest --no-tempest-venv \
       |rally verify install --source /var/lib/tempest|g' \
       rally-tempest/latest/setup_tempest.sh
sed -i 's|FROM rallyforge/rally:latest|FROM rallyforge/rally:0.4.0|g' \
       rally-tempest/latest/Dockerfile

sed -i '/RUN git clone/d' rally-tempest/latest/Dockerfile
sed -i '/pip install -r tempest/d' rally-tempest/latest/Dockerfile
sed -i '/mv tempest/d' rally-tempest/latest/Dockerfile

sed -i '8i\RUN git clone https://git.openstack.org/openstack/tempest &&  cd tempest && git checkout 63cb9a3718f394c9da8e0cc04b170ca2a8196ec2 && cd ../ && pip install -r tempest/requirements.txt -r tempest/test-requirements.txt && mv tempest/ /var/lib/' rally-tempest/latest/Dockerfile


##### Get ID of controller via SSH to admin node #####
CONTROLLER_ID=`echo 'fuel node | grep controller | awk '\''{print $1}'\'' | \
                     head -1' | sshpass -p 'r00tme' ssh -o UserKnownHostsFile=/dev/null \
                     -o StrictHostKeyChecking=no -T root@"$FUEL_MASTER_IP"`

##### Generating docker file and copying it to admin node,#####
##### and then to controller node                         #####
sudo docker build -t rally-tempest rally-tempest/latest
sudo docker save -o ./dimage rally-tempest
sshpass -p 'r00tme' scp -o UserKnownHostsFile=/dev/null \
                        -o StrictHostKeyChecking=no dimage root@"$FUEL_MASTER_IP":/root/rally
echo "scp /root/rally node-$CONTROLLER_ID:/root/rally" | \
      sshpass -p 'r00tme' ssh -o UserKnownHostsFile=/dev/null \
                              -o StrictHostKeyChecking=no \
                              -T root@"$FUEL_MASTER_IP"

##### For Ironic #####
set +e
EXEC_ADD_CMD="echo 'source /root/openrc && ironic node-create -d fake' | ssh -T node-$CONTROLLER_ID"
echo "$EXEC_ADD_CMD" | sshpass -p 'r00tme' ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -T root@"$FUEL_MASTER_IP"
set -e

###################################################################
##### Generate ssh file, which will be executed on controller #####
###################################################################
echo 'wget -qO- https://get.docker.com/ | sh' > ssh_scr.sh

wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/shell_scripts/prepare_controller.sh
cat prepare_controller.sh >> ssh_scr.sh
echo '' >> ssh_scr.sh

echo 'docker load -i /root/rally' >> ssh_scr.sh


echo 'docker images | grep rally > temp.txt' >> ssh_scr.sh
echo 'awk '\''{print $3}'\'' temp.txt > ans' >> ssh_scr.sh
echo 'ID=`cat ans`' >> ssh_scr.sh
echo 'echo $ID' >> ssh_scr.sh

echo 'docker run -tid -v /var/lib/rally-tempest-container-home-dir:/home/rally --net host "$ID" > dock.id' >> ssh_scr.sh
echo 'DOCK_ID=`cat dock.id`' >> ssh_scr.sh
echo 'sed -i "s|:5000|:5000/v2.0|g" /var/lib/rally-tempest-container-home-dir/openrc' >> ssh_scr.sh
echo 'docker exec -u root "$DOCK_ID" sed -i "s|\#swift_operator_role = Member|swift_operator_role=SwiftOperator|g" /etc/rally/rally.conf' >> ssh_scr.sh
echo 'docker exec "$DOCK_ID" setup-tempest' >> ssh_scr.sh

echo 'file=`find / -name tempest.conf`' >> ssh_scr.sh

echo 'sed -i "79i max_template_size = 5440000" $file ' >> ssh_scr.sh
echo 'sed -i "80i max_resources_per_stack = 20000" $file ' >> ssh_scr.sh
echo 'sed -i "81i max_json_body_size = 10880000" $file ' >> ssh_scr.sh
echo 'sed -i "24i volume_device_name = vdc" $file ' >> ssh_scr.sh
#echo ' sed -i "s/sahara = False/sahara = True/g" $file ' >> ssh_scr.sh

if [[ "$CEPH_RADOS" == 'TRUE' ]];
then
echo 'echo "[volume]" >> $file' >> ssh_scr.sh
echo 'echo "build_timeout = 300" >> $file' >> ssh_scr.sh
echo 'echo "storage_protocol = ceph" >> $file' >> ssh_scr.sh
fi

if [[ "$LVM_CINDER_FIX" == 'TRUE' ]];
then
echo 'echo "[volume]" >> $file' >> ssh_scr.sh
echo 'echo "build_timeout = 300" >> $file' >> ssh_scr.sh
echo 'echo "storage_protocol = iSCSI" >> $file' >> ssh_scr.sh
fi


echo 'deployment=$(docker exec "$DOCK_ID" bash -c "rally deployment list" | awk '\''/tempest/{print $2}'\'')' >> ssh_scr.sh
echo 'docker exec "$DOCK_ID" bash -c "cd .rally/tempest/for-deployment-${deployment} && git checkout 63cb9a3718f394c9da8e0cc04b170ca2a8196ec2" ' >> ssh_scr.sh

if [[ "$CEPH_RADOS" == 'TRUE' ]]; then
echo 'docker exec "$DOCK_ID" bash -c "wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/product-9.0/superjobs/rally-tempest/list" ' >> ssh_scr.sh
echo 'docker exec "$DOCK_ID" bash -c "source /home/rally/openrc && rally verify start --tests-file list --concurrency 1 --system-wide"' >> ssh_scr.sh
else
echo 'docker exec "$DOCK_ID" bash -c "source /home/rally/openrc && rally verify start --concurrency 1 --system-wide"' >> ssh_scr.sh
fi

echo 'docker exec "$DOCK_ID" bash -c "rally verify results --json --output-file output.json" ' >> ssh_scr.sh
echo 'docker exec "$DOCK_ID" bash -c "rm -rf rally_json2junit && git clone https://github.com/greatehop/rally_json2junit && python rally_json2junit/rally_json2junit/results_parser.py output.json" ' >> ssh_scr.sh
chmod +x ssh_scr.sh

##### Copying script to master node, then to controller #####
sshpass -p 'r00tme' scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ssh_scr.sh root@"$FUEL_MASTER_IP":/root/ssh_scr.sh
echo "scp /root/ssh_scr.sh node-$CONTROLLER_ID:/root/ssh_scr.sh" | sshpass -p 'r00tme' ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -T root@"$FUEL_MASTER_IP"

##### Executing script from admin node on controller node: #####
EXEC_CMD="echo 'chmod +x /root/ssh_scr.sh && /bin/bash -xe /root/ssh_scr.sh > /root/log.log' | ssh -T node-$CONTROLLER_ID"
echo "$EXEC_CMD" | sshpass -p 'r00tme' ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -T root@"$FUEL_MASTER_IP"

GET_RES_CMD="scp node-$CONTROLLER_ID:/var/lib/rally-tempest-container-home-dir/verification.xml /root/verification.xml"
echo "$GET_RES_CMD" |  sshpass -p 'r00tme' ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -T root@"$FUEL_MASTER_IP"
sshpass -p 'r00tme' scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@"$FUEL_MASTER_IP":/root/verification.xml ./

GET_LOG_CMD="scp node-$CONTROLLER_ID:/root/log.log /root/log.log"
echo "$GET_LOG_CMD" |  sshpass -p 'r00tme' ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -T root@"$FUEL_MASTER_IP"
sshpass -p 'r00tme' scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@"$FUEL_MASTER_IP":/root/log.log ./

dos.py destroy "$ENV_NAME"
