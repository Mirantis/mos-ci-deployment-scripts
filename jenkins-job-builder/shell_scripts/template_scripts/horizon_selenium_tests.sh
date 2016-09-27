set +e

dos.py revert-resume "$ENV_NAME" "$SNAPSHOT_NAME"

sudo apt-get update
#TBD need to remove firefox updaed since after FF 47.0 selenium tests are
#failed so far @schipiga will investigate on how to made that update
sudo apt-get -y install xvfb python-virtualenv libav-tools

git clone -b v9.1 https://github.com/Mirantis/mos-horizon.git
cd mos-horizon

virtualenv .venv
. .venv/bin/activate

pip install -U pip
pip install -r requirements
pip install -e .

export DASHBOARD_URL='http://10.109.4.6/horizon'

printenv || true

VIRTUAL_DISPLAY=1 py.test horizon_autotests -v --junitxml="$REPORT_FILE"

deactivate

cp "$REPORT_FILE" ../
cp *.log ../

dos.py destroy "$ENV_NAME"
