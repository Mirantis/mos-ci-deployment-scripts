#!/usr/bin/env bash
# This script allows to deploy OpenStack environments
# using simple configuration file

# Hide trace on jenkins
if [ -z "$JOB_NAME" ]; then
    set -o xtrace
fi

SKIP_INSTALL_ENV=${SKIP_INSTALL_ENV:-false}

if $SKIP_INSTALL_ENV ; then
    exit 0
fi

# exit from shell if error happens
set -e

# Download and link ISO
ISO_PATH=$(seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")

# Source python virtualenv and run db migration
source ${VENV_PATH}/bin/activate
pip install -U pip

django-admin.py syncdb --settings=devops.settings
django-admin.py migrate devops --settings=devops.settings

if [ -z "$ISO_PATH" ]
then
    echo "Please download ISO and define env variable ISO_PATH"
    exit 1
fi

# Set env name
ENV_NAME=${ENV_NAME:-maintenance_env_7.0}

# Set fuel QA version
# https://github.com/openstack/fuel-qa/branches
FUEL_QA_VER=${FUEL_QA_VER:-master}

# Erase all previous environments by default
ERASE_PREV_ENV=${ERASE_PREV_ENV:-true}

# Set GROUP. By default tempest_ceph_services
GROUP=${GROUP:-tempest_ceph_services}
DISABLE_SSL=${DISABLE_SSL:-false}

# Check if fuel-qa folder exist
if [ ! -d fuel-qa ]; then
    git clone -b "${FUEL_QA_VER}" https://github.com/openstack/fuel-qa
else
    pushd fuel-qa
    git clean -f -d -x
    git checkout "${FUEL_QA_VER}"
    git reset --hard
    git pull
    popd
fi

# erase previous environments
if ${ERASE_PREV_ENV} ; then
    dos.py list | tail -n+3 | xargs -I {} dos.py erase {}
fi

cat jenkins-job-builder/maintenance/helpers/$FILE >  fuel-qa/fuelweb_test/tests/test_services.py

cd fuel-qa

# Apply fuel-qa patches
if [[ ${IRONIC_ENABLE} == 'true' ]]; then
    file_name=ironic.patch
    patch_file=../fuel_qa_patches/$file_name
    echo "Check for patch $file_name"
    git apply --check $patch_file 2> /dev/null
    if [ $? -eq 0 ]; then
        echo "Applying patch $file_name"
        git apply $patch_file
    fi
fi

if [[ ${DVR_ENABLE} == 'true' ]] || [[ ${L3_HA_ENABLE} == 'true' ]] || [[ ${L2_POP_ENABLE} == 'true' ]]; then
    file_name=DVR_L2_pop_HA.patch
    patch_file=../fuel_qa_patches/$file_name
    echo "Check for patch $file_name"
    git apply --check $patch_file 2> /dev/null
    if [ $? -eq 0 ]; then
        echo "Applying patch $file_name"
        git apply $patch_file
    fi
fi

###################### Get MIRROR_UBUNTU ###############

MIRROR_HOST="http://mirror.seed-cz1.fuel-infra.org/"

TEST_ISO_JOB_URL="${TEST_ISO_JOB_URL:-https://product-ci.infra.mirantis.net/job/7.0.test_all/}"

if [[ ! "${MIRROR_UBUNTU}" ]]; then

    case "${UBUNTU_MIRROR_ID}" in
        latest-stable)
            UBUNTU_MIRROR_ID="$(curl -fsS "${TEST_ISO_JOB_URL}lastSuccessfulBuild/artifact/ubuntu_mirror_id.txt" | awk -F '[ =]' '{print $NF}')"
            UBUNTU_MIRROR_URL="${MIRROR_HOST}pkgs/${UBUNTU_MIRROR_ID}/"
            ;;
        latest)
            UBUNTU_MIRROR_URL="$(curl ${MIRROR_HOST}pkgs/ubuntu-latest.htm)"
            ;;
        *)
            UBUNTU_MIRROR_URL="${MIRROR_HOST}pkgs/${UBUNTU_MIRROR_ID}/"
    esac

    export MIRROR_UBUNTU="deb ${UBUNTU_MIRROR_URL} trusty main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-updates main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-security main universe multiverse"
