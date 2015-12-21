#!/bin/bash -xe

# Installs Rally (https://wiki.openstack.org/wiki/Rally)
# an run tests from Mirantis mos-scale lab.
# Make sure user that runs this script has ssh key configured to access gerrit.mirantis.com.
#
# FIXME: exit code should reflect success/failure of Rally tests (currently always SUCCESS)
#
# (c) mzawadzki@mirantis.com

RALLY_START_AT=`date -u +%s`

source functions/resources.sh
import_config ${1}

# CONFIGURATION:
######################################################
# default options:
INSTALL_RALLY=true

export FUEL_IP=${vm_master_ip:-localhost}
FUEL_VERSION=`python -c 'from componentspython import nailgun; nailgun.return_job_parameters()' ${environment_settings} ${FUEL_IP} milestone 2>/dev/null`
FUEL_BUILD=`python -c   'from componentspython import nailgun; nailgun.return_job_parameters()' ${environment_settings} ${FUEL_IP} iso       2>/dev/null`

ISO_NAME="${FUEL_VERSION}-${FUEL_BUILD}"

NETWORK_ISOLATION=`python -c 'from sys import argv; from componentspython import nailgun_client as fuel; print fuel.NailgunClient(argv[1]).get_networks(fuel.NailgunClient(argv[1]).list_clusters()[0]["id"])["networking_parameters"]["segmentation_type"]' ${FUEL_IP} 2>/dev/null`

DEFAULT_OPENRC_PATH=${PWD}"/openrc"
OPENRC_PATH=${DEFAULT_OPENRC_PATH}

MOS_SCALE_RALLY_TEMPLATE_VALUES_BASE='"compute": 1, "concurrency" : 1, "current_path": "mos-scenarios/rally-scenarios/heat", "vlan_amount": 1'
MOS_SCALE_RALLY_TEMPLATE_VALUES_GRE_ENABLED='"gre_enabled": true'
MOS_SCALE_RALLY_TEMPLATE_VALUES_GRE_DISABLED='"gre_enabled": false'
MOS_SCALE_RALLY_TEMPLATE_VALUES="{"${MOS_SCALE_RALLY_TEMPLATE_VALUES_BASE}"}"
if [ "${NETWORK_ISOLATION}" = "gre" ]; then
    MOS_SCALE_RALLY_TEMPLATE_VALUES="{"${MOS_SCALE_RALLY_TEMPLATE_VALUES_BASE}", "${MOS_SCALE_RALLY_TEMPLATE_VALUES_GRE_ENABLED}"}"
else
    MOS_SCALE_RALLY_TEMPLATE_VALUES="{"${MOS_SCALE_RALLY_TEMPLATE_VALUES_BASE}", "${MOS_SCALE_RALLY_TEMPLATE_VALUES_GRE_DISABLED}"}"
fi


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
export OS_AUTH_URL='http://`python -c "from componentspython import nailgun; nailgun.return_controller_ip()" ${environment_settings} ${FUEL_IP} 2>/dev/null`:5000/v2.0'
EOF

# Helper functions:
function usage {
    cat <<EOF
Usage: $0 [OPTION]
Install, configure and run Rally on scenarios from mos-scenarios repo.
Options:
--help               print usage and exit
--no-rally-install   skip Rally installation, assume it's available
--openrc=STRING      custom openrc path for a cloud that Rally should run
                     tests against (default: ${OPENRC_PATH})
--network-isolation=STRING
                     adjust Rally scenarios to specific network isolation
                     methods (e.g. "gre" or "vlan")
--iso-name=STRING    store the information in the report about ISO used to
                     deploy cloud
EOF
    exit
}

function exit_script {
    echo ${1} >&2
    exit 1
}


# Parse command-line options:
OPTS=`getopt -o '' --long help,no-rally-install,openrc:,network-isolation:,iso-name: -n 'parse-options' -- ${@}`
if [ ${?} != 0 ] ; then
    exit_script "Failed parsing options."
fi
eval set -- ${OPTS}

while true; do
case ${1} in
--help ) usage; shift ;;
--no-rally-install ) INSTALL_RALLY=false; shift ;;
--openrc ) OPENRC_PATH=${2}; shift; shift ;;
--network-isolation ) NETWORK_ISOLATION=${2}; shift; shift ;;
--iso-name ) ISO_NAME=${2}; shift; shift ;;
-- ) shift; break ;;
* ) break ;;
esac
done


