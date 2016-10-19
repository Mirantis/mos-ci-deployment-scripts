set +e

virtualenv --clear venv
. venv/bin/activate
pip install -U pip
pip install -r requirements.txt -r c-requirements.txt

OS_AUTH_URL="${{OS_AUTH_URL}}v3"

py.test {stepler_args}
deactivate

sudo dos.py destroy "$ENV_NAME"
