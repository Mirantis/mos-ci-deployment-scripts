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
# This script runs specific tests(tempest/scenario) for any project if gate job
# or runs all tempest tests if project not specified or if periodic job.
#


source functions/product.sh
source functions/resources.sh
import_config ${1}

test -f mos_version.env && source mos_version.env

INSTALL_MOS_TEMPEST_RUNNER_LOG=${INSTALL_MOS_TEMPEST_RUNNER_LOG:-"install_mos_tempest_runner_log.txt"}
RUN_TEMPEST_LOG=${RUN_TEMPEST_LOG:-"run_tempest_log.txt"}
RUN_TEMPEST_LOGGING_PATH=${RUN_TEMPEST_LOGGING_PATH:-"."}

install_python() {
    SCL_PYTHON_NAME=${1}
    # Check if SCL scl-tools installed
    if ! ssh_to_master "type -p scl" > /dev/null
    then
        ssh_to_master "yum install -y http://mirror.centos.org/centos/6/extras/x86_64/Packages/centos-release-SCL-6-5.el6.centos.x86_64.rpm"
        ssh_to_master "yum install -y scl-utils"
    fi

    # Check if python 2.7 installed
    if ! ssh_to_master "scl -l" | grep -q ${SCL_PYTHON_NAME}
    then
        ssh_to_master "yum install -y ${SCL_PYTHON_NAME} ${SCL_PYTHON_NAME}-python ${SCL_PYTHON_NAME}-python-setuptools ${SCL_PYTHON_NAME}-python-virtualenv"
    fi
    # Force using python from software collection
    ssh_to_master "ln -sf /opt/rh/${SCL_PYTHON_NAME}/enable /etc/profile.d/${SCL_PYTHON_NAME}-scl.sh"

    # Check if pip installed
    if ! ssh_to_master "pip -V" | grep -q ${SCL_PYTHON_NAME}
    then
        ssh_to_master "easy_install pip"
    fi
}

