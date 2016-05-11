#!/bin/bash -xe

echo "$BUILD_URL" > ./build_url

INSTALL_MOS_TEMPEST_RUNNER_LOG_NAME=${INSTALL_MOS_TEMPEST_RUNNER_LOG_NAME:-"install_mos_tempest_runner_log.txt"}
export INSTALL_MOS_TEMPEST_RUNNER_LOG="${INSTALL_MOS_TEMPEST_RUNNER_LOG_NAME}"

RUN_TEMPEST_LOG_NAME=${RUN_TEMPEST_LOG_NAME:-"run_tempest_log.txt"}
export RUN_TEMPEST_LOG="${RUN_TEMPEST_LOG_NAME}"

get_master_ip(){
    echo 'from devops.models import Environment' > temp.py
    echo "env = Environment.get(name='$ENV_NAME')" >> temp.py
    echo "print env.nodes().admin.get_ip_address_by_network_name('admin')" >> temp.py
    echo $(python temp.py)
}

source ${VENV_PATH}/bin/activate

if [ "$(echo $MILESTONE | cut -c 1)" -ge "8" ]; then
    dos.py revert-resume $ENV_NAME $SNAPSHOT_NAME
else
    dos.py revert-resume $ENV_NAME --snapshot-name $SNAPSHOT_NAME
fi

VM_IP=$(get_master_ip)
VM_IP=${VM_IP:-"10.109.0.2"}
deactivate

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

enable_public_ip() {
    source ${VENV_PATH}/bin/activate
    public_mac=$(virsh dumpxml ${ENV_NAME}_admin | grep -B 1 "${ENV_NAME}_public" | awk -F"'" '{print $2}' | head -1)
    public_ip=$(dos.py net-list ${ENV_NAME} | awk '/public/{print $2}' | egrep -o "[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}")
    public_net=$(dos.py net-list ${ENV_NAME} | awk -F/ '/public/{print $2}')
    deactivate

    echo '#!/bin/bash' > net_setup.sh
    echo "iface=\$(ifconfig -a | grep -iB 1 ${public_mac} | grep -v \"^\$\" | head -n 1 | awk -F':| ' '{print \$1}')" >> net_setup.sh
    echo 'ifconfig $iface up' >> net_setup.sh
    echo "ip addr add ${public_ip}.31/${public_net} dev \${iface}" >> net_setup.sh
    chmod +x net_setup.sh
    scp_to_fuel_master net_setup.sh $WORK_FLDR
    ssh_to_fuel_master "$WORK_FLDR/net_setup.sh"
}

WORK_FLDR=$(ssh_to_fuel_master "mktemp -d")
ssh_to_fuel_master "chmod 777 $WORK_FLDR"
enable_public_ip

if [ "$RALLY_TEMPEST" == "run_tempest" ];then

    set +e
    echo "Download and install mos-tempest-runner project"
    git clone https://github.com/Mirantis/mos-tempest-runner.git -b stable/${MILESTONE}
    rm -rf mos-tempest-runner/.git*
    scp_to_fuel_master -r mos-tempest-runner $WORK_FLDR
    ssh_to_fuel_master "$WORK_FLDR/mos-tempest-runner/setup_env.sh" &> ${INSTALL_MOS_TEMPEST_RUNNER_LOG}
    set -e
    check_return_code_after_command_execution $? "Install mos-tempest-runner is failure. Please see ${INSTALL_MOS_TEMPEST_RUNNER_LOG}"

    echo "Run tempest tests"
    set +e
    ( ssh_to_fuel_master <<EOF; echo $? ) | tee ${RUN_TEMPEST_LOG}
/$WORK_FLDR/mos-tempest-runner/rejoin.sh
. /home/developer/mos-tempest-runner/.venv/bin/activate
. /home/developer/openrc
run_tests > $WORK_FLDR/log.log
EOF

    echo "Store tempest result"
    scp_from_fuel_master -r /home/developer/mos-tempest-runner/tempest-reports/* .
    mv tempest-report.xml verification.xml
    echo "DONE"

elif [ "$RALLY_TEMPEST" == "rally_run" ];then
    sed -i 's|rally verify install --source /var/lib/tempest --no-tempest-venv|rally verify install --source /var/lib/tempest|g' rally-tempest/latest/setup_tempest.sh
    sed -i 's|FROM rallyforge/rally:latest|FROM rallyforge/rally:0.3.1|g' rally-tempest/latest/Dockerfile
    sed -i 's|RUN git clone https://git.openstack.org/openstack/tempest && \|RUN git clone https://git.openstack.org/openstack/tempest && pushd tempest && git checkout b39bbce80c69a57c708ed1b672319f111c79bdd5 && popd && \|g' rally-tempest/latest/Dockerfile

    virtualenv venv
    source venv/bin/activate

    sudo docker build -t rally-tempest rally-tempest/latest
    sudo docker save -o ./dimage rally-tempest
    deactivate

    scp_to_fuel_master dimage $WORK_FLDR/rally
    ssh_to_fuel_master "ln -sf $WORK_FLDR/rally /root/rally"
    scp_to_fuel_master mos-ci-deployment-scripts/jenkins-job-builder/maintenance/helpers/rally_run.sh "$WORK_FLDR"
    ssh_to_fuel_master "chmod +x $WORK_FLDR/rally_run.sh"
    ssh_to_fuel_master "/bin/bash -xe $WORK_FLDR/rally_run.sh > $WORK_FLDR/log.log"

    scp_from_fuel_master /var/lib/rally-tempest-container-home-dir/verification.xml ./
fi;

scp_from_fuel_master $WORK_FLDR/log.log ./
