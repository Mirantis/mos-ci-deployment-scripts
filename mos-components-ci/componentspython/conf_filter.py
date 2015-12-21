#!/usr/bin/env python

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

import json
import os
import sys

from ConfigParser import SafeConfigParser


STORAGE_LVM = ['volumes_lvm']

STORAGE_CEPH = ['volumes_ceph', 'images_ceph',
                'ephemeral_ceph', 'objects_ceph']

STORAGES = STORAGE_LVM + STORAGE_CEPH

COMPONENTS = ['ceilometer', 'murano', 'sahara']


def main():
    project_info = os.environ.get('ZUUL_PROJECT', '').split('/')
    if len(project_info) == 2 and project_info[0] == 'openstack':
        mos_project = project_info[1]
    else:
        mos_project = ''

    config = SafeConfigParser()
    config.read(sys.argv[1])

    # Enable/disable components
    settings = json.loads(config.get('cluster', 'settings'))
    for component in COMPONENTS:
        if component in mos_project:
            settings[component] = True
        else:
            settings[component] = False

    config.set('cluster', 'settings', json.dumps(settings))

    # Determine if Ceph is used
    use_ceph = False
    for ceph_stor in STORAGE_CEPH:
        use_ceph = use_ceph or settings[ceph_stor]

    # Determine if Cinder LVM is used
    use_lvm = False
    for lvm_stor in STORAGE_LVM:
        use_lvm = use_lvm or settings[lvm_stor]

    # Set correct node roles
    node_roles = json.loads(config.get('cluster', 'node_roles'))
    for node, roles in node_roles.items():
        # Remove mongo if ceilometer will not be installed
        if not settings['ceilometer'] and 'mongo' in roles['roles']:
            roles['roles'].remove('mongo')

        # Remove ceph-osd if Ceph will be not used
        if not use_ceph and 'ceph-osd' in roles['roles']:
            roles['roles'].remove('ceph-osd')

        # Remove cinder if Cinder LVM will be not used
        if not use_lvm and 'cinder' in roles['roles']:
            roles['roles'].remove('cinder')

    config.set('cluster', 'node_roles', json.dumps(node_roles))

    # Writing our configuration file to 'example.cfg'
    with open(sys.argv[1], 'wb') as configfile:
        config.write(configfile)


if __name__ == '__main__':
    main()
