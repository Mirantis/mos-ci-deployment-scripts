#!/bin/bash -e

if [ -z "${1}" ]; then
    echo "Missing deploy number"
    exit
fi

lxc-stop -n worker$1 || :
lxc-destroy -n worker$1
