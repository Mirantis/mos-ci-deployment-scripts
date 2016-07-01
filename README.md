### Introduction

This repository contains scripst to deploy Mirantis OpenStack in different configurations to run integration tests on it later. Here is some entry points (scripts) to deploy cloud:

* deploy_env.sh
* deploy_template.sh (with templates)


#### Deploying with templates

Easiest way - is to choose suitable template from *templates* folder and pass it as 1st argument to script:

```bash
$ export ISO_PATH=/path/to/fuel.iso
$ ./deploy_template.sh templates/neutron/vlan_dvr.yaml
```


#### Deploying of separate components with templates

Again choose suitable template from *templates* folder and just source script to obtain the plugins and set up the environment variables. By default the plugins to be stored in $HOME/detach-plugins/:

```bash
$ source jenkins-job-builder/shell_scripts/get_plugins.sh
$ export ISO_PATH=/path/to/fuel.iso
$ ./deploy_template.sh templates/neutron/vlan_dvr.yaml
```


#### Write your own template

Template is just YAML file with next keys under root key (template):

* **cluster_template** - this section will pass to fuel
* **devops_settings** - this section used to create virtual nodes with fuel_devops
* **name** - it's just output during deploy
* **slaves** - must be equal to devops slaves count

Nodes in cluster_template/nodes are mapping to devops_settings/groups[0]/nodes.
