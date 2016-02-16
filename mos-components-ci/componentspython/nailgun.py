#    Copyright 2014 Mirantis, Inc.
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

import os

from ConfigParser import SafeConfigParser
import json
import libvirt
from sys import argv
import time
import urllib2

from componentspython.componentshttp import logger
import componentspython.nailgun_client as fuel


POLL_PERIOD = 60  # seconds

multiversion_dict = {
    '5.1.2': {
        'cluster': 'cluster_id'
    },
    '6.0': {
        'cluster': 'cluster_id'
    },
    '6.0.1': {
        'cluster': 'cluster_id'
    },
    '6.1': {
        'cluster': 'cluster'
    },
    '7.0': {
        'cluster': 'cluster'
    },
    '8.0': {
        'cluster': 'cluster'
    },
}


def create_environment(fuel_ip, kvm_count, machines_count, cluster_settings):

    #   Connect to Fuel Main Server

    client = fuel.NailgunClient(str(fuel_ip))

    version = client.get_api_version()['release']

    #   Clean Fuel cluster

    for cluster in client.list_clusters():
        client.delete_cluster(cluster['id'])
        while True:
            try:
                client.get_cluster(cluster['id'])
            except urllib2.HTTPError as e:
                if str(e) == "HTTP Error 404: Not Found":
                    break
                else:
                    raise
            except Exception:
                raise
            time.sleep(1)

    #   Create cluster

    get_release = lambda x: next(release['id'] for release
                                 in client.get_releases()
                                 if release['operating_system'].lower() == x)

    release_id = get_release(cluster_settings['release_name'])

    data = {"name": cluster_settings['env_name'],
            "release": release_id,
            "mode": cluster_settings['config_mode'],
            "net_provider": cluster_settings['net_provider']}
    if cluster_settings.get('net_segment_type'):
        data['net_segment_type'] = cluster_settings['net_segment_type']

    client.create_cluster(data)

    #   Update cluster configuration

    cluster_id = client.get_cluster_id(cluster_settings['env_name'])
    attributes = client.get_cluster_attributes(cluster_id)

    settings = json.loads(cluster_settings['settings'])

    for option in settings:
        section = False
        if option in ('sahara', 'murano', 'ceilometer'):
            section = 'additional_components'
        if option in ('volumes_ceph', 'images_ceph', 'ephemeral_ceph',
                      'objects_ceph', 'osd_pool_size', 'volumes_lvm'):
            section = 'storage'
        if option in ('method'):
            section = 'provision'
        if section:
            attributes['editable'][section][option]['value'] = settings[option]

    hpv_data = attributes['editable']['common']['libvirt_type']
    hpv_data['value'] = str(cluster_settings['virt_type'])

    debug = cluster_settings.get('debug', 'false')
    auto_assign = cluster_settings.get('auto_assign_floating_ip', 'false')
    nova_quota = cluster_settings.get('nova_quota', 'false')

    attributes['editable']['common']['debug']['value'] = json.loads(debug)
    attributes['editable']['common'][
        'auto_assign_floating_ip']['value'] = json.loads(auto_assign)
    attributes['editable']['common']['nova_quota']['value'] = \
        json.loads(nova_quota)

    if cluster_settings['release_name'] == 'centos':
        use_fedora_lt = cluster_settings.get('use_fedora_lt', 'false')
        if json.loads(use_fedora_lt) is True:
            centos_kernel = 'fedora_lt_kernel'
        else:
            centos_kernel = 'default_kernel'
        attributes['editable']['use_fedora_lt'][
            'kernel']['value'] = centos_kernel

    if 'public_ssl' in attributes['editable']:
        # SSL/TLS for public services endpoints
        public_ssl = cluster_settings.get('public_ssl', 'false').lower()
        attributes['editable']['public_ssl']['services']['value'] = \
            public_ssl == 'true'
        # SSL/TLS for Horizon
        horizon_ssl = cluster_settings.get('horizon_ssl', 'false').lower()
        attributes['editable']['public_ssl']['horizon']['value'] = \
            horizon_ssl == 'true'

    client.update_cluster_attributes(cluster_id, attributes)

    #  Loop for wait cluster nodes

    counter = 0
    while True:

        actual_kvm_count = len([k for k in client.list_nodes()
                                if not k['cluster'] and k['online']
                                and k['status'] == 'discover'
                                and k['manufacturer'] in ['KVM', 'QEMU']])

        actual_machines_count = len([k for k in client.list_nodes()
                                    if not k['cluster'] and k['online']
                                    and k['status'] == 'discover'
                                    and k['manufacturer'] == 'Supermicro'])

        if (actual_kvm_count >= int(kvm_count)
                and actual_machines_count >= int(machines_count)):
            break
        counter += 5
        if counter > 60 * 15:
            raise RuntimeError
        time.sleep(5)

    #   Network configuration on environment

    default_networks = client.get_networks(cluster_id)

    networks = json.loads(cluster_settings['networks'])

    change_dict = networks.get('networking_parameters', {})
    for key, value in change_dict.items():
        default_networks['networking_parameters'][key] = value

    for net in default_networks['networks']:
        change_dict = networks.get(net['name'], {})
        for key, value in change_dict.items():
            net[key] = value

    client.update_network(cluster_id,
                          default_networks['networking_parameters'],
                          default_networks['networks'])

    #   Loop with operations of nodes

    for node_name, params in json.loads(
            cluster_settings['node_roles']).items():

        #   Add all available nodes to cluster
        if 'mac' in params:
            node = next(k for k in client.list_nodes()
                        if k['mac'] == params['mac'])
        elif 'version' in params:
            node = next(k for k in client.list_nodes()
                        if k['platform_name'] == node_name
                        and k['manufacturer'] == params['manufacturer']
                        and not k['cluster'] and k['online'])
        else:
            node = next(k for k in client.list_nodes()
                        if k['manufacturer'] == params['manufacturer']
                        and not k['cluster'] and k['online'])

        data = {multiversion_dict[version]["cluster"]: str(cluster_id),
                "pending_roles": params['roles'],
                "pending_addition": True,
                "name": node_name,
                }

        client.update_node(node['id'], data)

        #   Disks configuration on nodes

        if 'disks' in params:
            all_disks = client.get_node_disks(node['id'])
            list_for_update = []
            for disk in params['disks']:
                default_disks = [i for i in all_disks
                                 if i['name'] == disk['name']]
                if default_disks:
                    default_disk = default_disks[0]
                else:
                    msg = "Disk with name: {name} on node:{node} not found"
                    logger.warning(msg.format(name=disk['name'],
                                              node=node['id']))
                    continue
                volumes = []
                for volume, size in disk['volumes'].iteritems():
                    if not size.isdigit():
                        if size == "full":
                            size = int(default_disk['size'])
                        if size == "half":
                            size = int(default_disk['size'])/2 - 1
                        if size == "third":
                            size = int(default_disk['size'])/3 - 1
                    volumes.append({'name': volume, 'size': size})
                default_disk['volumes'] = volumes
                list_for_update.append(default_disk)
                all_disks.remove(default_disk)
            client.put_node_disks(node['id'], list_for_update)

        #   Network configuration on nodes

        if 'interfaces' in params:
            networks_dict = params['interfaces']
        else:
            networks_dict = json.loads(cluster_settings['interfaces'])
        update_node_networks(client, node['id'], networks_dict)


