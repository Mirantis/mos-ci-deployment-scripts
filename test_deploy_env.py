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

import collections
import os

import dpath.util

from system_test import action
from system_test.actions import BaseActions
from system_test.core.discover import load_yaml
from system_test import logger
from system_test import testcase
from system_test.tests import ActionTest


@testcase(groups=['system_test.deploy_env'])
class DeployEnv(ActionTest, BaseActions):
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

    base_group = ['system_test', 'system_test.deploy_env']
    actions_order = [
        'setup_master',
        'config_release',
        'make_slaves',
        'revert_slaves',
        'install_plugins',
        'create_env',
        'config_plugins',
        'add_nodes',
        'override_config',
        'update_nodes',
        'network_check',
        'deploy_cluster',
        'network_check',
        'health_check',
    ]

    def __init__(self, config_file=None):
        super(DeployEnv, self).__init__(config_file)
        self._fuel_plugins = None

        self.plugins_folder = os.environ.get("PLUGINS_PATH", '.')

    @property
    def fuel_plugins(self):
        if self._fuel_plugins is None:
            self._fuel_plugins = collections.OrderedDict()
            for plugin in self.full_config.get('plugins', []):
                for k, v in plugin.items():
                    self._fuel_plugins[k] = v
        return self._fuel_plugins

    def _get_plugin_path(self, plugin_name):
        files = os.listdir(self.plugins_folder)
        variants = [x for x in files if plugin_name in x]
        assert len(variants) == 1, (
            "Can't find plugin file for `{0}` "
            "within `{1}`").format(plugin_name, files)
        plugin_filename = variants[0]
        return os.path.join(self.plugins_folder, plugin_filename)

    @action
    def install_plugins(self):
        """Upload and install plugins for Fuel if it is required"""
        logger.info("The following plugins will be used: {}".format(
            self.fuel_plugins))
        for plugin_name in self.fuel_plugins:
            self.plugin_path = self._get_plugin_path(plugin_name)
            self.upload_plugin()
            logger.info("{} plugin has been uploaded.".format(plugin_name))
            self.install_plugin()
            logger.info("{} plugin has been installed.".format(plugin_name))

    def _get_settings_path(self, data, glob):
        """Returns expanded path in data matched by glob"""
        paths = [x[0] for x in dpath.util.search(data, glob, yielded=True)]
        assert len(paths) == 1, (
            'Should be only one path for glob `{glob}`,'
            ' founded: {paths}').format(glob=glob, paths=paths)
        return paths[0]

    @action
    def config_plugins(self):
        """Config plugins for Fuel"""
        configs = {}
        for plugin_name, plugin_config in self.fuel_plugins.items():
            plugin_path_prefix = '/*/{0}'.format(plugin_name)
            # Enable plugin
            configs['{0}/metadata/enabled'.format(plugin_path_prefix)] = True
            if plugin_config is not None and 'config_file' in plugin_config:
                config_data = load_yaml(plugin_config['config_file'])
                for k, v in config_data.items():
                    configs['{0}/**/{1}/value'.format(plugin_path_prefix,
                                                      k)] = v
            # Enable propagate_task_deploy for `ldap` plugin
            if plugin_name == 'ldap':
                configs['**/propagate_task_deploy/value'] = True
            logger.info("{} plugin has been enabled.".format(plugin_name))
        self._update_cluster_attributes(configs)

    def _update_dict_values(self, replacements_dict, dict_values):
        for glob, value in replacements_dict.items():
            path = self._get_settings_path(dict_values, glob)
            logger.info('Set `{path}` to `{value}`'.format(path=path,
                                                           value=dict_values))
            dpath.util.set(dict_values, path, value)
        return dict_values

    def _update_cluster_attributes(self, replacements_dict):
        """Apply replacements to fuel attributes (settings)"""
        if not replacements_dict:
            return

        attrs = self.fuel_web.client.get_cluster_attributes(self.cluster_id)
        updated_attrs = self._update_dict_values(replacements_dict, attrs)

        self.fuel_web.client.update_cluster_attributes(
            self.cluster_id, updated_attrs)

    def _update_network_params(self, replacements_dict):
        if not replacements_dict:
            return

        params = self.fuel_web.client.get_networks(
            cluster_id=self.cluster_id)

        networking_parameters = replacements_dict.get(
            'networking_parameters', {})

        updated_net_params = self._update_dict_values(
            replacements_dict=networking_parameters,
            dict_values=params['networking_parameters']
        )

        self.fuel_web.client.update_network(
            cluster_id=self.cluster_id,
            networking_parameters=updated_net_params
        )

    @action
    def override_config(self):
        """Override fuel config"""
        overrides = self.full_config.get('overrides', {})

        self._update_cluster_attributes(overrides.get('attributes', {}))
        self._update_network_params(overrides.get('networks', {}))

    def _get_interface_index(self, replacements_dict, total_interface_count):
        """Get interface number and convert it to array index"""
        try:
            number = replacements_dict['number']
        except AttributeError:
            raise AttributeError(
                "'number' parameter should be set for each "
                "interface which should be updated nodes."
            )

        assert 1 <= number <= total_interface_count, (
            "'number' of interface should be from '1' to '{0}'.").format(
                total_interface_count)

        return number - 1

    def _update_node_interfaces(self, node_id, replacements_list):
        if not replacements_list:
            return

        interfaces_list = self.fuel_web.client.get_node_interfaces(
            node_id=node_id)

        for interface_repl in replacements_list:
            interface_index = self._get_interface_index(
                replacements_dict=interface_repl,
                total_interface_count=len(interfaces_list)
            )
            interface_dict = interfaces_list[interface_index]

            params_dict = interface_repl.get('params', {})
            self._update_dict_values(replacements_dict=params_dict,
                                     dict_values=interface_dict)

        self.fuel_web.client.put_node_interfaces(
            [{'id': node_id, 'interfaces': interfaces_list}])

    def _update_node_attributes(self, node_id, replacements_dict):
        if not replacements_dict:
            return

        attributes_dict = self.fuel_web.client.get_node_attributes(
            node_id=node_id)

        self._update_dict_values(replacements_dict=replacements_dict,
                                 dict_values=attributes_dict)

        self.fuel_web.client.upload_node_attributes(
            attributes=attributes_dict,
            node_id=node_id
        )

    @action
    def update_nodes(self):
        """Update attributes of nodes"""
        nodes = self.full_config.get('update_nodes', [])

        for node in nodes:
            nailgun_node = self.fuel_web.get_nailgun_node_by_name(node['name'])

            interfaces_list = node.get('interfaces', [])
            self._update_node_interfaces(node_id=nailgun_node['id'],
                                         replacements_list=interfaces_list)

            attributes_dict = node.get('attributes', {})
            self._update_node_attributes(node_id=nailgun_node['id'],
                                         replacements_dict=attributes_dict)
