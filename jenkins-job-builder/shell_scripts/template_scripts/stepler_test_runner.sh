set +e

virtualenv --clear venv
. venv/bin/activate
pip install -U pip
pip install -r requirements.txt -r c-requirements.txt

OS_AUTH_URL=$(echo OS_AUTH_URL | sed 's/\/v2.*/\/v3/')

py.test stepler -v
deactivate

sudo dos.py destroy "$ENV_NAME"
