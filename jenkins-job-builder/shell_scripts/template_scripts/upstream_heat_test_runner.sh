set +e

virtualenv --clear venv
. venv/bin/activate
pip install -U pip
pip install tox

printenv || true

wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/heat_yamls/Heat_integration_resource.yaml

pip install -r requirements.txt
pip install python-heatclient
pip install python-swiftclient

export KEYSTONE_API="v2.0"

heat stack-create -f Heat_integration_resource.yaml resource
if [ $? -ne 0 ]
then
    echo "Can't create needed resources. Please see logs above."
    exit 255
fi

#wating for about 120 seconds for all stack resources to be created
is_created=1
for i in $(seq 1 100)
do
    heat stack-show  resource | grep stack_status | grep CREATE_COMPLETE
    is_created=$?
    if [ $is_created -eq 0 ]
    then
        break
    fi
    echo "waiting for the heat stack creation completed"
    sleep 1
done
if [ $is_created -ne 0 ]
then
# Stack creation was failed
    echo "Can't create needed resources. Please see logs above."
    exit 255
fi

echo '[DEFAULT]
username = nonadmin
password = nonadmin
admin_username = admin
admin_password = admin
tenant_name = nonadmin
admin_tenant_name = admin
user_domain_name = admin
project_domain_name = admin
instance_type = m1.medium
minimal_instance_type = m1.small
image_ref = TestVM
minimal_image_ref = Test
disable_ssl_certificate_validation = false
build_interval = 4
build_timeout = 1200
network_for_ssh = heat_net
fixed_network_name = heat_net
floating_network_name = heat_net
boot_config_env = heat_integrationtests/scenario/templates/boot_config_none_env.yaml
fixed_subnet_name = someSub
ssh_timeout = 300
ip_version_for_ssh = 4
ssh_channel_timeout = 60
tenant_network_mask_bits = 28
skip_scenario_tests = false
skip_functional_tests = false
skip_functional_test_list = ZaqarWaitConditionTest, ZaqarEventSinkTest, ZaqarSignalTransportTest, RemoteStackTest.test_stack_update, RemoteStacteStackTest.test_stack_resource_validation_fail, RemoteStackTest.test_stack_suspend_resume, RemoteStackTest.test_stack_create_bad_region, test_purge.PurgeTest.test_purge, ReloadOnSighupTest.test_api_cfn_reload_on_sighup, ReloadOnSighupTest.test_api_cloudwatch_on_sighup, ReloadOnSighupTest.test_api_reload_on_sighup, RemoteStackTest.test_stack_create, RemoteStackTest.test_stack_resource_validation_fail
skip_scenario_test_list = AodhAlarmTest.test_alarm, CfnInitIntegrationTest.test_server_cfn_init
skip_test_stack_action_list = ABANDON, ADOPT
volume_size = 1
connectivity_timeout = 140
sighup_timeout = 30
sighup_config_edit_retries = 10
heat_config_notify_script = heat-config-notify'>> heat_integrationtests/heat_integrationtests.conf

echo auth_url = "${OS_AUTH_URL}/${KEYSTONE_API}" >> heat_integrationtests/heat_integrationtests.conf

export uc_url=https://git.openstack.org/cgit/openstack/requirements/plain/upper-constraints.txt?h=stable/mitaka
sed -i~ -e "s,{env:UPPER_CONSTRAINTS_FILE[^ ]*}, $uc_url," tox.ini

tox -eintegration

deactivate

sudo dos.py destroy "$ENV_NAME"
