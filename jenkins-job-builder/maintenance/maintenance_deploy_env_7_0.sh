#!/usr/bin/env bash
# This script allows to deploy OpenStack environments
# using simple configuration file


# exit from shell if error happens
set -e

# Hide trace on jenkins
if [ -z "$JOB_NAME" ]; then
    set -o xtrace
fi

if [ -z "$ISO_PATH" ]
then
    echo "Please download ISO and define env variable ISO_PATH"
    exit 1
fi


# Set fuel QA version
# https://github.com/openstack/fuel-qa/branches
FUEL_QA_VER=${FUEL_QA_VER:-master}

# Erase all previous environments by default
ERASE_PREV_ENV=${ERASE_PREV_ENV:-true}

# Sat GROUP. By default tempest_ceph_services
GROUP=${GROUP:-tempest_ceph_services}


V_ENV_DIR="`pwd`/fuel-devops-venv"

# set ENV_NAME if it is not defined
ENV_NAME=${ENV_NAME:-Test_Deployment_MOS_CI_$RANDOM}

echo "Env name:         ${ENV_NAME}"
echo -n "Fuel QA branch:   ${FUEL_QA_VER}"

# Check if folder for virtual env exist
if [ ! -d "${V_ENV_DIR}" ]; then
    virtualenv --no-site-packages ${V_ENV_DIR}
fi

source ${V_ENV_DIR}/bin/activate
pip install -U pip


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

pip install -r fuel-qa/fuelweb_test/requirements.txt --upgrade

django-admin.py syncdb --settings=devops.settings
django-admin.py migrate devops --settings=devops.settings

# erase previous environments
if [ ${ERASE_PREV_ENV} == true ]; then
    for i in `dos.py list | grep MOS`; do dos.py erase $i; done
fi

cat jenkins-job-builder/maintenance/fuel-qa-tests/$FILE >  fuel-qa/fuelweb_test/tests/test_services.py

cd fuel-qa

# Apply fuel-qa patches
if [ ${IRONIC_ENABLE} == 'true' ]; then
    file_name=ironic.patch
    patch_file=../fuel_qa_patches/$file_name
    echo "Check for patch $file_name"
    git apply --check $patch_file 2> /dev/null
    if [ $? -eq 0 ]; then
        echo "Applying patch $file_name"
        git apply $patch_file
    fi
fi

if [ ${DVR_ENABLE} == 'true' ] || [ ${L3_HA_ENABLE} == 'true' ] || [ ${L2_POP_ENABLE} == 'true' ]; then
    file_name=DVR_L2_pop_HA.patch
    patch_file=../fuel_qa_patches/$file_name
    echo "Check for patch $file_name"
    git apply --check $patch_file 2> /dev/null
    if [ $? -eq 0 ]; then
        echo "Applying patch $file_name"
        git apply $patch_file
    fi
fi


# create new environment
# more time can be required to deploy env
export DEPLOYMENT_TIMEOUT=10000
export DRIVER_USE_HOST_CPU=false
export ENV_NAME=$ENV_NAME

./utils/jenkins/system_tests.sh -k -K -j fuelweb_test -t test -V ${V_ENV_DIR} -w $(pwd) -o --group="${GROUP}"
