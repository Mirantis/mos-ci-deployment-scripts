# This script deploy MirantisOpenStak from templates
git clone https://github.com/Mirantis/mos-ci-deployment-scripts.git
pushd mos-ci-deployment-scripts

# change fuel-qa version to stable/mitaka

if [[ "$USE_IPMI" == 'TRUE' ]]; then
    export MOSQA_IPMI_USER="$IPMI_USER"
    export MOSQA_IPMI_PASSWORD="$IPMI_PASSWORD"
fi

if [[ $MILESTONE == 9.* ]] && [[ $MILESTONE != 9.0 ]]; then
    # export 9.x repos
    # valid for maintenance
    wget http://cz7776.bud.mirantis.net:8080/jenkins/view/System%20Jobs/job/get_snaphots_for_all_slaves/lastSuccessfulBuild/artifact/set_snapshot_vars.sh
    source set_snapshot_vars.sh
    export EXTRA_DEB_REPOS
    export EXTRA_RPM_REPOS
    export UPDATE_FUEL_MIRROR
    export UPDATE_MASTER
    if [[ $UPDATE_MASTER_VIA_MOS_MU == True ]]; then
        export UPDATE_MASTER_VIA_MOS_MU
    fi
fi

# Not exiting from shell if error happens
set +e
./deploy_template.sh $CONFIG_PATH

# Exit from the repo folder
popd
