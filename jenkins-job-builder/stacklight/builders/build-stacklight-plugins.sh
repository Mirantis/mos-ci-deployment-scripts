#!/bin/bash
#
#   :mod: `build-stacklight-plugins.sh` -- Build the StackLight plugins
#   ===================================================================
#
#   .. module:: build-stacklight-plugins.sh
#       :platform: Unix
#       :synopsis: Script used to build the StackLight plugins
#   .. vesionadded:: MOS-9.0
#   .. vesionchanged:: MOS-9.0
#   .. author:: Simon Pasquier <spasquier@mirantis.com>
#
#
#   This script is used to build the StackLight plugins as well as their
#   dependencies such as detach-database and detach-rabbitmq.
#
#
#   .. envvar::
#       :var  PLUGINS_DIR: Path to the base directory containing the plugins
#       :type PLUGINS_DIR: path
#
#   .. requirements::
#
#       * slave with hiera enabled:
#           fuel_project::jenkins::slave::build_fuel_packages: true
#
#
#   .. affects::
#       :file stacklight-build.jenkins-injectfile: file holding variables used
#       by the deployment job
#

# Generate description for the job
echo "Description string: $TESTRAIL_ENV_DESCRIPTION.$(date +%m/%d/%Y)"

# Source system variables with correct Ruby settings,
# include before "set" to skip not required messages
source /etc/profile

set -ex

# Setup a virtual environment and install fpb
rm -rf "${WORKSPACE}"/venv_fpb
virtualenv "${WORKSPACE}"/venv_fpb
source "${WORKSPACE}"/venv_fpb/bin/activate

pip install "${WORKSPACE}"/fuel-plugins/

function build_plugin {
    eval val=\$$2
    if [[ ! "$val" ]]; then
        fpb --debug --build  "${PLUGINS_DIR}/$1"
    fi
}

function get_fullpath {
    ls "${PLUGINS_DIR}/$1/"*.rpm
}

# Build all the plugins necessary for testing the StackLight toolchain
build_plugin fuel-plugin-elasticsearch-kibana ELASTICSEARCH_KIBANA_PATH
build_plugin fuel-plugin-influxdb-grafana INFLUXDB_GRAFANA_PATH
build_plugin fuel-plugin-lma-infrastructure-alerting LMA_INFRA_ALERTING_PATH
build_plugin fuel-plugin-lma-collector LMA_COLLECTOR_PATH
build_plugin fuel-plugin-detach-database DETACH_DATABASE_PATH
build_plugin fuel-plugin-detach-rabbitmq DETACH_RABBITMQ_PATH

cat > "${ENV_INJECT_PATH}" << EOF
ELASTICSEARCH_KIBANA_PLUGIN_PATH=${ELASTICSEARCH_KIBANA_PATH:-$(get_fullpath fuel-plugin-elasticsearch-kibana)}
INFLUXDB_GRAFANA_PLUGIN_PATH=${INFLUXDB_GRAFANA_PATH:-$(get_fullpath fuel-plugin-influxdb-grafana)}
LMA_INFRA_ALERTING_PLUGIN_PATH=${LMA_INFRA_ALERTING_PATH:-$(get_fullpath fuel-plugin-lma-infrastructure-alerting)}
LMA_COLLECTOR_PLUGIN_PATH=${LMA_COLLECTOR_PATH:-$(get_fullpath fuel-plugin-lma-collector)}
DETACH_DATABASE_PLUGIN_PATH=${DETACH_DATABASE_PATH:-$(get_fullpath fuel-plugin-detach-database)}
DETACH_RABBITMQ_PLUGIN_PATH=${DETACH_RABBITMQ_PATH:-$(get_fullpath fuel-plugin-detach-rabbitmq)}
EOF
