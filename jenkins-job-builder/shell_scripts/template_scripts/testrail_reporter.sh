set -x

echo "$ISO_ID.$SNAPSHOT_NAME" > build-name-setter.info

virtualenv --clear testrail
. testrail/bin/activate

source /home/jenkins/env_inject.properties
export SNAPSHOT_ID

# NEED FIX! (move scripts from custom repo to Mirantis repo)
pip install git+https://github.com/gdyuldin/testrail_reporter.git@stable

source "$TESTRAIL_FILE"

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

if [[ -z "$TESTRAIL_PLAN_NAME" ]];
then
    TESTRAIL_PLAN_NAME="$MILESTONE snapshot $SNAPSHOT_ID"
else
    TESTRAIL_PLAN_NAME="$TESTRAIL_PLAN_NAME $(date +%m/%d/%Y)"
fi

if [[ "$TESTRAIL_TEMPEST" == 'TRUE' ]] ;
then
    report -v \
    --testrail-plan-name "$TESTRAIL_PLAN_NAME" \
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
    --testrail-plan-name "$TESTRAIL_PLAN_NAME" \
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
    --testrail-plan-name "$TESTRAIL_PLAN_NAME" \
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
