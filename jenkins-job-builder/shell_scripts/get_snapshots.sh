#!/usr/bin/env bash

# clear ENV_INJECT_PATH file
> "$ENV_INJECT_PATH"

# generate repo file for update fuel (9.0 -> 9.x)
git clone https://github.com/openstack/fuel-qa
cd fuel-qa
git checkout stable/mitaka
wget https://product-ci.infra.mirantis.net/job/9.x.snapshot/lastSuccessfulBuild/artifact/snapshots.param
python ./utils/jenkins/conv_snapshot_file.py

# get snapshot_id for TestRail
SNAPSHOT_ID=$(awk '/CUSTOM_VERSION/ {print $2}' snapshots.params)
echo "SNAPSHOT_ID=$SNAPSHOT_ID" >> "$ENV_INJECT_PATH"
cat extra_repos.sh >> "$ENV_INJECT_PATH"
