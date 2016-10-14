set -x

virtualenv --clear testrail
. testrail/bin/activate

# NEED FIX! (move scripts from custom repo to Mirantis repo)
pip install git+https://github.com/gdyuldin/testrail_reporter.git@stable


if [[ -z "$TESTRAIL_PLAN_NAME" ]];
then
    TESTRAIL_PLAN_NAME="$TESTRAIL_MILESTONE $REPORT_POSTFIX"
else
    TESTRAIL_PLAN_NAME="$TESTRAIL_PLAN_NAME $REPORT_POSTFIX"
fi


report -v \
--testrail-plan-name "$TESTRAIL_PLAN_NAME" \
--env-description "$TESTRAIL_ENV_DESCRIPTION" \
--testrail-url  "$TESTRAIL_URL" \
--testrail-user  "$TESTRAIL_USER" \
--testrail-password "$TESTRAIL_PASSWORD" \
--testrail-project "$TESTRAIL_PROJECT" \
--testrail-milestone "$TESTRAIL_MILESTONE" \
--testrail-suite "$TESTRAIL_SUITE" \
--test-results-link "$BUILD_URL" \
--testrail-name-template "{custom_test_group}" \
--xunit-name-template "{methodname}" \
--send-skipped \
"$REPORT_FILE"

deactivate
