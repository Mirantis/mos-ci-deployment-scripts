set +e

rm -rf mos-integration-tests
git clone https://github.com/Mirantis/mos-integration-tests.git
cd mos-integration-tests

murano bundle-import --is-public --exists-action s container-based-apps
sleep 3m

virtualenv --clear venv
. venv/bin/activate
pip install -U pip
pip install tox

printenv || true

# workaround for bug
export UBUNTU_QCOW2_URL=https://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img

FUEL_MASTER_MAC=$(virsh domiflist ${ENV_NAME}_admin | grep -m1 network | awk '{ print $5 }')
FUEL_MASTER_IP=$(ip neigh | grep ${FUEL_MASTER_MAC} | awk '{ print $1 }')

tox -r -e {tox_test_name} -- -ra -v -E "$ENV_NAME" -I "$FUEL_MASTER_IP"
deactivate

cp "$REPORT_FILE" ../
cp *.log ../

sudo mkdir -p "$REPORT_PREFIX"/"$ENV_NAME"_"$SNAPSHOT_NAME" && \
sudo cp "$REPORT_FILE" "$REPORT_PREFIX"/"$ENV_NAME"_"$SNAPSHOT_NAME" && \
sudo cp *.log "$REPORT_PREFIX"/"$ENV_NAME"_"$SNAPSHOT_NAME" \
|| true
deactivate

exit 0
