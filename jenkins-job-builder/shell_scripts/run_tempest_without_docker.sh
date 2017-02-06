#!/bin/bash -xe

rm -rf rally .rally /root/openrc_tempest
cp /root/openrc /root/openrc_tempest

set +e
source /root/openrc_tempest && ironic node-create -d fake
set -e

apt-get install -y git

git clone https://github.com/openstack/rally.git
cd rally
CDIR=$(pwd)

if [[ -f /var/lib/astute/haproxy/public_haproxy.pem ]]; then
    echo "export OS_CACERT='/var/lib/astute/haproxy/public_haproxy.pem'" >> /root/openrc_tempest
fi

sed -i "s/:5000\/'/:5000\/v3\/'/" /root/openrc_tempest
echo "export OS_PROJECT_DOMAIN_NAME='Default'" >> /root/openrc_tempest
echo "export OS_USER_DOMAIN_NAME='Default'" >> /root/openrc_tempest
echo "export OS_IDENTITY_API_VERSION='3'" >> /root/openrc_tempest

git checkout 01a1b5fc6e242775d126a0f357ea91c38c783404

./install_rally.sh --branch 0.7.0 -d rally-venv/ -y

NOVA_FLTR=$(sed -n '/scheduler_default_filters=/p' /etc/nova/nova.conf | cut -f2 -d=)
check_ceph=$(cat /etc/cinder/cinder.conf |grep '\[RBD-backend\]' | wc -l)
if [ ${check_ceph} == '1' ]; then
    storage_protocol="ceph"
    sed -i 's|#swift_operator_role = Member|swift_operator_role = swiftoperator|g' /root/rally/rally-venv/etc/rally/rally.conf
    wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/shell_scripts/skip_ceph.list
    wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/shell_scripts/ceph
    echo 'scheduler_available_filters = '$NOVA_FLTR >> ceph
else
    storage_protocol="lvm"
    sed -i 's|#swift_operator_role = Member|swift_operator_role = SwiftOperator|g' /root/rally/rally-venv/etc/rally/rally.conf
    wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/shell_scripts/skip_lvm.list
    wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/shell_scripts/lvm
    echo 'scheduler_available_filters = '$NOVA_FLTR >> lvm
fi

source /root/rally/rally-venv/bin/activate
source /root/openrc_tempest

rally-manage db recreate
rally deployment create --fromenv --name=tempest
rally verify install --version 2e7d0f026ec81540deef5fe2e4ddf84f484aaa37
rally verify genconfig --add-options $storage_protocol
rally verify showconfig

if [ $storage_protocol == 'ceph' ]; then
    rally verify start --skip-list skip_ceph.list --concurrency 2 > /root/rally/log.log
else
    rally verify start --skip-list skip_lvm.list --concurrency 2 > /root/rally/log.log
fi

set +e
rally verify results --json --output-file output.json
rally verify showconfig > /root/rally/tempest.conf
cp $(find / -name tempest.log) /root/rally/tempest.log
git clone https://github.com/EduardFazliev/rally_json2junit
python rally_json2junit/rally_json2junit/results_parser.py output.json
set -e

deactivate