fi

###################### Set extra DEB and RPM repos ####

if [[ -n "${RPM_LATEST}" ]]; then
    if [[ "${ENABLE_PROPOSED}" == "true" ]]; then
        RPM_PROPOSED="mos-proposed,${MIRROR_HOST}mos/${RPM_LATEST}/mos6.1/proposed"
        EXTRA_RPM_REPOS+="${RPM_PROPOSED}"
        UPDATE_FUEL_MIRROR="${MIRROR_HOST}mos/${RPM_LATEST}/mos6.1/proposed"
    fi
    if [[ "${ENABLE_UPDATES}" == "true" ]]; then
        RPM_UPDATES="mos-updates,${MIRROR_HOST}mos/${RPM_LATEST}/mos6.1/updates"
        if [[ -n "${EXTRA_RPM_REPOS}" ]]; then
            EXTRA_RPM_REPOS+="|"
            UPDATE_FUEL_MIRROR+=" "
        fi
        EXTRA_RPM_REPOS+="${RPM_UPDATES}"
        UPDATE_FUEL_MIRROR+="${MIRROR_HOST}mos/${RPM_LATEST}/mos6.1/updates"
    fi
    if [[ "${ENABLE_SECURITY}" == "true" ]]; then
        RPM_SECURITY="mos-security,${MIRROR_HOST}mos/${RPM_LATEST}/mos6.1/security"
        if [[ -n "${EXTRA_RPM_REPOS}" ]]; then
            EXTRA_RPM_REPOS+="|"
            UPDATE_FUEL_MIRROR+=" "
        fi
        EXTRA_RPM_REPOS+="${RPM_SECURITY}"
        UPDATE_FUEL_MIRROR+="${MIRROR_HOST}mos/${RPM_LATEST}/mos6.1/security"
    fi
    export EXTRA_RPM_REPOS
    export UPDATE_FUEL_MIRROR
    export UPDATE_MASTER=true
fi

if [[ -n "${DEB_LATEST}" ]]; then
    if [[ "${ENABLE_PROPOSED}" == "true" ]]; then
        DEB_PROPOSED="mos-proposed,deb ${MIRROR_HOST}mos/${DEB_LATEST} mos6.1-proposed main restricted"
        EXTRA_DEB_REPOS+="${DEB_PROPOSED}"
    fi
    if [[ "${ENABLE_UPDATES}" == "true" ]]; then
        DEB_UPDATES="mos-updates,deb ${MIRROR_HOST}mos/${DEB_LATEST} mos6.1-updates main restricted"
        if [[ -n "${EXTRA_DEB_REPOS}" ]]; then
            EXTRA_DEB_REPOS+="|"
        fi
        EXTRA_DEB_REPOS+="${DEB_UPDATES}"
    fi
    if [[ "${ENABLE_SECURITY}" == "true" ]]; then
        DEB_SECURITY="mos-security,deb ${MIRROR_HOST}mos/${DEB_LATEST} mos6.1-security main restricted"
        if [[ -n "${EXTRA_DEB_REPOS}" ]]; then
            EXTRA_DEB_REPOS+="|"
        fi
        EXTRA_DEB_REPOS+="${DEB_SECURITY}"
    fi
    export EXTRA_DEB_REPOS
fi


# create new environment
# more time can be required to deploy env
export DEPLOYMENT_TIMEOUT=10000
export ENV_NAME=$ENV_NAME
export ADMIN_NODE_MEMORY=4096
export SLAVE_NODE_CPU=3
export SLAVE_NODE_MEMORY=16384
export DISABLE_SSL=$DISABLE_SSL
export KVM_USE=true

./utils/jenkins/system_tests.sh -k -K -j fuelweb_test -t test -w $(pwd) -e "$ENV_NAME" -o --group="$GROUP" -i "$ISO_PATH"