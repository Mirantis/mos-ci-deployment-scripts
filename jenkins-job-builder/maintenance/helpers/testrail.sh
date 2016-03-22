#!/bin/bash -ex

CUSTOM_VERSION=${CUSTOM_VERSION:-MU-rc}
echo "$CUSTOM_VERSION"_"$TEST_GROUP" > build-name-setter.info

if [ ! -f $REPORT_XML ]; then
    echo "Can't find $REPORT_XML file"
    exit 1
fi

virtualenv venv
source venv/bin/activate
source "$TESTRAIL_FILE"

if [ -n "$SUITE" ]; then
    export TESTRAIL_TEST_SUITE="$SUITE"
fi

if [ -n "$MILESTONE" ]; then
    export TESTRAIL_MILESTONE="$MILESTONE"
fi

if [ -d fuel-qa ]; then
    rm -rf fuel-qa
fi

config_name=${CONFIG_NAME:-Ubuntu 14.04}

git clone https://github.com/openstack/fuel-qa.git
pip install launchpadlib
pip install simplejson
cd fuel-qa
export PYTHONPATH="$(pwd):$PYTHONPATH"
python fuelweb_test/testrail/report_tempest_results.py -r "$TEST_GROUP" -c "${config_name}" -i "${CUSTOM_VERSION}" -p "${REPORT_XML}"
