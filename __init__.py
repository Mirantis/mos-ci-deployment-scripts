import fuelweb_test
from proboscis import register


logger = fuelweb_test.logger

# Dark magic with hardcode for the fuel-qa moster:
from system_test.tests import deploy_env  # noqa


def define_custom_groups():
    # Should move to system_test.__init__.py after upgrade devops to 2.9.13
    groups_list = [
        {"groups": ["system_test.deploy_env"],
         "depends": [
             "system_test.deploy_env("
             "3_controllers_2compute_neutron_env)"]}
    ]

    for new_group in groups_list:
        register(groups=new_group['groups'],
                 depends_on_groups=new_group['depends'])
