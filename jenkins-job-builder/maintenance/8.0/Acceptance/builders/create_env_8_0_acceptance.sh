echo $(hostname)

SNAPSHOT=$(echo $SNAPSHOT_NAME | sed 's/ha_deploy_//')

echo 8.0_"$ENV_NAME"__"$SNAPSHOT" > build-name-setter.info

set +e
source /home/jenkins/qa-venv-8.0/bin/activate
#   Destroy all envs before deploy env
dos.py list | tail -n+3 | xargs -I {} dos.py destroy {}
#   Find already installed env
UT=$(dos.py snapshot-list "$ENV_NAME" || true)
OUT=$(echo "$UT" | grep "$SNAPSHOT_NAME")
deactivate
set -e

if [ -n "$OUT" ]; then
    exit 0
fi

# Download and link ISO
export ISO_PATH=$(seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")

export ENV_NAME="$ENV_NAME"
export ERASE_PREV_ENV="$ERASE_PREV_ENV"
export SEGMENT_TYPE="$SEGMENT_TYPE"
export DVR_ENABLE="$DVR_ENABLE"
export L3_HA_ENABLE="$L3_HA_ENABLE"
export L2_POP_ENABLE="$L2_POP_ENABLE"
export LVM_ENABLE="$LVM_ENABLE"
export CINDER_ENABLE="$CINDER_ENABLE"
export CEPH_ENABLE="$CEPH_ENABLE"
export CEPH_GLANCE_ENABLE="$CEPH_GLANCE_ENABLE"
export RADOS_ENABLE="$RADOS_ENABLE"
export SAHARA_ENABLE="$SAHARA_ENABLE"
export MURANO_ENABLE="$MURANO_ENABLE"
export MONGO_ENABLE="$MONGO_ENABLE"
export CEILOMETER_ENABLE="$CEILOMETER_ENABLE"
export IRONIC_ENABLE="$IRONIC_ENABLE"
export DISABLE_SSL="$DISABLE_SSL"
export COMPUTES_COUNT="$COMPUTES_COUNT"
export CONTROLLERS_COUNT="$CONTROLLERS_COUNT"
export IRONICS_COUNT="$IRONICS_COUNT"
export FUEL_QA_VER="$FUEL_QA_VER"
export NOVA_QUOTAS_ENABLED="$NOVA_QUOTAS_ENABLED"
export SLAVE_NODE_CPU="$SLAVE_NODE_CPU"
export SLAVE_NODE_MEMORY="$SLAVE_NODE_MEMORY"
export DEPLOYMENT_TIMEOUT="$DEPLOYMENT_TIMEOUT"
export INTERFACE_MODEL="$INTERFACE_MODEL"
export KVM_USE="$KVM_USE"

export TEMPEST="${TEMPEST,,}"
export REPLICA_CEPH="${REPLICA_CEPH,,}"

if ${TEMPEST}; then
    sed -i '181i\         - label: eth1' mos_tests_template.yaml
    sed -i '182i\           l2_network_device: public' mos_tests_template.yaml

    echo '          eth1:' >> mos_tests_template.yaml
    echo '            networks:' >> mos_tests_template.yaml
    echo '             - public' >> mos_tests_template.yaml
fi

if ${REPLICA_CEPH}; then
    sed -i '16i\ replica-ceph: 1' 3_controllers_2compute_neutron_env_template.yaml
    sed -i 's/ephemeral-ceph: false/ephemeral-ceph: true/g' 3_controllers_2compute_neutron_env_template.yaml
fi

###################### Get MIRROR_UBUNTU ###############
MIRROR_HOST="http://mirror.seed-cz1.fuel-infra.org/"
if [[ ! "${MIRROR_UBUNTU}" ]]; then

    case "${UBUNTU_MIRROR_ID}" in
        latest)
            UBUNTU_MIRROR_URL="$(curl ${MIRROR_HOST}pkgs/ubuntu-latest.htm)"
            ;;
        *)
            UBUNTU_MIRROR_URL="${MIRROR_HOST}pkgs/${UBUNTU_MIRROR_ID}/"
    esac

    UBUNTU_REPOS="deb ${UBUNTU_MIRROR_URL} trusty main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-updates main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-security main universe multiverse"

    if [ "$ENABLE_PROPOSED" = true ]; then
        UBUNTU_PROPOSED="deb ${UBUNTU_MIRROR_URL} trusty-proposed main universe multiverse"
        UBUNTU_REPOS="$UBUNTU_REPOS|$UBUNTU_PROPOSED"
    fi

    export MIRROR_UBUNTU="$UBUNTU_REPOS"

