#!/bin/bash -xe

set +e
source /root/openrc && ironic node-create -d fake
rm -rf rally_tempest_image /home/mount_dir
image_id=$(docker images |grep rally-tempest| awk {'print$3'})
docker_id=$(docker ps | grep $image_id | awk '{print $1}'| head -1)
docker rm -f $docker_id
docker rmi $image_id
set -e

wget http://cz7776.bud.mirantis.net:8080/jenkins/view/System%20Jobs/job/rally_tempest_docker_build/lastSuccessfulBuild/artifact/rally_tempest_image

apt-get install -y docker.io
apt-get install -y cgroup-bin
docker load -i rally_tempest_image

mkdir /home/mount_dir

cp /root/openrc /home/mount_dir/openrc
IS_TLS=$(source /root/openrc; openstack endpoint show identity 2>/dev/null | awk '/https/')
    if [ "${IS_TLS}" ]; then
        cp /var/lib/astute/haproxy/public_haproxy.pem /home/mount_dir/
        echo "export OS_CACERT='/home/rally/public_haproxy.pem'" >> /home/mount_dir/openrc
    fi

sed -i "s/:5000\/'/:5000\/v3\/'/" /home/mount_dir/openrc
echo "export OS_PROJECT_DOMAIN_NAME='Default'" >> /home/mount_dir/openrc
echo "export OS_USER_DOMAIN_NAME='Default'" >> /home/mount_dir/openrc
echo "export OS_IDENTITY_API_VERSION='3'" >> /home/mount_dir/openrc

cd /home/mount_dir/

image_id=$(docker images |grep rally-tempest| awk {'print$3'})
docker run --net host -v /home/mount_dir:/home/rally -id -u root $image_id
docker_id=$(docker ps | grep $image_id | awk '{print $1}'| head -1)

NOVA_FLTR=$(sed -n '/scheduler_default_filters=/p' /etc/nova/nova.conf | cut -f2 -d=)

check_ceph=$(cat /etc/cinder/cinder.conf |grep '\[RBD-backend\]' | wc -l)
if [ ${check_ceph} == '1' ]; then
    docker exec -i $docker_id bash -c "sed -i 's|#swift_operator_role = Member|swift_operator_role = swiftoperator|g' /etc/rally/rally.conf"
    wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/shell_scripts/rally_tempest_docker/skip_ceph.list
    cp skip_ceph.list skip.list
    wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/shell_scripts/rally_tempest_docker/ceph
    cp ceph tempest_config
else
    docker exec -i $docker_id bash -c "sed -i 's|#swift_operator_role = Member|swift_operator_role = SwiftOperator|g' /etc/rally/rally.conf"
    wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/shell_scripts/rally_tempest_docker/skip_lvm.list
    cp skip_lvm.list skip.list
    wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/shell_scripts/rally_tempest_docker/lvm
    cp lvm tempest_config
fi

echo 'scheduler_available_filters = '$NOVA_FLTR >> tempest_config

docker exec -i $docker_id bash -c "apt-get install -y iputils-ping"
docker exec -i $docker_id bash -c "setup-tempest"
docker exec -i $docker_id bash -c "rally verify showconfig"
docker exec -i $docker_id bash -c "rally verify start --skip-list skip.list --system-wide > tests.log"
docker exec -i $docker_id bash -c "rally verify results --json --output-file output.json"
docker exec -i $docker_id bash -c "git clone https://github.com/EduardFazliev/rally_json2junit && python rally_json2junit/rally_json2junit/results_parser.py output.json"
docker exec -i $docker_id bash -c "rally verify showconfig > /home/rally/tempest.conf"
cp $(find /home/mount_dir/.rally/tempest/ -name tempest.log) /home/mount_dir/
