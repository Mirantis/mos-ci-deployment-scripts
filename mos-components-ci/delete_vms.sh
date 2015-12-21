#!/bin/bash

source functions/vm.sh
source functions/resources.sh
import_config ${1}


master_vm_name="${vm_name_prefix}master-${private_interface}"
virsh vol-delete --pool default ${master_vm_name}.qcow2
destroy_vm ${master_vm_name}
virsh undefine ${master_vm_name}

worker_vm_name="${vm_name_prefix}worker-${private_interface}"

if [[ ${kvm_nodes_count} -gt 0 ]]; then
    for ((worker_counter=1;worker_counter<=kvm_nodes_count;worker_counter++)); do
        virsh vol-delete --pool default ${worker_vm_name}-${worker_counter}.qcow2
        destroy_vm ${worker_vm_name}-${worker_counter}
        virsh undefine ${worker_vm_name}-${worker_counter}
    done
fi
