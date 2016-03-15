#sudo rm -rf mos-ci-deployment-scripts
#git clone https://github.com/Mirantis/mos-ci-deployment-scripts.git
#PARSED_LINK='https://product-ci.infra.mirantis.net/job/9.0.all/lastSuccessfulBuild/api/python'
#ISO_DIR='/var/www/fuelweb-iso'
#cd mos-ci-deployment-scripts/jenkins-job-builder/python_scripts/9.0_parse_jenkins_for_iso
#iso_name=`sudo python parser.py --link "$PARSED_LINK" -d "$ISO_DIR" --link-only`

virtualenv init
. ./init/bin/activate
pip install python-jenkins

sudo rm -rf init_env.py
wget https://raw.githubusercontent.com/EduardFazliev/mos-ci-deployment-scripts/feature/jjb/jenkins-job-builder/python_scripts/9.0_init_env_for_job/init_env.py
sudo chmod +x init_env.py

iso_link=`python init_env.py`
sudo rm -rf /var/www/fuelweb-iso/*
wget "$iso_link" -P /var/www/fuelweb-iso/
iso_name=`ls /var/www/fuelweb-iso/`

set +e
env_presents=`sudo dos.py list | grep "$iso_name"`

if [[ "$env_presents" != '' ]];
then
echo 'There is env with name of downloaded iso, aborting...'
exit 0
fi

# sudo rm -rf /var/www/fuelweb-iso
# sudo wget http://srv65-bud.infra.mirantis.net/fuelweb-iso/fuel-9.0-mitaka-48-2016-02-29_06-16-00.iso -P /var/www/fuelweb-iso

sudo dos.py list > temp
while read -r line
do
set -e
sudo dos.py erase $line || true
done < temp