def deploy_environment(fuel_ip, cluster_settings):
    client = fuel.NailgunClient(str(fuel_ip))
    cluster_id = client.get_cluster_id(cluster_settings['env_name'])
    client.deploy_cluster_changes(cluster_id)


def update_node_networks(client, node_id, interfaces_dict, raw_data=None):

    # Check to change interface for fuelweb_admin network
    custom_fuelweb_admin = False
    network_list = []
    for iface, networks in interfaces_dict.iteritems():
        network_list.extend(networks)
    if 'fuelweb_admin' in network_list:
        custom_fuelweb_admin = True

    # get dictionary for update
    interfaces = client.get_node_interfaces(node_id)

    # create list with all networks on all interfaces
    all_networks = dict()
    for interface in interfaces:
        all_networks.update(
            {net['name']: net for net in interface['assigned_networks']})
        #  find and save interface with network fuelweb_admin if fuelweb_admin
        #  network is not specified
        if not custom_fuelweb_admin:
            for network in interface['assigned_networks']:
                if network['name'] == 'fuelweb_admin':
                    interfaces_dict[interface['name']].append('fuelweb_admin')

    # change network dictionary
    if raw_data:
        interfaces.append(raw_data)

    for interface in interfaces:
        name = interface["name"]
        interface['assigned_networks'] = \
            [all_networks[i] for i in interfaces_dict.get(name, [])]

    # update network parameters on cluster
    client.put_node_interfaces([{'id': node_id, 'interfaces': interfaces}])


