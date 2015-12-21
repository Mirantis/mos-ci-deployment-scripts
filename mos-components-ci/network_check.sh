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

#!/bin/bash

until [ -z $1 ]; do
    if [ "$1" = "-int" ]; then
        interface=$2
        shift
    elif [ "$1" = "-ip" ]; then
        ip=$2
        shift
    elif [ "$1" = "-gw" ]; then
        gateway=$2
        shift
    elif [ "$1" = "-vlans" ]; then
        vlans=$2
        shift
    elif [ "$1" = "default" ]; then
        FUNC=create_default_network
    elif [ "$1" = "custom" ]; then
        FUNC=create_custom_network
    elif [ "$1" = "--help" ]; then
        echo -e "
use
$./network_check.sh default
because create default network settings

use
$./network_check.sh custom
because create custom network settings

parameters:
-int    interface for creating vlans,
        format: sssx (e.g eth0),
        default: eth0

-ip     IP for bridge with Internet,
        format: xxx.xxx.xxx.xxx/xx (e.g 172.18.78.78/25),
        default finding ip in interface.

-gw     Gateway for bridge with Internet,
        format: xxx.xxx.xxx.xxx (e.g. 172.18.78.1),
        default 172.18.78.1

-vlans  list of vlans for creating or deleting,
        format: \"xxx xxxx xxx\".
        default: 1071
"

        exit 0
    fi
    shift
done

interface=${interface:-'eth0'}
vlans=${vlans:-"1071"}
gateway=${gateway:-"172.18.78.1"}

create_custom_network() {

    ip=${ip:-$(ip addr show | grep "global $interface" | awk '{print $2}')}

    sudo ip link add link $interface name br19 type bridge
    for vlan in $vlans; do
        sudo ip link add link $interface name $interface.$vlan type vlan id $vlan
    done
    for vlan in $vlans; do
        sudo ip link add link $interface.$vlan name br$vlan type bridge
    done
    sudo ip link set $interface master br19
    for vlan in $vlans; do
        sudo ip link set $interface.$vlan master br$vlan
    done

    sudo ip link set br19 up
    for vlan in $vlans; do
        sudo ip link set $interface.$vlan up; sudo ip link set br$vlan up
    done

    sudo ip addr del $ip dev $interface
    sudo ip addr add $ip dev br19
    i=0
    for vlan in $vlans; do
        sudo ip addr add 10.20.$i.200/24 dev br$vlan; let "i=i+1"
    done

    if [ ! -f /etc/network/interfaces ]; then
        sudo cp /etc/network/interfaces.sample /etc/network/interfaces 2>/dev/null
    fi
    if [ -f /etc/network/interfaces.new ]; then
        sudo rm /etc/network/interfaces.new
    fi
    if [ -f /etc/network/interfaces.old ]; then
        sudo rm /etc/network/interfaces.old
    fi
    sudo touch /etc/network/interfaces.new
    sudo chmod 666 /etc/network/interfaces.new
    sudo sed "s/$interface/br19/g" /etc/network/interfaces | sudo tee /etc/network/interfaces.new
    sudo mv /etc/network/interfaces /etc/network/interfaces.old
    sudo mv /etc/network/interfaces.new /etc/network/interfaces

    sudo service networking restart
    sudo ip ro add default via $gateway 2>/dev/null
}

create_default_network() {
    ip=${ip:-$(ip addr show | grep "global br19" | awk '{print $2}')}
    sudo rm /etc/network/interfaces 2>/dev/null
    sudo cp /etc/network/interfaces.sample /etc/network/interfaces 2>/dev/null
    sudo ip link del br19 2>/dev/null
    for vlan in $vlans; do
        sudo ip link del $interface.$vlan
    done
    for vlan in $vlans; do
        sudo ip link del br$vlan
    done
    sudo service networking restart
    sudo ip addr add $ip dev $interface
    sudo service networking restart
    sudo ip ro add default via $gateway 2>/dev/null
}

$FUNC
