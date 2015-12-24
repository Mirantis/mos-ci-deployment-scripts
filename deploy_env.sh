#!/bin/bash
# This script allows to deploy OpenStack environments
# using simple configuration file

if [ -z "$ISO_PATH" ]
then
    echo "Please download ISO and define env variable ISO_PATH"
    exit 1
fi

# Set fuel dev version
# https://github.com/openstack/fuel-devops/releases
if [ -z "$FUEL_DEV_VER" ]
then
    fuel_devops_ver='2.9.15'
else
    fuel_devops_ver=$FUEL_DEV_VER
fi

# Set fuel QA version
# https://github.com/openstack/fuel-qa/branches
if [ -z "$FUEL_QA_VER" ]
then
    fuel_qa_ver='master'
else
    fuel_qa_ver=$FUEL_QA_VER
fi
v_env_dir='/qa_environments/fuel-devops-venv/'

echo "Fuel Dev version: ${fuel_devops_ver}"
echo "Fuel QA branch:   ${fuel_qa_ver}"
echo ""

sudo apt-get update && sudo apt-get upgrade -y

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

sudo apt-get install -y python-virtualenv libpq-dev libgmp-dev

# Check if folder for virtual env exist
if [ -d "${v_env_dir}" ]; then
  sudo \rm -rf ${v_env_dir}
fi
sudo mkdir -p ${v_env_dir}
sudo chmod 777 ${v_env_dir}
virtualenv --system-site-packages ${v_env_dir}

source ${v_env_dir}bin/activate
sudo pip install git+https://github.com/openstack/fuel-devops.git@${fuel_devops_ver} --upgrade

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

# erase previous environments
for i in `dos.py list | grep MOS`; do dos.py erase $i; done

export ENV_NAME="Test_Deployment_MOS_CI_$RANDOM"
rm -rf fuel-qa
git clone -b "${fuel_qa_ver}" https://github.com/openstack/fuel-qa
cp mos_tests.yaml fuel-qa/system_test/tests_templates/devops_configs/
cp 3_controllers_2compute_neutronVLAN_and_ceph_env.yaml fuel-qa/system_test/tests_templates/tests_configs

cd fuel-qa
sudo pip install -r fuelweb_test/requirements.txt
sudo pip install git+https://github.com/openstack/fuel-devops.git@${fuel_devops_ver} --upgrade

# create new environment
./utils/jenkins/system_tests.sh -k -K -j fuelweb_test -t test -v ${v_env_dir} \
-w $(pwd) -o \
--group="system_test.deploy_and_check_radosgw(3_controllers_2compute_neutronVLAN_and_ceph_env)" ;
