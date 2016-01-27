#!/bin/bash -e

#    Copyright 2013 Mirantis, Inc.
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

# This file contains the functions for connecting to Fuel VM, checking if the installation process completed
# and Fuel became operational, and also enabling outbound network/internet access for this VM through the
# host system

source functions/vm.sh
source functions/resources.sh
SSH_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# Pairs of branch name and string, that identifies branch in OBS
branches_statuses=(
    "fuel-6.1" "stable-updates"
    "fuel-7.0" "stable"
)

is_product_vm_operational() {
    # Log in into the VM, see if Puppet has completed its run
    # Looks a bit ugly, but 'end of expect' has to be in the very beginning of the line

    result="$(ssh_to_master 'tail -1 /var/log/puppet/bootstrap_admin_node.log' | awk '/^Fuel node deployment / {print $NF}')"

    case "${result}" in
    complete*)
        return 0
        ;;
    failed*)
        echo "ERROR: Fuel Master setup failed!"
        exit 1
        ;;
    *)
        return 1
        ;;
    esac
}

ssh_to_master() {
    #   $1 - command
    ip=${vm_master_ip:-"10.20.0.2"}
    username=${vm_master_username:-"root"}
    password=${vm_master_password:-"r00tme"}
    SSH_CMD="sshpass -p ${password} ssh ${SSH_OPTIONS} ${username}@${ip}"
    ${SSH_CMD} "$1"
}

scp_from_fuel_master() {
    #   $1 - command
    ip=${vm_master_ip:-"10.20.0.2"}
    username=${vm_master_username:-"root"}
    password=${vm_master_password:-"r00tme"}
    SCP_CMD="sshpass -p r00tme scp ${SSH_OPTIONS}"
    case $1 in
        -r|--recursive)
        SCP_CMD+=" -r "
        shift
        ;;
    esac
    ${SCP_CMD} ${username}@${ip}:$@
}

# This function allows to establish connection to Internet for Fuel master node
enable_outbound_network_for_product_vm() {
    bootproto=${internet_bootproto:-"dhcp"}
    ifcfg=$"DEVICE=eth1\nTYPE=Ethernet\nONBOOT=yes\nNM_CONTROLLED=no\nBOOTPROTO=$bootproto\nPEERDNS=no\nGATEWAY=${internet_gateway}"
    if [ -n "${internet_netmask}" ]; then
        ifcfg+="\nNETMASK=${internet_netmask}"
    fi
    if [ -n "${internet_ip}" ]; then
        ifcfg+="\nIPADDR=${internet_ip}"
    fi
    ssh_to_master "ifup eth1"

}


