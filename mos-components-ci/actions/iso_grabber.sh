#!/bin/bash

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

#
# This script downloads latest Fuel ISO with all successful test results.
#

LOG=${LOG:-"log.txt"}
PRODUCT_JENKINS_URL=${PRODUCT_JENKINS_URL:-https://product-ci.infra.mirantis.net/}

{
echo
echo "######################################################"
echo "Download ISO for ${MOS_VERSION:+Fuel ${MOS_VERSION} }${CUSTOM_JOB:+custom job ${CUSTOM_JOB} }${MOS_BUILD:+#${MOS_BUILD}}"
echo "######################################################"
} | tee -a ${LOG}

test -f downloaded_iso.txt && rm -f downloaded_iso.txt

# Periodic jobs don't have parameter ZUUL_CHANGE
# Use latest Swarm-tested ISO
if [ -z "${ZUUL_CHANGE}" -a -z "${MAGNET_LINK}" ]; then
    eval $(curl -s ${PRODUCT_JENKINS_URL}/job/${MOS_VERSION:-8.0}.swarm.timer/lastSuccessfulBuild/artifact/links.txt | sed -r "s/=(.+)$/='\1'/")
fi

flock -w 14400 iso/.iso_fuel_download${CUSTOM_JOB:+-${CUSTOM_JOB}}${MOS_VERSION:+-${MOS_VERSION}}${MOS_BUILD:+-${MOS_BUILD}} \
    python componentspython/iso_grabber.py \
        ${MAGNET_LINK:+-l "${MAGNET_LINK}"} \
        ${CUSTOM_JOB:+-j ${CUSTOM_JOB}} \
        ${MOS_VERSION:+-v ${MOS_VERSION}} \
        ${MOS_BUILD:+-b ${MOS_BUILD}} \
        -o downloaded_iso.txt \
        etc/iso_grabber.conf

if grep -q -E 'MirantisOpenStack-[0-9.]+.iso' downloaded_iso.txt; then
    DOWNLOADED_ISO=$(cat downloaded_iso.txt)
    MOS_VERSION=${DOWNLOADED_ISO%.iso}
    MOS_VERSION=${MOS_VERSION##*-}
    echo "MOS_VERSION=${MOS_VERSION}" > mos_version.env
else
    echo "CUSTOM_JOB=${CUSTOM_JOB}" > mos_version.env
    perl -ne '/fuel-((?<prefix>\w+)-)?(?<version>\d\.[\d.]+)-(?<build>\d+)-\S+\.iso$/; printf "MOS_VERSION=%s\nMOS_BUILD=%d\nISO_PREFIX=%s\n", $+{version}, $+{build}, $+{prefix}' < downloaded_iso.txt >> mos_version.env
fi
