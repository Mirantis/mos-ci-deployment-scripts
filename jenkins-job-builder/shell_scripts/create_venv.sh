#!/usr/bin/env bash

virtualenv "$PY_VENV"
. "$PY_VENV"/bin/activate
pip install python-jenkins
deactivate