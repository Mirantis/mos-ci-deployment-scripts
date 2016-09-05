echo 'Trying to erase all MOS_CI environments...'

for LINE in $(dos.py list); do
    set -e

    if [[ "$LINE" == "$ENV_PREFIX"*"$ENV_SUFFIX" ]]; then
        echo "Erasing $LINE..."
        dos.py erase "$LINE" || true
    fi

done
