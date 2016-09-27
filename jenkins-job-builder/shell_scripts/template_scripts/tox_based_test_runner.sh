set +e

rm -rf mos-integration-tests
git clone https://github.com/Mirantis/mos-integration-tests.git
cd mos-integration-tests

virtualenv --clear venv
. venv/bin/activate
pip install -U pip
pip install tox

printenv || true

tox -e {tox_test_name} -- -v -E "$ENV_NAME" -S "$SNAPSHOT_NAME"
deactivate

cp "$REPORT_FILE" ../
cp *.log ../

sudo dos.py destroy "$ENV_NAME"
