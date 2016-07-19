#!/bin/bash

set -ex

# we just search for snapshots, no need to guess nearest
# MIRROR_HOST="mirror.fuel-infra.org"

# fixme: mirror.fuel-infra.org could point to brokem mirror
MIRROR_HOST="mirror.seed-cz1.fuel-infra.org"

rm -rvf snapshots.params snapshots.sh

function to_uppercase() {
    echo "$1" | awk '{print toupper($0)}'
}

function store() {
    echo "$1=$2" >> snapshots.params
    echo "$1=\"$2\"" >> snapshots.sh
}



# Create and store ID of this snapshot file, which will be used as PK for snapshot set

__ubuntu_latest_repo_snaphot_url="$(\
    curl "http://${MIRROR_HOST}/pkgs/ubuntu-latest.htm" \
    | head -1)"
__ubuntu_latest_repo_snaphot_id="${__ubuntu_latest_repo_snaphot_url##*/}"
store "UBUNTU_MIRROR_ID" "${__ubuntu_latest_repo_snaphot_id}"



# Store snapshot for copy of Centos rpm repo

# http://mirror.fuel-infra.org/pkgs/snapshots/centos-7.2.1511-2016-05-31-083834/
#                                             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
__centos_latest_repo_snaphot_url="$(\
    curl "http://${MIRROR_HOST}/pkgs/centos-latest.htm" \
    | head -1)"
__tmp="${__centos_latest_repo_snaphot_url%/}"
__centos_latest_repo_snaphot_id="${__tmp##*/}"
store "CENTOS_MIRROR_ID" "${__centos_latest_repo_snaphot_id}"



# Store snapshot for MOS deb repo

# 9.0-2016-06-23-164100
# ^^^^^^^^^^^^^^^^^^^^^
__mos_latest_deb_mirror_id="$(\
    curl "http://${MIRROR_HOST}/mos-repos/ubuntu/snapshots/9.0-latest.target.txt" \
    | head -1)"
store "MOS_UBUNTU_MIRROR_ID" "${__mos_latest_deb_mirror_id}"



# Store snapshots for full set of MOS rpm repos

# <distribution_name>-2016-07-14-082020
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
for _dn in  "os"        \
            "proposed"  \
            "updates"   \
            "holdback"  \
            "hotfix"    \
            "security"  ; do
    __dt_snapshot="$(\
        curl "http://${MIRROR_HOST}/mos-repos/centos/mos9.0-centos7/snapshots/${_dn}-latest.target.txt" \
        | head -1)"
    store "MOS_CENTOS_$(to_uppercase "${_dn}")_MIRROR_ID" "${__dt_snapshot}"
done

#LOCATION_FACT=$(facter --external-dir /etc/facter/facts.d/ location || :)
#LOCATION=${LOCATION_FACT:-bud}

LOCATION_FACT=bud
LOCATION=bud

ENABLE_MOS_UBUNTU_PROPOSED=true
ENABLE_MOS_UBUNTU_UPDATES=true
ENABLE_MOS_UBUNTU_SECURITY=true
ENABLE_MOS_UBUNTU_HOLDBACK=true
ENABLE_MOS_CENTOS_OS=true
ENABLE_MOS_CENTOS_PROPOSED=true
ENABLE_MOS_CENTOS_UPDATES=true
ENABLE_MOS_CENTOS_SECURITY=true
ENABLE_MOS_CENTOS_HOLDBACK=true

# fixme: move to macros
case "${LOCATION}" in
    # fixme: mirror.fuel-infra.org could point to brokem mirror
    # srt)
    #     MIRROR_HOST="osci-mirror-srt.srt.mirantis.net"
    #     ;;
    # msk)
    #     MIRROR_HOST="osci-mirror-msk.msk.mirantis.net"
    #     ;;
    # kha)
    #     MIRROR_HOST="osci-mirror-kha.kha.mirantis.net"
    #     LOCATION="hrk"
    #     ;;
    poz|bud|bud-ext|undef)
        MIRROR_HOST="mirror.seed-cz1.fuel-infra.org"
        LOCATION="cz"
        ;;
    mnv|scc|sccext)
        MIRROR_HOST="mirror.seed-us1.fuel-infra.org"
        LOCATION="usa"
        ;;
    *)
        # MIRROR_HOST="mirror.fuel-infra.org"
        # fixme: mirror.fuel-infra.org could point to brokem mirror
        MIRROR_HOST="mirror.seed-cz1.fuel-infra.org"

esac



