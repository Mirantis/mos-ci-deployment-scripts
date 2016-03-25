#!/bin/bash -ex

CUSTOM_VERSION=${CUSTOM_VERSION:-MU-rc}
config_name=${CONFIG_NAME:-Ubuntu 14.04}
echo $config_name

echo "$CUSTOM_VERSION"_"$TEST_GROUP" > build-name-setter.info

if [ ! -f $REPORT_XML ]; then
    echo "Can't find $REPORT_XML file"
    exit 1
fi

virtualenv venv
source venv/bin/activate
source "$TESTRAIL_FILE"

if [ -n "$SUITE" ]; then
    export TESTRAIL_TEST_SUITE=${SUITE}
fi

if [ -n "$MILESTONE" ]; then
    export TESTRAIL_MILESTONE=${MILESTONE}
fi

if [ -d fuel-qa ]; then
    rm -rf fuel-qa
fi

git clone https://github.com/openstack/fuel-qa.git
cd fuel-qa
pip install simplejson
pip install -r fuelweb_test/requirements.txt --upgrade
export PYTHONPATH="$(pwd):$PYTHONPATH"
export USE_CENTOS=$USE_CENTOS
python fuelweb_test/testrail/report_tempest_results.py -r "${TEST_GROUP}" -c "${config_name}" -i ${CUSTOM_VERSION} -p ${REPORT_XML}
