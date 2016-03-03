#!/bin/bash -xe

REPORT_PATH="${REPORT_PREFIX}/${ENV_NAME}_${SNAPSHOT_NAME}/"
LOG_NAME=${LOG_NAME:-"log.txt"}
export LOG="${REPORT_PATH}${LOG_NAME}"
if [ -d "${REPORT_PATH}" ]; then
    sudo rm -rf ${REPORT_PATH}
fi;
sudo mkdir ${REPORT_PATH}
sudo chmod 777 ${REPORT_PATH}
touch ${LOG}
chmod 666 ${LOG}

echo "$BUILD_URL" > ${REPORT_PATH}build_url

INSTALL_MOS_TEMPEST_RUNNER_LOG_NAME=${INSTALL_MOS_TEMPEST_RUNNER_LOG_NAME:-"install_mos_tempest_runner_log.txt"}
export INSTALL_MOS_TEMPEST_RUNNER_LOG="${REPORT_PATH}${INSTALL_MOS_TEMPEST_RUNNER_LOG_NAME}"

RUN_TEMPEST_LOG_NAME=${RUN_TEMPEST_LOG_NAME:-"run_tempest_log.txt"}
export RUN_TEMPEST_LOG="${REPORT_PATH}${RUN_TEMPEST_LOG_NAME}"



SSH_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

get_master_ip(){
    source ${VENV_PATH}/bin/activate
    echo 'from devops.models import Environment' > temp.py
    echo "env = Environment.get(name='$ENV_NAME')" >> temp.py
    echo "print env.nodes().admin.get_ip_address_by_network_name('admin')" >> temp.py
    MASTER_NODE_IP=$(python temp.py)
    echo "$MASTER_NODE_IP"
    deactivate
}

VM_MASTER_IP=$(get_master_ip)

    
ssh_to_master() {
    #   $1 - command
    ip=${VM_MASTER_IP:-"10.20.0.2"}
    username=${VM_MASTER_USERNAME:-"root"}
    password=${VM_MASTER_PASSWORD:-"r00tme"}
    SSH_CMD="sshpass -p ${password} ssh ${SSH_OPTIONS} ${username}@${ip}"
    ${SSH_CMD} "$1"
}

scp_to_fuel_master() {
    #   $1 - file
    #   $2 - target path
    tpath=$2
    ip=${VM_MASTER_IP:-"10.20.0.2"}
    username=${VM_MASTER_USERNAME:-"root"}
    password=${VM_MASTER_PASSWORD:-"r00tme"}
    SCP_CMD="sshpass -p ${password} scp ${SSH_OPTIONS}"
    ${SCP_CMD} "$1" ${username}@${ip}:${tpath:-"."}
}

scp_from_fuel_master() {
    #   $1 - command
    ip=${VM_MASTER_IP:-"10.20.0.2"}
    username=${VM_MASTER_USERNAME:-"root"}
    password=${VM_MASTER_PASSWORD:-"r00tme"}
    SCP_CMD="sshpass -p ${password} scp ${SSH_OPTIONS}"
    case $1 in
        -r|--recursive)
        SCP_CMD+=" -r "
        shift
        ;;
    esac
    ${SCP_CMD} ${username}@${ip}:$@
}

check_return_code_after_command_execution() {
    if [ "$1" -ne 0 ]; then
        if [ -n "$2" ]; then
            echo_fail "$2"
        fi
        exit 1
    fi
}

run_with_logs() {
    eval "$@" | tee -a ${LOG}
}

py27_virtualenv() {
    # Create and source python tox virtualenv
    tox -e py27
    source .tox/py27/bin/activate
    python setup.py install
}


if [ "$RALLY_TEMPEST" == "run_tempest" ];then

    rm -rf *
    project_name="compute"

    set +e
    echo "Download and install mos-tempest-runner project"
    fuel_disk_directory=$(mktemp -d)

    name=${ENV_NAME}_admin

    git clone https://github.com/Mirantis/mos-tempest-runner.git -b stable/7.0
    tar -czf mos-tempest-runner.tar.gz mos-tempest-runner
    ssh_to_master "rm -rf /tmp/mos-tempest-runner*"
    scp_to_fuel_master mos-tempest-runner.tar.gz /tmp

    ssh_to_master "tar -xf /tmp/mos-tempest-runner.tar.gz -C /tmp"

    ssh_to_master "/tmp/mos-tempest-runner/setup_env.sh" &> ${INSTALL_MOS_TEMPEST_RUNNER_LOG}
    set -e
    check_return_code_after_command_execution $? "Install mos-tempest-runner is failure. Please see ${INSTALL_MOS_TEMPEST_RUNNER_LOG}"

    echo "Run tempest tests"

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
        fi;
        error_message="Run tempest tests for ${project_name} is failure."
        USE_TESTRAIL=false
    fi;

    set +e
    ( ssh_to_master <<EOF; echo $? ) | tee ${RUN_TEMPEST_LOG}
/tmp/mos-tempest-runner/rejoin.sh
echo "rejoin.sh done"
. /home/developer/mos-tempest-runner/.venv/bin/activate
. /home/developer/openrc
echo "activate & openrc done"
run_tests ${run_command}
EOF

    echo "Add tempest result to folder: ${REPORT_PATH}"
    run_with_logs scp_from_fuel_master -r /home/developer/mos-tempest-runner/tempest-reports/* ${REPORT_PATH}
    echo "DONE"

    #   Add tempest result to testrail
    #if [ -f ${REPORT_PATH}tempest-report.xml ]; then
    #    if ${USE_TESTRAIL}; then
    #        testrail_results "deploy_successful"
    #    fi
    #fi

    #set -e
    #return_code=$(cat ${RUN_TEMPEST_LOG} | tail -1)
    #check_return_code_after_command_execution ${return_code} "${error_message}"
    touch log.log
    touch verification.xml

elif [ "$RALLY_TEMPEST" == "rally_run" ];then

    source ${VENV_PATH}/bin/activate
    echo 'from devops.models import Environment' > temp.py
    echo "env = Environment.get(name='$ENV_NAME')" >> temp.py
    echo "print env.nodes().admin.get_ip_address_by_network_name('admin')" >> temp.py
    MASTER_NODE_IP=$(python temp.py)
    echo "$MASTER_NODE_IP"
    deactivate

    virtualenv venv
    source venv/bin/activate
    sudo docker build -t rally-tempest custom-scripts/rally-tempest/
    sudo docker save -o ./dimage rally-tempest
    echo '' > ~/.ssh/known_hosts
    sshpass -p 'r00tme' scp -o "StrictHostKeyChecking no" dimage root@"$MASTER_NODE_IP":/root/rally

    echo '#!/bin/bash -xe' > ssh_scr.sh
    echo 'docker load -i /root/rally' >> ssh_scr.sh

    wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/maintenance/helpers/rally_run.sh

    chmod +x rally_run.sh

    sshpass -p 'r00tme' scp -o "StrictHostKeyChecking no" rally_run.sh root@"$MASTER_NODE_IP":/root/
    echo 'chmod +x /root/rally_run.sh && /bin/bash -xe /root/rally_run.sh > /root/log.log' | sshpass -p 'r00tme' ssh -T root@"$MASTER_NODE_IP"
    sshpass -p 'r00tme' scp -o "StrictHostKeyChecking no" root@"$MASTER_NODE_IP":/root/log.log ./
    sshpass -p 'r00tme' scp -o "StrictHostKeyChecking no" root@"$MASTER_NODE_IP":/var/lib/rally-tempest-container-home-dir/verification.xml ./
    deactivate
fi;

