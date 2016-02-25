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

patch_fuel_qa(){
    # Check and apply patch to fuel_qa
    set +e
    file_name=$1
    patch_file=../fuel_qa_patches/$file_name
    echo "Check for patch $file_name"
    git apply --check $patch_file 2> /dev/null
    if [ $? -eq 0 ]; then
        echo "Applying patch $file_name"
        git apply $patch_file
    fi
    set -e
}

set_default(){
    eval val=\$$1

    if [ -z ${val} ]; then
        eval $1=$2
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
# COMPUTE_COUNT can be from 1 to 3 (default value 2)
COMPUTES_COUNT=$(digit_from_range 'COMPUTES_COUNT' 0 3 2)
# IRONICS_COUNT can be from 1 to 3 (default value 0)
IRONICS_COUNT=$(digit_from_range 'IRONICS_COUNT' 0 3 0)
# SEPARATE_SERVICES_COUNT can be from 0 to 3 (default value 0)
SEPARATE_SERVICES_COUNT=$(digit_from_range 'SEPARATE_SERVICES_COUNT' 0 3 0)

# check that we have enough nodes
TOTAL_NODES_COUNT=$(($CONTROLLERS_COUNT + $COMPUTES_COUNT + $IRONICS_COUNT + $SEPARATE_SERVICES_COUNT))

# add slaves to mos_tests_template.yaml config
cp mos_tests_template.yaml mos_tests.yaml
for i in `seq 1 $TOTAL_NODES_COUNT`
do
    num=`printf "%02d" $i`
    echo "    - name: slave-${num}" >> mos_tests.yaml
    echo "      role: fuel_slave" >> mos_tests.yaml
    echo "      params: *rack-01-controller-node-params" >> mos_tests.yaml
done

# replace vars with its values in config files
for var in TOTAL_NODES_COUNT CONTROLLERS_COUNT COMPUTES_COUNT IRONICS_COUNT SEPARATE_SERVICES_COUNT
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
BOOL_VARS="L2_POP_ENABLE DVR_ENABLE L3_HA_ENABLE SAHARA_ENABLE MURANO_ENABLE CEILOMETER_ENABLE IRONIC_ENABLE RADOS_ENABLE CEPH_GLANCE_ENABLE"
SEPARATE_SERVICES="SEPARATE_SERVICE_RABBIT_ENABLE SEPARATE_SERVICE_DB_ENABLE SEPARATE_SERVICE_KEYSTONE_ENABLE"
for var in $BOOL_VARS $SEPARATE_SERVICES
do
    eval $var=$(boolean $var)
done
# Note: some params should be processed separately as
# they should be uncommented in config (not set to true or false as other)
MONGO_ENABLE=$(boolean 'MONGO_ENABLE')
CINDER_ENABLE=$(boolean 'CINDER_ENABLE')
# block storage (one of CEPH or LVM should be true)
CEPH_ENABLE=$(boolean 'CEPH_ENABLE')
LVM_ENABLE=$(boolean 'LVM_ENABLE')

# check limitations
# storage limitations
if [ ${CEPH_ENABLE} == 'true' ]; then
    if [ ${LVM_ENABLE} == 'true' ]; then
        echo "Error: variables CEPH_ENABLE and LVM_ENABLE can't be TRUE simultaniously."
        exit 1
    fi
elif [ ${LVM_ENABLE} != 'true' ]; then
    # LVM and CEPH hasn't been set up so we should set default value
    echo "lvm-volume will be used by default."
    LVM_ENABLE='true'
fi

if [ ${RADOS_ENABLE} == 'true' ] && [ ${CEPH_ENABLE} != 'true' ]; then
    echo "Please set env variable CEPH_ENABLE to 'TRUE' if you want to use RADOS."
    exit 1
fi

if [ ${CEPH_GLANCE_ENABLE} == 'true' ] && [ ${CEPH_ENABLE} != 'true' ]; then
    echo "Please set env variable CEPH_ENABLE to 'TRUE' if you want to use Ceph to Glance."
    exit 1
fi

# network limitations
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

# additional components limitations
if [ ${CEILOMETER_ENABLE} == 'true' ] && [ ${MONGO_ENABLE} != 'true' ]; then
    echo "Please set env variable MONGO_ENABLE to 'TRUE' if you want to use CEILOMETER."
    exit 1
fi

if [ ${IRONIC_ENABLE} == 'true' ]; then
    if [ ${SEGMENT_TYPE} != 'vlan' ]; then
        echo "Please set env variable SEGMENT_TYPE to 'VLAN' if you want to use IRONIC."
        exit 1
    fi
    if [ ${IRONICS_COUNT} -eq 0 ]; then
        echo "Please set env variable IRONICS_COUNT not to 0 if you want to use IRONIC."
        exit 1
    fi
fi

if [ ${IRONICS_COUNT} -gt 0 ] && [ ${IRONIC_ENABLE} != 'true' ]; then
    echo "Please set env variable IRONIC_ENABLE to 'TRUE' if you want to use IRONIC nodes."
    exit 1
fi

# plugins limitations
if [ ${SEPARATE_SERVICE_RABBIT_ENABLE} == 'true' ] && [ -z ${SEPARATE_SERVICE_RABBIT_PLUGIN_PATH} ]; then
    echo "Please set env variable SEPARATE_SERVICE_RABBIT_PLUGIN_PATH if you want to use SEPARATE_SERVICE_RABBIT."
    exit 1
fi

if [ ${SEPARATE_SERVICE_DB_ENABLE} == 'true' ] && [ -z ${SEPARATE_SERVICE_DB_PLUGIN_PATH} ]; then
    echo "Please set env variable SEPARATE_SERVICE_DB_PLUGIN_PATH if you want to use SEPARATE_SERVICE_DB."
    exit 1
fi

if [ ${SEPARATE_SERVICE_KEYSTONE_ENABLE} == 'true' ]; then
    if [ -z ${SEPARATE_SERVICE_KEYSTONE_PLUGIN_PATH} ]; then
        echo "Please set env variable SEPARATE_SERVICE_KEYSTONE_PLUGIN_PATH if you want to use SEPARATE_SERVICE_KEYSTONE."
        exit 1
    elif [ ${SEPARATE_SERVICE_DB_ENABLE} != 'true' ]; then
        echo "Please set env variable SEPARATE_SERVICE_DB_ENABLE to 'TRUE' if you want to use SEPARATE_SERVICE_KEYSTONE."
        exit 1
    fi
fi

# set dependent vars
if [ ${LVM_ENABLE} == 'true' ]; then
    CINDER_ENABLE='true'
fi

# replace vars with its values in config files
for var in SEGMENT_TYPE $BOOL_VARS CEPH_ENABLE
do
    eval value=\$$var
    # replace variable in config with its value
    sed -i -e "s/<%${var}%>/${value}/g" ${CONFIG_NAME}
    if [ ${value} == 'true' ]; then
         # Add the name of var without word '_ENABLE' to snapshot name
         SNAPSHOT_NAME="${SNAPSHOT_NAME}_$(echo ${var} | sed 's/_ENABLE//')"
    fi
done

# replace LVM var with its value in config without adding it to snapshot name
sed -i -e "s/<%LVM_ENABLE%>/${LVM_ENABLE}/g" ${CONFIG_NAME}

# uncomment some roles if it is required
if [ ${CEPH_ENABLE} == 'true' ]
then
    sed -i -e "s/# - ceph-osd/- ceph-osd/" ${CONFIG_NAME}
fi

if [ ${MONGO_ENABLE} == 'true' ]
then
    sed -i -e "s/# - mongo/- mongo/" ${CONFIG_NAME}
    SNAPSHOT_NAME="${SNAPSHOT_NAME}_MONGO"
fi

if [ ${CINDER_ENABLE} == 'true' ]
then
    sed -i -e "s/# - cinder/- cinder/" ${CONFIG_NAME}
    SNAPSHOT_NAME="${SNAPSHOT_NAME}_CINDER"
fi

if [ ${SEPARATE_SERVICE_RABBIT_ENABLE} == 'true' ]
then
    sed -i -e "s/# - standalone-rabbitmq/- standalone-rabbitmq/" ${CONFIG_NAME}
    SNAPSHOT_NAME="${SNAPSHOT_NAME}_RABBITMQ"
fi

if [ ${SEPARATE_SERVICE_DB_ENABLE} == 'true' ]
then
    sed -i -e "s/# - standalone-database/- standalone-database/" ${CONFIG_NAME}
    SNAPSHOT_NAME="${SNAPSHOT_NAME}_DATABASE"
fi

if [ ${SEPARATE_SERVICE_KEYSTONE_ENABLE} == 'true' ]
then
    sed -i -e "s/# - standalone-keystone/- standalone-keystone/" ${CONFIG_NAME}
    SNAPSHOT_NAME="${SNAPSHOT_NAME}_KEYSTONE"
fi

# Set fuel QA version
# https://github.com/openstack/fuel-qa/branches
set_default FUEL_QA_VER 'stable/8.0'

# Erase all previous environments by default
set_default ERASE_PREV_ENV true

V_ENV_DIR="`pwd`/fuel-devops-venv"

# set ENV_NAME if it is not defined
set_default ENV_NAME "Test_Deployment_MOS_CI_$RANDOM"
set_default USE_KVM true

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
    git checkout -- system_test/__init__.py
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

if [ -z ${PLUGINS_CONFIG_PATH} ]; then
    # set the path to plugins with default value"
    export PLUGINS_CONFIG_PATH=$(pwd)/plugins.yaml
fi

cp __init__.py fuel-qa/system_test/
cp deploy_env.py fuel-qa/system_test/tests/
cp mos_tests.yaml fuel-qa/system_test/tests_templates/devops_configs/
cp ${CONFIG_NAME} fuel-qa/system_test/tests_templates/tests_configs

cd fuel-qa

# Apply fuel-qa patches
if [ ${IRONIC_ENABLE} == 'true' ]; then
    patch_fuel_qa ironic.patch
fi

if [ ${DVR_ENABLE} == 'true' ] || [ ${L3_HA_ENABLE} == 'true' ] || [ ${L2_POP_ENABLE} == 'true' ]; then
    patch_fuel_qa DVR_L2_pop_HA.patch
fi

if [ ${INTERFACE_MODEL} == 'virtio' ]; then
    # Virtio network interfaces have names eth0..eth5
    # (rather than default names - enp0s3..enp0s8)
    patch_fuel_qa virtio.patch
    for i in {0..5}; do
        export IFACE_$i=eth$i
    done
fi

# erase previous environments
if [ ${ERASE_PREV_ENV} == true ]; then
    for i in `dos.py list | grep MOS`; do dos.py erase $i; done
fi

# create new environment
# more time can be required to deploy env
set_default DEPLOYMENT_TIMEOUT 10000

./utils/jenkins/system_tests.sh -k -K -j fuelweb_test -t test -V ${V_ENV_DIR} -w $(pwd) -o --group="system_test.deploy_env($GROUP_NAME)"

# make snapshot if deployment is successful
dos.py suspend ${ENV_NAME}
dos.py snapshot ${ENV_NAME} ${SNAPSHOT_NAME}
dos.py resume ${ENV_NAME}

