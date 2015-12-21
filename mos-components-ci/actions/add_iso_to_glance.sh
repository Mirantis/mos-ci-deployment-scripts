#!/bin/bash

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
# This script adds images to glance on deployed environment.
#

env_ip=$1

source functions/resources.sh

test -f mos_version.env && source mos_version.env

add_iso=${add_iso_to_glance:-false}
LOG=${LOG:-"log.txt"}

if ${add_iso}; then
    {
    echo "######################################################"
    echo "Configure Environment                                 "
    echo "######################################################"
    } | tee -a ${LOG}
    path=${public_key_path:-'~/.ssh/id_rsa.pub'}

    if [ ! -f componentspython/settings.py ]; then
        if [ -f iso_settings.py ]; then
            cp iso_settings.py componentspython/settings.py
        elif [ -f etc/iso_settings.py ]; then
            cp etc/iso_settings.py componentspython/settings.py
        fi
    fi

    if [ ! -f componentspython/settings.py ]; then
        echo "Config file for add glance images and configure security groups not found. Aborting."; exit 1;
    fi

    proto=$(python -c 'import componentspython.nailgun as fuel; print fuel.keystone_proto()' "${environment_settings}" "${vm_master_ip}" 2>/dev/null)

    export CONFIGURE_ENV_LOG=${CONFIGURE_ENV_LOG:-"configure_env_log.txt"}
    configure_env "${env_ip}" "${path}" "${MOS_VERSION}" "${proto}"
    check_return_code_after_command_execution $? "Fail while add images to OpenStack"
fi

