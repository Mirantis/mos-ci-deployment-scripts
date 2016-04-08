SNAPSHOT=`echo $SNAPSHOT_NAME | sed 's/ha_deploy_//'`
echo "$ENV_NAME"_"$SNAPSHOT" > build-name-setter.info

REPORT_XML="$REPORT_PREFIX"/"$ENV_NAME"_"$SNAPSHOT_NAME"/"$REPORT_FILE"

virtualenv venv
. venv/bin/activate

# standard credentials for testrail is in this file, that
# is copied to host by ansible playbook
. "$TESTRAIL_FILE"

# if we need to change SUITE
if [ -n "$SUITE" ];
then
    TESTRAIL_SUITE="$SUITE"
    export TESTRAIL_SUITE="$SUITE"
fi

# if we need to change MILESTONE
if [ -n "$MILESTONE" ];
then
    TESTRAIL_MILESTONE="$MILESTONE"
    export TESTRAIL_MILESTONE="$MILESTONE"
fi

python setup.py install
report -v --testrail-plan-name "$TESTRAIL_PLAN_NAME" --env-description "$SNAPSHOT-$TEST_GROUP" --testrail-user  "${TESTRAIL_USER}" --testrail-password "${TESTRAIL_PASSWORD}" --testrail-project "${TESTRAIL_PROJECT}" --testrail-milestone "${TESTRAIL_MILESTONE}" --testrail-suite "${TESTRAIL_SUITE}" --test-results-link "$BUILD" "$REPORT_XML"
