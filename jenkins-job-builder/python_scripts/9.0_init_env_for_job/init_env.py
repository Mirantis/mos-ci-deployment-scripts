import datetime
import os

import jenkins

def choose_successful_or_last_build(connection, iso_job, test_job,
                                   job_number_list):
    for number in job_number_list:
        build_info = connection.get_build_info(test_job, number)
        buildResult = build_info['result']
        upstreamBuild = build_info['actions'][1]['causes'][0]['upstreamBuild']
        # if tests are passed, then return upstream build
        # to take last successful iso
        if buildResult == 'SUCCESS':
            return upstreamBuild

    # if all jobs for today are failed, then take
    # last iso
    return 'lastSuccessful'


def choose_builds(connection, job):
    job_info = connection.get_job_info(job)
    builds = job_info['builds']
    today_builds = []

    # From builds choosing today's builds
    for build in builds:
        build_info = connection.get_build_info(job, build['number'])

        # Convert timestamp into datetime
        build_time = int(build_info['timestamp'])/1000
        build_datetime = datetime.datetime.fromtimestamp(build_time)
        # We need only builds for today
        required_date = datetime.datetime.date(datetime.datetime.now())

        if build_datetime.date() == required_date and not build_info['building']:
            #if not build_info['building']:
            today_builds.append(build['number'])
        if build_datetime.date() < required_date:
            break

    return today_builds


def get_from_build_with_number(connection, number, iso_job):
    build_info = connection.get_build_info(iso_job, number)
    descr = build_info['description']
    iso_link = descr.split('>')[0].split('=')[1]
    return iso_link


def get_last_successful(connection, flag, iso_job):
    job_info = connection.get_job_info(iso_job)
    number = job_info['lastSuccessfulBuild']['number']
    return get_from_build_with_number(connection, number, iso_job)



def main():
    jenkins_server = os.environ.get('JENKINS_PRODUCT_SERVER',
                                    'https://product-ci.infra.mirantis.net')
    iso_job = os.environ.get('JOB_WITH_ISO', '9.0.all')
    test_job = os.environ.get('TEST_JOB', '9.0.test_all')
    connection = jenkins.Jenkins(jenkins_server)

    #get_from_build_with_number(connection, 62, iso_job)
    #sys.exit(1)

    # get builds for today
    today_builds = choose_builds(connection, test_job)
    # get preferred iso - last or last with passed tests
    iso_answer = choose_successful_or_last_build(connection, iso_job, test_job,
                                                 today_builds)

    if iso_answer == 'lastSuccessful':
        print get_last_successful(connection, iso_answer, iso_job)
    else:
        print get_from_build_with_number(connection, iso_answer, iso_job)


if __name__ == '__main__':
    main()