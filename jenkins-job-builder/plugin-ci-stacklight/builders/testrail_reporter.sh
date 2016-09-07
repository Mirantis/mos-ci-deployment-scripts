set -x

echo "$ISO_ID.$SNAPSHOT_NAME" > build-name-setter.info

virtualenv --clear testrail
. testrail/bin/activate

# NEED FIX! (move scripts from custom repo to Mirantis repo)
pip install git+https://github.com/gdyuldin/testrail_reporter.git@stable

if [[ -z "$TESTRAIL_PLAN_NAME" ]];
then
    TESTRAIL_PLAN_NAME="$TESTRAIL_MILESTONE snapshot $SNAPSHOT_ID"
else
    TESTRAIL_PLAN_NAME="$TESTRAIL_PLAN_NAME $(date +%m/%d/%Y)"
fi

report -v \
--testrail-plan-name "$TESTRAIL_PLAN_NAME" \
--env-description "$TEST_GROUP" \
--testrail-url  "$TESTRAIL_URL" \
--testrail-user  "$TESTRAIL_USER" \
--testrail-password "$TESTRAIL_PASSWORD" \
--testrail-project "$TESTRAIL_PROJECT" \
--testrail-milestone "$TESTRAIL_MILESTONE" \
--testrail-suite "$TESTRAIL_SUITE" \
--testrail-name-template "{custom_test_group}" \
--xunit-name-template "{methodname}" \
"$REPORT_FILE"

deactivate
