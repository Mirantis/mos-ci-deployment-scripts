#!/bin/bash 

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

# If you want to change packages, please uncomment and set
# value for these variables.
#
#
#  url_to_change=
#  infra_user=

#
private_interface=net-admin
private_int_type=network
private_int_model=e1000

#
public_interface=net-all
public_int_type=network
public_int_model=e1000

# Parameters for public network of master node
# internet_interface=
# internet_int_type=
# internet_bootproto=
# internet_netmask=
# internet_ip=
# internet_gateway=

#
fuel_master_install_timeout=60

# Get the first available ISO from the directory 'iso'
#iso_path=

# Every Mirantis OpenStack machine name will start from this prefix
vm_name_prefix=fuel-

#
# kvm_nodes_count=
delete_old_kvms=false

# Master node settings
vm_master_cpu_cores=2
vm_master_memory_mb=1024
vm_master_disk_gb=50
vm_master_disk_bus=scsi

# These settings will be used to check if master node has installed or not.
# If you modify networking params for master node during the boot time
#   (i.e. if you pressed Tab in a boot loader and modified params),
#   make sure that these values reflect that change.
vm_master_ip=10.20.0.2
# vm_master_gateway=10.20.0.1
# vm_master_netmask=255.255.255.0
# vm_master_cidr=10.20.0.2/24
# vm_master_net_size=256
# vm_master_dhcp_pool_start=10.20.0.3
# vm_master_dhcp_pool_end=10.20.0.254

# Slave node settings
# Default cpu number, if no "version" specified in node_roles
vm_slave_cpu_cores=4
# When parameter "version" is specified bellow parameters are used
vm_slave_cpu_controller_cores=4
vm_slave_cpu_compute_cores=4
vm_slave_disk_gb=300
vm_slave_disk_bus=scsi
# Default memory size, if no "version" specified in node_roles
vm_slave_memory_mb=8192
# When parameter "version" is specified bellow parameters are used
vm_slave_memory_controller_mb=12288
vm_slave_memory_compute_mb=6144

# Settings for ipmi mashines

# mashines_count=

# mashine_1_host=
# mashine_1_user=
# mashine_1_role=
# mashine_1_password=

# Parameters for configure env

add_iso_to_glance=true

# Name for env_settings file

# environment_settings=

# Install and run tempest tests using mos-scale project

run_tests=true
# public_key_path=

# Log parameters

ENABLE_COLOR=true

feature_enable_hugepages=false
feature_add_smbios=false

PRODUCT_JENKINS_URL='https://product-ci.infra.mirantis.net/'