# Prepare environment:
WORKING_DIR=${PWD}"/simple_rally"
LOGS_DIR=${PWD}"/logs"
test -d ${WORKING_DIR} && rm -rf ${WORKING_DIR}
mkdir -p ${WORKING_DIR}
cd ${WORKING_DIR}
mkdir tmp
if [[ -z $(grep gerrit.mirantis.com ~/.ssh/known_hosts) ]]; then
    ssh-keyscan -p 29418 gerrit.mirantis.com >> ~/.ssh/known_hosts
fi
git clone ssh://gerrit.mirantis.com:29418/mos-scale/mos-scale.git
git clone ssh://gerrit.mirantis.com:29418/mos-scale/mos-scenarios.git
# Decrease number of iterations in scenario Authenticate.keystone
sed -ri 's|10000|100|' mos-scenarios/rally-scenarios/keystone/token-create-and-use-for-auth.yaml
# Fix path to script in scenario VMTasks.boot_runcommand_delete
sed -ri 's|/opt/stack/rally-scenarios|mos-scenarios/rally-scenarios|' mos-scenarios/rally-scenarios/vm/boot_runcommand_delete.yaml

if [ ${INSTALL_RALLY} == "true" ]; then
    git clone https://git.openstack.org/openstack/rally tmp/rally
    cd tmp/rally
    # Switch branch to the latest release (as done by MOS-Scale team):
    RALLY_VERSION=`git tag -l [0-9].[0-9].[0-9] | sort -n | tail -1`
    git checkout ${RALLY_VERSION}
    ./install_rally.sh -y -d ${WORKING_DIR}/rally
    RALLY_RUN_CMD=${WORKING_DIR}"/rally/bin/rally"
else
    RALLY_RUN_CMD="rally"
fi
${RALLY_RUN_CMD} --version
cd ${WORKING_DIR}
sed -n '/^prepare_cloud_for_rally()/,/}/p' mos-scale/deploy/deploy_tests/deploy_rally/deploy_rally.sh > prepare_cloud_for_rally.sh
source ${OPENRC_PATH}
bash prepare_cloud_for_rally.sh
# FIXME: this should be done at mos-scale, see: https://gerrit.mirantis.com/#/c/44961/
nova flavor-create m1.nano 41 64 0 1 || :
${RALLY_RUN_CMD}-manage db recreate
${RALLY_RUN_CMD} deployment create --fromenv --name=existing
${RALLY_RUN_CMD} deployment check
mkdir ~/.rally/plugins
cp mos-scale/deploy/deploy_tests/deploy_rally/rally_plugins/* ~/.rally/plugins/


find mos-scenarios/rally-scenarios -name '*.yaml' -o -name '*.json' | sort | while read SCENARIO; do
    ${RALLY_RUN_CMD} task start --abort-on-sla-failure --task-args "${MOS_SCALE_RALLY_TEMPLATE_VALUES}" --task ${SCENARIO}
done

# Collect Rally results:
TASK_LIST=`${RALLY_RUN_CMD} task list --uuids-only 2> /dev/null | tr "\n" " "`
RESULT_FILENAME="rally_report_mosi_mos-scenarios_all_ISO_"${ISO_NAME}"_`date +'%Y-%m-%d_%H-%M-%S'`_"${RANDOM}".html"
${RALLY_RUN_CMD} task report --out ${RESULT_FILENAME} --tasks ${TASK_LIST}
cp ${RESULT_FILENAME} ${LOGS_DIR}

# Print time of Rally tests
RALLY_FINISH_AT=`date -u +%s`
RALLY_DURATION=$(( ${RALLY_FINISH_AT} - ${RALLY_START_AT} ))
H=$(( ${RALLY_DURATION}/3600 ))             # Hours
M=$(( ${RALLY_DURATION}%3600/60 ))          # Minutes
S=$(( ${RALLY_DURATION}-${H}*3600-${M}*60)) # Seconds

printf "Rally tests took %02d:%02d:%02d\n" ${H} ${M} ${S}

# Skip testrail if  TESTRAIL_SEND set to 0 (default 1)
# or TESTRAIL_SKIP set to 1 (default 0)
if [ ${TESTRAIL_SEND:-1} -ne 1 -o ${TESTRAIL_SKIP:-0} -ne 0 ]; then
    exit 0
fi

# Activate virtualenv
source ~/rally/bin/activate

# Post data to TestRail and don't fail on error
python componentspython/testrail_send.py || :
