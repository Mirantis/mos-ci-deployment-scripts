#!/bin/bash

echo 'Trying to erase old environments...'

dos.py list > temp
while read -r LINE
do
set -e

if [[ "$LINE" == "$ENV_PREFIX" ]]; then
echo "Erasing ${LINE}..."
dos.py erase "$LINE" || true
fi

done < temp