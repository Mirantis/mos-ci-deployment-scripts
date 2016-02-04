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
# This script creates a master node for the product, launches its installation,
# and waits for its completion
#

# Include the handy functions to operate VMs and track ISO installation progress

source functions/resources.sh
source functions/product.sh
source functions/vm.sh

test -f mos_version.env && source mos_version.env

LOG=${LOG:-"log.txt"}
name="${vm_name_prefix}master-${private_interface}"

if [ -z "${iso_path}" ]; then
    if [ "${DOWNLOAD_ISO}" = "true" -a -f downloaded_iso.txt ]; then
        iso_path=`cat downloaded_iso.txt`
        echo "Using downloaded ISO: ${iso_path}"
    else
        find_iso
        iso_path=${RETVAL}
        echo "Found suitable ISO: ${iso_path}"
    fi
fi

{
echo
echo "######################################################"
echo "Install Fuel Master KVM node disk                     "
echo "######################################################"
} | tee -a ${LOG}

if [ -n "$(sudo virsh vol-list --pool default | grep ${name})" ]; then
    if [[ ${delete_old_kvms} =~ [Tt]rue ]]; then
        sudo virsh vol-delete --pool default ${name}.qcow2
    else
        echo
        echo "Volume with name ${name} already created. Aborting."
        exit 1
    fi
fi

virsh vol-create-as --name ${name}.qcow2 \
    --capacity ${vm_master_disk_gb}G \
    --format qcow2 \
    --allocation ${vm_master_disk_gb}G \
    --pool default \
    | tee -a ${LOG}


private_int_type=${private_int_type:-"network"}
internet_int_type=${internet_int_type:-"network"}
private_int_model=${private_int_model:-"e1000"}
internet_int_model=${internet_int_model:-"e1000"}
disk_bus=${vm_master_disk_bus:-"virtio"}
interfaces="-w $private_int_type=${private_interface},model=${private_int_model}"
if [ ! -z ${internet_interface} ]; then
    interfaces+=" -w ${internet_int_type}=${internet_interface},model=${internet_int_model}"
fi

{
echo "######################################################"
echo "Install Fuel Master KVM node                          "
echo "######################################################"
} | tee -a ${LOG}

if [ -n "$(sudo virsh list --all | grep ${name})" ]; then
    if [[ ${delete_old_kvms} =~ [Tt]rue ]]; then
        destroy_vm ${name}
        virsh undefine ${name}
    else
        echo
        echo "KVM with name ${name} already created. Aborting."
        exit 1
    fi
fi

virt-install --connect qemu:///system \
    --virt-type kvm \
    -n ${name} \
    -r ${vm_master_memory_mb} \
    --vcpus ${vm_master_cpu_cores} \
    -c ${iso_path} \
    ${interfaces} \
    --controller=scsi,model=virtio-scsi \
    --disk vol=default/${name}.qcow2,cache=writeback,bus=${disk_bus},serial=$(uuidgen) \
    --memballoon virtio \
    --os-type linux \
    --os-variant rhel6 \
    --noautoconsole \
    --graphics vnc,listen=0.0.0.0 \
    ${feature_cpu_param:-} \
    --noreboot \
    | tee -a ${LOG}

# We need to mark all Tempest tests as 'in progress' while env is being deployed
if [ "${ZUUL_PIPELINE}" == "periodic-deploy" -a "${USE_TESTRAIL}" == "true" ]; then
    testrail_results "deploy_in_progress"
fi

set +e
wait_for_product_vm_to_install ${name}
exit_code=$?
set -e

# We need to mark all Tempest tests as 'blocked' if the Fuel master node was not installed
if [ "${exit_code}" != "0" -a "${ZUUL_PIPELINE}" == "periodic-deploy" -a "${USE_TESTRAIL}" == "true" ]; then
    testrail_results "deploy_failed"
fi

{
echo "######################################################"
echo "Check network params                                  "
echo "######################################################"
} >> ${LOG}

check_network_params

{
echo "######################################################"
echo "Fuel master node installed and configured             "
echo "URL to UI on internal network: http://${vm_master_ip}:8000"
if [ -n "${internet_interface}" ]; then
external_ip=$(ssh_to_master "ifconfig eth1" 2>/dev/null | awk -F 'inet addr:|  Bcast:' '/inet /{print $2}')
    if [ -n "${external_ip}" ]; then
        echo "URL to UI on external network: http://${external_ip}:8000"
    else
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "External IP not found but internet interface:${internet_interface} is enabled."
        echo "Please check network parameters on Fuel master node"
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    fi
fi
echo "######################################################"
} | tee -a ${LOG}
