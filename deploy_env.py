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

import os

from proboscis import factory

from system_test.helpers.decorators import action
from system_test.helpers.decorators import deferred_decorator
from system_test.helpers.decorators import make_snapshot_if_step_fail
from system_test.helpers.utils import case_factory
from system_test.helpers.utils import load_yaml
from system_test import logger
from system_test.tests import actions_base


class DeployEnv(actions_base.ActionsBase):
    """Deploy cluster for tests

    Scenario:
        1. Create Environment
        2. Upload plugins to the master node if it is required
        3. Install plugins if it is required
        4. Create cluster
        5. Enable plugins if it is required
        6. Add nodes to Environment
        7. Run network checker
        8. Deploy Environment
        9. Run network checker
        10. Run OSTF
    """

    base_group = ['system_test',
                  'system_test.deploy_env']
    actions_order = [
        'setup_master',
        'config_release',
        'make_slaves',
        'revert_slaves',
        'upload_plugins',
        'install_plugins',
        'create_env',
        'enable_plugins',
        'add_nodes',
        'network_check',
        'deploy_cluster',
        'network_check',
        'health_check',
    ]

    def __init__(self, config_file=None):
        super(DeployEnv, self).__init__(config_file)
        self._required_plugins = None

        plugins_config = os.environ.get("PLUGINS_CONFIG_PATH")
        if not plugins_config:
            raise Exception("Path to config file for plugins is empty. "
                            "Please set PLUGINS_CONFIG_PATH env variable.")
        config = load_yaml(plugins_config)
        self.plugins_dependencies = config['dependencies']
        self.plugins_paths = config['paths']
        self.plugins_to_roles = config['plugins_to_roles']

    @property
    def required_plugins(self):
        """Get the list of plugins which are going to be used."""
        if self._required_plugins is None:
            self._required_plugins = set()
            nodes = self.env_config['nodes']
            for plugin_name in self.plugins_paths.keys():
                for node in nodes:
                    if (node['roles'] is not None and
                            self.plugins_to_roles[plugin_name] in node['roles']):
                        self._required_plugins.add(plugin_name)
                        break
            self._sort_required_plugins()

            logger.info("The following plugins will be used: {}".format(
                self._required_plugins))

        return self._required_plugins

    def _sort_required_plugins(self):
        """Sort the list of required plugins considering dependencies."""
        def plugins_compare(x, y):
            if (x in self.plugins_dependencies and
                    y in self.plugins_dependencies[x]):
                return 1
            elif (y in self.plugins_dependencies and
                  x in self.plugins_dependencies[y]):
                return -1
            return 0
        self._required_plugins = sorted(list(self._required_plugins),
                                        cmp=plugins_compare)

    @deferred_decorator([make_snapshot_if_step_fail])
    @action
    def upload_plugins(self):
        """Upload plugins for Fuel if it is required"""
        for plugin_name in self.required_plugins:
            self.plugin_name = plugin_name
            self.plugin_path = self.plugins_paths[plugin_name]
            self.upload_plugin()
            logger.info("{} plugin has been uploaded.".format(plugin_name))

    @deferred_decorator([make_snapshot_if_step_fail])
    @action
    def install_plugins(self):
        """Install plugins for Fuel if it is required"""
        for plugin_name in self.required_plugins:
            self.plugin_name = plugin_name
            self.plugin_path = self.plugins_paths[plugin_name]
            self.install_plugin()
            logger.info("{} plugin has been installed.".format(plugin_name))

    @deferred_decorator([make_snapshot_if_step_fail])
    @action
    def enable_plugins(self):
        """Enable plugins for Fuel if it is required"""
        for plugin_name in self.required_plugins:
            self.plugin_name = plugin_name
            self.plugin_path = self.plugins_paths[plugin_name]
            self.enable_plugin()
            logger.info("{} plugin has been enabled.".format(plugin_name))


@factory
def cases():
    return case_factory(DeployEnv)
