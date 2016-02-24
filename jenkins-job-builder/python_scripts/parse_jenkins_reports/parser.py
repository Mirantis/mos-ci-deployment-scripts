import argparse
import os
import sys
from subprocess import Popen, PIPE

from parse_jenkins_reports import IsoJenkinsParser
from parse_jenkins_reports import PluginsJenkinsParser


def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--link', help='Link to parse')
    parser.add_argument('-d', type=str)
    parser.add_argument('--type', default='iso')
    args = parser.parse_args()
    return args.d, args.link, args.type


def prepare_directory(target_directory):
    if not os.path.exists(target_directory):
        try:
            os.mkdir(target_directory, 0755)
        except Exception as e:
            print 'Error while trying to create directory {}'.format(
                target_directory)
            print e
            sys.exit(1)
    try:
        os.chdir(target_directory)
        for f in os.listdir("."):
            os.remove(f)
            print 'Removed old file {}'.format(f)
    except IOError as e:
        print 'Error: {0}'.format(e)


def load_file_from_link(link):
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
            sys.exit(1)


def main():
    target_directory, link, link_type = get_args()
    print 'Parsing {}'.format(link)

    if link_type == 'iso':
        jenkins_parser = IsoJenkinsParser(link)
    elif link_type == 'plugins':
        jenkins_parser = PluginsJenkinsParser(link)
    else:
        raise ValueError("Error: only the following types are available: "
                         "'iso', 'plugins'.")

    links = jenkins_parser.get_links()

    prepare_directory(target_directory)
    for link in links:
        load_file_from_link(link)


if __name__ == '__main__':
    main()