wait_for_product_vm_to_install() {
    name=$1
    LOG=${LOG:-"log.txt"}
    echo "Waiting for product VM to install. Please do NOT abort the script... "
    echo_logs "######################################################"
    echo_logs "Waiting for start Fuel master                         "
    echo_logs "######################################################"
    run_with_logs await_vm_status $name "running"
    counter=0

    # Loop until master node gets successfully installed
    while ! is_product_vm_operational; do

        let counter=counter+1
        state=$(virsh domstate ${name})
        echo_logs "######################################################"
        echo_logs "$((${counter}/2)) minutes                               "
        echo_logs "Fuel master state: ${state}                           "

        if [ "${state}" = "выключен" -o  "${state}" = "shut off" ]; then
            echo_logs "######################################################"
            echo_logs "Fuel master are stoped                                "
            echo_logs "######################################################"
            #   Change cache mode for master node disk to unsafe
            echo_logs "######################################################"
            echo_logs "Change cache mode for master node disk to unsafe      "
            echo_logs "######################################################"

            run_with_logs change_cache_to_unsafe ${name}
            run_with_logs add_smbios ${name}
            run_with_logs enable_hugepages ${name}

            # Do not open configuration menu during installation fuel master node
            echo_logs "######################################################"
            echo_logs "Don't open configuration menu during installation     "
            echo_logs "######################################################"

            for config in /root/.showfuelmenu /etc/fuel/bootstrap_admin_node.conf; do
                if sudo virt-ls -d ${name} ${config%/*} 2>/dev/null | grep ${config##*/}; then
                    run_with_logs edit_file_on_vm ${name} ${config} "s/showmenu=yes/showmenu=no/"
                fi
            done

            echo_logs "------------------------------------------------------"
            echo_logs "DONE"
            echo_logs

            if [ -n "${internet_interface}" -o "${vm_master_ip}" != "10.20.0.2" -o -n "${url_to_change}" -o -n "${ZUUL_CHANGE}" -o "${run_tests}" == "true" ]; then

                echo_logs "######################################################"
                echo_logs "Mount Fuel master disk to host                        "
                echo_logs "######################################################"

                fuel_disk_directory=$(mktemp -d)
                run_with_logs mount_disk_vm ${name} ${fuel_disk_directory}

                #   Add mos-tempest-runner scripts to fuel master
                if ${run_tests}; then
                    if [ -d mos-tempest-runner ]; then
                        rm -rf mos-tempest-runner
                    fi

                    echo_logs "######################################################"
                    echo_logs "Clone mos-tempest-runner from github.com              "
                    echo_logs "######################################################"
                    local mos_tempest_runner_branch="master"
                    if [ "${MOS_VERSION}" = "6.1" ]; then
                        mos_tempest_runner_branch="stable/6.1"
                    fi
                    run_with_logs git clone https://github.com/Mirantis/mos-tempest-runner.git -b ${mos_tempest_runner_branch}
                    echo_logs "------------------------------------------------------"
                    echo_logs "DONE"
                    echo_logs

                    echo_logs "######################################################"
                    echo_logs "Copy mos-tempest-runner project to Fuel master node   "
                    echo_logs "######################################################"

                    sudo cp -r mos-tempest-runner ${fuel_disk_directory}/tmp/
                    echo_logs "------------------------------------------------------"
                    echo_logs "DONE"
                    echo_logs
                    sync
                fi

                #   Install custom packages
                if [ -n "${ZUUL_CHANGE}" -o -n "${url_to_change}" ]; then

                    echo_logs "######################################################"
                    echo_logs "Install custom packages                               "
                    echo_logs "######################################################"

                    change_packets $name $fuel_disk_directory
                fi

                #   Change ip on master node if in settings file set not default IP(default: 10.20.0.2)
                if [ "${vm_master_ip}" != "10.20.0.2" ]; then

                    echo_logs "#####################################################################################"
                    echo_logs "Change ip on master node if in settings file set not default IP(default: 10.20.0.2)  "
                    echo_logs "#####################################################################################"

                    sudo sed -i "s/^IPADDR.*/IPADDR=${vm_master_ip}/" ${fuel_disk_directory}/etc/sysconfig/network-scripts/ifcfg-eth0
                    sudo sed -i "s/^NETMASK.*/NETMASK=${vm_master_netmask}/" ${fuel_disk_directory}/etc/sysconfig/network-scripts/ifcfg-eth0
                    sudo sed -i "s/^GATEWAY.*/GATEWAY=${vm_master_gateway}/" ${fuel_disk_directory}/etc/sysconfig/network
                    sudo sed -i "s/10.20.0.2/${vm_master_ip}/" ${fuel_disk_directory}/etc/hosts
                    sudo sed -i "s/10.20.0.1/${vm_master_gateway}/" ${fuel_disk_directory}/etc/dnsmasq.upstream
                    sudo sed -i "s/^  ipaddress: .*/  ipaddress: \"${vm_master_ip}\"/" ${fuel_disk_directory}/etc/fuel/astute.yaml
                    sudo sed -i "s/^  netmask: .*/  netmask: \"${vm_master_netmask}\"/" ${fuel_disk_directory}/etc/fuel/astute.yaml
                    sudo sed -i "s/^  cidr: .*/  cidr: \"$(echo ${vm_master_cidr} | sed "s/\//\\\\\//")\"/" ${fuel_disk_directory}/etc/fuel/astute.yaml
                    sudo sed -i "s/^  size: .*/  size: \"${vm_master_net_size}\"/" ${fuel_disk_directory}/etc/fuel/astute.yaml
                    sudo sed -i "s/^  dhcp_pool_start: .*/  dhcp_pool_start: \"${vm_master_dhcp_pool_start}\"/" ${fuel_disk_directory}/etc/fuel/astute.yaml
                    sudo sed -i "s/^  dhcp_pool_end: .*/  dhcp_pool_end: \"${vm_master_dhcp_pool_end}\"/" ${fuel_disk_directory}/etc/fuel/astute.yaml
                fi

                if [ -n "${internet_interface}" ]; then
                    bootproto=${internet_bootproto:-"dhcp"}
                    ifcfg=$"DEVICE=eth1\nTYPE=Ethernet\nONBOOT=yes\nNM_CONTROLLED=no\nBOOTPROTO=$bootproto\nPEERDNS=no\nGATEWAY=${internet_gateway}"
                    if [ -n "${internet_netmask}" ]; then
                        ifcfg+="\nNETMASK=${internet_netmask}"
                    fi
                    if [ -n "${internet_ip}" ]; then
                        ifcfg+="\nIPADDR=${internet_ip}"
                    fi
                    echo -e "${ifcfg}" | sudo tee ${fuel_disk_directory}/etc/sysconfig/network-scripts/ifcfg-eth1
                fi

                # Umount disk to host

                echo_logs "######################################################"
                echo_logs "Umount Fuel master disk to host                       "
                echo_logs "######################################################"
                run_with_logs umount_disk_vm ${fuel_disk_directory}
            fi

            # Start fuel master node

            echo_logs "######################################################"
            echo_logs "Start Fuel master node                                "
            echo_logs "######################################################"
            run_with_logs start_vm ${name}

        fi;
        if [ ${counter} -eq $((${fuel_master_install_timeout}*2)) ]; then
            echo "Fuel Master does not start for ${fuel_master_install_timeout} minutes"
            exit 1
        fi
        sleep 30
        if [ $((counter % 2)) = 0 ]; then
            echo "Waiting start Fuel Master $((${counter}/2)) minutes"
        fi
    done
}

