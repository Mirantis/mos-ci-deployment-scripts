#!/bin/bash
# This script allows to deploy OpenStack environments
# using simple configuration file

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
pip install git+https://github.com/openstack/fuel-devops.git@2.9.13 --upgrade

sudo virsh pool-define-as --type=dir --name=default --target=/var/lib/libvirt/images
sudo virsh pool-autostart default
sudo virsh pool-start default

sudo usermod $(whoami) -a -G libvirtd,sudo

sudo sed -ir 's/peer/trust/' /etc/postgresql/9.*/main/pg_hba.conf
sudo service postgresql restart
sudo expect -c 'spawn sudo -u postgres createuser -P fuel_devops; expect "password" {send -- "fuel_devops\rfuel_devops\r"};'

#sudo -u postgres createuser -P fuel_devops
sudo -u postgres createdb fuel_devops -O fuel_devops
django-admin.py syncdb --settings=devops.settings
django-admin.py migrate devops --settings=devops.settings
