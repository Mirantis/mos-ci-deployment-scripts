set +e

rm -rf mos-integration-tests
git clone https://github.com/Mirantis/mos-integration-tests.git
cd mos-integration-tests

virtualenv venv
. venv/bin/activate
pip install -U pip
pip install tox

printenv || true

tox -e {tox_test_name} --  -k {tox_properties} -v -E "$ENV_NAME" -S "$SNAPSHOT_NAME"
deactivate

cp "$REPORT_FILE" ../
cp *.log ../

sudo mkdir -p "$REPORT_PREFIX"/"$ENV_NAME"_"$SNAPSHOT_NAME" && \
sudo cp "$REPORT_FILE" "$REPORT_PREFIX"/"$ENV_NAME"_"$SNAPSHOT_NAME" && \
sudo cp *.log "$REPORT_PREFIX"/"$ENV_NAME"_"$SNAPSHOT_NAME" \
|| true
deactivate

sudo dos.py destroy "$ENV_NAME"


###############################################################################

cd ../

virtualenv testrail
. testrail/bin/activate

git clone https://github.com/gdyuldin/testrail_reporter.git
cd testrail_reporter
# git checkout stable
python setup.py install
cd ../

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

if [[ "$TESTRAIL_TEMPLATE_ALTER" == 'TRUE' ]] ;
then
report -v --testrail-plan-name "9.0 mos iso #$ISO_ID" --env-description "$TEST_GROUP_{tox_properties}" --testrail-url  "$TESTRAIL_URL" --testrail-user  "$TESTRAIL_USER" --testrail-password "$TESTRAIL_PASSWORD" --testrail-project "$TESTRAIL_PROJECT" --testrail-milestone "$TESTRAIL_MILESTONE" --testrail-suite "$TESTRAIL_SUITE" --test-results-link "$BUILD_URL" "$REPORT_FILE" --testrail-name-template "{{custom_test_group}}.{{title}}" --xunit-name-template "{{classname}}.{{methodname}}"
else
report -v --testrail-plan-name "9.0 mos iso #$ISO_ID" --env-description "$TEST_GROUP_{tox_properties}" --testrail-url  "$TESTRAIL_URL" --testrail-user  "$TESTRAIL_USER" --testrail-password "$TESTRAIL_PASSWORD" --testrail-project "$TESTRAIL_PROJECT" --testrail-milestone "$TESTRAIL_MILESTONE" --testrail-suite "$TESTRAIL_SUITE" --test-results-link "$BUILD_URL" "$REPORT_FILE"
fi

deactivate

exit 0