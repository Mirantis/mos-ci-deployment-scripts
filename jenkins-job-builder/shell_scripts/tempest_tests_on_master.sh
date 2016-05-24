ISO_NAME=`ls "$ISO_DIR"`
ENV_NAME=MOS_CI_"$ISO_NAME"
SNAPSHOT=`echo $SNAPSHOT_NAME | sed 's/ha_deploy_//'`
ISO_NAME=`ls "$ISO_DIR"`
ISO_ID=`echo "$ISO_NAME" | cut -f3 -d-`
REPORT_PATH="$REPORT_PREFIX"/"$ENV_NAME"_"$SNAPSHOT_NAME"
echo "BUILD_URL=$BUILD_URL" >> "$ENV_INJECT_PATH"
echo "REPORT_PATH=$REPORT_PATH" >> "$ENV_INJECT_PATH"
echo "$REPORT_PATH" > ./param.pm

dos.py revert-resume "$ENV_NAME" "$SNAPSHOT_NAME"
sed -i 's|rally verify install --source /var/lib/tempest --no-tempest-venv|rally verify install --source /var/lib/tempest|g' rally-tempest/latest/setup_tempest.sh
sed -i 's|FROM rallyforge/rally:latest|FROM rallyforge/rally:0.3.1|g' rally-tempest/latest/Dockerfile

git clone https://github.com/Mirantis/mos-integration-tests
cd mos-integration-tests

echo 'from mos_tests.environment.devops_client import DevopsClient' > temp.py
echo "print DevopsClient.get_admin_node_ip('$ENV_NAME')" >> temp.py
MASTER_NODE_IP=`python temp.py`
echo "$MASTER_NODE_IP"

cd ..

virtualenv venv
. venv/bin/activate
sudo apt-get install docker.io sshpass -y
sudo docker build -t rally-tempest rally-tempest/latest
sudo docker save -o ./dimage rally-tempest
echo '' > ~/.ssh/known_hosts
sshpass -p 'r00tme' scp -o "StrictHostKeyChecking no" dimage root@"$MASTER_NODE_IP":/root/rally

echo '#!/bin/bash -xe' > ssh_scr.sh
echo 'docker load -i /root/rally' >> ssh_scr.sh

wget https://raw.githubusercontent.com/EduardFazliev/mos-ci-deployment-scripts/feature/jjb/jenkins-job-builder/shell_scripts/rally_tempest_prepare_host.sh
cat rally_tempest_prepare_host.sh >> ssh_scr.sh
echo '' >> ssh_scr.sh

echo 'docker images | grep rally > temp.txt' >> ssh_scr.sh
echo 'awk '\''{print $3}'\'' temp.txt > ans' >> ssh_scr.sh
echo 'ID=`cat ans`' >> ssh_scr.sh
echo 'echo $ID' >> ssh_scr.sh

echo 'docker run -tid -v /var/lib/rally-tempest-container-home-dir:/home/rally --net host "$ID" > dock.id' >> ssh_scr.sh
echo 'DOCK_ID=`cat dock.id`' >> ssh_scr.sh
echo 'sed -i "s|:5000|:5000/v2.0|g" /var/lib/rally-tempest-container-home-dir/openrc' >> ssh_scr.sh
echo 'docker exec -u root "$DOCK_ID" sed -i "s|\#swift_operator_role = Member|swift_operator_role=SwiftOperator|g" /etc/rally/rally.conf' >> ssh_scr.sh

echo 'docker exec "$DOCK_ID" setup-tempest' >> ssh_scr.sh

if [[ "$CEPH_SKIP_TESTS" == 'TRUE' ]];
then
echo 'docker exec -u root "$DOCK_ID" bash -c '\''find / -name test_server_personality.py -exec sed -i "22i from tempest.lib import decorators" {} \; -exec sed  -i "54i\    @decorators.skip_because(bug=\"1467860\")" {} \; -exec sed  -i "109i\    @decorators.skip_because(bug=\"1467860\")" {} \;'\'' ' >> ssh_scr.sh
fi

echo 'file=`find / -name tempest.conf`' >> ssh_scr.sh
echo 'echo "backup = False" >> $file' >> ssh_scr.sh

if [[ "$IRONIC_ENABLE" == 'TRUE' ]] ;
then
echo ' sed -i "95i ironic = True" $file ' >> ssh_scr.sh
else
echo ' sed -i "95i ironic = False" $file ' >> ssh_scr.sh
fi

echo 'sed -i "79i max_template_size = 524288" $file ' >> ssh_scr.sh
echo 'sed -i "80i max_resources_per_stack = 1000" $file ' >> ssh_scr.sh
echo 'sed -i "81i max_json_body_size = 10880000" $file ' >> ssh_scr.sh
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

echo 'docker exec "$DOCK_ID" bash -c "source /home/rally/openrc && rally verify start --system-wide --concurrency 1"' >> ssh_scr.sh

# echo 'docker exec "$DOCK_ID" bash -c "source /home/rally/openrc && rally verify start --regex tempest.api --concurrency 1"' >> ssh_scr.sh

echo 'docker exec "$DOCK_ID" bash -c "rally verify results --json --output-file output.json" ' >> ssh_scr.sh
echo 'docker exec "$DOCK_ID" bash -c "rm -rf rally_json2junit && git clone https://github.com/EduardFazliev/rally_json2junit.git && python rally_json2junit/rally_json2junit/results_parser.py output.json" ' >> ssh_scr.sh
chmod +x ssh_scr.sh
sshpass -p 'r00tme' scp -o "StrictHostKeyChecking no" ssh_scr.sh root@"$MASTER_NODE_IP":/root/
echo 'chmod +x /root/ssh_scr.sh && /bin/bash -xe /root/ssh_scr.sh > /root/log.log' | sshpass -p 'r00tme' ssh -T root@"$MASTER_NODE_IP"
sshpass -p 'r00tme' scp -o "StrictHostKeyChecking no" root@"$MASTER_NODE_IP":/root/log.log ./
sshpass -p 'r00tme' scp -o "StrictHostKeyChecking no" root@"$MASTER_NODE_IP":/var/lib/rally-tempest-container-home-dir/verification.xml ./
deactivate
