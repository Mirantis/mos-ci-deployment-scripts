#!/usr/bin/env bash

set +e

SNAPSHOT=$(echo $SNAPSHOT_NAME | sed 's/ha_deploy_//')
echo 8.0_"$ENV_NAME"__"$SNAPSHOT" > build-name-setter.info

echo "" > ~/.ssh/known_hosts

REPORT_PATH="$REPORT_PREFIX"/"$ENV_NAME"_"$SNAPSHOT_NAME"
echo "$REPORT_PATH" > ./param.pm
echo "$BUILD_URL" > ./build_url

source ~/qa-venv-8.0/bin/activate

pip install -r requirements.txt
echo 'from mos_tests.environment.devops_client import DevopsClient' > temp.py
echo "print DevopsClient.get_admin_node_ip('$ENV_NAME')" >> temp.py
MASTER_NODE_IP=$(python temp.py)
echo "$MASTER_NODE_IP"

echo '#!/bin/bash -x' > test.sh
echo 'yum -y install git' >> test.sh
echo 'rm -rf mos-integration-tests' >> test.sh
echo 'git clone https://github.com/Mirantis/mos-integration-tests.git' >> test.sh
echo 'cd mos-integration-tests' >> test.sh
echo ' CONTR_ID=$( fuel node | grep controller | head -1 | awk '\''{print$1}'\'' ) ' >> test.sh
echo 'scp -rp mos_tests/ node-$CONTR_ID:/root/' >> test.sh
echo 'scp requirements.txt node-$CONTR_ID:/root/' >> test.sh
echo 'ssh node-$CONTR_ID "apt-get install git python-nose python-pip -y && \
pip install pytest && \
export PYTHONPATH=.:$PYTHONPATH && source /root/openrc && \
apt-get install git \
postgresql \
postgresql-server-dev-all \
libyaml-dev \
libffi-dev \
python-dev \
python-libvirt \
python-pip \
qemu-kvm \
qemu-utils \
libvirt-bin \
libvirt-dev \
ubuntu-vm-builder \
bridge-utils -y && \

sudo apt-get update -y && sudo apt-get upgrade -y && \

pip install -r requirements.txt && \

nosetests mos_tests/sahara/sahara_tests.py --with-xunit --xunit-file=sahara_tests_report.xml"' >> test.sh
echo 'scp node-$CONTR_ID:/root/sahara_tests_report.xml /root/' >> test.sh
#echo 'ssh node-$CONTR_ID "\rm -rf ~/mos_tests"' >> test.sh

sshpass -p 'r00tme' scp -o "StrictHostKeyChecking no" ./test.sh root@"$MASTER_NODE_IP":/root/

echo 'chmod +x /root/test.sh && /bin/bash -x /root/test.sh > /root/sahara-scenario.log' | sshpass -p 'r00tme' ssh -T root@"$MASTER_NODE_IP"

sshpass -p 'r00tme' scp -o "StrictHostKeyChecking no" root@"$MASTER_NODE_IP":/root/sahara_tests_report.xml ./report.xml
sshpass -p 'r00tme' scp -o "StrictHostKeyChecking no" root@"$MASTER_NODE_IP":/root/sahara-scenario.log ./test.log

deactivate
