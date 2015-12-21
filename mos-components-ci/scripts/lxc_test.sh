#!/bin/bash

rm -rf mos
cp -r /opt/mos-components-ci mos
pushd mos
cp etc/lxc/ha/neutron_vlan_ubuntu/* .
ln -s ~/images iso
sed -i 's|./actions/prepare-environment.sh|#./actions/prepare-environment.sh|' launch.sh
./launch.sh
popd
