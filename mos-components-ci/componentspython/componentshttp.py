#    Copyright 2013 Mirantis, Inc.
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

import functools
import json
import logging
import os
import urllib2

from keystoneclient import exceptions
from keystoneclient.v2_0 import Client as keystoneclient


def logger_func():
    log_file = os.environ.get("NAILGUN_LOG", "nailgun_log.txt")
    if log_file.startswith('/'):
        logfile = log_file
    else:
        logfile = os.path.join(os.path.join(os.getcwd()), log_file)

    logging.basicConfig(level=logging.DEBUG,
                        format='%(asctime)s - %(levelname)s %(filename)s:'
                        '%(lineno)d -- %(message)s',
                        filename=logfile,
                        filemode='w')

    console = logging.StreamHandler()
    console.setLevel(logging.INFO)
    formatter = logging.Formatter('%(asctime)s - %(levelname)s %(filename)s:'
                                  '%(lineno)d -- %(message)s')
    console.setFormatter(formatter)

    logger = logging.getLogger(__name__)
    logger.addHandler(console)
    return logger


logger = logger_func()


def debug(logger):
    def wrapper(func):
        @functools.wraps(func)
        def wrapped(*args, **kwargs):
            logger.debug(
                "Calling: {} with args: {} {}".format(
                    func.__name__, args, kwargs
                )
            )
            result = func(*args, **kwargs)
            logger.debug(
                "Done: {} with result: {}".format(func.__name__, result))
            return result
        return wrapped
    return wrapper


def json_parse(func):
    @functools.wraps(func)
    def wrapped(*args, **kwargs):
        response = func(*args, **kwargs)
        return json.loads(response.read())
    return wrapped

logwrap = debug(logger)


class HTTPClient(object):

    def __init__(self, url, keystone_url, credentials, **kwargs):
        logger.info('Initiate HTTPClient with url %s', url)
        self.url = url
        self.keystone_url = keystone_url
        self.creds = dict(credentials, **kwargs)
        self.keystone = None
        self.authenticate()
        self.opener = urllib2.build_opener(urllib2.HTTPHandler)

    def authenticate(self):
        try:
            logger.info('Initialize keystoneclient with url %s',
                        self.keystone_url)
            self.keystone = keystoneclient(
                auth_url=self.keystone_url, **self.creds)
            # it depends on keystone version, some versions doing auth
            # explicitly some dont, but we are making it explicitly always
            self.keystone.authenticate()
            logger.debug('Authorization token is successfully updated')
        except exceptions.AuthorizationFailure:
            logger.warning(
                'Cant establish connection to keystone with url %s',
                self.keystone_url)

    @property
    def token(self):
        if self.keystone is not None:
            return self.keystone.auth_token
        return None

    def get(self, endpoint):
        req = urllib2.Request(self.url + endpoint)
        return self._open(req)

    def post(self, endpoint, data=None, content_type="application/json"):
        if not data:
            data = {}
        logger.info('self url is %s' % self.url)
        req = urllib2.Request(self.url + endpoint, data=json.dumps(data))
        req.add_header('Content-Type', content_type)
        return self._open(req)

    def put(self, endpoint, data=None, content_type="application/json"):
        if not data:
            data = {}
        req = urllib2.Request(self.url + endpoint, data=json.dumps(data))
        req.add_header('Content-Type', content_type)
        req.get_method = lambda: 'PUT'
        return self._open(req)

    def delete(self, endpoint):
        req = urllib2.Request(self.url + endpoint)
        req.get_method = lambda: 'DELETE'
        return self._open(req)

    def _open(self, req):
        try:
            return self._get_response(req)
        except urllib2.HTTPError as e:
            if e.code == 401:
                logger.warning('Authorization failure: {0}'.format(e.read()))
                self.authenticate()
                return self._get_response(req)
            else:
                raise

    def _get_response(self, req):
        if self.token is not None:
            logger.debug('Set X-Auth-Token to {0}'.format(self.token))
            req.add_header("X-Auth-Token", self.token)
        return self.opener.open(req)
