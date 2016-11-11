last_snapshot=$(dos.py snapshot-list "$ENV_NAME" | tail -1 | awk '{print $1}')
if [[ -n $last_snapshot ]]; then
    SNAPSHOT_NAME=${last_snapshot}
    echo "SNAPSHOT_NAME=${SNAPSHOT_NAME}" >> "${ENV_INJECT_PATH}"
fi
