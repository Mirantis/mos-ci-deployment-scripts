#!/usr/bin/env bash
export PLUGINS_PATH=$(pwd)/fuel_plugins

if [ ! -d $PLUGINS_PATH ]; then
    rm -rf $PLUGINS_PATH
fi

mkdir $PLUGINS_PATH

cd $PLUGINS_PATH
wget https://3a98d2877cb62a6e6b14-93babe93196056fe375611ed4c1716dd.ssl.cf5.rackcdn.com/dm1.0-1.0.0-1/detach-murano-1.0-1.0.0-1.noarch.rpm
cd ..

env > "$ENV_INJECT_PATH"
