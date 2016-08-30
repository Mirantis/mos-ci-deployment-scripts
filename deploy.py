#!/usr/bin/env python

import os
import yaml

from fuel_qa import discover


def as_bool(string):
    return as_bool.lower() in ('1', 'yes', 'true')


def main():
    config = discover.load_yaml('../mosqa.yaml')

    # Change config

    with open('system_test/tests_templates/tests_configs/mosqa.yaml', 'wb') as f:
        yaml.dump(config, f)

    os.system('python run_system_test.py run "system_test.deploy_env" --with-config mosqa')
    os.system('dos.py suspend ${ENV_NAME}')
    os.system('dos.py snapshot ${ENV_NAME} ${SNAPSHOT_NAME}')
    os.system('dos.py resume ${ENV_NAME}')

if __name__ == '__main__':
    main()
