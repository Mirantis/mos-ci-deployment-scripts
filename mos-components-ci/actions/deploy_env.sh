#!/bin/bash -e

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

#
# This script deploys Fuel environment and if necessary and env has error state
# added all tempest result with fail status to testrail
#

source functions/resources.sh
import_config ${1}

test -f mos_version.env && source mos_version.env

set +e
deploy_cluster ${environment_settings} ${vm_master_ip} ${kvm_nodes_count} ${mashines_count}
exit_code=$?
set -e

if [ "${exit_code}" != "0" -a "${ZUUL_PIPELINE}" == "periodic-deploy" -a "${USE_TESTRAIL}" == "true" ]; then
    testrail_results "deploy_failed"
fi
exit ${exit_code}
