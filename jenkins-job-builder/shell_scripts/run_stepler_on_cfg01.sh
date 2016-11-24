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

scp ctl01:keystonercv3 .

source keystonercv3

export OS_FAULTS_CONFIG="/root/os_faults_config.yaml"
export OPENRC_ACTIVATE_CMD="source /root/keystonercv3"

py.test stepler -v --junit-xml=test_reports/report.xml

deactivate
