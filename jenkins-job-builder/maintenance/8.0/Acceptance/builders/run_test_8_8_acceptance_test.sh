#!/bin/bash
set +e

# Generate file for build-name plugin
SNAPSHOT=$(echo $SNAPSHOT_NAME | sed 's/ha_deploy_//')
echo 8.0_"$ENV_NAME"__"$SNAPSHOT" > build-name-setter.info

# Storing path for xml reports, that will be used in
# report_to_testrail job
REPORT_PATH="$REPORT_PREFIX"/"$ENV_NAME"_"$SNAPSHOT_NAME"
echo "$REPORT_PATH" > ./param.pm
echo "$BUILD_URL" > ./build_url

virtualenv --no-site-packages 8.0-acceptance
source 8.0-acceptance/bin/activate
pip install pip --upgrade
pip install -r requirements.txt --upgrade
py.test '{test_path}' -E "$ENV_NAME" -S "$SNAPSHOT_NAME" -v
deactivate