import urllib2

import re


class IsoJenkinsParser(object):
    def __init__(self, parsed_link):
        self.parsed_link = parsed_link

    def get_links(self):
        flow = urllib2.urlopen(self.parsed_link)
        html = flow.read()
        html_table = re.compile('<table.*</table>', flags=re.DOTALL)
        table = html_table.findall(html)[0]

        html_ubuntu_bvt2_result = re.compile(
            '\s*<span class=".*" title="8.0.ubuntu.bvt_2">'
            '([A-Z]{0,4}|N/A)</span>'
        )
        html_download_link = re.compile(
            '\s*<td>\n\s*<a href="(.*)"><i class="fa fa-download"></i></a>')
        bvt2 = html_ubuntu_bvt2_result.finditer(table)
        iso_link = html_download_link.finditer(table)

        for i, j in zip(bvt2, iso_link):
            if i.group(1) == "PASS":
                return [j.group(1)]


class PluginsJenkinsParser(object):
    def __init__(self, parsed_link):
        self.parsed_link = parsed_link

    def get_links(self):
        flow = urllib2.urlopen(self.parsed_link)
        html = flow.read()

        number_template = 'href="lastSuccessfulBuild/">[^<]*\(\#(\d+)\)'
        number = re.search(number_template, html).group(1)

        template = '<a href="(http://\S*/{0}/\S*)detach-.*\.rpm">'.format(
            number)
        build_link = re.search(template, html)
        if build_link:
            build_link = build_link.group(1)
        else:
            raise Exception("Link for build #{0} doesn't exist.".format(
                number))

        flow = urllib2.urlopen(build_link)
        html = flow.read()
        templates = ['(detach-rabbitmq[^\n>]*\.rpm)',
                     '(detach-database[^\n>]*\.rpm)',
                     '(detach-keystone[^\n>]*\.rpm)']
        links = []
        for plugin_template in templates:
            plugin_name = re.search(plugin_template, html).group(1)
            links.append("".join([build_link, plugin_name]))

        return links
