#!/bin/bash -ex

SNAPSHOT=$(echo $SNAPSHOT_NAME | sed 's/ha_deploy_//')

echo "${MILESTONE}"_"$ENV_NAME"__"$SNAPSHOT" > build-name-setter.info

REPORT_XML="${REPORT_PREFIX}/${ENV_NAME}_${SNAPSHOT_NAME}/${REPORT_FILE}"

if [ ! -f $REPORT_XML ]; then
    echo "Can't find $REPORT_XML file"
    exit 1
fi

# standard credentials for testrail is in this file, that
# is copied to host by ansible playbook
source "${TESTRAIL_FILE}"

# if we need to change SUITE
if [ -n "$SUITE" ]; then
    TESTRAIL_SUITE="${SUITE}"
fi

# if we need to change MILESTONE
if [ -n "${MILESTONE}" ]; then
    TESTRAIL_MILESTONE="${MILESTONE}"
fi

if ${ADD_TIMESTAMP}; then
    TESTRAIL_PLAN_NAME+="-$(date +%Y/%m/%d)"
fi

TEMPLATE=""
if ${USE_TEMPLATE}; then
    TEMPLATE="--testrail-name-template '{custom_test_group}.{title}' --xunit-name-template '{classname}.{methodname}'"
fi

# Workaround for bug #1647388
sed -i "s/setuptools>=17.1/setuptools==30.1.0/g" setup.py

virtualenv venv
source venv/bin/activate
python setup.py install
report -v --testrail-plan-name "$TESTRAIL_PLAN_NAME" \
          --env-description "$SNAPSHOT-$TEST_GROUP" \
          --testrail-user  "${TESTRAIL_USER}" \
          --testrail-password "${TESTRAIL_PASSWORD}" \
          --testrail-project "${TESTRAIL_PROJECT}" \
          --testrail-milestone "${TESTRAIL_MILESTONE}" \
          --testrail-suite "${TESTRAIL_SUITE}" \
          --test-results-link "$BUILD" "$REPORT_XML" \
          ${TEMPLATE}
