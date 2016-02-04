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

#
# This script performs initial check and configuration of the host system. It:
#   - verifies that all available command-line tools are present on the host system
#   - check that there is no previous installation of Mirantis OpenStack (if there is one, the script deletes it)
#   - creates host-only network interfaces
#
# We are avoiding using 'which' because of http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script 
#

# Include the script with handy functions to operate VMs and VirtualBox networking
source functions/resources.sh

PREPARE_ENV_LOG=${PREPARE_ENV_LOG:-"prepare_env_log.txt"}

# skip checks for LXC env
if [ ! -f "/proc/1/cgroup" ] || grep -q "/$" /proc/1/cgroup; then

sudo apt-get update >>${PREPARE_ENV_LOG}

# Check for kvm
echo -n "Checking for 'kvm'... "
kvm --version >/dev/null 2>&1 || sudo apt-get install kvm -y >>${PREPARE_ENV_LOG} 2>&1 || { echo >&2 "'kvm' is not available in the path, but it's required. Please install 'kvm' package. Aborting."; exit 1; }
echo_ok

# Check for virt-tools
echo -n "Checking for 'virt-tools'... "
virt-edit --version >/dev/null 2>&1 || sudo apt-get install libvirt-dev libvirt-bin libguestfs-tools -y | tee -a install.log || { echo >&2 "'virt-tools' is not available in the path, but it's required. Likely, virt-tools is not installed. Aborting."; exit 1; }
echo_ok

# Check for virt-tools
echo -n "Checking for 'virt-install'... "
virt-install --version >/dev/null 2>&1 || sudo apt-get install virtinst -y >>${PREPARE_ENV_LOG} 2>&1 || { echo >&2 "'virtinst' is not available in the path, but it's required. Likely, virtinst is not installed. Aborting."; exit 1; }
echo_ok

# Check for sshpass
echo -n "Checking for sshpass... "
sshpass -V >/dev/null 2>&1 || sudo apt-get install sshpass -y >>${PREPARE_ENV_LOG} 2>&1 || { echo >&2 "'sshpass' is not available in the path, but it's required. Likely, sshpass is not installed. Aborting."; exit 1; }
echo_ok

# Check for createrepo
echo -n "Checking for createrepo... "
createrepo --version >/dev/null 2>&1 || sudo apt-get install createrepo -y >>${PREPARE_ENV_LOG} 2>&1 || { echo >&2 "'createrepo' is not available in the path, but it's required. Likely, createrepo is not installed. Aborting."; exit 1; }
echo_ok

# Check for rpm
echo -n "Checking for rpm... "
rpm --version >/dev/null 2>&1 || sudo apt-get install rpm -y >>${PREPARE_ENV_LOG} 2>&1 || { echo >&2 "'rpm' is not available in the path, but it's required. Likely, rpm is not installed. Aborting."; exit 1; }
echo_ok

# Check for virsh
echo -n "Checking for 'virsh'... "
virsh -v >/dev/null 2>&1 || sudo apt-get install libvirt-bin -y >>${PREPARE_ENV_LOG} 2>&1 || { echo >&2 "'guestfish' is not available in the path, but it's required. Likely, guestfish is not installed. Aborting."; exit 1; }
echo_ok

# Check for ipmitool
echo -n "Checking for ipmitool... "
ipmitool -V >/dev/null 2>&1 || sudo apt-get install ipmitool -y >>${PREPARE_ENV_LOG} 2>&1 || { echo >&2 "'ipmitool' is not available in the path, but it's required. Likely, ipmitool is not installed. Aborting."; exit 1; }
echo_ok

# Check for pip
echo -n "Checking for python-pip... "
pip -v >/dev/null 2>&1 || sudo apt-get install python-pip python-dev -y >>${PREPARE_ENV_LOG} 2>&1 || { echo >&2 "'python-pip' is not available in the path, but it's required. Likely, python-pip is not installed. Aborting."; exit 1; }
echo_ok

# Check for libmysqlclient-dev
echo -n "Checking for libmysqlclient-dev... "
sudo apt-get install libmysqlclient-dev -y >>${PREPARE_ENV_LOG} 2>&1 || { echo >&2 "'libmysqlclient-dev' is not available in the path, but it's required. Likely, libmysqlclient-dev is not installed. Aborting."; exit 1; }
echo_ok

