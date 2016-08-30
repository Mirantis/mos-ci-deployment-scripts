#!/usr/bin/env bash

ENV_NAME=MOS_CI_fuel-9.0-mos-597-2016-07-12_06-18-00.iso_ironic
BAREMETAIL_IFACE=em2
IRONIC_NET=${ENV_NAME}_ironic

IRONIC_BRIDGE=$(virsh net-dumpxml $IRONIC_NET | xmllint --xpath 'string(//bridge/@name)' - )

sudo brctl addif $IRONIC_BRIDGE $BAREMETAIL_IFACE
sudo brctl delif $IRONIC_BRIDGE $BAREMETAIL_IFACE
