#!/usr/bin/env bash

virtualenv init
source ./init/bin/activate
pip install python-jenkins

# clear ENV_INJECT_PATH file
> "$ENV_INJECT_PATH"

# update fuel (9.0 -> 9.x)
wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/shell_scripts/update_fuel.sh
sudo chmod +x update_fuel.sh
./update_fuel.sh

# get last snapshot id
wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/python_scripts/9.0_init_env_for_job/get_shapshot_id.py
SNAPSHOT_ID=$(python get_shapshot_id.py)

echo "SNAPSHOT_ID=$SNAPSHOT_ID" >> "$ENV_INJECT_PATH"
