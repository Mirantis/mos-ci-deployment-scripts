#!/bin/bash
#
#   :mod: `deploy-test-stacklight.sh` -- Deploy and test StackLight
#   ===============================================================
#
#   .. module:: deploy-test-stacklight.sh
#       :platform: Unix
#       :synopsis: Script used to deploy and test the StackLight toolchain
#   .. vesionadded:: MOS-9.0
#   .. vesionchanged:: MOS-9.0
#   .. author:: Simon Pasquier <spasquier@mirantis.com>
#
#
#   This script is used to start a single deployment test with the specified
#   test group
#
#
#   .. envvar::
#       :var  VENV_PATH: Path to the virtualenv directory that has the test
#                        framework installed
#       :var  TEST_GROUP: Test group used in test
#       :var  ISO_PATH: Path to ISO file used in test
#       :var  ENV_PREFIX: Prefix used to create the test environment name
#       :var  OPENSTACK_RELEASE: Backend distribution used in test
#
#   .. requirements::
#
#       * slave with hiera enabled:
#           fuel_project::jenkins::slave::run_tests: true
#

set -ex

rm -rf logs/*

# Prepare variable for system test
ENV_NAME="${ENV_PREFIX:0:68}"

# Generate description for the job
echo "Description string: $JOB_NAME"

export MAKE_SNAPSHOT=false

# Enable virtualenv
source "${VENV_PATH}/bin/activate"

# Store ENV name for the post job which will kill timeouted tests
echo "export ENV_NAME=\"${ENV_NAME}\"" > \
     "${WORKSPACE}/${DOS_ENV_NAME_PROPS_FILE:=.dos_environment_name}"

TEST_GROUPS=""

# delete symbols , [ ] ' characters from string and add --group=<group> for each test
for group in ${TEST_GROUP//[,\[\]\'\\]/}
do
    TEST_GROUPS="$TEST_GROUPS -o --group=${group} "
done

echo "TEST_GROUPS: $TEST_GROUPS"

# Not exit from shell if error happens so that we can report results
set +e

# Execute test
bash -x "./utils/jenkins/system_tests.sh" \
     -t test -w "${WORKSPACE}" \
     -e "${ENV_NAME}" \
     "${TEST_GROUPS}" \
     -i "${ISO_PATH}" \
     -k
