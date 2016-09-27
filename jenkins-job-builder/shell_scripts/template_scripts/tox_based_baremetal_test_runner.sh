set +e

rm -rf mos-integration-tests
git clone https://github.com/Mirantis/mos-integration-tests.git
cd mos-integration-tests

virtualenv --clear venv
. venv/bin/activate
pip install -U pip
pip install tox

printenv || true

# workaround for bug https://bugs.launchpad.net/mos/+bug/1618473
export UBUNTU_QCOW2_URL=https://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img

tox -e {tox_test_name} -- -v -E "$ENV_NAME" -I "$FUEL_MASTER_IP"
deactivate

cp "$REPORT_FILE" ../
cp *.log ../

exit 0
