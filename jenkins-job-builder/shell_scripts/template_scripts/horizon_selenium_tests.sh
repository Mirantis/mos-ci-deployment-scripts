set +e

sudo dos.py revert-resume "$ENV_NAME" "$SNAPSHOT_NAME"

git clone https://github.com/Mirantis/mos-horizon.git
cd mos-horizon
git checkout stable/mitaka

sudo apt-get update
sudo apt-get -y install firefox xvfb python-virtualenv

virtualenv venv
. venv/bin/activate

pip install -U pip
pip install -r requirements.txt -r test-requirements.txt

export DASHBOARD_URL='http://10.109.4.6/horizon'

printenv || true

./run_tests.sh -N --integration --selenium-headless --skip-new-design --with-xunit --xunit-file=report.xml

deactivate

cp "$REPORT_FILE" ../
cp *.log ../
cp openstack_dashboard/test/integration_tests/integration_tests_screenshots/** ../

sudo mkdir -p "$REPORT_PREFIX"/"$ENV_NAME"_"$SNAPSHOT_NAME" && \
sudo cp "$REPORT_FILE" "$REPORT_PREFIX"/"$ENV_NAME"_"$SNAPSHOT_NAME" && \
sudo cp *.log "$REPORT_PREFIX"/"$ENV_NAME"_"$SNAPSHOT_NAME" \
|| true

sudo dos.py destroy "$ENV_NAME"

exit 0