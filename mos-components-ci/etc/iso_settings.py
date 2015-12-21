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

# Services tests
SERVTEST_LOCAL_PATH = '~/images'
SERVTEST_USERNAME = 'admin'
SERVTEST_PASSWORD = SERVTEST_USERNAME
SERVTEST_TENANT = SERVTEST_USERNAME


# TODO(esikachev): Need add ambari image, when sahara-image-elements
# be able to build them
images = [
    {
        "url": "http://sahara-files.mirantis.com/mos70",
        "image": "sahara-kilo-vanilla-2.6.0-ubuntu-14.04.qcow2",
        "mos_versions": ['7.0'],
        "name": "vanilla2-70",
        "md5sum": "c794e8066b8893eaa15ebf44ee55e9ee",
        "meta": {'_sahara_tag_2.6.0': 'True', '_sahara_tag_vanilla': 'True',
                 '_sahara_username': 'ubuntu'}
    },
    {
        "url": "http://sahara-files.mirantis.com/mos80",
        "image": "sahara-liberty-vanilla-2.7.1-ubuntu-14.04.qcow2",
        "mos_versions": ['8.0'],
        "name": "sahara",
        "md5sum": "3da49911332fc46db0c5fb7c197e3a77",
        "meta": {'_sahara_tag_2.7.1': 'True', '_sahara_tag_vanilla': 'True',
                 '_sahara_username': 'ubuntu'}
    },
    {
        "url": "http://sahara-files.mirantis.com/images/upstream/liberty",
        "image": "sahara-liberty-ambari-2.2-centos-6.6.qcow2.qcow2",
        "mos_versions": ['8.0'],
        "name": "ambari22",
        "md5sum": "445086de3e9a9562201ff30276af5496",
        "meta": {'_sahara_tag_2.2': 'True', '_sahara_tag_ambari': 'True',
                 '_sahara_tag_2.3': 'True', '_sahara_username': 'cloud_user'}
    },
    {
        "url": "http://sahara-files.mirantis.com/images/upstream/liberty",
        "image": "sahara-liberty-cdh-5.4.0-ubuntu-14.04.qcow2",
        "mos_versions": ['8.0'],
        "name": "cdh54",
        "md5sum": "f5c833d2d34a41ea9b52a6c1f95054be",
        "meta": {'_sahara_tag_5.4.0': 'True', '_sahara_tag_cdh': 'True',
                 '_sahara_username': 'ubuntu'}
    },
    {
        "url": "http://sahara-files.mirantis.com/images/upstream/liberty",
        "image": "sahara-liberty-mapr-5.0.0-ubuntu-14.04.qcow2",
        "mos_versions": ['8.0'],
        "name": "mapr5",
        "md5sum": "77d16c462311a7c5db9144e1e8ab30a8",
        "meta": {'_sahara_tag_5.0.0.mrv2': 'True', '_sahara_tag_mapr': 'True',
                 '_sahara_username': 'ubuntu'}
    },
    {
        "url": "http://sahara-files.mirantis.com/mos70",
        "image": "sahara-kilo-cdh-5.4.0-ubuntu-12.04.qcow2",
        "mos_versions": ['7.0'],
        "name": "cdh540",
        "md5sum": "3c40ca050305eac7d5fdfb33f4af8d66",
        "meta": {'_sahara_tag_5.4.0': 'True', '_sahara_tag_cdh': 'True',
                 '_sahara_username': 'ubuntu'}
    },
    {
        "url": "http://sahara-files.mirantis.com/mos70",
        "image": "sahara-kilo-mapr-4.0.2-ubuntu-14.04.qcow2",
        "mos_versions": ['7.0'],
        "name": "mapr402",
        "md5sum": "1191778635972e9559474a3a5b9a8b54",
        "meta": {'_sahara_tag_4.0.2.mrv2': 'True', '_sahara_tag_mapr': 'True',
                 '_sahara_username': 'ubuntu'}
    },
    {
        "url": "http://sahara-files.mirantis.com/mos70",
        "image": "sahara-kilo-spark-1.3.1-ubuntu-14.04.qcow2",
        "mos_versions": ['7.0', '8.0'],
        "name": "spark131",
        "md5sum": "4004994e10920f23b2b2a4a3f47281d3",
        "meta": {'_sahara_tag_1.3.1': 'True', '_sahara_tag_spark': 'True',
                 '_sahara_username': 'ubuntu'}
    },
    {
        "url": "http://sahara-files.mirantis.com/mos61",
        "image": "sahara-juno-vanilla-2.4.1-ubuntu-14.04.qcow2",
        "mos_versions": ['6.0', '6.1'],
        "name": "vanilla2-60",
        "md5sum": "04603154484f58827e02244cb8efdd17",
        "meta": {'_sahara_tag_2.4.1': 'True', '_sahara_tag_vanilla': 'True',
                 '_sahara_username': 'ubuntu'}
    },
    {
        "url": "http://sahara-files.mirantis.com/mos61",
        "image": "sahara-juno-cdh-5-ubuntu-12.04.qcow2",
        "mos_versions": ['6.0', '6.1'],
        "name": "cdh5",
        "md5sum": "f2c989057d1dbf373069867fa6123b84",
        "meta": {'_sahara_tag_5': 'True', '_sahara_tag_cdh': 'True',
                 '_sahara_username': 'ubuntu'}
    },
    {
        "url": "http://sahara-files.mirantis.com/mos61",
        "image": "sahara-juno-hdp-2.0.6-centos-6.6.qcow2",
        "mos_versions": ['6.0', '6.1'],
        "name": "hdp2",
        "md5sum": "e3435ad985d8bae17a3d670e2074fcd4",
        "meta": {'_sahara_tag_2.0.6': 'True', '_sahara_tag_hdp': 'True',
                 '_sahara_username': 'cloud-user'}
    },
    {
        "url": "http://sahara-files.mirantis.com/mos61",
        "image": "sahara-juno-hdp-2.2.0-centos-6.6.qcow2",
        "mos_versions": ['6.1'],
        "name": "hdp22",
        "md5sum": "20763652e7ef6a741a5dc666a48a700f",
        "meta": {'_sahara_tag_2.2.0': 'True', '_sahara_tag_hdp': 'True',
                 '_sahara_username': 'cloud-user'}
    },
    {
        "url": "http://sahara-files.mirantis.com/mos61",
        "image": "sahara-juno-spark-1.0.0-ubuntu-14.04.qcow2",
        "mos_versions": ['6.1'],
        "name": "spark1",
        "md5sum": "6a54136d5bf3750c66788fc4fe305c5d",
        "meta": {'_sahara_tag_1.0.0': 'True', '_sahara_tag_spark': 'True',
                 '_sahara_username': 'ubuntu'}
    },
    {
        "url": "http://sahara-files.mirantis.com/mos61",
        "image": "sahara-juno-vanilla-1.2.1-ubuntu-14.04.qcow2",
        "mos_versions": ['6.0', '6.1'],
        "name": "vanilla1",
        "md5sum": "1e0e6e8b141f1bc1f8486ac9519bc162",
        "meta": {'_sahara_tag_1.2.1': 'True', '_sahara_tag_vanilla': 'True',
                 '_sahara_username': 'ubuntu'}
    },
    {
        "url": "http://murano-files.mirantis.com",
        "mos_versions": ['6.0'],
        "image": "F17-x86_64-cfntools.qcow2",
        "name": "F17-x86_64-cfntools",
        "md5sum": "afab0f79bac770d61d24b4d0560b5f70",
        "meta": {}
    },
    {
        "url": "http://storage.apps.openstack.org/images",
        "image": "ubuntu-14.04-m-agent.qcow2",
        "mos_versions": ['6.1', '7.0', '8.0'],
        "name": "ubuntu-14.04-m-agent.qcow2",
        "md5sum": "cbd9ded8587b98d144d9cf0faea991a9",
        "meta": {"type": "linux",
                 "title": "Ubuntu with pre installed murano-agent"}
    },
    {
        "url": "http://storage.apps.openstack.org/images",
        "image": "debian-8-m-agent.qcow2",
        "mos_versions": ['6.1', '7.0', '8.0'],
        "name": "debian-8-m-agent.qcow2",
        "md5sum": "6fa21e861d08a7cc2fbc40b0c99745a7",
        "meta": {"type": "linux",
                 "title": "Debian with pre-installed murano-agent"}
    },
    {
        "url": "http://storage.apps.openstack.org/images",
        "image": "debian-8-docker.qcow2",
        "mos_versions": ['6.1', '7.0', '8.0'],
        "name": "debian-8-docker.qcow2",
        "md5sum": "f9f2466c39dac98a1e4ed03fb5701225",
        "meta": {"type": "linux",
                 "title": "Debian with pre-installed docker and murano-agent"}
    },
    {
        "url": "http://storage.apps.openstack.org/images",
        "image": "ubuntu14.04-x64-kubernetes.qcow2",
        "mos_versions": ['6.1', '7.0', '8.0'],
        "name": "ubuntu14.04-x64-kubernetes",
        "md5sum": "0d959023d0551d68f9dc7139cb814e92",
        "meta": {"type": "linux", "title": "ubuntu14.04-x64-kubernetes"}
    }
]
