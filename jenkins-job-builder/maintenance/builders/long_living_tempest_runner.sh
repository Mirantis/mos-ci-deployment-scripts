#!/bin/bash -ex

REPORT_PATH="${REPORT_PREFIX}/long_living_tempest_${VERSION}"
echo "$REPORT_PATH" > ./param.pm
echo "$BUILD_URL" > ./build_url

# Helpers

VM_IP=${get_master_ip:-"10.20.1.2"}
VM_USERNAME=${vm_master_username:-"root"}
VM_PASSWORD=${vm_master_password:-"r00tme"}


SSH_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
ssh_to_fuel_master() {
    #   $1 - command
    SSH_CMD="sshpass -p ${VM_PASSWORD} ssh ${SSH_OPTIONS} ${VM_USERNAME}@${VM_IP}"
    ${SSH_CMD} "$1"
}

scp_to_fuel_master() {
    #   $1 - file
    #   $2 - target path
    SCP_CMD="sshpass -p ${VM_PASSWORD} scp ${SSH_OPTIONS}"
    case $1 in
        -r|--recursive)
        SCP_CMD+=" -r "
        shift
        ;;
    esac
    tpath=$2
    ${SCP_CMD} "$1" ${VM_USERNAME}@${VM_IP}:${tpath:-"/tmp/"}
}

scp_from_fuel_master() {
    #   $1 - command
    SCP_CMD="sshpass -p ${VM_PASSWORD} scp ${SSH_OPTIONS}"
    case $1 in
        -r|--recursive)
        SCP_CMD+=" -r "
        shift
        ;;
    esac
    ${SCP_CMD} ${VM_USERNAME}@${VM_IP}:$@
}

check_return_code_after_command_execution() {
    if [ "$1" -ne 0 ]; then
        if [ -n "$2" ]; then
            echo "$2"
        fi
        exit 1
    fi
}

# Install updates

wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/maintenance/helpers/long_living_install_updates.sh
scp_to_fuel_master long_living_install_updates.sh /root/
ssh_to_fuel_master 'chmod +x /root/long_living_install_updates.sh && /bin/bash -xe /root/long_living_install_updates.sh > /root/log.log'

# Run tempest

if [ "$RALLY_TEMPEST" == "run_tempest" ];then

    RUN_TEMPEST_LOG_NAME=${RUN_TEMPEST_LOG_NAME:-"run_tempest_log.txt"}
    export RUN_TEMPEST_LOG="${RUN_TEMPEST_LOG_NAME}"

    installed_tempest=$(ssh_to_fuel_master "find /root/ -maxdepth 1 -name mos-tempest-runner")
    if [ -n "${installed_tempest}" ]; then
        set +e
        echo "Download and install mos-tempest-runner project"
        git clone https://github.com/Mirantis/mos-tempest-runner.git -b stable/${MILESTONE}
        rm -rf mos-tempest-runner/.git*
        scp_to_fuel_master -r mos-tempest-runner /root/
        ssh_to_fuel_master "/root/mos-tempest-runner/setup_env.sh" & > install_mos_tempest_runner_log.txt
        set -e
        check_return_code_after_command_execution $? "Install mos-tempest-runner is failure. $(cat install_mos_tempest_runner_log.txt)"
    else
        # Delete old tempest xml result
        ssh_to_fuel_master "rm /home/developer/mos-tempest-runner/tempest-reports/tempest-report.xml"
    fi

    echo "Run tempest tests"
    set +e
    ( ssh_to_fuel_master <<EOF; echo $? ) | tee ${RUN_TEMPEST_LOG}
/root/mos-tempest-runner/rejoin.sh
. /home/developer/mos-tempest-runner/.venv/bin/activate
. /home/developer/openrc
run_tests > /root/log.log
EOF

    echo "Store tempest result"
    scp_from_fuel_master /home/developer/mos-tempest-runner/tempest-reports/tempest-report.xml verification.xml
    echo "DONE"

    set -e
    return_code=$(cat ${RUN_TEMPEST_LOG} | tail -1)
    check_return_code_after_command_execution ${return_code} "Run tempest tests is failure."

elif [ "$RALLY_TEMPEST" == "rally_run" ];then
    rally_id=$(ssh_to_fuel_master "docker images | awk '/rally/{print $3}'")
    if [ -z "${rally_id}" ]; then
        # Install rally docker
        virtualenv venv
        source venv/bin/activate

        sudo docker build -t rally-tempest rally-tempest/latest
        sudo docker save -o ./dimage rally-tempest
        deactivate
        scp_to_fuel_master dimage /root/rally
        ssh_to_fuel_master "wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/maintenance/helpers/rally_run.sh"
        ssh_to_fuel_master "chmod +x rally_run.sh"
        ssh_to_fuel_master "/bin/bash -xe rally_run.sh > /root/log.log"
    else
        rally_run_script=$(ssh_to_fuel_master "ls /root/ | grep long_living_rally_run.sh")
        if [ -z "${rally_run_script}" ]; then
            wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/maintenance/helpers/long_living_rally_run.sh
            scp_to_fuel_master long_living_rally_run.sh /root/
            ssh_to_fuel_master 'chmod +x /root/long_living_rally_run.sh'
        fi
        ssh_to_fuel_master "/bin/bash -xe /root/long_living_rally_run.sh > /root/log.log"
    fi
    scp_from_fuel_master /var/lib/rally-tempest-container-home-dir/verification.xml ./
fi;

scp_from_fuel_master /root/log.log ./