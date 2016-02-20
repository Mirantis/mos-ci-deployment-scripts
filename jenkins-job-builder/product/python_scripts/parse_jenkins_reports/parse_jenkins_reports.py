import urllib2

import re


class NoBS4ParseJenkinsReports(object):
    def __init__(self, parsed_link):
        self.parsed_link = parsed_link

    def get_iso_link(self):
        flow = urllib2.urlopen(self.parsed_link)
        html = flow.read()
        html_table = re.compile('\<table.*\<\/table\>', flags=re.DOTALL)
        table = html_table.findall(html)[0]
        #print table
        html_ubuntu_bvt2_result = re.compile('\s*<span class=\".*\" title="8.0.ubuntu.bvt_2">([A-Z]{0,4}|N\/A)<\/span>')
        html_download_link = re.compile('\s*<td>\n\s*<a href=\"(.*)\"><i class=\"fa fa-download\"><\/i><\/a>')
        bvt2 = html_ubuntu_bvt2_result.finditer(table)
        iso_link = html_download_link.finditer(table)
        #for i in iso_link:
        #    print i.group(1)
        for i, j in zip(bvt2, iso_link):
            if i.group(1) == "PASS":
                return j.group(1)
