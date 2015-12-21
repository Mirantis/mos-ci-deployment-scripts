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

import ConfigParser
import logging
from optparse import OptionParser
import os
import time

import libtorrent as lt
import product_jenkins


def logger():
    log_file = os.environ.get("ISO_GRABBER_LOG", "iso_grabber_log.txt")
    if log_file.startswith('/'):
        logfile = log_file
    else:
        logfile = os.path.join(os.path.join(os.getcwd()), log_file)

    log = logging.getLogger(__name__)
    log.setLevel(logging.DEBUG)
    fh = logging.FileHandler(logfile)
    fh.setLevel(logging.DEBUG)
    ch = logging.StreamHandler()
    ch.setLevel(logging.INFO)
    log.addHandler(fh)
    log.addHandler(ch)
    return log


LOG = logger()


class IsoGrabberCore(object):
    def __init__(self):
        # Try to find configuration name parameter
        config_file = None
        if options.CONFIG_FILENAME:
            config_file = options.CONFIG_FILENAME
        elif args:
            config_file = args[0]

        # Parse configuration file if it used
        self.config = ConfigParser.RawConfigParser(allow_no_value=True)
        if config_file:
            self.config.read(config_file)

        # Get option(s) from config
        if self.config.has_option("storage", "store_path"):
            self.path = self.config.get("storage", "store_path")

        # Override options if any by command line parameters
        if options.STORAGE_PATH:
            self.path = options.STORAGE_PATH

        # Get magnet link
        if options.MAGNET_LINK:
            self.magnet_link = options.MAGNET_LINK
        else:
            self._iso_search = IsoSearchCore(config=self.config)
            self.magnet_link = self._iso_search.get_magnet_link()

    def download_iso(self):
        if not self.magnet_link:
            LOG.error("magnet_link for newtest Fuel ISO not found. Aborted")
            return None
        session = lt.session()
        session.listen_on(6881, 6891)
        params = {
            'save_path': self.path,
            'storage_mode': lt.storage_mode_t(2),
            'paused': False,
            'auto_managed': True,
            'duplicate_is_error': True}
        handle = lt.add_magnet_uri(session, self.magnet_link, params)
        session.start_dht()

        while not handle.has_metadata():
            time.sleep(1)
        filename = handle.get_torrent_info().files()[0].path
        LOG.debug('Got metadata, starting torrent download...')
        while handle.status().state != lt.torrent_status.seeding:
            status = handle.status()
            state_str = ['queued', 'checking', 'downloading metadata',
                         'downloading',
                         'finished', 'seeding', 'allocating']
            LOG.info('{0:.2f}% complete (down: {1:.1f} kb/s up: {2:.1f} kB/s '
                     'peers: {3:d}) {4:s} {5:d}.3'
                     .format(status.progress * 100,
                             status.download_rate / 1000,
                             status.upload_rate / 1000,
                             status.num_peers,
                             state_str[status.state],
                             status.total_download / 1000000))
            time.sleep(5)
        LOG.info('Ready for deploy iso {0}'.format(filename))
        return '/'.join([self.path, filename])


class IsoSearchCore(object):
    def __init__(self, config):
        # Initialise empty variables
        self.jenkins_url = None
        self.job_name = None
        self.fuel_version = None
        self.stable_iso_number = None

        if config:
            # Get option(s) from config
            if config.has_option("jenkins", "url"):
                self.jenkins_url = config.get("jenkins", "url")
            if config.has_option("fuel", "fuel_version"):
                self.fuel_version = config.get("fuel", "fuel_version")
            if config.has_option("fuel", "fuel_build"):
                self.stable_iso_number = int(config.get("fuel", "fuel_build"))
            if config.has_option("fuel", "job_name"):
                self.job_name = config.get("fuel", "job_name")

        # Override options by command line parameters
        if options.JENKINS_URL:
            self.jenkins_url = options.JENKINS_URL
        if options.MOS_VERSION:
            self.fuel_version = options.MOS_VERSION
            # Command line overrides configuration file even for custom job
            self.job_name = None
            self.stable_iso_number = None
        if options.CUSTOM_JOB:
            self.job_name = options.CUSTOM_JOB
            self.stable_iso_number = None
        if options.MOS_BUILD:
            self.stable_iso_number = options.MOS_BUILD

        self.jenkins = product_jenkins.ProductJenkins(self.jenkins_url)

        # If custom job is not used, use job containing MOS version
        if not self.job_name:
            if not self.fuel_version:
                # MOS version is not set nor by config nor by command line
                self.fuel_version = self.jenkins.get_latest_version()
            # Use job derived from MOS version
            self.job_name = '{0}.all'.format(self.fuel_version)

        # If fuel_build is not set, find latest stable build
        if not self.stable_iso_number:
            self.stable_iso_number = self.jenkins.get_latest_tested_build(
                job_name=self.job_name
            )

    def get_stable_build_number(self):
        return self.stable_iso_number

    def get_magnet_link(self):
        return self.jenkins.get_magnet_link(
            job_name=self.job_name,
            build_number=self.stable_iso_number
        )


if __name__ == "__main__":
    parser = OptionParser()
    parser.add_option(
        '-l', '--link', '-m',  '--magnet-link', '--magnet',
        action='store', type='string', dest='MAGNET_LINK',
        help='Magnet link to download.',
    )
    parser.add_option(
        '-v', '--version', '--mos-version',
        action='store', type='string', dest='MOS_VERSION',
        help='MOS ISO version to download. Used to construct job name as '
        '"MOS_VERSION.all".',
    )
    parser.add_option(
        '-j', '--job', '--custom-job',
        action='store', type='string', dest='CUSTOM_JOB',
        help='Job name from which download ISO. Overrides version setting.',
    )
    parser.add_option(
        '-b', '--build',
        action='store', type='int', dest='MOS_BUILD',
        help='Build of job, that is set by custom job parameter or by '
        'conjunction of MOS ISO version and string ".all".',
    )
    parser.add_option(
        '-c', '--config',
        action='store', type='string', dest='CONFIG_FILENAME',
        help='Path to configuration file containing basic parameters.',
    )
    parser.add_option(
        '-u', '--url', '--jenkins-url',
        action='store', type='string', dest='JENKINS_URL',
        help='Path to configuration file containing basic parameters.',
    )
    parser.add_option(
        '-d', '--directory', '-s', '--storage',
        action='store', type='string', dest='STORAGE_PATH',
        help='Path to save downloaded files.',
    )
    parser.add_option(
        '-o', '--output',
        action='store', type='string', dest='OUT_FILE',
        help='Path to file into which store path to downloaded file.',
    )
    (options, args) = parser.parse_args()

    iso = IsoGrabberCore()
    downloaded_file = iso.download_iso()

    print 'Local path to just downloaded file: {}'.format(downloaded_file)
    if downloaded_file and options.OUT_FILE:
        with open(options.OUT_FILE, 'w') as out_file:
            out_file.write(downloaded_file)
