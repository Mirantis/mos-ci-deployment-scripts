#!/bin/bash -xe

REPORT_PATH="${REPORT_PREFIX}/${ENV_NAME}_${SNAPSHOT_NAME}"
echo "$REPORT_PATH" > ./param.pm
echo "$BUILD_URL" > ./build_url

source ${VENV_PATH}/bin/activate
echo 'from devops.models import Environment' > temp.py
echo "env = Environment.get(name='$ENV_NAME')" >> temp.py
echo "print env.nodes().admin.get_ip_address_by_network_name('admin')" >> temp.py
MASTER_NODE_IP=$(python temp.py)
echo "$MASTER_NODE_IP"
deactivate

virtualenv venv
source venv/bin/activate
sudo docker build -t rally-tempest custom-scripts/rally-tempest/
sudo docker save -o ./dimage rally-tempest
echo '' > ~/.ssh/known_hosts
sshpass -p 'r00tme' scp -o "StrictHostKeyChecking no" dimage root@"$MASTER_NODE_IP":/root/rally

echo '#!/bin/bash -xe' > ssh_scr.sh
echo 'docker load -i /root/rally' >> ssh_scr.sh

wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/maintenance/helpers/rally_run.sh

chmod +x run_rally.sh

sshpass -p 'r00tme' scp -o "StrictHostKeyChecking no" run_rally.sh root@"$MASTER_NODE_IP":/root/
echo 'chmod +x /root/run_rally.sh && /bin/bash -xe /root/run_rally.sh > /root/log.log' | sshpass -p 'r00tme' ssh -T root@"$MASTER_NODE_IP"
sshpass -p 'r00tme' scp -o "StrictHostKeyChecking no" root@"$MASTER_NODE_IP":/root/log.log ./
sshpass -p 'r00tme' scp -o "StrictHostKeyChecking no" root@"$MASTER_NODE_IP":/var/lib/rally-tempest-container-home-dir/verification.xml ./
deactivate