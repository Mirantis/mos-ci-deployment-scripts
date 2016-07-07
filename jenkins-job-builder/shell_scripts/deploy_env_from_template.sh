#!/usr/bin/env bash
# This script deploy MirantisOpenStak from templates
git clone https://github.com/Mirantis/mos-ci-deployment-scripts.git
cd mos-ci-deployment-scripts
git checkout stable/9.0

# Not exiting from shell if error happens
set +e
./deploy_template.sh $CONFIG_PATH
exit 0
