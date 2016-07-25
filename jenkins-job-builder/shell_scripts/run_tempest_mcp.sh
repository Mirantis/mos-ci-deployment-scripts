#!/bin/bash -xe

function prepare {
    mkdir /home/vagrant/rally
    echo "sed -i 's|#swift_operator_role = Member|swift_operator_role=SwiftOperator|g' /etc/rally/rally.conf
          source /home/rally/openrc
          rally-manage db recreate
          rally deployment create --fromenv --name=tempest
          rally verify install
          rally verify genconfig
          rally verify showconfig" > /home/vagrant/rally/install_tempest.sh
    chmod +x /home/vagrant/rally/install_tempest.sh
    keystone_ip=$(kubectl get services --namespace demo |grep keystone |awk {'print$2'})
    echo "export OS_NO_CACHE='true'
          export OS_TENANT_NAME='admin'
          export OS_PROJECT_NAME='admin'
          export OS_USERNAME='admin'
          export OS_PASSWORD='password'
          export OS_AUTH_URL='http://$keystone_ip:5000/v2.0'
          export OS_DEFAULT_DOMAIN='Default'
          export OS_AUTH_STRATEGY='keystone'
          export OS_REGION_NAME='RegionOne'
          export CINDER_ENDPOINT_TYPE='internalURL'
          export GLANCE_ENDPOINT_TYPE='internalURL'
          export KEYSTONE_ENDPOINT_TYPE='internalURL'
          export NOVA_ENDPOINT_TYPE='internalURL'
          export NEUTRON_ENDPOINT_TYPE='internalURL'
          export OS_ENDPOINT_TYPE='internalURL'
          export MURANO_REPO_URL='http://storage.apps.openstack.org/'
          export MURANO_PACKAGES_SERVICE='glance'" > /home/vagrant/rally/openrc
}

function install_docker_and_run {
    docker pull rallyforge/rally:0.5.0
    image_id=$(docker images | grep 0.5.0| awk '{print $3}')
    docker run --net host -v /home/vagrant/rally:/home/rally -tid -u root $image_id
    docker_id=$(docker ps | grep $image_id | awk '{print $1}'| head -1)
}

function run_tempest {
    source /home/vagrant/rally/openrc
    docker exec -ti $docker_id bash -c "./install_tempest.sh"
    docker exec -ti $docker_id bash -c "source /home/rally/openrc && rally verify start $0"
    docker exec -ti $docker_id bash -c "rally verify results --json --output-file result.json"
    docker exec -ti $docker_id bash -c "rally verify results --html --output-file result.html"
}

prepare
install_docker_and_run
run_tempest
