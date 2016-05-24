#!/usr/bin/env bash

# This script deploy MirantisOpenStak from templates


patch_fuel_qa(){
    # Check and apply patch to fuel_qa
    set +e
    pushd $PWD/fuel-qa
    file_name=$1
    patch_file=../fuel_qa_patches/$file_name
    echo "Check for patch $file_name"
    git apply --check $patch_file 2> /dev/null
    if [ $? -eq 0 ]; then
        echo "Applying patch $file_name"
        git apply $patch_file
    fi
    popd
    set -e
}

# exit from shell if error happens
set -e

# Hide trace on jenkins
if [ -z "$JOB_NAME" ]; then
    set -o xtrace
fi

if [ -z "$ISO_PATH" ]; then
    echo "Please download ISO and define env variable ISO_PATH"
    exit 1
fi
if [ ! -f "$ISO_PATH" ]; then
    echo "$ISO_PATH is not exists or not a regular file"
    exit 1
fi

PWD=$(pwd)
#CONFIG_PATH=${1:?You should pass a valid path to Yaml tempate as first argument}

if [ ! -f "$CONFIG_PATH" ]; then
    echo "$CONFIG_PATH is not exists or not a regular file"
    exit 1
fi
CONFIG_FOLDER=$(basename $(dirname $CONFIG_PATH))
CONFIG_FILE=$(basename $CONFIG_PATH)
CONFIG_NAME="${CONFIG_FILE%.*}"

SNAPSHOT_NAME="ha_deploy_"$CONFIG_FOLDER"_"$CONFIG_NAME
echo "SNAPSHOT_NAME=${SNAPSHOT_NAME}" > "$ENV_INJECT_PATH"

# Set fuel QA version
# https://github.com/openstack/fuel-qa/branches
FUEL_QA_VER=${FUEL_QA_VER:-'master'}

V_ENV_DIR="$(pwd)/fuel-devops-venv"

# set ENV_NAME if it is not defined
ENV_NAME=${ENV_NAME:-"$CONFIG_FOLDER"_"$CONFIG_NAME"_"$RANDOM"}
DISABLE_SSL=${DISABLE_SSL:-TRUE}
KVM_USE=${KVM_USE:-true}
INTERFACE_MODEL=${INTERFACE_MODEL:-virtio}
PLUGINS_CONFIG_PATH=${PLUGINS_CONFIG_PATH:-$(pwd)/plugins.yaml}
# more time can be required to deploy env
DEPLOYMENT_TIMEOUT=${DEPLOYMENT_TIMEOUT:-10000}

export ENV_NAME DISABLE_SSL KVM_USE INTERFACE_MODEL PLUGINS_CONFIG_PATH DEPLOYMENT_TIMEOUT

echo "Env name:         ${ENV_NAME}"
echo "Snapshot name:    ${SNAPSHOT_NAME}"
echo "Fuel QA branch:   ${FUEL_QA_VER}"
echo ""

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
    git checkout -- *
    git checkout "${FUEL_QA_VER}"
    git reset --hard
    git pull
    popd
fi

patch_fuel_qa qos.patch

pip install -r fuel-qa/fuelweb_test/requirements.txt --upgrade

django-admin.py syncdb --settings=devops.settings
django-admin.py migrate devops --settings=devops.settings


cp test_deploy_env.py fuel-qa/system_test/tests/
cp -r templates/* fuel-qa/system_test/tests_templates/
cp $CONFIG_PATH fuel-qa/system_test/tests_templates/tests_configs/

cd fuel-qa


if [ "${INTERFACE_MODEL}" == 'virtio' ]; then
    # Virtio network interfaces have names eth0..eth5
    # (rather than default names - enp0s3..enp0s8)
    for i in {0..5}; do
        export IFACE_$i=eth$i
    done
fi

# create new environment
./run_system_test.py run 'system_test.deploy_env' --with-config $CONFIG_NAME

# make snapshot if deployment is successful
dos.py suspend ${ENV_NAME}
dos.py snapshot ${ENV_NAME} ${SNAPSHOT_NAME}
dos.py resume ${ENV_NAME}
