#!/bin/bash -xe

source functions/resources.sh
import_config ${1}

# Import MOS info
test -f mos_version.env && source mos_version.env
export CUSTOM_JOB ISO_PREFIX
export MOS_VERSION MOS_BUILD

# If set of tests (MOS project) is unset (i.e. run all tests), run Rally by parameter
# set in sourced above functions/resources.sh
# Note! import_config is required!
if [ -z "${MOS_PROJECT}" ]; then
    if ! ${USE_RALLY}; then
        exit 0
    fi
fi

RALLY_START_AT=$(date -u +%s)

RALLY_VERSION=0.0.4

FUEL_IP=${vm_master_ip:-localhost}
if [ -n "${MOS_VERSION}" ]; then
    FUEL_VERSION=${MOS_VERSION}
else
    FUEL_VERSION=`python -c 'from componentspython import nailgun; nailgun.return_job_parameters()' ${environment_settings} ${FUEL_IP} milestone 2>/dev/null`
fi
if [ -n "${MOS_BUILD}" ]; then
    FUEL_BUILD=${MOS_BUILD}
else
    FUEL_BUILD=`python -c   'from componentspython import nailgun; nailgun.return_job_parameters()' ${environment_settings} ${FUEL_IP} iso       2>/dev/null`
fi

ISO_NAME="${FUEL_VERSION}-${FUEL_BUILD}"

NETWORK_ISOLATION=`python -c 'from sys import argv; from componentspython import nailgun_client as fuel; print fuel.NailgunClient(argv[1]).get_networks(fuel.NailgunClient(argv[1]).list_clusters()[0]["id"])["networking_parameters"]["segmentation_type"]' ${FUEL_IP} 2>/dev/null`

### Storage options
get_storage_option() {
    python -c 'from sys import argv; from componentspython import nailgun_client as fuel; print str(fuel.NailgunClient(argv[1]).get_cluster_attributes(fuel.NailgunClient(argv[1]).list_clusters()[0]["id"])["editable"]["storage"].get(argv[2], None)["value"]).lower()' ${1} ${2} 2> /dev/null
}

VOLUMES_LVM=`get_storage_option ${FUEL_IP} volumes_lvm`

DEFAULT_OPENRC_PATH=${PWD}"/openrc"
OPENRC_PATH=${DEFAULT_OPENRC_PATH}

MOS_SCALE_RALLY_TEMPLATE_VALUES_BASE='"compute": 1, "concurrency" : 1, "current_path": "mos-scenarios/rally-scenarios/heat", "vlan_amount": 1'
MOS_SCALE_RALLY_TEMPLATE_VALUES_GRE_ENABLED='"gre_enabled": true'
MOS_SCALE_RALLY_TEMPLATE_VALUES_GRE_DISABLED='"gre_enabled": false'
if [ "${NETWORK_ISOLATION}" = "gre" ]; then
    MOS_SCALE_RALLY_TEMPLATE_VALUES="{${MOS_SCALE_RALLY_TEMPLATE_VALUES_BASE}, ${MOS_SCALE_RALLY_TEMPLATE_VALUES_GRE_ENABLED}}"
else
    MOS_SCALE_RALLY_TEMPLATE_VALUES="{${MOS_SCALE_RALLY_TEMPLATE_VALUES_BASE}, ${MOS_SCALE_RALLY_TEMPLATE_VALUES_GRE_DISABLED}}"
fi

# space separated list of json/yaml files that should be skipped when running tests:
MOS_SCENARIOS_TO_SKIP="token-create-and-use-for-auth.yaml"
######################################################

LOGS_DIR=${PWD}"/logs"
test -d ${LOGS_DIR} || mkdir ${LOGS_DIR}

keystone_proto=$(python -c 'from componentspython import nailgun; print nailgun.keystone_proto()' ${environment_settings} ${FUEL_IP} 2>/dev/null)
keystone_addr=$(python -c 'from componentspython import nailgun; nailgun.return_controller_ip()'  ${environment_settings} ${FUEL_IP} 2>/dev/null)

