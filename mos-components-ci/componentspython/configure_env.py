#    Copyright 2014 Mirantis, Inc.
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

import getpass
import hashlib
import logging
import os
import settings
from sys import argv
import urllib

from glanceclient.client import Client as Glance
from keystoneclient.v2_0 import Client as Keystone
from novaclient.client import Client as Nova


def logger_func():
    log_file = os.environ.get("CONFIGURE_ENV_LOG", "configure_env_log.txt")
    if log_file.startswith('/'):
        logfile = log_file
    else:
        logfile = os.path.join(os.path.join(os.getcwd()), log_file)

    logging.basicConfig(level=logging.DEBUG,
                        format='%(asctime)s - %(levelname)s %(filename)s:'
                        '%(lineno)d -- %(message)s',
                        filename=logfile,
                        filemode='w')

    console = logging.StreamHandler()
    console.setLevel(logging.INFO)
    formatter = logging.Formatter('%(asctime)s - %(levelname)s %(filename)s:'
                                  '%(lineno)d -- %(message)s')
    console.setFormatter(formatter)

    logger = logging.getLogger(__name__)
    logger.addHandler(console)
    return logger

LOGGER = logger_func()


class Common():
    # This script adds Images to glance and configures security groups.
    def __init__(self, controller_ip, keystone_proto='http'):
        self.controller_ip = controller_ip
        self.keystone_proto = keystone_proto

    def _get_auth_url(self):
        LOGGER.debug('Slave-01 is {0}'.format(self.controller_ip))
        return '{0}://{1}:5000/v2.0/'.format(self.keystone_proto,
                                             self.controller_ip)

    def goodbye_security(self, pkey_path):
        auth_url = self._get_auth_url()
        nova = Nova("2", settings.SERVTEST_USERNAME,
                    settings.SERVTEST_PASSWORD, settings.SERVTEST_TENANT,
                    auth_url, service_type='compute', no_cache=True,
                    insecure=True)
        LOGGER.info('Permit all TCP and ICMP in security group default')
        secgroup = nova.security_groups.find(name='default')

        for rule in secgroup.rules:
            nova.security_group_rules.delete(rule['id'])

        nova.security_group_rules.create(secgroup.id,
                                         ip_protocol='tcp',
                                         from_port=1,
                                         to_port=65535)
        nova.security_group_rules.create(secgroup.id,
                                         ip_protocol='udp',
                                         from_port=1,
                                         to_port=65535)
        nova.security_group_rules.create(secgroup.id,
                                         ip_protocol='icmp',
                                         from_port=-1,
                                         to_port=-1)
        key_name = getpass.getuser()
        if not nova.keypairs.findall(name=key_name):
            LOGGER.info("Adding keys")
            with open(os.path.expanduser(pkey_path)) as fpubkey:
                nova.keypairs.create(name=key_name, public_key=fpubkey.read())
        try:
            nova.flavors.find(name='sahara')
        except Exception:
            LOGGER.info("Adding sahara flavor")
            nova.flavors.create('sahara', 2048, 1, 40)

    def check_image(self, url, image, md5,
                    path=settings.SERVTEST_LOCAL_PATH):
        download_url = "{0}/{1}".format(url, image)
        local_path = os.path.expanduser("{0}/{1}".format(path, image))
        LOGGER.debug('Check md5 {0} of image {1}/{2}'.format(md5, path, image))
        if not os.path.isfile(local_path):
            urllib.urlretrieve(download_url, local_path)
        if md5:
            with open(local_path, mode='rb') as fimage:
                digits = hashlib.md5()
                while True:
                    buf = fimage.read(4096)
                    if not buf:
                        break
                    digits.update(buf)
                md5_local = digits.hexdigest()
            if md5_local != md5:
                LOGGER.debug('MD5 is not correct, download {0} to {1}'.format(
                             download_url, local_path))
                urllib.urlretrieve(download_url, local_path)

    def image_import(self, properties, local_path, image, image_name):
        LOGGER.info('Import image {0}/{1} to glance'.format(local_path, image))
        auth_url = self._get_auth_url()
        LOGGER.debug('Auth URL is {0}'.format(auth_url))
        keystone = Keystone(username=settings.SERVTEST_USERNAME,
                            password=settings.SERVTEST_PASSWORD,
                            tenant_name=settings.SERVTEST_TENANT,
                            auth_url=auth_url,
                            verify=False)
        token = keystone.auth_token
        LOGGER.debug('Token is {0}'.format(token))
        glance_endpoint = keystone.service_catalog.url_for(
            service_type='image', endpoint_type='publicURL')
        LOGGER.debug('Glance endpoind is {0}'.format(glance_endpoint))
        glance = Glance("2", endpoint=glance_endpoint, token=token,
                        insecure=True)
        LOGGER.debug('Importing {0}'.format(image))
        with open(os.path.expanduser('{0}/{1}'.format(local_path,
                                                      image))) as fimage:
            image = glance.images.create(name=image_name,
                                         disk_format='qcow2',
                                         container_format='bare',
                                         visibility='public',
                                         properties=str(properties))
            glance.images.upload(image.id, fimage)
            for tag_name, value in properties.iteritems():
                glance.image_tags.update(image.id, tag_name)
                tag = {tag_name: value}
                glance.images.update(image.id, **tag)


def main():

    controller = argv[1]
    public_key_path = argv[2]
    mos_version = argv[3]
    keystone_proto = argv[4]

    common_func = Common(controller, keystone_proto)
    for image_info in settings.images:
        if mos_version in image_info['mos_versions']:
            LOGGER.debug(image_info)
            common_func.check_image(
                image_info['url'],
                image_info['image'],
                image_info['md5sum'])
            common_func.image_import(
                image_info['meta'],
                settings.SERVTEST_LOCAL_PATH,
                image_info['image'],
                image_info['name'])
    common_func.goodbye_security(public_key_path)

    LOGGER.info('All done !')
