# This script is using python-jenkins python module,
# to get information from

#!/usr/bin/env bash

virtualenv init
. ./init/bin/activate
pip install python-jenkins

sudo rm -rf init_env.py
sudo wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/python_scripts/9.0_init_env_for_job/init_env.py
sudo chmod +x init_env.py

SWARM_ISO_LINK=`python init_env.py`

# uncomment and set link for special ISO
#SWARM_ISO_LINK="http://link/to/custom.iso"

sudo rm -rf "$ISO_DIR"/*
sudo wget "$SWARM_ISO_LINK" -P "$ISO_DIR"
