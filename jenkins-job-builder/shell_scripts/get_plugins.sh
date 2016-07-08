#!/usr/bin/env bash
PLUGINS_ARCHIVE=${PLUGINS_ARCHIVE:-"http://cz7776.bud.mirantis.net:8080/jenkins/job/build_plugins/lastSuccessfulBuild/artifact/*zip*/archive.zip"}

TMPFILE=$(mktemp)
export PLUGINS_PATH=$(pwd)/fuel_plugins
wget $PLUGINS_ARCHIVE -O $TMPFILE
unzip -jo $TMPFILE '*.rpm' -d $PLUGINS_PATH
rm $TMPFILE
env > "$ENV_INJECT_PATH"