if [[ ! "${MIRROR_UBUNTU}" ]]; then

    case "${UBUNTU_MIRROR_ID}" in
        latest)
            UBUNTU_MIRROR_URL="$(curl "http://${MIRROR_HOST}ubuntu-latest.htm")"
            ;;
        *)
            UBUNTU_MIRROR_URL="http://${MIRROR_HOST}/pkgs/${UBUNTU_MIRROR_ID}/"
    esac

    UBUNTU_REPOS="deb ${UBUNTU_MIRROR_URL} trusty main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-updates main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-security main universe multiverse"

# todo: later ..
#    ENABLE_PROPOSED="${ENABLE_PROPOSED:-true}"
#
#    if [ "$ENABLE_PROPOSED" = true ]; then
#        UBUNTU_PROPOSED="deb ${UBUNTU_MIRROR_URL} trusty-proposed main universe multiverse"
#        UBUNTU_REPOS="$UBUNTU_REPOS|$UBUNTU_PROPOSED"
#    fi

    export MIRROR_UBUNTU="$UBUNTU_REPOS"

fi



function join() {
    local __sep="${1}"
    local __head="${2}"
    local __tail="${3}"

    if [[ -n "${__head}" ]]; then
        echo "${__head}${__sep}${__tail}"
    else
        echo "${__tail}"
    fi
}

function to_uppercase() {
    echo "$1" | awk '{print toupper($0)}'
}

__space=' '
__pipe='|'


# Adding MOS rpm repos to
# - UPDATE_FUEL_MIRROR - will be used for master node
# - EXTRA_RPM_REPOS - will be used for nodes in cluster

for _dn in  "os"        \
            "proposed"  \
            "updates"   \
            "holdback"  \
            "hotfix"    \
            "security"  ; do
    # a pointer to variable name which holds value of enable flag for this dist name
    __enable_ptr="ENABLE_MOS_CENTOS_$(to_uppercase "${_dn}")"
    if [[ "${!__enable_ptr}" = true ]] ; then
        # a pointer to variable name which holds repo id
        __repo_id_ptr="MOS_CENTOS_$(to_uppercase "${_dn}")_MIRROR_ID"
        __repo_url="http://${MIRROR_HOST}/mos-repos/centos/mos9.0-centos7/snapshots/${!__repo_id_ptr}/x86_64"
        __repo_name="mos-${_dn},${__repo_url}"
        UPDATE_FUEL_MIRROR="$(join "${__space}" "${UPDATE_FUEL_MIRROR}" "${__repo_url}" )"
        EXTRA_RPM_REPOS="$(join "${__pipe}" "${EXTRA_RPM_REPOS}" "${__repo_name}" )"
    fi
done

# UPDATE_MASTER=true in case when we have set some repos
# otherwise there will be no reason to start updating without any repos to update from

if [[ -n "${UPDATE_FUEL_MIRROR}" ]] ; then
    UPDATE_MASTER=true
fi

# Adding MOS deb repos to
# - EXTRA_DEB_REPOS - will be used for nodes in cluster

for _dn in  "proposed"  \
            "updates"   \
            "holdback"  \
            "hotfix"    \
            "security"  ; do
    # a pointer to variable name which holds value of enable flag for this dist name
    __enable_ptr="ENABLE_MOS_UBUNTU_$(to_uppercase "${_dn}")"
    # a pointer to variable name which holds repo id
    __repo_id_ptr="MOS_UBUNTU_MIRROR_ID"
    __repo_url="http://${MIRROR_HOST}/mos-repos/ubuntu/snapshots/${!__repo_id_ptr}"

    if [[ "${!__enable_ptr}" = true ]] ; then
        __repo_name="mos-${_dn},deb ${__repo_url} mos9.0-updates main restricted"
        EXTRA_DEB_REPOS="$(join "${__pipe}" "${EXTRA_DEB_REPOS}" "${__repo_name}")"
    fi
done

echo 'EXTRA_DEB_REPOS="'$EXTRA_DEB_REPOS'"' >> "$ENV_INJECT_PATH"
echo 'UPDATE_FUEL_MIRROR="'$UPDATE_FUEL_MIRROR'"' >> "$ENV_INJECT_PATH"
echo 'UPDATE_MASTER="'$UPDATE_MASTER'"' >> "$ENV_INJECT_PATH"
echo 'EXTRA_RPM_REPOS="'$EXTRA_RPM_REPOS'"' >> "$ENV_INJECT_PATH"
echo 'EXTRA_DEB_REPOS="'$EXTRA_DEB_REPOS'"' >> "$ENV_INJECT_PATH"
