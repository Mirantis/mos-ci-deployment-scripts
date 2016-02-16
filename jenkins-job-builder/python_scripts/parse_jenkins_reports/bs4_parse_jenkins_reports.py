import ast
import re
import urllib2

from bs4 import BeautifulSoup


class ParseJenkinsReports(object):
    def __init__(self, parsed_url,
                 ci_link='https://product-ci.infra.mirantis.net/job/8.0.all/',
                 python_jenkins_api='/api/python?pretty=true'):
        self.parsed_url = parsed_url
        self.build_number = ''
        self.ci_link = ci_link
        self.python_jenkins_api = python_jenkins_api
        self.iso_download_link = ''

    def get_iso_build_by_jenkins_python_api(self):
        self.get_iso_number_by_parsing_html()
        self.get_link_by_jenkins_python_api()

    def get_iso_number_by_parsing_html(self):
        soup = BeautifulSoup(urllib2.urlopen(self.parsed_url).read())
        i = 1
        row = []
        while True:
            for j in xrange(4):
                row.append(soup('table')[0].findAll('tr')[i].findAll('td')[j])
                #print j, ' -=-', row[j]
            if row[3].text.replace('\n', '') == 'PASS':
                self.build_number = row[0].text.replace('\n', '')
                break
            i += 1

    def get_link_by_jenkins_python_api(self):
        try:
            jenkins_link = ''.join((self.ci_link, self.build_number,
                                    self.python_jenkins_api))
            result = ast.literal_eval(urllib2.urlopen(jenkins_link).read())
        except Exception as e:
            print 'Error: {}'.format(e)
            return 1
        else:
            self.iso_download_link = self.parse_jenkins_job_description_for_download_link(result['description'])
            return 0

    def parse_jenkins_job_description_for_download_link(self, descr):
        soup = BeautifulSoup(descr)
        for link in soup.findAll('a'):
            return link.get('href')