# Check for libpq-dev
echo -n "Checking for libpq-dev... "
sudo apt-get install libpq-dev -y >>${PREPARE_ENV_LOG} 2>&1 || { echo >&2 "'libpq-dev' is not available in the path, but it's required. Likely, libpq-dev is not installed. Aborting."; exit 1; }
echo_ok

# Check for libffi-dev
echo -n "Checking for libffi-dev... "
sudo apt-get install libffi-dev -y >>${PREPARE_ENV_LOG} 2>&1 || { echo >&2 "'libffi-dev' is not available in the path, but it's required. Likely, libffi-dev is not installed. Aborting."; exit 1; }
echo_ok

# Check for e2fsprogs
echo -n "Checking for e2fsprogs... "
uuidgen -V >/dev/null 2>&1 || sudo apt-get install e2fsprogs -y >>${PREPARE_ENV_LOG} 2>&1 || { echo >&2 "'e2fsprogs' is not available in the path, but it's required. Likely, e2fsprogs is not installed. Aborting."; exit 1; }
echo_ok

# Check for python-libtorrent
echo -n "Checking for python-libtorrent... "
python -c "import libtorrent" >/dev/null 2>&1 || sudo apt-get install python-libtorrent -y >>${PREPARE_ENV_LOG} 2>&1 || { echo >&2 "'python-libtorrent' is not available in the path, but it's required. Likely, python-libtorrent is not installed. Aborting."; exit 1; }
echo_ok

# Check for tox
echo -n "Checking for tox... "
tox --version >/dev/null 2>&1 || { sudo pip install tox >>${PREPARE_ENV_LOG} 2>&1; } || { echo >&2 "'tox' is not available in the path, but it's required. Likely, tox is not installed. Aborting."; exit 1; }
echo_ok

fi

# Check for add vibvirtd group to user and user has permissions for r/w on libvirt folders
echo -n "Checking for add vibvirtd group to user... "
username=$(echo $USER)
if [ -z "$(groups | grep libvirtd)" ]; then
    sudo usermod -a -G libvirtd ${username}
fi
echo_ok

echo -n "Checking for user has permissions for r/w on libvirt folders... "
if [[ -d ~/.virtinst/ ]]; then
    if [ "$(stat -c %U  ~/.virtinst/)" != "${username}" -o "$(stat -c %G  ~/.virtinst/)" != "${username}" ]; then
        sudo chown -R ${username}:${username} ~/.virtinst/
    fi
fi

if [[ -d ~/.virt-manager/ ]]; then
    if [ "$(stat -c %U  ~/.virt-manager/)" != "${username}" -o "$(stat -c %G  ~/.virt-manager/)" != "${username}" ]; then
        sudo chown -R ${username}:${username} ~/.virt-manager/
    fi
fi
echo_ok

# Check for master Fuel ISO image to be available
echo -n "Checking for Mirantis OpenStack ISO image... "
if [ -z "${iso_path}" ]; then

    DOWNLOAD_ISO=${DOWNLOAD_ISO:-false}

    if ${DOWNLOAD_ISO}; then
        actions/iso_grabber.sh
    else
        echo "ISO file not specified, attempt to find ISO file."
    fi
    if [ -z "${iso_path}" ]; then
        find_iso
        iso_path=${RETVAL}
    fi
fi
echo_ok

# Check for environment settings to be available
echo -n "Checking for environment settings... "
if [ ! -f $environment_settings ]; then
    echo "Environment settings is not found."
    exit 1
fi
echo_ok

# Check for savanna ISO settings to be available
echo -n "Checking for ISO settings... "
if [ ! -f iso_settings.py -a ! -f etc/iso_settings.py -a ! -f python/iso_settings.py ]; then
    echo "ISO settings is not found."
    exit 1
fi
echo_ok

if [ ! -f "/proc/1/cgroup" ] || grep -q "/$" /proc/1/cgroup; then
    #Check for network
    echo -n "Checking for network settings... "
    ifconfig $private_interface &>/dev/null || virsh net-info $private_interface &>/dev/null
    check_return_code_after_command_execution $? "info for interface:$private_interface not found, please change network settings or parameters in config file"
    if [ ! -z "$public_interface" ]; then
        ifconfig $public_interface &>/dev/null || virsh net-info $public_interface &>/dev/null
        check_return_code_after_command_execution $? "info for interface:$public_interface not found, please change network settings or parameters in config file"
    fi
    echo_ok
fi

# Report success
echo "Setup is done."
