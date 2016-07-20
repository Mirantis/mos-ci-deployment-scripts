import datetime
import os

import jenkins


def choose_successful_or_last_build(connection, test_job, job_number_list):

    for number in job_number_list:
        build_info = connection.get_build_info(test_job, number)
        build_result = build_info['result']
        # if tests are passed, then return upstream build
        # to take last successful iso
        if build_result == 'SUCCESS':
            return build_info['displayName']

def choose_builds(connection, job):
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
    job_info = connection.get_job_info(iso_job)
    number = job_info['lastSuccessfulBuild']['number']
    return get_from_build_with_number(connection, number, iso_job)


def main():
    jenkins_server = os.environ.get('JENKINS_PRODUCT_SERVER',
                                    'https://product-ci.infra.mirantis.net')
    iso_job = os.environ.get('JOB_WITH_ISO', '9.x.snapshot')
    test_job = os.environ.get('TEST_JOB', '9.x.snapshot')
    connection = jenkins.Jenkins(jenkins_server)

    # Get list of today's builds for job test_job.
    today_builds = choose_builds(connection, test_job)

    # Get ISO download link - last with passed tests,
    # if none - then simply last.
    iso_answer = choose_successful_or_last_build(connection, test_job,
                                                 today_builds)
    print iso_answer

if __name__ == '__main__':
    main()