fi

###################### Set extra DEB and RPM repos ####
if [[ -n "${RPM_LATEST}" ]]; then
    RPM_MIRROR="${MIRROR_HOST}mos-repos/centos/mos8.0-centos7-fuel/snapshots/"
    if [[ "${ENABLE_PROPOSED}" == "true" ]]; then
        RPM_PROPOSED="mos-proposed,${RPM_MIRROR}proposed-${RPM_LATEST}/x86_64"
        EXTRA_RPM_REPOS+="${RPM_PROPOSED}"
        UPDATE_FUEL_MIRROR="${RPM_MIRROR}proposed-${RPM_LATEST}/x86_64"
    fi
    if [[ "${ENABLE_UPDATES}" == "true" ]]; then
        RPM_UPDATES="mos-updates,${RPM_MIRROR}updates-${RPM_LATEST}/x86_64"
        if [[ -n "${EXTRA_RPM_REPOS}" ]]; then
            EXTRA_RPM_REPOS+="|"
            UPDATE_FUEL_MIRROR+=" "
        fi
        EXTRA_RPM_REPOS+="${RPM_UPDATES}"
        UPDATE_FUEL_MIRROR+="${RPM_MIRROR}updates-${RPM_LATEST}/x86_64"
    fi
    if [[ "${ENABLE_SECURITY}" == "true" ]]; then
        RPM_SECURITY="mos-security,${RPM_MIRROR}security-${RPM_LATEST}/x86_64"
        if [[ -n "${EXTRA_RPM_REPOS}" ]]; then
            EXTRA_RPM_REPOS+="|"
            UPDATE_FUEL_MIRROR+=" "
        fi
        EXTRA_RPM_REPOS+="${RPM_SECURITY}"
        UPDATE_FUEL_MIRROR+="${RPM_MIRROR}security-${RPM_LATEST}/x86_64"
    fi
    export EXTRA_RPM_REPOS
    export UPDATE_FUEL_MIRROR
    export UPDATE_MASTER=true
fi

if [[ -n "${DEB_LATEST}" ]]; then
    DEB_MIRROR="${MIRROR_HOST}mos-repos/ubuntu/snapshots/8.0-${DEB_LATEST}"
    if [[ "${ENABLE_PROPOSED}" == "true" ]]; then
        DEB_PROPOSED="mos-proposed,deb ${DEB_MIRROR} mos8.0-proposed main restricted"
        EXTRA_DEB_REPOS+="${DEB_PROPOSED}"
    fi
    if [[ "${ENABLE_UPDATES}" == "true" ]]; then
        DEB_UPDATES="mos-updates,deb ${DEB_MIRROR} mos8.0-updates main restricted"
        if [[ -n "${EXTRA_DEB_REPOS}" ]]; then
            EXTRA_DEB_REPOS+="|"
        fi
        EXTRA_DEB_REPOS+="${DEB_UPDATES}"
    fi
    if [[ "${ENABLE_SECURITY}" == "true" ]]; then
        DEB_SECURITY="mos-security,deb ${DEB_MIRROR} mos8.0-security main restricted"
        if [[ -n "${EXTRA_DEB_REPOS}" ]]; then
            EXTRA_DEB_REPOS+="|"
        fi
        EXTRA_DEB_REPOS+="${DEB_SECURITY}"
    fi
    export EXTRA_DEB_REPOS
fi

/bin/bash -x deploy_env.sh
