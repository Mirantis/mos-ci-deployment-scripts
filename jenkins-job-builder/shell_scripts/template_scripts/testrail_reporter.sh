set -x

echo "$ISO_ID.$SNAPSHOT_NAME" > build-name-setter.info

virtualenv --clear testrail
. testrail/bin/activate

# NEED FIX! (move scripts from custom repo to Mirantis repo)
pip install git+https://github.com/gdyuldin/testrail_reporter.git@stable

source "$TESTRAIL_FILE"

# export variables with fuel snapshots
source /home/jenkins/env_inject.properties

# NEED FIX!
MILESTONE="9.1"

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

if [[ "$TESTRAIL_TEMPEST" == 'TRUE' ]] ;
then
    report -v \
    --testrail-plan-name "$MILESTONE snapshot $SNAPSHOT_ID" \
    --env-description "$TEST_GROUP" \
    --testrail-url  "$TESTRAIL_URL" \
    --testrail-user  "$TESTRAIL_USER" \
    --testrail-password "$TESTRAIL_PASSWORD" \
    --testrail-project "$TESTRAIL_PROJECT" \
    --testrail-milestone "$TESTRAIL_MILESTONE" \
    --testrail-suite "$TESTRAIL_SUITE" \
    --test-results-link "$BUILD_URL" \
    --testrail-name-template "{{custom_test_group}}.{{title}}" \
    --xunit-name-template "{{classname}}.{{methodname}}" \
    "$REPORT_FILE"

elif [[ "$HORIZON_UI_TESTS" == 'TRUE' ]] ;
then
    report -v \
    --testrail-plan-name "$MILESTONE snapshot $SNAPSHOT_ID" \
    --env-description "$TEST_GROUP" \
    --testrail-url  "$TESTRAIL_URL" \
    --testrail-user  "$TESTRAIL_USER" \
    --testrail-password "$TESTRAIL_PASSWORD" \
    --testrail-project "$TESTRAIL_PROJECT" \
    --testrail-milestone "$TESTRAIL_MILESTONE" \
    --testrail-suite "$TESTRAIL_SUITE" \
    --test-results-link "$BUILD_URL" \
    --testrail-name-template "{{title}}" \
    --xunit-name-template "{{methodname}}" \
    "$REPORT_FILE"
else
    report -v \
    --testrail-plan-name "$MILESTONE snapshot $SNAPSHOT_ID" \
    --env-description "$TEST_GROUP" \
    --testrail-url  "$TESTRAIL_URL" \
    --testrail-user  "$TESTRAIL_USER" \
    --testrail-password "$TESTRAIL_PASSWORD" \
    --testrail-project "$TESTRAIL_PROJECT" \
    --testrail-milestone "$TESTRAIL_MILESTONE" \
    --testrail-suite "$TESTRAIL_SUITE" \
    --test-results-link "$BUILD_URL" \
    "$REPORT_FILE"
fi

deactivate
