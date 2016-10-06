#!/bin/bash -xe

set +e
source /root/openrc && ironic node-create -d fake
set -e

### need fix ###
wget http://cz7776.bud.mirantis.net/rally_tempest_image
###
apt-get install -y docker.io
apt-get install -y cgroup-bin
docker load -i rally_tempest_image

mkdir /home/mount_dir
cp /root/openrc /home/mount_dir/openrc
IS_TLS=$(source /root/openrc; openstack endpoint show identity 2>/dev/null | awk '/https/')
    if [ "${IS_TLS}" ]; then
        echo "export OS_CACERT='/var/lib/astute/haproxy/public_haproxy.pem'" >> /home/mount_dir/openrc
    fi

sed -i "s/:5000\/'/:5000\/v3\/'/" /home/mount_dir/openrc
echo "export OS_PROJECT_DOMAIN_NAME='Default'" >> /home/mount_dir/openrc
echo "export OS_USER_DOMAIN_NAME='Default'" >> /home/mount_dir/openrc
echo "export OS_IDENTITY_API_VERSION='3'" >> /home/mount_dir/openrc

cd /home/mount_dir/

image_id=$(docker images |grep rally-tempest| awk {'print$3'})
docker run --net host -v /home/mount_dir:/home/rally -tid -u root $image_id
docker_id=$(docker ps | grep $image_id | awk '{print $1}'| head -1)

NOVA_FLTR=$(sed -n '/scheduler_default_filters=/p' /etc/nova/nova.conf | cut -f2 -d=)

check_ceph=$(cat /etc/cinder/cinder.conf |grep '\[RBD-backend\]' | wc -l)
if [ ${check_ceph} == '1' ]; then
    docker exec -ti $docker_id bash -c "sed -i 's|#swift_operator_role = Member|swift_operator_role = swiftoperator|g' /etc/rally/rally.conf"
    wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/shell_scripts/skip_ceph.list
    cp skip_ceph.list skip.list
    wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/shell_scripts/ceph
    cp ceph tempest_config
else
    docker exec -ti $docker_id bash -c "sed -i 's|#swift_operator_role = Member|swift_operator_role = SwiftOperator|g' /etc/rally/rally.conf"
    wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/shell_scripts/skip_lvm.list
    cp skip_lvm.list skip.list
    wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/shell_scripts/lvm
    cp lvm tempest_config
fi

echo 'scheduler_available_filters = '$NOVA_FLTR >> tempest_config

docker exec -ti $docker_id bash -c "apt-get install -y iputils-ping"
docker exec -ti $docker_id bash -c "setup-tempest"
docker exec -ti $docker_id bash -c "rally verify showconfig"
docker exec -ti $docker_id bash -c "rally verify start --skip-list skip.list --system-wide > log.log"
docker exec -ti $docker_id bash -c "rally verify results --json --output-file output.json"
docker exec -ti $docker_id bash -c "git clone https://github.com/greatehop/rally_json2junit && python rally_json2junit/rally_json2junit/results_parser.py output.json"
