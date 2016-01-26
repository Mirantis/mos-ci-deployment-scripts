#!/bin/bash

sudo virsh net-define etc/helper_xmls/networks/net_public.xml
sudo virsh net-autostart net-public
sudo virsh net-start net-public
sudo virsh net-define etc/helper_xmls/networks/net_admin.xml
sudo virsh net-autostart net-admin
sudo virsh net-start net-admin
sudo virsh net-define etc/helper_xmls/networks/net_all.xml
sudo virsh net-autostart net-all
sudo virsh net-start net-all
sudo virsh net-define etc/helper_xmls/networks/net_ext.xml
sudo virsh net-autostart net-ext
sudo virsh net-start net-ext
