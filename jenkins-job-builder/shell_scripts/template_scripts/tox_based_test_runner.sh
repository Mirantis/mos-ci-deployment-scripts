set +e

rm -rf mos-integration-tests
git clone https://github.com/Mirantis/mos-integration-tests.git
cd mos-integration-tests

virtualenv venv
. venv/bin/activate
pip install -U pip
pip install tox

printenv || true

tox -e {tox_test_name} -- -v -E "$ENV_NAME" -S "$SNAPSHOT_NAME"
deactivate

cp "$REPORT_FILE" ../
cp *.log ../

sudo mkdir -p "$REPORT_PREFIX"/"$ENV_NAME"_"$SNAPSHOT_NAME" && \
sudo cp "$REPORT_FILE" "$REPORT_PREFIX"/"$ENV_NAME"_"$SNAPSHOT_NAME" && \
sudo cp *.log "$REPORT_PREFIX"/"$ENV_NAME"_"$SNAPSHOT_NAME" \
|| true
deactivate

sudo dos.py destroy "$ENV_NAME"

exit 0