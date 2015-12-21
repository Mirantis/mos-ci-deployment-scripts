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

TOPDIR=$( cd "$(dirname $0)/.." ; pwd -P )
export TOPDIR

SETCOLOR_SUCCESS="echo -en \\033[1;32m"
SETCOLOR_FAILURE="echo -en \\033[1;31m"
SETCOLOR_NORMAL="echo -en \\033[0;39m"

import_config() {
    CONFIG=${1}
    if [ -z $CONFIG ]; then
        echo -e "Config file not specified, attempt to find config file..."
        CONFIG=$(find . -maxdepth 1 -name "deploy_config*" | head -1)
        if [ -z $CONFIG ]; then
            echo -e "Config file not specified and not found, please create config file. Aborting."
            exit 1
        else
            echo -e "Found file: $CONFIG"
        fi
    fi

    set -a
    source etc/default_config.sh
    source $CONFIG

    # Set variable USE_TESTRAIL based on parameters TESTRAIL_SEND and TESTRAIL_SKIP
    if [ ${TESTRAIL_SEND:-0} -eq 1 -a ${TESTRAIL_SKIP:-0} -eq 0 ]; then
        export USE_TESTRAIL=true
    else
        export USE_TESTRAIL=false
    fi

    # Set variable USE_RALLY based on parameters RALLY_RUN and RALLY_SKIP
    if [ ${RALLY_RUN:-0} -eq 1 -a ${RALLY_SKIP:-0} -eq 0 ]; then
        export USE_RALLY=true
    else
        export USE_RALLY=false
    fi

    set +a
}

virtualenv() {
# Create and source python tox virtualenv
tox -e py27
source .tox/py27/bin/activate
python setup.py install
}

check_return_code_after_command_execution() {
    if [ "$1" -ne 0 ]; then
        if [ -n "$2" ]; then
            echo_fail "$2"
        fi
        exit 1
    fi
}

find_iso() {
    local search_dir=${1:-iso}/

    if [ -f downloaded_iso.txt ]; then
        RETVAL=$(readlink -e $(cat downloaded_iso.txt))
        echo -n "Downloaded ISO found: '$RETVAL'"
        return
    else
        RETVAL=$(find ${search_dir} -iname "fuel-*${MOS_VERSION:-*}-${MOS_BUILD:-*}-*.iso" -type f -printf "%T+\t%p\n" | sort | awk 'END{print $2}')
        if [ -n "$RETVAL" ]; then
            RETVAL=$(readlink -e $RETVAL)
            echo -n "Fuel ISO found: '$RETVAL'"
            return
        fi

        RETVAL=$(find ${search_dir} -iname 'MirantisOpenStack*.iso' -type f -printf "%T+\t%p\n" | sort | awk 'END{print $2}')
        if [ -n "$RETVAL" ]; then
            RETVAL=$(readlink -e $RETVAL)
            echo -n "Mirantis OpenStack ISO found: '$RETVAL'"
            return
        fi
    fi

    echo_fail "Unable to find Fuel ISO"
    exit 1
}

echo_ok() {
    msg=$1
    if [ "${ENABLE_COLOR}" == "true" ]; then
        ${SETCOLOR_SUCCESS}
        echo "$(tput hpa $(tput cols))$(tput cub 6)[OK]"
        if [ -n "${msg}" ]; then
            echo "${msg}"
        fi
        ${SETCOLOR_NORMAL}
    else
        echo "[OK]"
        if [ -n "${msg}" ]; then
            echo "${msg}"
        fi
    fi
}

echo_fail() {
    msg=$1
    if [ "${ENABLE_COLOR}" == "true" ]; then
        ${SETCOLOR_FAILURE}
        echo "$(tput hpa $(tput cols))$(tput cub 6)[FAIL]"
        if [ -n "${msg}" ]; then
            echo "${msg}"
        fi
        ${SETCOLOR_NORMAL}
    else
            echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
            echo "!!!                  FAIL                   !!!"
            echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        if [ -n "$msg" ]; then
            echo
            echo "${msg}"
            echo
            echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        fi
    fi
}

echo_logs() {
    echo $1 | tee -a ${LOG}
}

run_with_logs() {
    eval "$@" | tee -a ${LOG}
}

await_open_port() {
    counter=0
    echo -n "Waiting port $2 availability at virtual machine $1... "
    while ! echo q | telnet -e q $1 $2 2>/dev/null | grep -oq Connected &> /dev/null; do
        let counter=counter+1
        if [ $counter -eq 24 ]; then
            echo "Expected port $2 at virtual machine $1 is not obtained in 2 minutes"
            exit 1
        fi
        sleep 5
    done
    echo_ok
}