test -f ${DEFAULT_OPENRC_PATH} || cat > ${DEFAULT_OPENRC_PATH} <<EOF
export OS_NO_CACHE='true'
export OS_TENANT_NAME='admin'
export OS_USERNAME='admin'
export OS_PASSWORD='admin'
export OS_AUTH_STRATEGY='keystone'
export OS_REGION_NAME='RegionOne'
export CINDER_ENDPOINT_TYPE='publicURL'
export GLANCE_ENDPOINT_TYPE='publicURL'
export KEYSTONE_ENDPOINT_TYPE='publicURL'
export NOVA_ENDPOINT_TYPE='publicURL'
export NEUTRON_ENDPOINT_TYPE='publicURL'
export OS_ENDPOINT_TYPE='publicURL'
export MURANO_REPO_URL='http://catalog.openstack.org/'
export OS_AUTH_URL='${keystone_proto}://${keystone_addr}:5000/v2.0'
EOF

# Prepare home directory for Rally container
tmp_dir=`mktemp -d`
mkdir ${tmp_dir}/rally_home

# Python code
cp -r componentspython ${tmp_dir}/rally_home/

pushd ${tmp_dir}/rally_home

# Get scripts from Scale lab
git clone ssh://gerrit.mirantis.com:29418/mos-scale/mos-scale.git

# Get Rally scenarios
git clone ssh://gerrit.mirantis.com:29418/mos-scale/mos-scenarios.git

# Fix some scenarios
# Decrease number of iterations in scenario Authenticate.keystone
sed -ri 's|10000|100|' mos-scenarios/rally-scenarios/keystone/token-create-and-use-for-auth.yaml
# Fix path to script in scenario VMTasks.boot_runcommand_delete
sed -ri 's|/opt/stack/rally-scenarios|mos-scenarios/rally-scenarios|' mos-scenarios/rally-scenarios/vm/boot_runcommand_delete.yaml
# Skip live migration testing if Cinder LVM (iSCSI) is not used
if ! ${VOLUMES_LVM}; then
    rm -f mos-scenarios/rally-scenarios/nova/boot_and_live_migrate_server.yaml
    rm -f mos-scenarios/rally-scenarios/nova/boot_server_attach_created_volume_and_live_migrate.yaml
fi
# Use only one set of Sahara scenarios basing on MOS version
# First - split scenarios by version
SCENARIO_PRE70=""
SCENARIO_POST70=""
for scenario in `find mos-scenarios/rally-scenarios/sahara/ -type f -name "*.json" -o -name "*.yaml"`; do
    scenario_name=${scenario%.*}
    scenario_no_version=${scenario_name%_7_0}
    if [ "${scenario_name}" = "${scenario_no_version}" ]; then
        SCENARIO_PRE70="${SCENARIO_PRE70} ${scenario}"
    else
        SCENARIO_POST70="${SCENARIO_POST70} ${scenario}"
    fi
done
# Second - remove unneeded scenarios
MOS_NUMVERSION=`echo ${FUEL_VERSION:-0} | awk '{split($0, V, /\./); printf("%d%02d%02d", V[1], V[2], V[3])}'`
if [ ${MOS_NUMVERSION} -ge 70000 ]; then
    rm -f ${SCENARIO_PRE70}
else
    rm -f ${SCENARIO_POST70}
fi

# Cut script for preparing cluster
sed -n '/^prepare_cloud_for_rally()/,/}/p' mos-scale/deploy/deploy_tests/deploy_rally/deploy_rally.sh > prepare_cloud_for_rally.sh

