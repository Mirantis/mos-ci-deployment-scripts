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

# This file contains the functions to manage VMs in through virsh

source functions/resources.sh

await_vm_status() {
    time_counter=0
    max_count=12
    sec_state=''
    await=false
    echo "######################################################"
    echo "Wait to $2 state for $1                               "
    echo "######################################################"
    if [ $2 == "running" ]; then
        sec_state='работает';
    elif [ $2 == "shut off" ]; then
        sec_state='выключен';
    elif [ $2 == "paused" ]; then
        sec_state='Приостановлена';
    fi
    while [  $time_counter -lt $max_count ]; do
        sleep 5
        vm_state=$(virsh domstate $1 2>/dev/null; check_return_code_after_command_execution "$?" "vm $1 not found")
        echo "state for $1: ${vm_state}"
        if [ "${vm_state}" == "$2" -o "${vm_state}" == "${sec_state}" ]; then
            await=true
            break
        fi
        let time_counter=time_counter+1
    done
    if ! ${await}; then
        echo -e "\nvirtual machine $1 didn't pass into $2 status of 2 minutes\n"
        exit 1
    fi
}

start_vm() {
    vm_state=$(virsh domstate $1 2>/dev/null; check_return_code_after_command_execution "$?" "vm $1 not found")
    if [ "${vm_state}" == "выключен" -o  "${vm_state}" == "shut off" ]; then
        virsh start $1
        await_vm_status $1 "running"
    else
        echo
        echo "virtual machine $1 already started"
    fi;
}

shutdown_vm() {
    vm_state=$(virsh domstate $1 2>/dev/null; check_return_code_after_command_execution "$?" "vm $1 not found")
    if [ "${vm_state}" == "работает" -o  "${vm_state}" == "running" ]; then
        virsh shutdown $1
        await_vm_status $1 "shut off"
    else
        echo
        echo "virtual machine $1 already stoped"
    fi;
}

destroy_vm() {
    vm_state=$(virsh domstate $1 2>/dev/null; check_return_code_after_command_execution "$?" "vm $1 not found")
    if [ "${vm_state}" == "работает" -o  "${vm_state}" == "running" ]; then
        virsh destroy $1
        sleep 1
        time_counter=0
        max_count=120
        destroy=false
        while [ ${time_counter} -lt ${max_count} ]; do
            vm_state=$(virsh domstate $1 2>/dev/null; check_return_code_after_command_execution "$?" "vm $1 not found")
            if [ "${vm_state}" == "работает" -o  "${vm_state}" == "running" ]; then
                virsh destroy $1
                sleep 1
            else
                destroy=true; break;
            fi
        done
        if ! ${destroy};
            then echo "virtual machine $1 didn't get into shut off status of 2 minutes"; exit 1;
        fi
    else
        echo "virtual machine $1 already stoped"
    fi
}

reboot_vm() {
    vm_state=$(virsh domstate $1 2>/dev/null; check_return_code_after_command_execution "$?" "vm $1 not found")
    virsh reboot $1
    await_vm_status $1 "running"
}

edit_file_on_vm() {
# $1 - name of vm
# $2 - path to file
# $3 - regular expression to edit file
    sudo virt-edit -d $1 $2 -e $3
}

change_cache_to_unsafe() {
# $1 - name of vm
    virsh dumpxml $1 | sed "s/cache='writeback'/cache='unsafe'/g" > $1.xml
    virsh define $1.xml
    rm $1.xml
}

enable_hugepages() {
# $1 - name of vm
    if ${feature_enable_hugepages}; then
        virsh dumpxml $1 | sed "s|</domain>|<memoryBacking><hugepages/></memoryBacking></domain>|" > $1.xml
        virsh define $1.xml
        rm $1.xml
    fi
}

add_smbios() {
# $1 - name of vm
    if ${feature_add_smbios}; then
        virsh dumpxml $1 | sed -e "s|</domain>|<sysinfo type='smbios'><system><entry name='manufacturer'>KVM</entry><entry name='product'>${1}</entry></system></sysinfo></domain>|" \
        -e "s|</os>|<smbios mode='sysinfo'/></os>|" > $1.xml
        virsh define $1.xml
        rm $1.xml
    fi
}
