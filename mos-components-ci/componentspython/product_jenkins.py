#!/usr/bin/env python
# vim: tabstop=4 expandtab shiftwidth=4 softtabstop=4

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

import os
import re

import jenkinsapi.jenkins
import yaml


class ProductJenkins(object):
    def __init__(self, jenkins_url=None, job_name=None, **kwargs):
        if not jenkins_url:
            jenkins_url = os.environ.get(
                'JENKINS_URL',
                'https://product-ci.infra.mirantis.net/'
            )
        self._client = jenkinsapi.jenkins.Jenkins(jenkins_url)
        if job_name:
            self._job = self._client[job_name]
        else:
            self._job = None

    def get_latest_version(self):
        ver = None
        jobname_re = re.compile('^(?P<version>\d+(\.\d+)+)\.all')
        for jobname in self._client.jobs.keys():
            jobmatch = jobname_re.match(jobname)
            if jobmatch:
                jobversion = jobmatch.group('version')
                if jobversion > ver:
                    ver = jobversion
        return ver

    def get_last_good_build(self, job_name=None):
        if not job_name:
            job_name = self._job.name
        return self._client[job_name].get_last_good_buildnumber()

    def get_prev_good_build(self, job_name=None, build_number=-1):
        if not job_name:
            job_name = self._job.name

        # If build_number is not set, return last good build
        if build_number < 0:
            return self.get_last_good_build(job_name)

        build_number -= 1
        # Not found
        if build_number == 0:
            return None

        if not self._client[job_name][build_number].is_good():
            self.get_prev_good_build(job_name=job_name,
                                     build_number=build_number)

        return build_number

    def check_downstream_jobs(self, job_name=None, build_number=-1,
                              skip_list=['deploy_iso_on_cachers',
                                         'fuel_ci-status_reports',
                                         'trigger-external-events',
                                         '7.0.all-Testrail',
                                         '8.0.all-Testrail']):
        if not job_name:
            job_name = self._job.name
        if build_number <= 0:
            build_number = self.get_last_good_build(job_name)

        downstream_jobs = self._client[job_name].get_downstream_job_names()

        result = True

        # Downstream job names
        for djn in [job for job in downstream_jobs if job not in skip_list]:
            dj = self._client[djn]

            # Last good downstream build
            db = self.get_last_good_build(djn)
            # If downstream build belongs to upstream build with a hihger
            # number, get previous downstream build
            while dj[db].get_upstream_build_number() > build_number:
                db = self.get_prev_good_build(djn, build_number=db)

            # Check if found build belongs to upstream build
            # and is successful
            result = result \
                and dj[db].get_upstream_build_number() == build_number \
                and dj[db].is_good()

        return result

    def get_magnet_link(self, job_name=None, build_number=-1):
        if not job_name:
            job_name = self._job.name
        if build_number <= 0:
            build_number = self.get_last_good_build(job_name)

        for artifact in self._client[job_name][build_number].get_artifacts():
            if artifact.filename == 'magnet_link.txt':
                return artifact.get_data().splitlines()[0].split('=', 1)[1]

    def get_iso_filename(self, job_name=None, build_number=-1):
        if not job_name:
            job_name = self._job.name
        if build_number <= 0:
            build_number = self.get_last_good_build(job_name)

        for artifact in self._client[job_name][build_number].get_artifacts():
            if re.match('^fuel-.+\.iso\.data\.txt', artifact.filename):
                for line_data in [
                        line.split('=')
                        for line in artifact.get_data().splitlines()
                ]:
                    if line_data[0] == 'ARTIFACT':
                        return line_data[1]

    def get_iso_suffix(self, job_name=None, build_number=-1):
        if not job_name:
            job_name = self._job.name
        if build_number <= 0:
            build_number = self.get_last_good_build(job_name)

        suffix_match = re.match('^fuel-(?P<suffix>.+)-[0-9]+(\.[0-9]+)+-',
                                self.get_iso_filename(job_name, build_number))
        if suffix_match and suffix_match.group('suffix'):
            return suffix_match.group('suffix')

    def get_latest_tested_build(self, job_name=None):
        if not job_name:
            job_name = self._job.name

        good_build_number = self.get_last_good_build(job_name)
        while not self.check_downstream_jobs(job_name=job_name,
                                             build_number=good_build_number):
            good_build_number = self.get_prev_good_build(
                job_name=job_name,
                build_number=good_build_number
            )

        return good_build_number

    def get_version(self, job_name=None, build_number=-1):
        if not job_name:
            job_name = self._job.name
        if build_number <= 0:
            build_number = self.get_last_good_build(job_name)

        for artifact in self._client[job_name][build_number].get_artifacts():
            if artifact.filename == 'version.yaml.txt':
                return yaml.safe_load(artifact.get_data())['VERSION']
