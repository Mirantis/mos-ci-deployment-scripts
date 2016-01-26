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


private_interface=net-admin

internet_interface=net-ext
internet_int_type=bridge
internet_bootproto=dhcp
#internet_netmask=
#internet_ip=
internet_gateway=172.18.173.1

kvm_nodes_count=0

vm_slave_memory_mb=7168
vm_slave_disk_gb=200

mashines_count=5

mashine_1_host=cz7858-kvm.host-telecom.com
mashine_1_user=engineer
mashine_1_role=Operator
mashine_1_password=UrioJ5jiet

mashine_2_host=cz7859-kvm.host-telecom.com
mashine_2_user=engineer
mashine_2_role=Operator
mashine_2_password=UrioJ5jiet

mashine_3_host=cz7860-kvm.host-telecom.com
mashine_3_user=engineer
mashine_3_role=Operator
mashine_3_password=UrioJ5jiet

mashine_4_host=cz7868-kvm.host-telecom.com
mashine_4_user=engineer
mashine_4_role=Operator
mashine_4_password=UrioJ5jiet

mashine_5_host=cz7869-kvm.host-telecom.com
mashine_5_user=engineer
mashine_5_role=Operator
mashine_5_password=UrioJ5jiet



environment_settings=env_config.cfg

run_tests=false
