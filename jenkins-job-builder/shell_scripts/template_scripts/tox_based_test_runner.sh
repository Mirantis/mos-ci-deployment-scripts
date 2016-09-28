set +e

virtualenv --clear venv
. venv/bin/activate
pip install -U pip
pip install tox

printenv || true

tox -e {tox_test_name} -- -v -E "$ENV_NAME" -S "$SNAPSHOT_NAME"
deactivate

sudo dos.py destroy "$ENV_NAME"