change_packets() {
    name=$1
    fuel_disk_directory=$2
    LOG=${LOG:-"log.txt"}

    # Because this method has cd function we need to know the full path to the log file
    if ! [[ "${LOG}" == /* ]]; then
        LOG="$(pwd)/${LOG}"
    fi

    MOS_NUMVERSION=$(echo ${MOS_VERSION:-0} | awk '{split($0, V, /\./); printf("%d%02d%02d", V[1], V[2], V[3])}')

    # Handle new build system (Perestroyka) for MOS 7.0 and above
    if [ ${MOS_NUMVERSION} -ge 70000 ]; then
        # Choose CentOS version
        case ${MOS_VERSION} in
            7.0)     CENTOS=centos6 ;;
            7.[1-9]) CENTOS=centos7 ;;
            8.*)     CENTOS=centos7 ;;
        esac
        packages_url=${packages_url:-"http://perestroika-repo-tst.infra.mirantis.net/"}
        ubuntu_packages_url="${packages_url}/review/CR-${ZUUL_CHANGE}/mos-repos/ubuntu/${MOS_VERSION}/pool/main/"
        centos_packages_url="${packages_url}/review/CR-${ZUUL_CHANGE}/mos-repos/centos/mos${MOS_VERSION}-${CENTOS}-cluster/os/x86_64/"
        cut_dirs=5
    else
        #   Generate URLs for packages
        packages_url=${packages_url:-"http://osci-obs.vm.mirantis.net:82"}
        ubuntu_packages_url="$packages_url/ubuntu-"
        centos_packages_url="$packages_url/centos-"
        if [ -n "${ZUUL_CHANGE}" ]; then
            change_number=${ZUUL_CHANGE}
            branch=${ZUUL_BRANCH}
            branch_with_split=$(echo ${branch} | awk -F/ '{print $2}')
        elif [ -n "${url_to_change}" ]; then
            change_number=$(echo $url_to_change | awk -F "/" '{print $6}')
            if [ -n "${infra_user}" ]; then
                infra_user+="@"
            fi
            branch=$(ssh -p 29418 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${infra_user}"review.fuel-infra.org gerrit query ${change_number} 2>/dev/null | awk '/branch/ {print $2}')
            branch_with_split=$(echo ${branch} | awk -F/ '{print $2}')
        else echo "WTF? o_O"; exit 1;
        fi
        BRANCH_STATUS=stable
        for b in ${!branches_statuses[*]}; do
            if [ "${branches_statuses[${b}]}" = "${branch_with_split}" ]; then
                BRANCH_STATUS=${branches_statuses[$(( ${b} + 1 ))]}
            fi
        done
        if [ -n "${branch_with_split}" ]; then
            ubuntu_packages_url+="${branch_with_split}-${BRANCH_STATUS}-${change_number}/ubuntu/"
            centos_packages_url+="${branch_with_split}-${BRANCH_STATUS}-${change_number}/centos/"
        elif [ -n "${branch}" ]; then
            ubuntu_packages_url+="fuel-${branch}-${change_number}/ubuntu/"
            centos_packages_url+="fuel-${branch}-${change_number}/centos/"
        elif [ -z "${branch_with_split}" -a -z "${branch}" ]; then
            echo "Branch for packages not found"
            exit 1
        fi
        cut_dirs=2
    fi

    # Wget's --cut-dirs feature requires URL without double slashes
    # Function normalize_url sourced from functions/resources.sh
    ubuntu_packages_url=$(normalize_url ${ubuntu_packages_url})
    centos_packages_url=$(normalize_url ${centos_packages_url})

    if [ -d ${fuel_disk_directory}/etc/puppet/2*/ ]; then
        puppet_folder="${fuel_disk_directory}/etc/puppet/2*"
        centos_packages_folder="${fuel_disk_directory}/var/www/nailgun/2*/centos/x86_64"
        ubuntu_packages_folder="${fuel_disk_directory}/var/www/nailgun/2*/ubuntu/x86_64"
    else
        puppet_folder="${fuel_disk_directory}/etc/puppet"
        centos_packages_folder="${fuel_disk_directory}/var/www/nailgun/centos/fuelweb/x86_64"
        ubuntu_packages_folder="${fuel_disk_directory}/var/www/nailgun/ubuntu/fuelweb/x86_64"
    fi
    #   Logging for variables
    echo_logs
    echo_logs "######################################################"
    echo_logs "Variables for change packages                         "
    echo_logs "######################################################"
    echo_logs "change_number=${change_number}                        "
    echo_logs "branch=${branch}                                      "
    echo_logs "branch_with_split=${branch_with_split}                "
    echo_logs "ubuntu_packages_url=${ubuntu_packages_url}            "
    echo_logs "centos_packages_url=${centos_packages_url}            "
    echo_logs "######################################################"
    echo_logs

    #   Download and replace CentOS packages and backup old CentOS packages
    if [ -z "$(curl ${centos_packages_url} 2>/dev/null | grep "Error 40*")" ]; then
        centos_packages_dir=$(mktemp -d)
        centos_packages_backup="${fuel_disk_directory}/var/centos_packages_backup-$RANDOM"
        sudo mkdir ${centos_packages_backup}
        cd ${centos_packages_dir}
        echo_logs "######################################################"
        echo_logs "wget -r -l 2 ${centos_packages_url} -R "*.src.rpm" -A "*.rpm" -np -nd -q"
        run_with_logs wget -r -l 2 ${centos_packages_url} -R "*.src.rpm" -A "*.rpm" -np -nd -q 2
        echo_logs "------------------------------------------------------"
        echo_logs "DONE"
        echo_logs
        for file in $(ls); do
            file_prefix=$(rpm -qp "${file}" --qf "%{NAME}\n" 2>/dev/null)
            find_old_file="$(find ${centos_packages_folder}/Packages -name "${file_prefix}-[0-9]*")"
            if [ -n "${find_old_file}" ]; then
                sudo mv ${find_old_file} ${centos_packages_backup}
            fi
            sudo cp ${file} ${centos_packages_folder}/Packages
            sync
        done
        cd - 1>/dev/null 2
        rm -rf ${centos_packages_dir}

        #   replace CentOS packages
        echo_logs "######################################################"
        echo_logs "Replace CentOS packages                               "
        echo_logs "######################################################"
        run_with_logs ${TOPDIR:-.}/functions/regenerate_centos_repo.sh ${centos_packages_folder} 1>/dev/null 2
        echo_logs "------------------------------------------------------"
        echo_logs "DONE"
        echo_logs
        sync

        echo_logs "######################################################"
        echo_logs "Replace CentOS packages versions for Fuel mirror      "
        echo_logs "######################################################"
        run_with_logs rpm -qi -p ${centos_packages_folder}/Packages/*.rpm 2>/dev/null | awk -f ${TOPDIR:-.}/functions/versions.awk | sudo tee ${puppet_folder}/manifests/centos-versions.yaml 1>/dev/null 2
        echo_logs "------------------------------------------------------"
        echo_logs "DONE"
        echo_logs
        sync

    else
        echo_logs "Packages for centos repo not found"
    fi

    #   Download Ubuntu packages and replace and backup old packages
    if [ -z "$(curl ${ubuntu_packages_url} 2>/dev/null | grep "Error 40*")" ]; then
        ubuntu_release=$(cat ${ubuntu_packages_folder}/dists/*/Release | awk '/Codename:/ {print $2}')
        if [ -z "${ubuntu_release}" ]; then
            echo "Ubuntu release unspecified. Abort."
            exit 1
        fi

        ubuntu_packages_dir=$(mktemp -d)
        ubuntu_packages_backup="${fuel_disk_directory}/var/ubuntu_packages_backup-$RANDOM"
        sudo mkdir ${ubuntu_packages_backup}
        cd ${ubuntu_packages_dir}
        echo_logs
        echo_logs "######################################################"
        echo_logs "wget -r -l 5 ${ubuntu_packages_url} -A "*.deb" -np -nH --cut-dirs=${cut_dirs:-0} -q 2"
        run_with_logs wget -r -l 5 ${ubuntu_packages_url} -A "*.deb" -np -nH --cut-dirs=${cut_dirs:-0} -q 2
        echo_logs "------------------------------------------------------"
        echo_logs "DONE"
        echo_logs
        for file in $(find . -type f -name "*.deb"); do
            pkg_file=${file##*/}
            pkg_path=${file%/*}
            pkg_path=${pkg_path#./}
            pkg_path=${pkg_path#pool/main/}
            pkg_name=$(echo "${pkg_file}" | awk -F_ '{print $1}')
            found_old_file="$(find ${ubuntu_packages_folder}/pool/main -name "${pkg_name}_[0-9]*")"
            if [ -f "${found_old_file}" ]; then
                sudo mkdir -p ${ubuntu_packages_backup}/${pkg_path}
                sudo mv ${found_old_file} ${ubuntu_packages_backup}/${pkg_path}
            fi
            sudo cp -vf ${file} ${ubuntu_packages_folder}/pool/main/${pkg_path}
            sync
        done
        cd - 1>/dev/null 2
        rm -rf ${ubuntu_packages_dir}

        #   replace Ubuntu packages
        echo_logs "######################################################"
        echo_logs "Replace Ubuntu packages                               "
        echo_logs "######################################################"
        run_with_logs ${TOPDIR:-.}/functions/regenerate_ubuntu_repo.sh ${ubuntu_packages_folder} ${ubuntu_release}
        echo_logs "------------------------------------------------------"
        echo_logs "DONE"
        echo_logs
        sync

        echo_logs "######################################################"
        echo_logs "Replace Ubuntu packages versions for Fuel mirror      "
        echo_logs "######################################################"
        run_with_logs cat ${ubuntu_packages_folder}/dists/${ubuntu_release}/main/binary-amd64/Packages | awk -f ${TOPDIR:-.}/functions/versions.awk | sudo tee ${puppet_folder}/manifests/ubuntu-versions.yaml 1>/dev/null 2
        echo_logs "------------------------------------------------------"
        echo_logs "DONE"
        echo_logs
        sync

    else
        echo_logs "Packages for ubuntu repo not found"
    fi
}

check_network_params() {
    ip=${vm_master_ip:-"10.20.0.2"}
    LOG=${LOG:-"log.txt"}

    await_open_port ${ip} "8000"

    # If has Internet interface, check Internet connectivity
    if [ -n "${internet_interface}" ]; then
        echo_logs "######################################################"
        echo_logs "Set parameters of interface with network              "
        echo_logs "######################################################"
        run_with_logs enable_outbound_network_for_product_vm

        echo -n "Check Internet connection on Fuel Master node...  "

        result=$(ssh_to_master "for i in 1 2 3 4 5; do ping -c 2 google.com || ping -c 2 wikipedia.com || sleep 2; done" 2>>${LOG} | grep icmp_seq)
        # When you are launching command in a sub-shell, there are issues with IFS (internal field separator)
        # and parsing output as a set of strings. So, we are saving original IFS, replacing it, iterating over lines,
        # and changing it back to normal
        #
        # http://blog.edwards-research.com/2010/01/quick-bash-trick-looping-through-output-lines/


        if [ -n "$result" ]; then
            echo_ok
            return 0;
        else
            return 1
        fi
    fi
}

add_sahara_client_tests() {
    ssh_to_master "cat > tempest/scenario/data_processing/etc/sahara_tests.conf <<EOF
[data_processing]

floating_ip_pool='net04_ext'
private_network_id='net04'
flavor_id=2
EOF
"
    ssh_to_master "cp -r tempest/  /home/developer/mos-tempest-runner/tempest/"
}
