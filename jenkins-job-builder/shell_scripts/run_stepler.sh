set +e

source keystonercv3

MK22_KEY_PATH=${PWD}/${{MK22_KEY}}

cat > "os_faults_config.yaml" << EOF
cloud_management:
  driver: tcpcloud
  args:
    address: ${{MK22_CFG01_IP}}
    username: root
    master_sudo: True
    slave_username: root
    private_key_file: ${{MK22_KEY_PATH}}
EOF

OS_FAULTS_CONFIG="${{PWD}}/os_faults_config.yaml"

mkdir reports

### Docker part
export CONTAINER_NAME_PREFIX=stepler

# Pull fresh image
sudo docker pull mostestci/stepler

# Clean old containers
container=$(sudo docker ps -a | grep ${{CONTAINER_NAME_PREFIX}} | awk '{{ print $1 }}')
if [[ -n ${{container}} ]]; then
	sudo docker rm -f ${{container}}
fi

# Clean old images
image=$(sudo docker images -f "dangling=true" -q)
if [[ -n ${{image}} ]]; then
	sudo docker rmi -f ${{image}}
fi


sudo docker run \
  --rm \
  --name=${{CONTAINER_NAME_PREFIX}}_${{RANDOM}} \
  --net=host \
  -e OS_AUTH_URL="${{OS_AUTH_URL}}" \
  -e OS_FAULTS_CONFIG=/opt/app/os-faults-config \
  -e OS_PASSWORD=${{OS_PASSWORD}} \
  -e ANSIBLE_HOST_KEY_CHECKING=False \
  -v $(pwd)/reports:/opt/app/test_reports \
  -v $OS_FAULTS_CONFIG:/opt/app/os-faults-config \
  -v ${{MK22_KEY_PATH}}:/opt/app/mk22.key \
  mostestci/stepler stepler --ignore=stepler/cinder --ignore=stepler/horizon \
  --ignore=stepler/baremetal -k "not destructive"

# Need to move report.xml in the root of workdir
mv reports/report.xml .
