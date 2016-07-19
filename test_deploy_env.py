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
from system_test.core.discover import load_yaml
from system_test import logger
from system_test import testcase

from system_test.tests import ActionTest
from system_test.actions import BaseActions


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
            logger.info("{} plugin has been enabled.".format(plugin_name))
        self._apply_cluster_attributes(configs)

    def _apply_cluster_attributes(self, replacements):
        """Apply replacements to fuel attributes (settings)"""
        if len(replacements) == 0:
            return
        attrs = self.fuel_web.client.get_cluster_attributes(self.cluster_id)
        for glob, value in replacements.items():
            path = self._get_settings_path(attrs, glob)
            logger.info('Set `{path}` to `{value}`'.format(path=path,
                                                           value=value))
            dpath.util.set(attrs, path, value)
        self.fuel_web.client.update_cluster_attributes(self.cluster_id, attrs)

    @action
    def override_config(self):
        """Override fuel config"""
        overrides = self.full_config.get('overrides', {})
        self._apply_cluster_attributes(overrides.get('attributes', {}))
