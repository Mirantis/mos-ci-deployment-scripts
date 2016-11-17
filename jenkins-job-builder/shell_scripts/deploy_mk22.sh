set +e

virtualenv --clear venv
. venv/bin/activate
pip install -U pip
pip install -r ./tcp_tests/requirements.txt

images_folder='$HOME/mk22_images'

if [ ! -d "$image_folder" ]; then
    mkdir $image_folder
    wget http://172.18.173.8:8080/jenkins/view/System%20Jobs/job/get_ubuntu_image/lastSuccessfulBuild/artifact/trusty-server-cloudimg-amd64-disk1.img -O $images_folder/trusty-server-cloudimg-amd64.qcow2
    wget http://172.18.173.8:8080/jenkins/view/System%20Jobs/job/get_ubuntu_image/lastSuccessfulBuild/artifact/xenial-server-cloudimg-amd64-disk1.img -O $images_folder/xenial-server-cloudimg-amd64.qcow2
fi

export IMAGE_PATH1404=$image_folder/trusty-server-cloudimg-amd64.qcow2
export IMAGE_PATH1604=$image_folder/xenial-server-cloudimg-amd64.qcow2

export ENV_NAME=tcpcloud-mk22
export LAB_CONFIG_NAME=mk22-lab-basic

export SHUTDOWN_ENV_ON_TEARDOWN=false

LC_ALL=en_US.UTF-8  py.test -vvv -s -k test_tcp_install_default

deactivate