def await_deploy(fuel_ip, cluster_settings):
    client = fuel.NailgunClient(str(fuel_ip))
    cluster_id = client.get_cluster_id(cluster_settings['env_name'])
    conn = libvirt.open("qemu:///system")
    err_message = "Cluster {0} with name {1} has error status".format(
        cluster_id, cluster_settings['env_name'])

    deploy_timeout = int(cluster_settings.get('deploy_timeout', 7200))
    waiting_time = 0
    while waiting_time < deploy_timeout:
        for domain_name in conn.listDefinedDomains():
            conn.lookupByName(domain_name).create()

        try:
            state = client.get_cluster(cluster_id)['status']
            if state == 'operational':
                return
            if state == 'error':

                task_id = client.generate_logs()['id']
                start_time = time.time()

                while client.get_task(task_id)['status'] == 'running':
                    time.sleep(5)
                    if time.time() - start_time > 600:
                        raise RuntimeError(
                            "Diagnostic snapshot makes so very long. "
                            "Aborting. " + err_message)

                task = client.get_task(task_id)
                url = "http://{0}:8000{1}".format(fuel_ip, task['message'])
                log_path = os.environ.get("LOGGING_PATH", "logs/")
                log_name = "diagnostic_snapshot.tar.xz"

                if log_path.startswith('/'):
                    logfile = os.path.join(log_path, log_name)
                else:
                    logfile = os.path.join(
                        os.path.join(os.getcwd()), log_path, log_name)

                try:
                    with open(logfile, 'w') as f:
                        f.write(
                            urllib2.urlopen(url).read()
                        )
                except (urllib2.HTTPError, urllib2.URLError) as e:
                    raise RuntimeError(
                        "Diagnostic snapshot ready, but not saved. " +
                        err_message + "({0}): {1}".format(e.errno, e.strerror)
                    )

                raise RuntimeError(err_message)
            logger.info('Waiting {0} of {1} seconds - cluster {2} has '
                        'state "{3}"'.format(
                            waiting_time,
                            deploy_timeout,
                            cluster_id,
                            state
                        ))
        except urllib2.URLError:
            pass
        waiting_time += POLL_PERIOD
        time.sleep(POLL_PERIOD)
    raise RuntimeError('Timeout waiting for cluster deployment')


def get_snapshot(fuel_ip):
    client = fuel.NailgunClient(str(fuel_ip))

    task_id = client.generate_logs()['id']
    start_time = time.time()

    while client.get_task(task_id)['status'] == 'running':
        time.sleep(5)
        if time.time() - start_time > 1200:
            raise RuntimeError(
                "Diagnostic snapshot makes so very long. Aborting.")

    task = client.get_task(task_id)
    log_path = os.environ.get("LOGGING_PATH", "logs/")
    log_name = "diagnostic_snapshot.tar.xz"

    if log_path.startswith('/'):
        logfile = os.path.join(log_path, log_name)
    else:
        logfile = os.path.join(
            os.path.join(os.getcwd()), log_path, log_name)

    client.save_diagnostic_snapshot(task['message'], logfile)


def get_node_type():
    config = argv[1]
    node_name = argv[2]

    parser = SafeConfigParser()
    parser.read(config)

    cluster_settings = dict(parser.items('cluster'))

    node_roles = json.loads(cluster_settings['node_roles'])
    if str(node_name) in node_roles:
        print node_roles[str(node_name)]['version']


