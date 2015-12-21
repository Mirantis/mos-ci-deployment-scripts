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


private_interface=br1071
private_int_type=bridge

public_interface=br19
public_int_type=bridge

kvm_nodes_count=3

vm_slave_memory_mb=7168
vm_slave_disk_gb=200

mashines_count=1

mashine_1_host=srv21-srt-ipmi.srt.mirantis.net
mashine_1_user=engineer
mashine_1_role=Operator
mashine_1_password=iKiePh4e

environment_settings=env_config_1071_neutron_gre.cfg

run_tests=false
