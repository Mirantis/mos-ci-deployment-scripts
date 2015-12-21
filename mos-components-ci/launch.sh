#!/bin/bash

#    Copyright 2014 Mirantis, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

source functions/resources.sh
import_config ${1}

# Log parameters
LOGGING_PATH=${LOGGING_PATH:-"logs/"}
LOG_NAME=${LOG_NAME:-"log.txt"}

ISO_GRABBER_LOGGING_PATH=${ISO_GRABBER_LOGGING_PATH:-"${LOGGING_PATH}"}
ISO_GRABBER_LOG_NAME=${ISO_GRABBER_LOG_NAME:-"iso_grabber_log.txt"}

PREPARE_ENV_LOGGING_PATH=${PREPARE_ENV_LOGGING_PATH:-"${LOGGING_PATH}"}
PREPARE_ENV_LOG_NAME=${PREPARE_ENV_LOG_NAME:-"prepare_env_log.txt"}

NAILGUN_LOGGING_PATH=${NAILGUN_LOGGING_PATH:-"${LOGGING_PATH}"}
NAILGUN_LOG_NAME=${NAILGUN_LOG_NAME:-"nailgun_log.txt"}

CONFIGURE_ENV_LOGGING_PATH=${CONFIGURE_ENV_LOGGING_PATH:-"${LOGGING_PATH}"}
CONFIGURE_ENV_LOG_NAME=${CONFIGURE_ENV_LOG_NAME:-"configure_env_log.txt"}

export LOG="${LOGGING_PATH}${LOG_NAME}"
export PREPARE_ENV_LOG="${PREPARE_ENV_LOGGING_PATH}${PREPARE_ENV_LOG_NAME}"
export ISO_GRABBER_LOG="${ISO_GRABBER_LOGGING_PATH}${ISO_GRABBER_LOG_NAME}"
export NAILGUN_LOG="${NAILGUN_LOGGING_PATH}${NAILGUN_LOG_NAME}"
export CONFIGURE_ENV_LOG="${CONFIGURE_ENV_LOGGING_PATH}${CONFIGURE_ENV_LOG_NAME}"

rm ./*.txt &> /dev/null
rm ./*.log &> /dev/null
if [ -n "${LOGGING_PATH}" -a -d "${LOGGING_PATH}" ]; then
    sudo rm -rf ${LOGGING_PATH}
fi
mkdir ${LOGGING_PATH}
touch ${LOG}
chmod 666 ${LOG}

# display motd for worker
test ! -f ~/worker_motd.sh || ~/worker_motd.sh

# Print variables
echo "######################################################"
test -z "${MOS_VERSION}" || echo "MOS_VERSION=${MOS_VERSION}"
test -z "${MOS_BUILD}" || echo "MOS_BUILD=${MOS_BUILD}"
test -z "${CUSTOM_JOB}" || echo "MOS_BUILD=${CUSTOM_JOB}"
test -z "${ZUUL_PROJECT}" || echo "ZUUL_PROJECT=${ZUUL_PROJECT}"
echo "######################################################"

#   Prepare the host system
./actions/prepare-environment.sh
check_return_code_after_command_execution $? "prepare environment is failed."

# Import MOS info
test -f mos_version.env && source mos_version.env
export CUSTOM_JOB ISO_PREFIX
export MOS_VERSION MOS_BUILD

# Create and use python virtualenv
virtualenv
check_return_code_after_command_execution $? "Create virtualenv is failed."

#   Create and launch master node
./actions/master-node-create-and-install.sh
check_return_code_after_command_execution $? "Create or install master node is failed."

#   Create and launch slave nodes
./actions/slave-nodes-create-and-boot.sh
check_return_code_after_command_execution $? "Create or boot worker nodes is failed."

#   Create and deploy environment
./actions/deploy_env.sh
check_return_code_after_command_execution $? "Create of deploy OpenStack environment is failed."

#   Save environment ip
env_ip=$(controller_ip "${environment_settings}" "${vm_master_ip}")
check_return_code_after_command_execution $? "IP of OpenStack environment not obtained."

#   Add Savanna ISO for tests
./actions/add_iso_to_glance.sh ${env_ip}
check_return_code_after_command_execution $? "Images not uploaded on OpenStack or security groups not configured."
