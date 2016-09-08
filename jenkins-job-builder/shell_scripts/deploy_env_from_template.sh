#!/usr/bin/env bash
# This script deploy MirantisOpenStak from templates
git clone https://github.com/Mirantis/mos-ci-deployment-scripts.git
cd mos-ci-deployment-scripts
git checkout stable/9.0

# change fuel-qa version to stable/mitaka
export FUEL_QA_VER=stable/mitaka

if [[ "$USE_IPMI" == 'TRUE' ]]; then
    export MOSQA_IPMI_USER="$IPMI_USER"
    export MOSQA_IPMI_PASSWORD="$IPMI_PASSWORD"
fi

if [[ "$USE_9_0" != 'TRUE' ]]; then
    # export 9.x repos
    source /home/jenkins/env_inject.properties
    export EXTRA_DEB_REPOS
    export EXTRA_RPM_REPOS
    export UPDATE_FUEL_MIRROR
    export UPDATE_MASTER
fi

# Not exiting from shell if error happens
set +e
./deploy_template.sh $CONFIG_PATH
exit 0
