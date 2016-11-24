set -e

APT_PACKAGES="libssl-dev pkg-config libvirt-dev"
PIP_PACKAGES="virtualenv libvirt-python"

sudo apt install $APT_PACKAGES
sudo pip install $PIP_PACKAGES

git clone https://github.com/Mirantis/stepler.git
cd stepler
virtualenv .venv
. .venv/bin/activate
pip install -U pip
pip install -r requirements.txt -r c-requirements.txt

cat > "os_faults_config.yaml" << EOF
cloud_management:
  driver: tcpcloud
  args:
    address: cfg01
    username: root
    master_sudo: True
    slave_username: root
    private_key_file: /root/.ssh/id_rsa
EOF

export OS_FAULTS_CONFIG="/root/os_faults_config.yaml"
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=admin
export OS_PASSWORD=workshop
export OS_USERNAME=admin
export OS_PROJECT_DOMAIN_NAME=default
export OS_AUTH_URL=http://172.16.10.254:35357/v3
export OPENRC_ACTIVATE_CMD="source /root/keystonerc"

py.test stepler -v --junit-xml=test_reports/report.xml

deactivate
