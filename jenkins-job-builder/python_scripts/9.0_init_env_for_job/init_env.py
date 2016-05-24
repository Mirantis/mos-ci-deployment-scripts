"""Get Swarm ISO for tests.

    This module parses jenkins jobs, and prints link to ISO, which
    is chosen for Swarm tests. Also link to ISO writes to file, to be
    injected as environment variable in next scripts.

    Environment variables:
        JOB_WITH_ISO (str): Name of jenkins job, that builds ISO, used for
            tests.
            This parameter is defined by environment variable. Default value
            is correct for current developed MOS version.
        TEST_JOB (str): Name of jenkins job, that tests ISO, which have been
            built by JOB_WITH_ISO job. Default value is correct for current
            developed MOS version.
        ENV_INJECT_FILE (str): Full path to file, that will be used by
            jenkins EVN_INJECT plugin. User, that runs script, must have
            permission to write to ENV_INJECT_FILE.

    Example:
        You can provide required parameters and run script from command line::

            $ export JOB_WITH_ISO='Build_iso_jenkins_job'
            $ export TEST_JOB='Job_to_test_iso'
            $ python init_env.py

        You also can provide ENV_INJECT_PATH, and ISO download link will be
        added to your inject .properties file::

            $ export ENV_INJECT_FILE='/home/jenkins/env_inject.properties'
            $ export JOB_WITH_ISO='Build_iso_jenkins_job'
            $ export TEST_JOB='Job_to_test_iso'
            $ python init_env.py
"""
import datetime
import os

import jenkins


def choose_successful_or_last_build(connection, test_job, job_number_list):
    """Function to define build, which will be parsed for ISO download link.

    Args:
        connection(jenkins.Jenkins): Connection object,
            that is used by python-jenkins
            module to connect and get information from jenkins server.
        test_job (string):
        job_number_list (list):

    Returns:
        upstream_build (number): Upstream build number for test_job build if test_job
          build is successful.
        'lastSuccessful' (str): If all builds from job_number_list are
         failed, then returns string 'lastSuccessful'.

    """
    for number in job_number_list:
        build_info = connection.get_build_info(test_job, number)
        build_result = build_info['result']
        # if tests are passed, then return upstream build
        # to take last successful iso
        if build_result == 'SUCCESS':
            upstream_build = (
                build_info['actions'][1]['causes'][0]['upstreamBuild']
            )
            return upstream_build

    # If all jobs for today are failed, then return string, that tells
    # other functions to take last successful build, which is not passed
    # tests.
    return 'lastSuccessful'


def choose_builds(connection, job):
    """This function chooses all builds, that were build today and
    stores there numbers in list.

    Args:
        connection(jenkins.Jenkins): Connection object,
            that is used by python-jenkins
            module to connect and get information from jenkins server.
        job (str): Name of jenkins job to parse.

    Returns:
        today_builds: List of builds number.
    """
    job_info = connection.get_job_info(job)
    builds = job_info['builds']
    today_builds = []

    # From builds choosing today's builds.
    for build in builds:
        build_info = connection.get_build_info(job, build['number'])

        # Convert timestamp into datetime.
        build_time = int(build_info['timestamp']) / 1000
        build_datetime = datetime.datetime.fromtimestamp(build_time)
        # We need only today's builds.
        required_date = datetime.datetime.date(datetime.datetime.now())

        if build_datetime.date() == required_date:
            # Ignore build, if it is still running.
            if not build_info['building']:
                today_builds.append(build['number'])
        if build_datetime.date() < required_date:
            break

    return today_builds


def get_from_build_with_number(connection, number, iso_job):
    build_info = connection.get_build_info(iso_job, number)
    descr = build_info['description']
    iso_link = descr.split('>')[0].split('=')[1]
    return iso_link


def get_last_successful(connection, iso_job):
    """Function gets number of last successful build of iso_job and pass it
    to function 'get_from_build_with_number'.

    Args:
        connection(jenkins.Jenkins): Connection object,
            that is used by python-jenkins
            module to connect and get information from jenkins server.
        iso_job:
    """
    job_info = connection.get_job_info(iso_job)
    number = job_info['lastSuccessfulBuild']['number']
    return get_from_build_with_number(connection, number, iso_job)


def main():
    jenkins_server = os.environ.get('JENKINS_PRODUCT_SERVER',
                                    'https://product-ci.infra.mirantis.net')
    iso_job = os.environ.get('JOB_WITH_ISO', '9.0-mos.all')
    test_job = os.environ.get('TEST_JOB', '9.0-mos.test_all')
    connection = jenkins.Jenkins(jenkins_server)

    # Get list of today's builds for job test_job.
    today_builds = choose_builds(connection, test_job)

    # Get ISO download link - last with passed tests,
    # if none - then simply last.
    iso_answer = choose_successful_or_last_build(connection, test_job,
                                                 today_builds)

    if iso_answer == 'lastSuccessful':
        iso_link = get_last_successful(connection, iso_answer, iso_job)
    else:
        iso_link = get_from_build_with_number(connection, iso_answer, iso_job)

    # Now we need to print link to stdout for one type of get_iso scripts,
    # and we also need to add this link to env_inject file, that must be
    # provided as environment variable by upstream job.
    print iso_link
    # Usually env_inject_path is ~/env_inject.properties
    env_inject_default = os.path.expanduser('~/env_inject.properties')
    env_inject_path = os.environ.get('ENV_INJECT_FILE', env_inject_default)

    try:
        with open(env_inject_path, 'w') as f:
            f.write('SWARM_ISO_LINK={0}'.format(iso_link))
    except Exception as e:
        print e


if __name__ == '__main__':
    main()
