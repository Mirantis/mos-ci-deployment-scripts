#!/usr/bin/env python
# vim: tabstop=8:expandtab:shiftwidth=4:softtabstop=4

#    Copyright 2015 Mirantis, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

#
# Testrail API description:
#  http://docs.gurock.com/testrail-api2/start
#

import os
import re
import sys

from testrail_client import TestRailProject
from testrail_settings import PRODUCT_JENKINS
from testrail_settings import TestRailSettings

import nailgun_client as fuel

from oslo_config import cfg
import rally.db.api


CONF = cfg.CONF


JENKINS_JOB = os.environ.get('JOB_NAME', '') + '/' + \
    os.environ.get('BUILD_NUMBER', '')


def get_enabled_attributes(attributes, subtree):
    return [
        str(component) for component, comp_data in
        attributes['editable'].get(subtree, None).items()
        if isinstance(comp_data.get('value', None), bool)
        and comp_data['value'] is True
    ]


def get_run_by_config(runs, suite_id, milestone_id, config_id):
    for run in runs:
        if(run['suite_id'] == suite_id
           and run['milestone_id'] == milestone_id
           and config_id in run['config_ids']):
            return run


def main():

    rally_name = TestRailSettings.tests_suite + ' ' + \
        TestRailSettings.tests_section

    cluster_description = os.environ.get('BUILD_URL', '') + '\n---\n'

    #
    # Collect info about cluster
    #

    # Initialize Nailgun client
    fuelmaster = os.environ.get('FUEL_IP', 'localhost')
    fuel_client = fuel.NailgunClient(fuelmaster)

    # Get Fuel version
    mos_version = os.environ.get('MOS_VERSION')
    mos_build = os.environ.get('MOS_BUILD')
    if mos_version and mos_build:
        fuel_version = {
            'release': mos_version,
            'build_number': mos_build,
        }
    else:
        fuel_version = fuel_client.get_api_version()
    # Build number should be an integer
    fuel_version['build_number'] = int(fuel_version['build_number'])
    cluster_description += 'Fuel version: {}-{}\n\n'.format(
        fuel_version['release'], fuel_version['build_number']
    )

    # Fuel cluster is needed only to get releases
    fuel_cluster = fuel_client.list_clusters()[0]
    # Release contains info about operating system
    fuel_release = fuel_client.get_releases_details(fuel_cluster['release_id'])
    cluster_description += 'Cluster configuration: {}\n\n'.format(
        fuel_release['name']
    )

    # Networking parameters
    cluster_network = fuel_client.get_networks(fuel_cluster['id'])
    # Network segmentation
    cluster_ns = cluster_network['networking_parameters']['segmentation_type']
    cluster_description += 'Network segmentation: {}\n\n'.format(
        cluster_ns
    )

    # Cluster nodes
    controllers = 0
    computes = 0
    for node in fuel_client.list_nodes():
        if(node['cluster'] == fuel_cluster['id']):
            if('controller' in node['roles']):
                controllers += 1
            if('compute' in node['roles']):
                computes += 1
    cluster_description += 'Total nodes:   {}\n'.format(controllers + computes)
    cluster_description += '+ controllers: {}\n'.format(controllers)
    cluster_description += '+ computes:    {}\n\n'.format(computes)

    # Other cluster options
    cluster_attributes = fuel_client.get_cluster_attributes(fuel_cluster['id'])
    cluster_components = get_enabled_attributes(cluster_attributes,
                                                'additional_components')
    cluster_description += 'Optional components: {}\n\n'.format(
        ', '.join(map(str.capitalize, cluster_components))
    )

    # Storage
    cluster_storage = get_enabled_attributes(cluster_attributes, 'storage')
    cluster_description += 'Storage: {}\n'.format(
        ', '.join(cluster_storage)
    )

    # Display Fuel info and cluster configuration
    print(cluster_description)

    #
    # Find appropriate existing or create new one test run in TestRail
    #

    # Initialize TestRail
    testrail = TestRailProject(
        url=TestRailSettings.url,
        user=TestRailSettings.user,
        password=TestRailSettings.password,
        project=TestRailSettings.project
    )

    # Find milestone
    for ms in testrail.get_milestones():
        if(ms['name'] == fuel_version['release']):
            milestone = ms
            break
    print('Testrail milestone: {}'.format(milestone['name']))

    # Find config
    for cf in testrail.get_configs():
        if(cf['name'] == 'Operation System'):
            for ccf in cf['configs']:
                if(ccf['name'].lower() in fuel_release['name'].lower()):
                    test_config = ccf
                    break
    print('Testrail configuration: {}'.format(test_config['name']))

    # Get test suite
    test_suite = testrail.get_suite_by_name(rally_name)
    if not test_suite:
        testrail.create_suite(
            name=rally_name,
            description='Periodic deployment tests by MOS Infra team.\nSee: '
            'https://jenkins.mosi.mirantis.net/view/Periodic%20(deployment)/'
        )

    # Get test cases for test section in suite
    test_cases = testrail.get_cases(
        suite_id=test_suite['id']
    )
    print('Testrail test suite "{}" contains {} test cases'.format(
        test_suite['name'], len(test_cases))
    )

    job_name = os.environ.get('CUSTOM_JOB', fuel_version['release'] + '.all')

    prefix = os.environ.get('ISO_PREFIX', '')

    # Test plans have names like "<fuel-version> iso #<fuel-build>"
    test_plan_name = '{milestone}{prefix} iso #{iso_number}'.format(
        milestone=milestone['name'],
        prefix=' ' + prefix if prefix else '',
        iso_number=fuel_version['build_number'])

    # Find appropriate test plan
    test_plan = testrail.get_plan_by_name(test_plan_name)
    if not test_plan:
        test_plan = testrail.add_plan(
            test_plan_name,
            description='{url}/job/{job}/{build}'.format(
                url=PRODUCT_JENKINS['url'],
                job=job_name,
                build=fuel_version['build_number']
            ),
            milestone_id=milestone['id'],
            entries=[]
        )

    # Create test plan entry (run)
    plan_entries = []
    plan_entries.append(
        testrail.test_run_struct(
            name=JENKINS_JOB,
            suite_id=test_suite['id'],
            milestone_id=milestone['id'],
            description=cluster_description,
            config_ids=[test_config['id']]
        )
    )

    # Add newly created plan entry to test plan and renew plan on success
    re_storage = re.compile('^([^_]+)')
    plan_entry_name = rally_name
    plan_entry_name += ' ({} controllers, {} computes)'.format(controllers,
                                                               computes)
    plan_entry_name += ': ' + cluster_ns.upper()
    if('volumes_lvm' in cluster_storage):
        plan_entry_name += '; LVM'
    else:
        plan_entry_name += '; Ceph for '
        plan_entry_name += ', '.join([
            re_storage.match(storage).group(1).capitalize()
            for storage in sorted(cluster_storage)
        ])
    if(cluster_components > 0):
        plan_entry_name += '; '
        plan_entry_name += ', '.join(map(str.capitalize,
                                         cluster_components))
    # Find appropriate run
    test_run = None
    for e in test_plan['entries']:
        if(e['suite_id'] == test_suite['id']
                and e['name'] == plan_entry_name):
            plan_entry = e
            test_run = get_run_by_config(
                plan_entry['runs'],
                test_suite['id'],
                milestone['id'],
                test_config['id']
            )
            if test_run:
                break
    # ... if not found, create new one
    if not test_run:
        plan_entry = testrail.add_plan_entry(
            plan_id=test_plan['id'],
            name=plan_entry_name,
            suite_id=test_suite['id'],
            config_ids=[test_config['id']],
            runs=plan_entries
        )
        test_run = get_run_by_config(
            plan_entry['runs'],
            test_suite['id'],
            milestone['id'],
            test_config['id']
        )
    print('Using Testrail run "{}" (ID {})'.format(
        test_run['name'],
        test_run['id']
    ))

    # Create list of test case names with ids for further use
    test_cases_exist = {}
    for tc in test_cases:
        test_cases_exist[tc['title']] = tc['id']

    # Will contain test results for publishing
    test_results = []

    # Will contain list of runned tests
    test_cases_run = []

    #
    # Proceed Rally results
    #

    # Get Rally config
    CONF(sys.argv[1:], project='rally')

    # Prepare regexp for component matching
    re_comp = re.compile('([A-Z]+[a-z]+)(.*)\.')

    # Use first avalable rally deployment
    deployment = rally.db.deployment_list()[0]

    # Get all tasks for specified deployment
    for task in rally.db.task_list(deployment=deployment.uuid):

        # Single task may have many scenarios
        for res in rally.db.task_result_get_all_by_uuid(task.uuid):

            atomic_actions = []

            # Create test case if it is not exists
            if res.key['name'] not in test_cases_exist.keys():
                print('Create new test case: {}'.format(
                    res.key['name'])
                )
                # Get atomic actions as steps if any
                if(len(res.data['raw']) > 0):
                    atomic_actions = [{
                        'content': aa,
                        'expected': 'Any positive value (seconds)'
                    } for aa in res.data['raw'][0]['atomic_actions']]

                test_section_name = re_comp.match(res.key['name']).group(1)

                # Check existense of tests section
                test_section = testrail.get_section_by_name(
                    suite_id=test_suite['id'],
                    section_name=test_section_name
                )
                # Create tests section if it doesn't exists
                if not test_section:
                    test_section = testrail.create_section(
                        suite_id=test_suite['id'],
                        name=test_section_name
                    )

                # Create test case object
                test_case = {
                    'title': res.key['name'],
                    'type_id': 1,
                    'priority_id': 5,
                    'custom_test_group': re_comp.match(
                        res.key['name']).group(2),
                    'custom_test_case_description': res.key['name'],
                    'custom_test_case_steps': atomic_actions
                }

                # Create test case in Testrail
                new_test_case = testrail.add_case(
                    section_id=test_section['id'],
                    case=test_case
                )

                # Register test case as existing
                test_cases.append(new_test_case)
                test_cases_exist[res.key['name']] = new_test_case['id']

            # Add test case to list of runned tests
            test_cases_run.append(test_cases_exist[res.key['name']])

            # Create test results
            del test_results[:]

            new_result = {
                'case_id': test_cases_exist[res.key['name']],
                'status_id': 1,
                'version': test_plan_name,
                'elapsed': '{}s'.format(int(res.data["full_duration"]))
                if(int(res.data["full_duration"]) > 0) else '0',
            }

            # Each test can have many iterations, so many results
            for result in res.data['raw']:
                # Fail entire test case if any iteration is failed
                if(len(result['error']) > 0):
                    new_result['status_id'] = 5

                # Collect info about atomic actions
                #  atomic_actions is array of dicts containing keys
                #  "content" and "expected"
                #  so need to add "actual" and "status_id"
                for aa in atomic_actions:
                    # Get name of already defined atomic action
                    aa_name = aa['content']
                    # Try to get duration of named atomic action
                    aa_duration = result['atomic_actions'].get(aa_name, 0.0)
                    aa_duration = round(float(aa_duration), 3)

                    # Summarize atomic actions durations
                    old_duration = aa.get('actual', '0.0')
                    aa['actual'] = str(float(old_duration) + aa_duration)

                    # Set atomic action status
                    # Assume that it is not failed
                    old_status = aa.get('status_id', 1)
                    # Fail atomic action if it's duration unset
                    # Atomic action doesn't contain key status_id, so it's must
                    # be set explicitly to failure (5) or success (1)
                    if(old_status == 1 and aa_duration == 0):
                        aa['status_id'] = 5
                    else:
                        aa['status_id'] = old_status

            new_result['custom_test_case_steps_results'] = atomic_actions

            # Append result to array
            test_results.append(new_result)

            # Send results
            if(test_run and test_results):
                print('Send results "{}"'.format(res.key['name']))
                testrail.add_results_for_cases(
                    run_id=test_run['id'],
                    results=test_results
                )


if __name__ == '__main__':
    main()
