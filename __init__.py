#    Copyright 2015 Mirantis, Inc.
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
import fuelweb_test
from proboscis import register


logger = fuelweb_test.logger

# Dark magic with hardcode for the fuel-qa moster:
from system_test.tests import deploy_env  # noqa


def define_custom_groups():
    # Should move to system_test.__init__.py after upgrade devops to 2.9.13
    groups_list = [
        {"groups": ["system_test.deploy_env"],
         "depends": [
             "system_test.deploy_env("
             "3_controllers_2compute_neutron_env)"]}
    ]

    for new_group in groups_list:
        register(groups=new_group['groups'],
                 depends_on_groups=new_group['depends'])
