#!/usr/bin/env bash
# This script allows to deploy OpenStack environments
# using simple configuration file

# Hide trace on jenkins
if [ -z "$JOB_NAME" ]; then
    set -o xtrace
fi

if [ -z "$ISO_PATH" ]
then
    echo "Please download ISO and define env variable ISO_PATH"
    exit 1
fi

if [ -z "$NEUTRONCONF" ] || [ "$NEUTRONCONF" != 'VLAN' -a  "$NEUTRONCONF" != 'VxLAN' ]
then
    echo "Please define env variable NEUTRONCONF as 'VLAN' or 'VxLAN'"
    exit 1
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

cp __init__.py fuel-qa/system_test/
cp deploy_env.py fuel-qa/system_test/tests/
cp mos_tests.yaml fuel-qa/system_test/tests_templates/devops_configs/
cp 3_controllers_2compute_neutron*.yaml fuel-qa/system_test/tests_templates/tests_configs

cd fuel-qa
pip install -r fuelweb_test/requirements.txt --upgrade
# https://bugs.launchpad.net/oslo.service/+bug/1525992 workaround
pip uninstall -y python-neutronclient
pip install 'python-neutronclient<4.0.0'

# create new environment
if [ ${NEUTRONCONF} == "VLAN" ]
then
    if [ ${CEPH_ENABLE} == "TRUE" ]
    then
        ./utils/jenkins/system_tests.sh -k -K -j fuelweb_test -t test -V ${V_ENV_DIR} -w $(pwd) -o --group="system_test.deploy_env(3_controllers_2compute_neutronVLAN_and_ceph_env)"
    else
        ./utils/jenkins/system_tests.sh -k -K -j fuelweb_test -t test -V ${V_ENV_DIR} -w $(pwd) -o --group="system_test.deploy_env(3_controllers_2compute_neutronVLAN_env)"
    fi
fi

if [ ${NEUTRONCONF} == "VxLAN" ]
then
    if [ ${CEPH_ENABLE} == "TRUE" ]
    then
        ./utils/jenkins/system_tests.sh -k -K -j fuelweb_test -t test -V ${V_ENV_DIR} -w $(pwd) -o --group="system_test.deploy_env(3_controllers_2compute_neutronVxLAN_and_ceph_env)"
    else
        ./utils/jenkins/system_tests.sh -k -K -j fuelweb_test -t test -V ${V_ENV_DIR} -w $(pwd) -o --group="system_test.deploy_env(3_controllers_2compute_neutronVxLAN_env)"
    fi
fi
