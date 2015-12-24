#    Copyright 2015 Mirantis, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE_2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

from proboscis import register
from proboscis import factory
from proboscis.asserts import assert_true

from system_test.tests import actions_base
from system_test.helpers.utils import case_factory
from system_test.helpers.decorators import deferred_decorator
from system_test.helpers.decorators import make_snapshot_if_step_fail
from system_test.helpers.decorators import action


def define_custom_groups():
    # Should move to system_test.__init__.py after upgrade devops to 2.9.13
    groups_list = [
        {"groups": ["system_test.deploy_env"],
         "depends": [
             "system_test.deploy_env("
             "ceph_all_on_neutron_vlan)"]}
    ]

    for new_group in groups_list:
        register(groups=new_group['groups'],
                 depends_on_groups=new_group['depends'])


class DeployEnv(actions_base.ActionsBase):
    """Deploy cluster for tests

    Scenario:
        1. Create Environment
        2. Add nodes to Environment
        3. Run network checker
        4. Deploy Environment

    """

    base_group = ['system_test',
                  'system_test.deploy_env']
    actions_order = [
        'setup_master',
        'config_release',
        'make_slaves',
        'revert_slaves',
        'create_env',
        'add_nodes',
        'network_check',
        'deploy_cluster'
    ]

@factory
def cases():
    return case_factory(DeployEnv)
