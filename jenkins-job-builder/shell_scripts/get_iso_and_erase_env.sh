#!/usr/bin/env bash

virtualenv init
. ./init/bin/activate
pip install python-jenkins

sudo rm -rf init_env.py
sudo wget https://raw.githubusercontent.com/EduardFazliev/mos-ci-deployment-scripts/feature/jjb/jenkins-job-builder/python_scripts/9.0_init_env_for_job/init_env.py
sudo chmod +x init_env.py

iso_link=`python init_env.py`

######workaround for product-ci bug#################
#iso_link=`python init_env.py | sed 's/iso"/iso/g'`#
####################################################

sudo rm -rf /var/www/fuelweb-iso/*
sudo wget "$iso_link" -P /var/www/fuelweb-iso/

#####if we need some special iso#####
#sudo rm -rf /var/www/fuelweb-iso   #
#sudo wget  -P /var/www/fuelweb-iso #
#####################################

sudo dos.py list > temp
while read -r line
do
set -e
sudo dos.py erase $line || true
done < temp