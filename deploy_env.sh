#!/usr/bin/env bash
# This script allows to deploy OpenStack environments
# using simple configuration file

boolean(){
    if [ -z "$2" ] || [ ${2^^} == 'FALSE' ]
    then
        echo 'false'
    elif [ ${2^^} == 'TRUE' ]
    then
        echo 'true'
    else
        echo "Please set env variable $1 to empty, 'TRUE' or 'FALSE'."
        exit 1
    fi
}

# Hide trace on jenkins
if [ -z "$JOB_NAME" ]; then
    set -o xtrace
fi

if [ -z "$ISO_PATH" ]
then
    echo "Please download ISO and define env variable ISO_PATH"
    exit 1
fi

# Replace parameters in config file
GROUP_NAME='3_controllers_2compute_neutron_env'
CONFIG_NAME="${GROUP_NAME}.yaml"
cp 3_controllers_2compute_neutron_env_template.yaml ${CONFIG_NAME}

if [ "$SEGMENT_TYPE" == 'VLAN' ]
then
    SEGMENT_TYPE="vlan"
elif [ "$SEGMENT_TYPE" == 'VxLAN' ]
then
    SEGMENT_TYPE="tun"
else
    echo "Please define env variable SEGMENT_TYPE as 'VLAN' or 'VxLAN'"
    exit 1
fi

L2_POP_ENABLE=$(boolean "L2_POP_ENABLE" "$L2_POP_ENABLE")
DVR_ENABLE=$(boolean "DVR_ENABLE" "$DVR_ENABLE")
L3_HA_ENABLE=$(boolean "L3_HA_ENABLE" "$L3_HA_ENABLE")

CEPH_ENABLE=$(boolean "CEPH_ENABLE" "$CEPH_ENABLE")

if [ ${L2_POP_ENABLE} == 'true' ]
then
    if [ ${SEGMENT_TYPE} != 'tun' ]
    then
        echo "Error: L2_POP_ENABLE can be set to TRUE only for VxLAN configuration."
        exit 1
    fi

fi

# check limitations
if [ ${DVR_ENABLE} == 'true' ]
then
    if [ ${L3_HA_ENABLE} == 'true' ]
    then
        echo "Error: variables DVR_ENABLE and L3_HA_ENABLE can't be TRUE simultaniously."
        exit 1
    fi
    if [ ${SEGMENT_TYPE} == 'tun' ] && [ ${L2_POP_ENABLE} != 'true' ]
    then
        echo "Please set env variable L2_POP_ENABLE to 'TRUE' if you want to use VxLAN DVR configuration."
        exit 1
    fi
fi

# replace vars with its values in config files
sed -i -e "s/<%SEGMENT_TYPE%>/${SEGMENT_TYPE}/g" ${CONFIG_NAME}
sed -i -e "s/<%L2_POP_ENABLE%>/${L2_POP_ENABLE}/g" ${CONFIG_NAME}
sed -i -e "s/<%DVR_ENABLE%>/${DVR_ENABLE}/g" ${CONFIG_NAME}
sed -i -e "s/<%L3_HA_ENABLE%>/${L3_HA_ENABLE}/g" ${CONFIG_NAME}

if [ ${CEPH_ENABLE} == 'true' ]
then
    sed -i -e "s/# - ceph-osd/- ceph-osd/" ${CONFIG_NAME}
fi

# Set fuel dev version
# https://github.com/openstack/fuel-devops/releases
if [ -z "$FUEL_DEV_VER" ]
then
    FUEL_DEV_VER='2.9.15'
fi

# Set fuel QA version
# https://github.com/openstack/fuel-qa/branches
if [ -z "$FUEL_QA_VER" ]
then
    FUEL_QA_VER='master'
fi

# Erase all previous environments by default
if [ -z "$ERASE_PREV_ENV" ]; then
    ERASE_PREV_ENV=true
fi

V_ENV_DIR="`pwd`/fuel-devops-venv"

echo "Fuel Dev version: ${FUEL_DEV_VER}"
echo "Fuel QA branch:   ${FUEL_QA_VER}"
echo ""

# Check if folder for virtual env exist
if [ ! -d "${V_ENV_DIR}" ]; then
    virtualenv --no-site-packages ${V_ENV_DIR}
fi

source ${V_ENV_DIR}/bin/activate
pip install git+https://github.com/openstack/fuel-devops.git@${FUEL_DEV_VER} --upgrade

django-admin.py syncdb --settings=devops.settings
django-admin.py migrate devops --settings=devops.settings

# erase previous environments
if [ ${ERASE_PREV_ENV} == true ]; then
    for i in `dos.py list | grep MOS`; do dos.py erase $i; done
fi

export ENV_NAME="Test_Deployment_MOS_CI_$RANDOM"

# Check if fuel-qa folder exist
if [ ! -d fuel-qa ]; then
    git clone -b "${FUEL_QA_VER}" https://github.com/openstack/fuel-qa
else
    pushd fuel-qa
    git clean -f -d -x
    git checkout "${FUEL_QA_VER}"
    git reset --hard
    git pull
    popd
fi

# TEMPORARY: Delete code below after
# https://bugs.launchpad.net/fuel/+bug/1529230 merging
cd fuel-qa
git fetch https://review.openstack.org/openstack/fuel-qa refs/changes/71/262771/4
git checkout FETCH_HEAD
cd ..
#####

cp mos_tests.yaml fuel-qa/system_test/tests_templates/devops_configs/
cp ${CONFIG_NAME} fuel-qa/system_test/tests_templates/tests_configs

cd fuel-qa
pip install -r fuelweb_test/requirements.txt --upgrade
# https://bugs.launchpad.net/oslo.service/+bug/1525992 workaround
pip uninstall -y python-neutronclient
pip install 'python-neutronclient<4.0.0'

# create new environment
./utils/jenkins/system_tests.sh -k -K -j fuelweb_test -t test -v ${V_ENV_DIR} -w $(pwd) -o --group="system_test.create_deploy_ostf($GROUP_NAME)"
