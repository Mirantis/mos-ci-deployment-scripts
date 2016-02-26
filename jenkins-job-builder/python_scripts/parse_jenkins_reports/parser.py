import argparse
import os
import sys
from subprocess import Popen, PIPE

from parse_jenkins_reports import NoBS4ParseJenkinsReports


def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--link', help='Link to parse')
    parser.add_argument('-d', type=str)
    args = parser.parse_args()
    return args.d, args.link


def main():
    target_directory, link = get_args()
    print 'Parsing {}'.format(link)

    nobs4_jenkins_parser = NoBS4ParseJenkinsReports(link)
    link = nobs4_jenkins_parser.get_iso_link()

    if not os.path.exists(target_directory):
        try:
            os.mkdir(target_directory, 0755)
        except Exception as e:
            print 'Error while trying to create directory {}'.format(target_directory)
            print e
            sys.exit(1)
    try:
        os.chdir(target_directory)
        for f in os.listdir("."):
            os.remove(f)
            print 'Removed old file {}'.format(f)
    except IOError as e:
        print 'Error: {0}'.format(e)

    try:
        wget_command = 'wget {}'.format(link)
        print 'Executing wget command: {}'.format(wget_command)
        p = Popen(wget_command, stderr=PIPE, stdout=PIPE, shell=True)
        while True:
            line = p.stderr.readline()
            if not line:
                break
            print line

        out, err = p.communicate()
        if out:
            print 'wget command output is: {0}'.format(out)
    except Exception as e:
        print 'ERROR: {0}'.format(e)
        if err:
            print 'wget command error: {0}'.format(err)


if __name__ == '__main__':
    main()