run_tempest() {
    project_name="$1"

    echo_logs "######################################################"
    echo_logs "Install mos-tempest-runner project                    "
    echo_logs "######################################################"
    set +e
    ssh_to_master "/tmp/mos-tempest-runner/setup_env.sh" &> ${INSTALL_MOS_TEMPEST_RUNNER_LOG}
    set -e
    check_return_code_after_command_execution $? "Install mos-tempest-runner is failure. Please see ${INSTALL_MOS_TEMPEST_RUNNER_LOG}"
    echo_logs "######################################################"
    echo_logs "Run tempest tests                                     "
    echo_logs "######################################################"

    if [ -z "${project_name}" ]; then
        run_command=""
        error_message="Run tempest tests is failure."
    else
        run_command="tempest.api.${project_name}"
        if [ "$project_name" == "sahara" ]; then
            ssh_to_master "scp -r root@${controller_ip}:/usr/lib/python2.7/dist-packages/sahara/tests/tempest/ ."
            add_sahara_client_tests
            run_command="tempest.scenario.data_processing.client_tests"
            ssh_to_master "scp -r root@${controller_ip}:/usr/lib/python2.7/dist-packages/saharaclient /home/developer/mos-tempest-runner/.venv/lib/python2.7/site-packages/saharaclient"
        fi
        error_message="Run tempest tests for ${project_name} is failure."
        USE_TESTRAIL=false
    fi

    set +e
    ( ssh_to_master <<EOF; echo $? ) | tee ${RUN_TEMPEST_LOG}
/tmp/mos-tempest-runner/rejoin.sh
. /home/developer/mos-tempest-runner/.venv/bin/activate
. /home/developer/openrc
run_tests ${run_command}
EOF

    echo_logs "######################################################"
    echo_logs "Add tempest result to folder: ${RUN_TEMPEST_LOGGING_PATH}"
    echo_logs "######################################################"
    run_with_logs scp_from_fuel_master -r /home/developer/mos-tempest-runner/tempest-reports/* ${RUN_TEMPEST_LOGGING_PATH}
    echo_logs "------------------------------------------------------"
    echo_logs "DONE"
    echo_logs

    #   Add tempest result to testrail
    if [ -f ${RUN_TEMPEST_LOGGING_PATH}tempest-report.xml ]; then
        if ${USE_TESTRAIL}; then
            testrail_results "deploy_successful"
        fi
    fi

    set -e
    return_code=$(cat ${RUN_TEMPEST_LOG} | tail -1)
    check_return_code_after_command_execution ${return_code} "${error_message}"
}

create_sahararc() {
    FUEL_IP=${vm_master_ip:-localhost}
    DEFAULT_OPENRC_PATH=${PWD}"/sahararc"

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
export OS_AUTH_URL='http://`python -c "from componentspython import nailgun; nailgun.return_controller_ip()" ${environment_settings} ${FUEL_IP} 2>/dev/null`:5000/v2.0'
EOF
}

set_quotas_for_scenario_tests() {
    create_sahararc
    . sahararc
    local tenant=$(keystone tenant-list | awk '/admin/ {print $2}')
    echo_logs "********************************"
    echo_logs "Set quotas for SAHARA tests     "
    echo_logs "********************************"
    nova quota-update --ram 122880 $tenant
    nova quota-update --security-groups 100 $tenant
    nova quota-update --security-group-rules 1000 $tenant
    neutron quota-update --floatingip 50
    neutron quota-update --security_group 100
    neutron quota-update --security_group_rule 1000
}

run_scenario() {
    export LC_ALL=en_US.UTF-8
    export LANG=en_US.UTF-8
    set_quotas_for_scenario_tests
    echo_logs "######################################################"
    echo_logs "Run scenario SAHARA tests                             "
    echo_logs "######################################################"

    env_ip=$(controller_ip "${environment_settings}" "${vm_master_ip}")
    env_ip="http://${env_ip}:5000/v2.0"

    if [ -d sahara ]; then
        rm -rf sahara
    fi
    run_with_logs git clone https://github.com/openstack/sahara.git
    cp -r etc/sahara_scenario/${MOS_VERSION} sahara
    pushd sahara
    sed -i "s@sahara_host@${env_ip}@" ${MOS_VERSION}/credentials.yaml

    sudo pip install tox
    export OS_TEST_TIMEOUT=600
    run_with_logs tox -e scenario ${MOS_VERSION}

    popd
    rm -rf sahara
}

run_murano_tests() {
    local mode="$1"
    local auth_host=$(controller_ip "${environment_settings}" "${vm_master_ip}")
    echo_logs "######################################################"
    echo_logs "             Run Murano deployment tests              "
    echo_logs "######################################################"
    # Temporarily workaround for murano testing due to in upstream repos
    # we haven't yet these tests.
    run_with_logs ssh_to_master 'bash -s' <<EOF | tee temp_log.log
yum install -y git
WORK_DIR=\$(mktemp -d)
cd \${WORK_DIR}
git clone https://github.com/vryzhenkin/pegasus.git \${WORK_DIR}/pegasus
internal_controller_ip=\$(fuel node | awk '/controller/ {print \$9}' | head -1)
scp \${internal_controller_ip}:~/openrc \${WORK_DIR}/pegasus/.
PEGASUS_DIR=\${WORK_DIR}/pegasus && cd \${PEGASUS_DIR}
sed -i "s@internalURL@publicURL@g" \${PEGASUS_DIR}/openrc
sed -i "s@[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\:5000@${auth_host}:5000@g" \${PEGASUS_DIR}/openrc
\${PEGASUS_DIR}/run_tests.sh ${mode}
mkdir \${PEGASUS_DIR}/logs
cp \${PEGASUS_DIR}/*.log \${PEGASUS_DIR}/logs
cp \${PEGASUS_DIR}/pegasus_results.* \${PEGASUS_DIR}/logs
echo \${WORK_DIR}
EOF
    MURANO_WORK_DIR=$( cat temp_log.log | tail -1 )
    run_with_logs scp_from_fuel_master -r ${MURANO_WORK_DIR}/pegasus/logs/* ${LOGGING_PATH}
}

if ${run_tests}; then
    if [ -n "${ZUUL_PROJECT}" ]; then
        project=${ZUUL_PROJECT##*/}
    elif [ -n "${url_to_change}" ]; then
        if [ -z "${infra_user}" ]; then
            infra_user=$(hostname)
        fi
        change_number=$(echo ${url_to_change} | awk -F "/" '{print $6}')
        project=$(ssh -p 29418 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${infra_user}@review.fuel-infra.org gerrit query ${change_number} 2>/dev/null | awk '/project/ {print $2}')
        project=$(echo "${project}" | awk -F/ '{print $2}')
    fi

    # SCL for RHEL/CentOS 6 has python27 and python33
    #install_python python27 || :

    case ${project} in
        *nova*)
        run_tempest compute
        ;;
        *keystone*)
        run_tempest identity
        ;;
        *glance*)
        run_tempest image
        ;;
        *neutron*)
        run_tempest network
        ;;
        *swift*)
        run_tempest object_storage
        ;;
        *heat*)
        run_tempest orchestration
        ;;
        *cinder*)
        run_tempest volume
        ;;
        *ceilometer*)
        run_tempest telemetry
        ;;
        *sahara*)
        run_tempest sahara
        ;;
        *sahara-nightly*)
        run_scenario
        ;;
        *murano*)
        run_murano_tests light
        ;;
        "")
        echo "Project not obtained. run all tempest api tests"
        run_tempest
        ;;
        *)
        echo "${project} unknown project. run all tempest api tests"
        run_tempest
        ;;
    esac
fi
