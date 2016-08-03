#!/bin/bash

set -ex

MIRROR_HOST="mirror.seed-cz1.fuel-infra.org"

rm -rvf snapshots.params snapshots.sh

wget https://product-ci.infra.mirantis.net/job/9.x.snapshot/lastSuccessfulBuild/artifact/snapshots.params

source snapshots.params

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

echo "UPDATE_FUEL_MIRROR=$UPDATE_FUEL_MIRROR" >> "$ENV_INJECT_PATH"
echo "UPDATE_MASTER=$UPDATE_MASTER" >> "$ENV_INJECT_PATH"
echo "EXTRA_RPM_REPOS=$EXTRA_RPM_REPOS" >> "$ENV_INJECT_PATH"
echo "EXTRA_DEB_REPOS=$EXTRA_DEB_REPOS" >> "$ENV_INJECT_PATH"
