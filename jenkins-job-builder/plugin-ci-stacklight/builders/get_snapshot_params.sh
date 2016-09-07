#!/usr/bin/env bash

#get 9.x repositories
set +e
rm snapshots.params
wget https://product-ci.infra.mirantis.net/job/9.x.snapshot/lastSuccessfulBuild/artifact/snapshots.params

rm conv_snapshot_file.py
wget https://raw.githubusercontent.com/openstack/fuel-qa/stable/mitaka/utils/jenkins/conv_snapshot_file.py
set -e

chmod 755 ./conv_snapshot_file.py
./conv_snapshot_file.py

SNAPSHOT_ID=$(awk '/CUSTOM_VERSION/ {print $2}' snapshots.params)

echo "SNAPSHOT_ID=$SNAPSHOT_ID" >> "${ENV_INJECT_PATH}"
cat extra_repos.sh >> ${ENV_INJECT_PATH}
