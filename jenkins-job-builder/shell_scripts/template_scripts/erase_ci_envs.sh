PREFIX='MOS_CI_'

echo 'Trying to erase all MOS_CI environments...'

for LINE in $(dos.py list); do
set -e

if [[ "$LINE" == "$PREFIX"*"$ENV_CHANGER" ]]; then
echo "Erasing ${{LINE}}..."
dos.py erase "$LINE" || true
fi

done
