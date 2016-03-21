#!/usr/bin/env bash
# This script install all necessary dependencies to deploy OpenStack environment

# Set default locale if it's empty
if [ -z "$LC_ALL" ]; then echo "export LC_ALL=C" | sudo tee -a /etc/profile ; source /etc/profile; fi

sudo apt-get update && sudo apt-get upgrade -y

sudo apt-get install -y --force-yes git \
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
bridge-utils \
docker.io \
sshpass \
python-virtualenv \
python-dev \
libxml2-dev \
libxslt1-dev \
libpq-dev \
libgmp-dev \
tshark

# Install seedclient
wget -O /tmp/python-seed-client.deb http://mirror.fuel-infra.org/devops/ubuntu/all/python-seed-client_0.17-ubuntu55_all.deb
sudo apt-get -y -f install
sudo dpkg -i /tmp/python-seed-client.deb
sudo apt-get -y -f --force-yes install

sudo virsh pool-define-as --type=dir --name=default --target=/var/lib/libvirt/images
sudo virsh pool-autostart default
sudo virsh pool-start default

sudo usermod $(whoami) -a -G libvirtd

sudo sed -ir 's/peer/trust/' /etc/postgresql/9.*/main/pg_hba.conf
sudo service postgresql restart

sleep 1

sudo -u postgres psql <<EOF
CREATE DATABASE fuel_devops;
CREATE USER fuel_devops WITH password 'fuel_devops';
GRANT ALL privileges ON DATABASE fuel_devops TO fuel_devops;
\q
EOF