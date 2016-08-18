set -x

echo "$ISO_ID.$SNAPSHOT_NAME" > build-name-setter.info

virtualenv --clear testrail
. testrail/bin/activate

source /home/jenkins/env_inject.properties
export SNAPSHOT_ID

# NEED FIX! (move scripts from custom repo to Mirantis repo)
pip install git+https://github.com/gdyuldin/testrail_reporter.git@stable

TESTRAIL_URL=https://mirantis.testrail.com
TESTRAIL_USER=releaseacceptance@mirantis.com
TESTRAIL_PASSWORD=Release6.1
TESTRAIL_PROJECT='Mirantis OpenStack'
TESTRAIL_SUITE="$SUITE"
TESTRAIL_MILESTONE="$MILESTONE"

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
