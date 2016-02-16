#!/usr/bin/env bash
# This script allows to deploy OpenStack environments
# using simple configuration file

boolean(){
    eval val=\$$1

    if [ -z "$val" ] || [ ${val^^} == 'FALSE' ]
    then
        echo 'false'
    elif [ ${val^^} == 'TRUE' ]
    then
        echo 'true'
    else
        echo "Please set env variable $1 to empty, 'TRUE' or 'FALSE'."
        exit 1
    fi
}

digit_from_range(){
    eval val=\$$1

    if [ -z ${val} ]; then
        # set default value
        val=$4
    fi

    if [ ${val} -ge $2 ] && [ ${val} -le $3 ]; then
        echo ${val}
    else
        echo "Error: variable $1 can be from $2 to $3 or empty (will be set to $4 in this case)."
        exit 1
    fi
}

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

# Replace parameters in config file
GROUP_NAME='3_controllers_2compute_neutron_env'
CONFIG_NAME="${GROUP_NAME}.yaml"
cp 3_controllers_2compute_neutron_env_template.yaml ${CONFIG_NAME}

# set up nodes count
# CONTROLLERS_COUNT can be from 1 to 3 (default value 3)
CONTROLLERS_COUNT=$(digit_from_range 'CONTROLLERS_COUNT' 1 3 3)
# CONTROLLERS_COUNT can be from 1 to 3 (default value 2)
COMPUTES_COUNT=$(digit_from_range 'COMPUTES_COUNT' 0 3 2)
# CONTROLLERS_COUNT can be from 1 to 3 (default value 0)
IRONICS_COUNT=$(digit_from_range 'IRONICS_COUNT' 0 3 0)

NODES_COUNT=$(($CONTROLLERS_COUNT + $COMPUTES_COUNT + $IRONICS_COUNT))

# replace vars with its values in config files
for var in CONTROLLERS_COUNT COMPUTES_COUNT IRONICS_COUNT NODES_COUNT
do
    eval value=\$$var
    # replace variable in config with its value
    sed -i -e "s/<%${var}%>/${value}/g" ${CONFIG_NAME}
done

# set up segmet type
if [ "$SEGMENT_TYPE" == 'VLAN' ]
then
    SEGMENT_TYPE='vlan'
    SNAPSHOT_NAME='ha_deploy_VLAN'
elif [ "$SEGMENT_TYPE" == 'VxLAN' ]
then
    SEGMENT_TYPE='tun'
    SNAPSHOT_NAME='ha_deploy_VxLAN'
else
    echo "Please define env variable SEGMENT_TYPE as 'VLAN' or 'VxLAN'"
    exit 1
fi

# set up all vars which should be set to true or false
BOOL_VARS="L2_POP_ENABLE DVR_ENABLE L3_HA_ENABLE SAHARA_ENABLE MURANO_ENABLE CEILOMETER_ENABLE IRONIC_ENABLE RADOS_ENABLE"
for var in $BOOL_VARS
do
    eval $var=$(boolean $var)
done
# Note: CEPH and MONGODB params should be processed separately as
# they should be uncommented in config (not set to true or false as other)
CEPH_ENABLE=$(boolean 'CEPH_ENABLE')
MONGO_ENABLE=$(boolean 'MONGO_ENABLE')

# check limitations
if [ ${L2_POP_ENABLE} == 'true' ] && [ ${SEGMENT_TYPE} != 'tun' ]; then
    echo "Error: L2_POP_ENABLE can be set to TRUE only for VxLAN configuration."
    exit 1
fi

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

if [ ${RADOS_ENABLE} == 'true' ] && [ ${CEPH_ENABLE} != 'true' ]; then
    echo "Please set env variable CEPH_ENABLE to 'TRUE' if you want to use RADOS."
    exit 1
fi

if [ ${CEILOMETER_ENABLE} == 'true' ] && [ ${MONGO_ENABLE} != 'true' ]; then
    echo "Please set env variable MONGO_ENABLE to 'TRUE' if you want to use CEILOMETER."
    exit 1
fi

if [ ${IRONIC_ENABLE} == 'true' ] && [ ${SEGMENT_TYPE} != 'vlan' ]; then
    echo "Please set env variable SEGMENT_TYPE to 'VLAN' if you want to use IRONIC."
    exit 1
fi

if [ ${IRONICS_COUNT} -gt 0 ] && [ ${IRONIC_ENABLE} != 'true' ]; then
    echo "Please set env variable IRONIC_ENABLE to 'TRUE' if you want to use IRONIC nodes."
    exit 1
fi

# replace vars with its values in config files
for var in SEGMENT_TYPE $BOOL_VARS
do
    eval value=\$$var
    # replace variable in config with its value
    sed -i -e "s/<%${var}%>/${value}/g" ${CONFIG_NAME}
    if [ ${value} == 'true' ]; then
         # Add the name of var without word '_ENABLE' to snapshot name
         SNAPSHOT_NAME="${SNAPSHOT_NAME}_$(echo ${var} | sed 's/_ENABLE//')"
    fi
done

if [ ${CEPH_ENABLE} == 'true' ]
then
    sed -i -e "s/# - ceph-osd/- ceph-osd/" ${CONFIG_NAME}
    SNAPSHOT_NAME="${SNAPSHOT_NAME}_CEPH"
fi

if [ ${MONGO_ENABLE} == 'true' ]
then
    sed -i -e "s/# - mongo/- mongo/" ${CONFIG_NAME}
    SNAPSHOT_NAME="${SNAPSHOT_NAME}_MONGO"
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

# set ENV_NAME if it is not defined
if [ -z "${ENV_NAME}" ]; then
    export ENV_NAME="Test_Deployment_MOS_CI_$RANDOM"
fi

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
    git checkout "${FUEL_QA_VER}"
    git reset --hard
    git pull
    popd
fi

pip install -r fuel-qa/fuelweb_test/requirements.txt --upgrade
# https://bugs.launchpad.net/oslo.service/+bug/1525992 workaround
pip uninstall -y python-neutronclient
pip install 'python-neutronclient<4.0.0'

django-admin.py syncdb --settings=devops.settings
django-admin.py migrate devops --settings=devops.settings

# erase previous environments
if [ ${ERASE_PREV_ENV} == true ]; then
    for i in `dos.py list | grep MOS`; do dos.py erase $i; done
fi


cp mos_tests.yaml fuel-qa/system_test/tests_templates/devops_configs/
cp ${CONFIG_NAME} fuel-qa/system_test/tests_templates/tests_configs

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

./utils/jenkins/system_tests.sh -k -K -j fuelweb_test -t test -V ${V_ENV_DIR} -w $(pwd) -o --group="system_test.create_deploy_ostf($GROUP_NAME)"

# make snapshot if deployment is successful
dos.py suspend ${ENV_NAME}
dos.py snapshot ${ENV_NAME} ${SNAPSHOT_NAME}
dos.py resume ${ENV_NAME}
