set +e
ISO_NAME=`ls "$ISO_DIR"`
ISO_ID=`echo "$ISO_NAME" | cut -f3 -d-`
# Generate file for build-name plugin
SNAPSHOT=`echo $SNAPSHOT_NAME | sed 's/ha_deploy_//'`
echo "$ISO_ID"_"$SNAPSHOT" > build-name-setter.info
ENV_NAME=MOS_CI_"$ISO_NAME"

# Storing path for xml reports, that will be used in
# report_to_testrail job
REPORT_PATH="$REPORT_PREFIX"/"$ENV_NAME"_"$SNAPSHOT_NAME"
echo "$REPORT_PATH" > ./param.pm
echo "$BUILD_URL" > ./build_url

virtualenv venv
. venv/bin/activate
pip install -U pip
pip install -r requirements.txt
py.test '{test_path}' -E "$ENV_NAME" -S "$SNAPSHOT_NAME" -v
deactivate