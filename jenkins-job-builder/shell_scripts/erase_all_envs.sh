#!/usr/bin/env bash

sudo dos.py list > temp
while read -r line
do
set -e
sudo dos.py erase $line || true
done < temp
