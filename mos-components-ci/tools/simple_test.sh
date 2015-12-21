#!/bin/bash

export MOS_VERSION=8.0
#export CUSTOM_JOB=6.1
#export CUSTOM_JOB=7.0
#export CUSTOM_JOB=7.0-custom-119
#export MOS_BUILD=525

cp etc/lxc/test/simple/* .
ln -s ~/images iso
./launch.sh
