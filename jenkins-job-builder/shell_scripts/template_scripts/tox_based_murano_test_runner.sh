set +e

source /home/jenkins/openrc

murano bundle-import --is-public --exists-action s container-based-apps
sleep 3m

rm -rf mos-integration-tests
git clone https://github.com/Mirantis/mos-integration-tests.git
cd mos-integration-tests

virtualenv --clear venv
. venv/bin/activate
pip install -U pip
pip install tox

printenv || true

tox -r -e {tox_test_name} -- -ra -v -E "$ENV_NAME" -I "$FUEL_MASTER_IP"
deactivate

cp "$REPORT_FILE" ../
cp *.log ../

sudo mkdir -p "$REPORT_PREFIX"/"$ENV_NAME"_"$SNAPSHOT_NAME" && \
sudo cp "$REPORT_FILE" "$REPORT_PREFIX"/"$ENV_NAME"_"$SNAPSHOT_NAME" && \
sudo cp *.log "$REPORT_PREFIX"/"$ENV_NAME"_"$SNAPSHOT_NAME" \
|| true
deactivate

exit 0
