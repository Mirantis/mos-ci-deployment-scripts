set -x

echo "$ISO_ID.$SNAPSHOT_NAME" > build-name-setter.info

virtualenv --clear testrail
. testrail/bin/activate

if [[ -f /home/jenkins/env_inject.properties ]];
then
    source /home/jenkins/env_inject.properties
    export SNAPSHOT_ID
else
    export SNAPSHOT_ID=''
fi

pip install -U pip
pip install xunit2testrail

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

if [[ $MILESTONE == 9.* ]] && [[ $MILESTONE != 9.0 ]];
then
    REPORT_SUFFIX="snapshot $SNAPSHOT_ID"
else
    REPORT_SUFFIX="iso #$ISO_ID"
fi

if [[ -z "$TESTRAIL_PLAN_NAME" ]];
then
    TESTRAIL_PLAN_NAME="$MILESTONE $REPORT_SUFFIX"
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
    --testrail-name-template "{custom_test_group}.{title}" \
    --xunit-name-template "{classname}.{methodname}" \
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
    --testrail-name-template "{title}" \
    --xunit-name-template "{methodname}" \
    "$REPORT_FILE"

elif [[ "$STEPLER_TESTS" == 'TRUE' ]] ;
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
    --xunit-name-template "{methodname}" \
    --testrail-name-template "{title}" \
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
