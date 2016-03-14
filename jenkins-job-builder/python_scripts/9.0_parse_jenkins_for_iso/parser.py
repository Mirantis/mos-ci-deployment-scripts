import argparse
import os
import sys

from ast import literal_eval
from subprocess import Popen, PIPE
from urllib2 import urlopen


def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--link', help='Link to parse')
    parser.add_argument('-d', type=str)
    parser.add_argument('--link-only', action="store_true")
    args = parser.parse_args()
    return args.d, args.link, args.link_only


def get_iso_link(link):
    flow = literal_eval(urlopen(link).read())
    iso_link = flow['description'].split('>', 1)[0].split('=', 1)[1]
    return iso_link


def main():
    target_directory, link_to_jenkins, link_only = get_args()

    link = get_iso_link(link_to_jenkins)
    print link.split('/')[-1]

    if link_only:
        sys.exit(0)

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
