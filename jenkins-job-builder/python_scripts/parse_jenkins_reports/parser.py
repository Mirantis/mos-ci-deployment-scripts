import argparse
import os

import sys

#from bs4_parse_jenkins_reports import ParseJenkinsReports
from parse_jenkins_reports import NoBS4ParseJenkinsReports
from subprocess import Popen, PIPE


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--link', help='Link to parse')
    parser.add_argument('-d', type=str)
    args = parser.parse_args()

    print 'Parsing {}'.format(args.link)
    #link = ''
    #try:
    ##    jenkins_parser = ParseJenkinsReports(args.link)
    #    jenkins_parser.get_iso_build_by_jenkins_python_api()
    #    link =jenkins_parser.iso_download_link
    #except Exception as e:
    nobs4_jenkins_parser = NoBS4ParseJenkinsReports(args.link)
    link = nobs4_jenkins_parser.get_iso_link()

    if not os.path.exists(args.d):
        try:
            os.mkdir(args.d, 0755)
        except Exception as e:
            print 'Error while trying to create directory {}'.format(args.d)
    try:
        os.chdir(args.d)

        filelist = [f for f in os.listdir(".")]
        for f in filelist:
            os.remove(f)
            print 'Removed old file {}'.format(f)

        wget_command = 'wget {}'.format(link)
        print 'Executing wget command: {}'.format(wget_command)
        p = Popen(wget_command, stderr=PIPE, stdout=PIPE, shell=True)
        out, err = p.communicate()
        print out, err
    except Exception as e:
        print 'ERROR: {}'.format(e)


if __name__ == '__main__':
    main()
