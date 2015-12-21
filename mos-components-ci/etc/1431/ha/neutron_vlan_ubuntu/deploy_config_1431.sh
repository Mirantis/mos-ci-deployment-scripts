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


# Parameters for public network of master node
internet_interface=net-public
internet_int_type=network
internet_bootproto=static
internet_netmask=255.255.255.192
internet_ip=172.16.50.197
internet_gateway=172.16.50.193

kvm_nodes_count=3

mashines_count=3

mashine_1_host=cz7197-kvm.host-telecom.com
mashine_1_user=engineer
mashine_1_role=Operator
mashine_1_password=XSRujdbguyP

mashine_2_host=cz7198-kvm.host-telecom.com
mashine_2_user=engineer
mashine_2_role=Operator
mashine_2_password=XSRujdbguyP

mashine_3_host=cz7199-kvm.host-telecom.com
mashine_3_user=engineer
mashine_3_role=Operator
mashine_3_password=XSRujdbguyP

environment_settings=env_config_1431_neutron_vlan.cfg

public_key_path='~/.ssh/review.fuel-infra.org.id_rsa.pub'

ENABLE_COLOR=false
