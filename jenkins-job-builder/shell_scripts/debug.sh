#!/bin/bash -xe

rm -rf rally .rally /root/openrc_tempest
cp /root/openrc /root/openrc_tempest

set +e
source /root/openrc_tempest && ironic node-create -d fake
set -e

apt-get install -y git

git clone https://github.com/openstack/rally.git
cd rally
IS_TLS=$(source /root/openrc_tempest; openstack endpoint show identity 2>/dev/null | awk '/https/')
    if [ "${IS_TLS}" ]; then
        echo "export OS_CACERT='/var/lib/astute/haproxy/public_haproxy.pem'" >> /root/openrc_tempest
    fi

sed -i "s/:5000\/'/:5000\/v3\/'/" /root/openrc_tempest
echo "export OS_PROJECT_DOMAIN_NAME='Default'" >> /root/openrc_tempest
echo "export OS_USER_DOMAIN_NAME='Default'" >> /root/openrc_tempest
echo "export OS_IDENTITY_API_VERSION='3'" >> /root/openrc_tempest

./install_rally.sh -d rally-venv/ -y

source /root/rally/rally-venv/bin/activate
source /root/openrc_tempest

rally-manage db recreate
rally deployment create --fromenv --name=tempest
rally verify install --version 4db514cc0178662163e337bc0cddbdc7357c2220
rally verify genconfig
rally verify showconfig

for i in {1..3}; do
    mkdir /root/run-$i && \
    rally verify start --regex tempest.api.identity > /root/run-$i/tests.log && \
    rally verify results --html --output-file /root/run-$i/result.html
done

deactivate
