#!/bin/bash -xe

rm -rf rally .rally /root/openrc_tempest
cp /root/openrc /root/openrc_tempest
sed -i "s/:5000\/'/:5000\/v2.0\/'/" /root/openrc_tempest

source /root/openrc_tempest && ironic node-create -d fake

apt-get install -y git

git clone https://github.com/openstack/rally.git
cd rally
git checkout tags/0.6.0
CDIR=$(pwd)

IS_TLS=$(source /root/openrc_tempest; openstack endpoint show identity 2>/dev/null | awk '/https/')
    if [ "${IS_TLS}" ]; then
        echo "export OS_CACERT='var/lib/astute/haproxy/public_haproxy.pem" >> /root/openrc_tempest
    fi

./install_rally.sh -d rally-venv/ -y

sed -i 's|#swift_operator_role = Member|swift_operator_role = SwiftOperator|g' /root/rally/rally-venv/etc/rally/rally.conf

NOVA_FLTR=$(sed -n '/scheduler_default_filters=/p' /etc/nova/nova.conf | cut -f2 -d=)
check_ceph=$(cat /etc/cinder/cinder.conf |grep '\[RBD-backend\]' | wc -l)
if [ ${check_ceph} == '1' ]; then
    storage_protocol="ceph"
    wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/shell_scripts/skip_ceph.list
    wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/shell_scripts/ceph
    echo 'scheduler_available_filters = '$NOVA_FLTR >> ceph
else
    storage_protocol="lvm"
    wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/shell_scripts/skip_lvm.list
    wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/shell_scripts/lvm
    echo 'scheduler_available_filters = '$NOVA_FLTR >> lvm
fi

source /root/rally/rally-venv/bin/activate
source /root/openrc_tempest

rally-manage db recreate
rally deployment create --fromenv --name=tempest
rally verify install
rally verify genconfig --add-options $storage_protocol
rally verify showconfig

if [ $storage_protocol == 'ceph' ]; then
    rally verify start --skip-list skip_ceph.list > /root/rally/log.log
else
    rally verify start --skip-list skip_lvm.list > /root/rally/log.log
fi

rally verify results --json --output-file output.json
rally verify showconfig > /root/rally/tempest.conf
cp $(find / -name tempest.log) /root/rally/tempest.log
git clone https://github.com/greatehop/rally_json2junit
python rally_json2junit/rally_json2junit/results_parser.py output.json

deactivate