# Copy Rally plugins
mkdir -p .rally/plugins
cp -r mos-scale/deploy/deploy_tests/deploy_rally/rally_plugins/* .rally/plugins/
rm -rf mos-scale

# Copy openrc
cp ${DEFAULT_OPENRC_PATH} .
popd

# Send directory to Fuel master
cd ${tmp_dir}
tar -cf - rally_home | sshpass -p r00tme ssh root@${FUEL_IP} tar -xf -
cd -
# ... and remove it
rm -rf ${tmp_dir}

SHARED_IMAGES_PATH=/home/jenkins/images
if [ -f ${SHARED_IMAGES_PATH}/rally-${RALLY_VERSION}.tar ]; then
    sshpass -p r00tme ssh root@${FUEL_IP} docker load < ${SHARED_IMAGES_PATH}/rally-${RALLY_VERSION}.tar
else
sshpass -p r00tme ssh root@${FUEL_IP} <<SSHPREP
# Download rally container
docker pull rallyforge/rally:${RALLY_VERSION}
# Fix failing cinder scenario for nested snapshots (not needed for Rally > 0.0.4)
docker run -i --name=rally --user=root rallyforge/rally:${RALLY_VERSION} <<RALLY_ROOT
sed -ri '344 a\        size = random.randint(size["min"], size["max"])\n' /usr/local/lib/python2.7/dist-packages/rally/benchmark/scenarios/cinder/volumes.py
RALLY_ROOT
# Commit fix to image
docker commit rally rallyforge/rally:${RALLY_VERSION}
# Remove container
docker rm -vf rally
SSHPREP
fi

sshpass -p r00tme ssh root@${FUEL_IP} <<SSH
chown -R 65500 ~/rally_home
# Run rally in prepared container
docker run --net=host -i --user=rally -v ~/rally_home:/home/rally rallyforge/rally:${RALLY_VERSION} <<RALLY
set -x
echo "Use Rally version \\\$(rally --version)"
source ~/openrc
rally-manage db recreate
bash -xe ~/prepare_cloud_for_rally.sh
nova flavor-create m1.nano 41 64 0 1 || :
rally deployment create --fromenv --name="Deployment test"
rally deployment check
find mos-scenarios/rally-scenarios/${MOS_PROJECT} -name '*.yaml' -o -name '*.json' | sort | while read SCENARIO; do
    rally task start --abort-on-sla-failure --task-args "${MOS_SCALE_RALLY_TEMPLATE_VALUES}" --task \\\${SCENARIO}
done

rally task report --out rally.html --tasks \\\$(rally task list --uuids-only 2> /dev/null | tr "\n" " ")

# Print time of Rally tests
RALLY_FINISH_AT=\\\$(date -u +%s)
RALLY_DURATION=\\\$(( \\\${RALLY_FINISH_AT} - ${RALLY_START_AT} ))
H=\\\$(( \\\${RALLY_DURATION}/3600 ))             # Hours
M=\\\$(( \\\${RALLY_DURATION}%3600/60 ))          # Minutes
S=\\\$(( \\\${RALLY_DURATION}-\\\${H}*3600-\\\${M}*60)) # Seconds

printf "Rally tests took %02d:%02d:%02d\n" \\\${H} \\\${M} \\\${S}

# Skip send report to TestRail by parameter set in sourced above functions/resources.sh
# Note! import_config is required!
if ! ${USE_TESTRAIL}; then
    exit 0
fi

# Fuel master IP address or resolvable hostname
export FUEL_IP=${FUEL_IP}

# Jenkins job info
export JOB_NAME=${JOB_NAME}
export BUILD_NUMBER=${BUILD_NUMBER}
export BUILD_URL=${BUILD_URL}

# TestRail credentials
export TESTRAIL_USER=${TESTRAIL_USER}
export TESTRAIL_PASSWORD=${TESTRAIL_PASSWORD}

# MOS version
export MOS_VERSION=${MOS_VERSION}
export MOS_BUILD=${MOS_BUILD}

# Install required package(s)
pip install --user --upgrade jenkinsapi

# Post data to TestRail and don't fail on error
python componentspython/testrail_send.py || :
RALLY
SSH

sshpass -p r00tme scp root@${FUEL_IP}:~/rally_home/rally.html "${LOGS_DIR:-.}/rally_report_mosi_mos-scenarios_${MOS_PROJECT:-all}_ISO_${ISO_NAME}_`date +'%Y-%m-%d_%H-%M-%S'`_${RANDOM}.html"
