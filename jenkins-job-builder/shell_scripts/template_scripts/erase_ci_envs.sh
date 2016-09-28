PREFIX='MOS_CI_'

echo 'Trying to erase all MOS_CI environments...'

set +e

for LINE in `sudo dos.py list`; do
    if [[ "$LINE" == "$PREFIX"*"$ENV_CHANGER" ]]; then
        echo "Erasing ${LINE}..."
        sudo dos.py erase "$LINE" || true
    fi
done
