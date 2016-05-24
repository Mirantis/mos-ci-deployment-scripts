set +e

rm -rf mos-integration-tests
git clone https://github.com/Mirantis/mos-integration-tests.git
cd mos-integration-tests

sudo dos.py revert-resume "$ENV_NAME" "$SNAPSHOT_NAME"

virtualenv tests
. tests/bin/activate

pip install -U pip
pip install -r requirements.txt
printenv || true
py.test {test_path} -E "$ENV_NAME" -S "$SNAPSHOT_NAME" -v

cp "$REPORT_FILE" ../
cp *.log ../

sudo mkdir -p "$REPORT_PREFIX"/"$ENV_NAME"_"$SNAPSHOT_NAME" && \
sudo cp "$REPORT_FILE" "$REPORT_PREFIX"/"$ENV_NAME"_"$SNAPSHOT_NAME" && \
sudo cp *.log "$REPORT_PREFIX"/"$ENV_NAME"_"$SNAPSHOT_NAME" \
|| true
deactivate

sudo dos.py destroy "$ENV_NAME"

exit 0