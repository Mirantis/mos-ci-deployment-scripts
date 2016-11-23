set +e

OS_AUTH_URL="${{OS_AUTH_URL}}/v3"

cat > "os_faults_config.yaml" << EOF
cloud_management:
  driver: fuel
  args:
    address: ${{FUEL_MASTER_IP}}
    username: root
    private_key_file: /opt/app/fuel.key
power_management:
  driver: libvirt
  args:
    connection_uri: qemu:///system
EOF

OS_FAULTS_CONFIG="${{PWD}}/os_faults_config.yaml"
export ANSIBLE_HOST_KEY_CHECKING=False

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
sudo docker rmi -f $(sudo docker images -f "dangling=true" -q)

sudo docker run \
  --rm \
  --name=${{CONTAINER_NAME_PREFIX}}_${{RANDOM}} \
  --net=host \
  -e OS_AUTH_URL="${{OS_AUTH_URL}}" \
  -e OS_FAULTS_CONFIG=/opt/app/os-faults-config \
  -e OS_DASHBOARD_URL="${{OS_DASHBOARD_URL}}" \
  -v $(pwd)/reports:/opt/app/test_reports \
  -v $OS_FAULTS_CONFIG:/opt/app/os-faults-config \
  -v ${{PWD}}/${{FUEL_KEY}}:/opt/app/fuel.key \
  mostestci/stepler {stepler_args}

# Need to move report.xml in the root of workdir
mv reports/report.xml .

sudo dos.py destroy "${{ENV_NAME}}"
