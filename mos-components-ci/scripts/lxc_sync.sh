#!/bin/bash

PARAMS="-avH --progress --delete"
#PARAMS="-avH --progress --delete --dry-run"

rsync $PARAMS /opt/mos-components-ci/ /var/lib/lxc/worker1/rootfs/opt/mos-components-ci/
rsync $PARAMS /opt/mos-components-ci/ /var/lib/lxc/worker2/rootfs/opt/mos-components-ci/
rsync $PARAMS /opt/mos-components-ci/ root@172.16.48.12:/opt/mos-components-ci/
rsync $PARAMS /opt/mos-components-ci/ root@172.16.48.12:/var/lib/lxc/worker3/rootfs/opt/mos-components-ci/
rsync $PARAMS /opt/mos-components-ci/ root@172.16.48.12:/var/lib/lxc/worker4/rootfs/opt/mos-components-ci/
