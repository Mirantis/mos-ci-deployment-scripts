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
# This script creates a KVM slave nodes and reboot IPMI slave nodes.
#

source functions/resources.sh
source functions/vm.sh

test -f mos_version.env && source mos_version.env

LOG=${LOG:-"log.txt"}
name="${vm_name_prefix}worker-${private_interface}"

# Start KVM nodes
if [[ ${kvm_nodes_count} > 0 ]]; then

    {
    echo "######################################################"
    echo "Start KVM worker nodes                                "
    echo "######################################################"
    } | tee -a ${LOG}

    for worker_counter in $(eval echo {1..${kvm_nodes_count}}); do

        if [ -n "$(sudo virsh vol-list --pool default | grep ${name}-${worker_counter})" ]; then
            if [[ ${delete_old_kvms} =~ [Tt]rue ]]; then
                sudo virsh vol-delete --pool default ${name}-${worker_counter}.qcow2
            else
                echo
                echo "Volume with name ${name} already created. Aborting."
                exit 1
            fi
        fi

        virsh vol-create-as --name ${name}-${worker_counter}.qcow2 \
                            --capacity ${vm_slave_disk_gb}G \
                            --format qcow2 \
                            --allocation ${vm_slave_disk_gb}G \
                            --pool default \
                            | tee -a ${LOG}

        private_int_type=${private_int_type:-"network"}
        public_int_type=${public_int_type:-"network"}
        private_int_model=${private_int_model:-"e1000"}
        public_int_model=${public_int_model:-"e1000"}
        disk_bus=${vm_slave_disk_bus:-"virtio"}

        # get memory
        NODE_TYPE=$(get_node_type "${environment_settings}" "${name}-${worker_counter}")
        echo Node: ${NODE_TYPE}
        VM_MEMORY=${vm_slave_memory_mb}
        VM_CPU=${vm_slave_cpu_cores}
        if [[ "${NODE_TYPE}" == 'controller' ]]; then
            VM_MEMORY=${vm_slave_memory_controller_mb}
            VM_CPU=${vm_slave_cpu_controller_cores}
        elif [[ "${NODE_TYPE}" == 'compute' ]]; then
            VM_MEMORY=${vm_slave_memory_compute_mb}
            VM_CPU=${vm_slave_cpu_compute_cores}
        fi

        if [ -n "$(sudo virsh list --all | grep ${name}-${worker_counter})" ]; then
            if [[ ${delete_old_kvms} =~ [Tt]rue ]]; then
                destroy_vm ${name}-${worker_counter}
                virsh undefine ${name}-${worker_counter}
            else
                echo
                echo "KVM with name ${name} already created. Aborting."
                exit 1
            fi
        fi

        virt-install --connect qemu:///system \
        --virt-type kvm \
        -n ${name}-${worker_counter} \
        -r ${VM_MEMORY} \
        --vcpus ${VM_CPU} \
        --controller=scsi,model=virtio-scsi \
        --disk vol=default/${name}-${worker_counter}.qcow2,cache=writeback,bus=${disk_bus},serial=$(uuidgen) \
        --pxe \
        -w ${private_int_type}=${private_interface},model=${private_int_model} \
        -w ${public_int_type}=${public_interface},model=${public_int_model} \
        --boot network,hd \
        --noautoconsole \
        --memballoon virtio \
        --os-type linux \
        --graphics vnc,listen=0.0.0.0 \
        ${feature_cpu_param:-} \
        | tee -a ${LOG}

        await_vm_status ${name}-${worker_counter} "running" &>>${LOG}
        sleep 5
        destroy_vm ${name}-${worker_counter}
        change_cache_to_unsafe ${name}-${worker_counter} &>>${LOG}
        enable_hugepages ${name}-${worker_counter} &>>${LOG}
        add_smbios ${name}-${worker_counter} &>>${LOG}
        start_vm ${name}-${worker_counter} &>>${LOG}
        echo -n "Install worker node $name-$worker_counter"
        echo_ok
    done
fi

# Reboot IPMI nodes
if [[ ${mashines_count} > 0 ]]; then

    {
    echo "######################################################"
    echo "Restart IPMI nodes                                    "
    echo "######################################################"
    } | tee -a ${LOG}

    for ipmi_counter in $(eval echo {1..${mashines_count}}); do
        type="mashine_$ipmi_counter"
        eval host=\$${type}_host
        eval user=\$${type}_user
        eval role=\$${type}_role
        eval pass=\$${type}_password
        echo -n "Reboot hardware machine ${host} using IPMI... "
        sudo ipmitool -I lanplus -H ${host} -U ${user} -L ${role} -P ${pass} chassis power reset &>>${LOG}
        echo_ok
    done
fi

{
echo "######################################################"
echo "Fuel worker nodes installed and configured            "
echo "######################################################"
} | tee -a ${LOG}
