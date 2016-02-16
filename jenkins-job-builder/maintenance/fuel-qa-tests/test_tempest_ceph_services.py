#    Copyright 2016 Mirantis, Inc.
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

from proboscis import test

from fuelweb_test.helpers.decorators import log_snapshot_after_test
from fuelweb_test import settings
from fuelweb_test.tests.base_test_case import SetupEnvironment
from fuelweb_test.tests.base_test_case import TestBasic

@test(groups=["tempest", "tempest.ceph"])
class TempestCeph(TestBasic):
    """TempestCeph."""

    @test(depends_on=[SetupEnvironment.prepare_slaves_5],
          groups=["tempest_ceph_services"])
    @log_snapshot_after_test
    def tempest_ceph_services(self):
        """Deploy env with 3 controller_mongo and 2 
           Compute +ceph nodes.

        Scenario:
            1. Create cluster
            2. Add 3 nodes with controller role
            3. Add 2 nodes with compute role
            4. Add 2 nodes with cinder and ceph OSD roles
            5. Deploy the cluster

        Duration 40m
        Snapshot tempest_test_ceph
        """

        self.env.revert_snapshot("ready_with_5_slaves")

        cluster_id = self.fuel_web.create_cluster(
            name=self.__class__.__name__,
            mode=settings.DEPLOYMENT_MODE,
            settings={
                "net_provider": 'neutron',
                "net_segment_type": settings.NEUTRON_SEGMENT_TYPE,
                'volumes_ceph': True,
                'images_ceph': True,
                'objects_ceph': True,
                'volumes_lvm': False,
                'sahara': True,
                'murano': True,
                'ceilometer': True,
                'tenant': 'tempest',
                'user': 'tempest',
                'password': 'tempest',
            }
        )
        self.fuel_web.update_nodes(
            cluster_id,
            {
                'slave-01': ['controller', 'mongo'],
                'slave-02': ['controller', 'mongo'],
                'slave-03': ['controller', 'mongo'],
                'slave-04': ['compute', 'ceph-osd'],
                'slave-05': ['compute', 'ceph-osd']
            }
        )
        # Cluster deploy
        self.fuel_web.deploy_cluster_wait(cluster_id)

        # Run ostf
        self.fuel_web.run_ostf(cluster_id=cluster_id)

        self.env.make_snapshot("ceph_ha_one_controller_with_cinder",
                               is_make=True)
