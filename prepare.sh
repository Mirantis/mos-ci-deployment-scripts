#!/usr/bin/env bash
# This script install all necessary dependencies to deploy OpenStack environment

sudo apt-get update && sudo apt-get upgrade -y
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


sudo virsh pool-define-as --type=dir --name=default --target=/var/lib/libvirt/images
sudo virsh pool-autostart default
sudo virsh pool-start default

sudo usermod $(whoami) -a -G libvirtd

sudo sed -ir 's/peer/trust/' /etc/postgresql/9.*/main/pg_hba.conf
sudo service postgresql restart

sudo expect -c 'spawn sudo -u postgres createuser -P fuel_devops; expect "password" {send -- "fuel_devops\rfuel_devops\r"};'
sudo -u postgres createdb fuel_devops -O fuel_devops
