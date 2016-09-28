PREFIX='MOS_CI_'

echo 'Trying to erase all MOS_CI environments...'

for line in $(dos.py list); do
    if [[ "${{line}}" == "${{PREFIX}}"*"${{ENV_CHANGER}}" ]]; then
        echo "Erasing ${{line}}..."
        dos.py erase "$line" || true
    fi
done