def return_job_parameters():
    config = argv[1]
    fuel_ip = argv[2]
    parameter = argv[3]

    parser = SafeConfigParser()
    parser.read(config)

    cluster_settings = dict(parser.items('cluster'))
    settings = json.loads(cluster_settings['settings'])

    if parameter == "iso":
        print str(
            fuel.NailgunClient(str(fuel_ip)).get_api_version()['build_number']
        )

    if parameter == "milestone":
        print str(
            fuel.NailgunClient(str(fuel_ip)).get_api_version()['release']
        )

    if parameter == "config":

        get_version = lambda x: next(
            ".".join(release['name'].split()[-1].split(".")[0:2]) for release
            in fuel.NailgunClient(str(fuel_ip)).get_releases()
            if release['operating_system'].lower() == x)

        get_config = lambda x: x[0].upper() + x[1:] + " " + get_version(x)

        print str(get_config(cluster_settings['release_name']))

    if parameter == "run_name":
        run_name = ""

        if cluster_settings["config_mode"] == 'ha_compact':
            run_name += "HA mode"
        else:
            run_name += "Simple mode"

        if cluster_settings["net_provider"] == "neutron":
            run_name += "; Neutron with {}".format(
                cluster_settings['net_segment_type'].upper())
        else:
            run_name += "; Nova network"

        if settings["volumes_lvm"]:
            run_name += "; Cinder LVM"

        ceph_list = []
        if settings['volumes_ceph']:
            ceph_list.append('volumes')
        if settings['images_ceph']:
            ceph_list.append('images')
        if settings['ephemeral_ceph']:
            ceph_list.append('eph. volumes')
        if ceph_list:
            run_name += "; Ceph " + ", ".join(ceph_list)

        if settings['objects_ceph']:
            run_name += "; RadosGW"

        components_list = []
        if settings['sahara']:
            components_list.append('Sahara')
        if settings['murano']:
            components_list.append('Murano')
        if settings['ceilometer']:
            components_list.append('Ceilo')
        if components_list:
            run_name += "; " + ", ".join(components_list) + " enabled"

        print run_name


def return_controller_ip():
    config = argv[1]
    fuel_ip = argv[2]

    parser = SafeConfigParser()
    parser.read(config)

    cluster_settings = dict(parser.items('cluster'))

    client = fuel.NailgunClient(str(fuel_ip))
    cluster_id = client.get_cluster_id(cluster_settings['env_name'])
    if cluster_settings['config_mode'] == 'ha_compact':
        ext_env_ip = client.get_networks(cluster_id).get("public_vip", "")
    else:
        ext_env_ip = next(network['ip_ranges'][0][0] for network
                          in client.get_networks(cluster_id)['networks']
                          if network['name'] == 'public')
    if ext_env_ip:
        logger.info("Cluster URL: http://{}/".format(ext_env_ip))
        print ext_env_ip
    else:
        logger.warning("Cluster URL not found")


def keystone_proto():
    config = argv[1]
    fuel_ip = argv[2]

    parser = SafeConfigParser()
    parser.read(config)

    cluster_settings = dict(parser.items('cluster'))

    client = fuel.NailgunClient(str(fuel_ip))
    cluster_id = client.get_cluster_id(cluster_settings['env_name'])

    if dict(client.get_cluster_attributes(cluster_id)).get(
            'editable', {}).get('public_ssl', {}).get('services', {}).get(
            'value', False):
        return 'https'
    else:
        return 'http'


def get_attributes():
    config = argv[1]
    fuel_ip = argv[2]

    parser = SafeConfigParser()
    parser.read(config)

    cluster_settings = dict(parser.items('cluster'))

    client = fuel.NailgunClient(str(fuel_ip))
    cluster_id = client.get_cluster_id(cluster_settings['env_name'])

    print json.dumps(client.get_cluster_attributes(cluster_id))


def main():
    parser = SafeConfigParser()
    parser.read(argv[1])

    fuel_ip = argv[2]
    kvm_count = argv[3]
    machines_count = argv[4]

    cluster_settings = dict(parser.items('cluster'))

    create_environment(fuel_ip, kvm_count, machines_count, cluster_settings)
    deploy_environment(fuel_ip, cluster_settings)
    await_deploy(fuel_ip, cluster_settings)
