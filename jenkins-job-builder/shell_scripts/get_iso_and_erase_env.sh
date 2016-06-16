#!/usr/bin/env bash

virtualenv init
. ./init/bin/activate
pip install python-jenkins

sudo rm -rf init_env.py
sudo wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/python_scripts/9.0_init_env_for_job/init_env.py
sudo chmod +x init_env.py

#iso_link=`python init_env.py`

# uncomment and set link for special ISO
iso_link="http://srv52-bud.infra.mirantis.net/fuelweb-iso/fuel-9.0-mos-490-2016-06-15_21-03-09.iso"

######workaround for product-ci bug#################
#iso_link=`python init_env.py | sed 's/iso"/iso/g'`#
####################################################

sudo rm -rf /var/www/fuelweb-iso/*
sudo wget "$iso_link" -P /var/www/fuelweb-iso/

sudo dos.py list > temp
while read -r line
do
set -e
sudo dos.py erase $line || true
done < temp