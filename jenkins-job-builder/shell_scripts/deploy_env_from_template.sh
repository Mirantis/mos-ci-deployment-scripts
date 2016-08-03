#!/usr/bin/env bash
# This script deploy MirantisOpenStak from templates
git clone https://github.com/Mirantis/mos-ci-deployment-scripts.git
cd mos-ci-deployment-scripts
git checkout stable/9.0

# change fuel-qa version to stable/mitaka
export FUEL_QA_VER=stable/mitaka

# Not exiting from shell if error happens
set +e
./deploy_template.sh $CONFIG_PATH
exit 0
