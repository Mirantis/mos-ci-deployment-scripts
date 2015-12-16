#!/bin/bash
# This script allows to deploy OpenStack environments
# using simple configuration file

sudo apt-get update
sudo apt-get install -y python-dev libxml2-dev libxslt1-dev
sudo apt-get install -y expect

sudo apt-get install -y git \
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
bridge-utils

sudo apt-get update && sudo apt-get upgrade -y

sudo apt-get install -y python-virtualenv libpq-dev libgmp-dev

sudo mkdir -p /qa_environments/fuel-devops-venv
sudo chmod 777 /qa_environments/fuel-devops-venv

virtualenv --system-site-packages /qa_environments/fuel-devops-venv

source /qa_environments/fuel-devops-venv/bin/activate
pip install git+https://github.com/openstack/fuel-devops.git@2.9.15 --upgrade

sudo virsh pool-define-as --type=dir --name=default --target=/var/lib/libvirt/images
sudo virsh pool-autostart default
sudo virsh pool-start default

sudo usermod $(whoami) -a -G libvirtd,sudo

sudo sed -ir 's/peer/trust/' /etc/postgresql/9.*/main/pg_hba.conf
sudo service postgresql restart

sudo expect -c 'spawn sudo -u postgres createuser -P fuel_devops; expect "password" {send -- "fuel_devops\rfuel_devops\r"};'
sudo -u postgres createdb fuel_devops -O fuel_devops

django-admin.py syncdb --settings=devops.settings
django-admin.py migrate devops --settings=devops.settings


export ENV_NAME="Test_Deployment_MOS_CI_$RANDOM"
rm -rf fuel-qa
git clone https://github.com/openstack/fuel-qa
cp mos_tests.yaml fuel-qa/system_test/tests_templates/devops_configs/
cp 3_controllers_2compute_neutronVLAN_and_ceph_env.yaml fuel-qa/system_test/tests_templates/tests_configs
cd fuel-qa
sudo pip install -r fuelweb_test/requirements.txt

./utils/jenkins/system_tests.sh -k -K -j fuelweb_test -t test -v /qa_environments/fuel-devops-venv -w $(pwd) -o --group=system_test.deploy_and_check_radosgw.3_controllers_2compute_neutronVLAN_and_ceph_env