mount_disk_vm() {
    #   $2 - vm name
    #   $3 - path to attached disk
    name=$1
    disk_directory=$2

    if [ -f /tmp/mount_fuel_disk.log ]; then
        echo "Finded already mounted storage. Umount old storage"
        set +e
        umount_disk_vm $(cat /tmp/mount_fuel_disk.log)
        set -e
        echo "Umounted old storage successfully"
    fi

    pool=${pool:-"default"}
    pool_directory=$(virsh pool-dumpxml $pool | awk -F "<path>|</path>" '/<path>/ {print $2}')
    if [ -z "${pool_directory}" ]; then
        echo "No storage pool with matching name $pool"
        exit 1
    fi

    #   Mount fuel master disk
    if [ -f "${pool_directory}/$name.qcow2" ]; then

        if [ -f "/proc/1/cgroup" ] && grep -vq "/$" /proc/1/cgroup; then
            #   Mount disk
            echo "Mount disk from $name, using libguestfs"
            my_uid=${UID}
            sudo guestmount -o uid=${my_uid} -o allow_other -o modules=subdir -o subdir=/ -o rellinks -d $name -m /dev/os/root ${disk_directory}
            sudo guestmount -o uid=${my_uid} -o allow_other -o modules=subdir -o subdir=/ -o rellinks -d $name -m /dev/os/var ${disk_directory}/var
        else
            #   Setting host for mount fuel master disk
            echo "modprobe nbd max_part=63"
            sudo modprobe nbd max_part=63

            #   Mount disk
            echo "Mount ${pool_directory}/$name.qcow2, using ndb"
            sudo qemu-nbd -n -c /dev/nbd0 ${pool_directory}/$name.qcow2
            sleep 5
            sudo vgscan --mknode
            sudo vgchange -ay os
            sudo mount /dev/os/root ${disk_directory}
            sudo mount /dev/os/var ${disk_directory}/var
        fi

        # Add log file that disk is mounted
        echo "${disk_directory}" 1> /tmp/mount_fuel_disk.log
        echo "Mounted storage successfully"

    else
        echo "vm disk on path ${pool_directory}/$name.qcow2 not found"
        exit 1
    fi

}

umount_disk_vm() {
    #   $1 - disk directory
    sudo umount $1/var
    sudo umount $1
    if [ ! -f "/proc/1/cgroup" ] || grep -q "/$" /proc/1/cgroup; then
        sudo vgchange -an os
        sudo qemu-nbd -d /dev/nbd0
    fi
    sudo rm -rf $1
    rm /tmp/mount_fuel_disk.log
}

testrail_results() {
    env_status=$1

    export TESTRAIL_USER=${TESTRAIL_USER:-"user"}
    export TESTRAIL_PASSWORD=${TESTRAIL_PASSWORD:-"pass"}
    export TESTRAIL_MILESTONE=${MOS_VERSION}
    export TESTRAIL_TEST_SUITE="[${TESTRAIL_MILESTONE}][MOSQA] Tempest ${TESTRAIL_MILESTONE}"
    export JENKINS_URL="${PRODUCT_JENKINS_URL}"

    # (tnurlygayanov) We need to fix this hardcoded value when
    # we will have more than one configuration:
    config_name="Ubuntu 14.04"

    path_to_report="${PWD}/${RUN_TEMPEST_LOGGING_PATH}tempest-report.xml"
    run_name=$(job_parameters "${environment_settings}" "${vm_master_ip}" "run_name")

    if [ -d fuel-qa ]; then
        rm -rf fuel-qa
    fi
    git clone https://github.com/openstack/fuel-qa.git >> ${LOG}
    {
    echo "######################################################"
    if [ ${env_status} == "deploy_in_progress" ]; then
        echo "Marking all tempest tests as 'in progress' while env is being deployed"
    elif [ ${env_status} == "deploy_successful" ]; then
        echo "Adding tempest tests results to TestRail                              "
    else
        echo "Marking all tempest tests as 'blocked' because env was not deployed!  "
    fi
    echo "######################################################"
    echo "Variables for testrail                                "
    echo "######################################################"
    echo "TESTRAIL_USER=${TESTRAIL_USER}                        "
    echo "TESTRAIL_PASSWORD=${TESTRAIL_PASSWORD}                "
    echo "TESTRAIL_TEST_SUITE=${TESTRAIL_TEST_SUITE}            "
    echo "TESTRAIL_MILESTONE=${TESTRAIL_MILESTONE}              "
    echo "JENKINS_URL=${JENKINS_URL}                            "
    echo "config_name=${config_name}                            "
    echo "iso=${MOS_BUILD}                                      "
    echo "path_to_report=${path_to_report}                      "
    echo "run_name=${run_name}                                  "
    echo "######################################################"
    echo
    } | tee -a ${LOG}

    if [ -n "${CUSTOM_JOB}" ]; then
        python fuel-qa/fuelweb_test/testrail/report.py -j ${CUSTOM_JOB} -N ${MOS_BUILD}
    else
        if [ ${env_status} == "deploy_successful" ]; then
            python fuel-qa/fuelweb_test/testrail/report_tempest_results.py -r "${run_name}" -c "${config_name}" -i "${MOS_BUILD}" -p "${path_to_report}" | tee -a ${LOG}
        elif [ ${env_status} == "deploy_failed" ]; then
            python fuel-qa/fuelweb_test/testrail/report_tempest_results.py -r "${run_name}" -c "${config_name}" -i "${MOS_BUILD}" -b | tee -a ${LOG}
        elif [ ${env_status} == "deploy_in_progress" ]; then
            python fuel-qa/fuelweb_test/testrail/report_tempest_results.py -r "${run_name}" -c "${config_name}" -i "${MOS_BUILD}" -t | tee -a ${LOG}
        fi
    fi
    {
    echo "------------------------------------------------------"
    echo "DONE"
    echo
    } | tee -a ${LOG}
}

normalize_url() {
    perl -ne 's|(?<!:)//+|/|g; print;' <<< ${1}
}
