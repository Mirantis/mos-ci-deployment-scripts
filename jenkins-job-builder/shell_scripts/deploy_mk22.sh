set +e

virtualenv --clear venv
. venv/bin/activate
pip install -U pip
pip install -r ./tcp_tests/requirements.txt

export IMAGE_PATH1404=http://172.18.173.8:8080/jenkins/view/System%20Jobs/job/get_ubuntu_image/lastSuccessfulBuild/artifact/trusty-server-cloudimg-amd64-disk1.img
export IMAGE_PATH1604=http://172.18.173.8:8080/jenkins/view/System%20Jobs/job/get_ubuntu_image/lastSuccessfulBuild/artifact/xenial-server-cloudimg-amd64-disk1.img 

export ENV_NAME=tcpcloud-mk22
export LAB_CONFIG_NAME=mk22-lab-basic

export SHUTDOWN_ENV_ON_TEARDOWN=false

LC_ALL=en_US.UTF-8  py.test -vvv -s -k test_tcp_install_default

deactivate
