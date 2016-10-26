set +e

virtualenv --clear venv
. venv/bin/activate
pip install -U pip
pip install -r requirements.txt -r c-requirements.txt

OS_AUTH_URL="${OS_AUTH_URL}v3"

cat > "os_faults_cofig.yaml" << EOF
cloud_management:
  driver: fuel
  args:
    address: ${FUEL_MASTER_IP}
    username: root
    private_key_file: ${FUEL_KEY}
power_management:
  driver: libvirt
  args:
    connection_uri: qemu:///system
EOF

OS_FAULTS_CONFIG="${PWD}/os_faults_cofig.yaml"

py.test stepler -v --ignore=stepler/horizon --junit-xml=report.xml
deactivate

sudo dos.py destroy "$ENV_NAME"
