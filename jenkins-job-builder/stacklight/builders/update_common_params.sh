#!/usr/bin/env bash

cat >> ${ENV_INJECT_PATH} <<EOF
ADMIN_NODE_MEMORY=4096
ADMIN_NODE_CPU=2
SLAVE_NODE_MEMORY=5120
SELENIUM_HEADLESS=True
ENABLE_LIBVIRT_NWFILTERS=True

VENV_PATH=$WORKSPACE/venv_test
OPENSTACK_RELEASE=ubuntu
POOL_DEFAULT=10.109.0.0/16:24
CONNECTION_STRING=qemu+tcp://127.0.0.1:16509/system
ENV_NAME="${ENV_PREFIX:0:68}"
EOF

if [[ "$USE_9_0" != 'TRUE' ]]; then
    #get 9.x repositories
    set +e
    rm snapshots.params
    rm conv_snapshot_file.py

    wget https://product-ci.infra.mirantis.net/job/9.x.snapshot/lastSuccessfulBuild/artifact/snapshots.params
    wget https://raw.githubusercontent.com/openstack/fuel-qa/stable/mitaka/utils/jenkins/conv_snapshot_file.py
    set -e

    chmod 755 ./conv_snapshot_file.py
    ./conv_snapshot_file.py

    REPORT_POSTFIX="snapshot $(awk '/CUSTOM_VERSION/ {print $2}' snapshots.params) $START_DATE"

    echo "REPORT_POSTFIX=$REPORT_POSTFIX" >> "${ENV_INJECT_PATH}"
    cat extra_repos.sh >> ${ENV_INJECT_PATH}
    echo "" >> ${ENV_INJECT_PATH}
else
    echo "REPORT_POSTFIX=9.0 $START_DATE" >> "${ENV_INJECT_PATH}"
fi
