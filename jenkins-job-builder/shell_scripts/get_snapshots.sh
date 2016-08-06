#!/usr/bin/env bash

virtualenv init
source ./init/bin/activate

# clear ENV_INJECT_PATH file
> "$ENV_INJECT_PATH"

# generate repo file for update fuel (9.0 -> 9.x)
wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/shell_scripts/update_fuel.sh
sudo chmod +x update_fuel.sh
./update_fuel.sh

# get snapshot_id for TestRail
SNAPSHOT_ID=$(awk '/CUSTOM_VERSION/ {print $2}' snapshots.params)
echo "SNAPSHOT_ID=$SNAPSHOT_ID" >> "$ENV_INJECT_PATH"
