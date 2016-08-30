import yaml


class Config(object):
    def __init__(self, env_name, release):
        self.env_name = env_name
        self.release = release
        self.slaves_count = 0
        self.cluster_template = {}
        self.devops_settings = {}

    def to_dict(self):
        self.cluster_template.update({
            'name': self.env_name,
            'release': self.release
        })
        return {'template': {
            'name': self.env_name,
            'slaves': self.slaves_count,
            'cluster_template': self.cluster_template,
            'devops_settings': self.devops_settings,
        }}

    def __str__(self):
        return yaml.dump(self.template)

    def add_node(self, roles, count, disk, memory, cpus):
        pass
