#!/bin/bash -xe

docker load -i /root/rally

CONTAINER_MOUNT_HOME_DIR="${CONTAINER_MOUNT_HOME_DIR:-/var/lib/rally-tempest-container-home-dir}"
CONTROLLER_PROXY_PORT="8888"
KEYSTONE_API_VERSION="v2.0"
CA_CERT_PATH="/var/lib/astute/haproxy/public_haproxy.pem"
APACHE_API_PROXY_CONF_PATH="/etc/apache2/sites-enabled/25-apache_api_proxy.conf"

if [ ! -d ${CONTAINER_MOUNT_HOME_DIR} ]; then
    mkdir ${CONTAINER_MOUNT_HOME_DIR}
fi
chown 65500 ${CONTAINER_MOUNT_HOME_DIR}

CONTROLLER_IP="$(fuel node "$@" | awk '/controller/{print $9}' | head -1)"
CONTROLLER_PROXY_URL="http://${CONTROLLER_IP}:${CONTROLLER_PROXY_PORT}"
scp ${CONTROLLER_IP}:/root/openrc ${CONTAINER_MOUNT_HOME_DIR}/
chown 65500 ${CONTAINER_MOUNT_HOME_DIR}/openrc
echo "export HTTP_PROXY='$CONTROLLER_PROXY_URL'" >> ${CONTAINER_MOUNT_HOME_DIR}/openrc
echo "export HTTPS_PROXY='$CONTROLLER_PROXY_URL'" >> ${CONTAINER_MOUNT_HOME_DIR}/openrc

ALLOW_CONNECT="$(ssh ${CONTROLLER_IP} "cat ${APACHE_API_PROXY_CONF_PATH} | grep AllowCONNECT")"
if [ ! "$(echo ${ALLOW_CONNECT} | grep -o 35357)" ]; then
    ssh ${CONTROLLER_IP} "sed -i 's/9696/9696 35357/' ${APACHE_API_PROXY_CONF_PATH} && service apache2 restart"
fi

IS_TLS="$(ssh ${CONTROLLER_IP} ". openrc; keystone catalog --service identity 2>/dev/null | awk '/https/'")"
if [ "${IS_TLS}" ]; then
    scp ${CONTROLLER_IP}:${CA_CERT_PATH} ${CONTAINER_MOUNT_HOME_DIR}/
    chown 65500 ${CONTAINER_MOUNT_HOME_DIR}/$(basename ${CA_CERT_PATH})
    echo "export OS_CACERT='/home/rally/$(basename ${CA_CERT_PATH})'" >> ${CONTAINER_MOUNT_HOME_DIR}/openrc
fi

cat > ${CONTAINER_MOUNT_HOME_DIR}/bashrc <<EOF
test "\${PS1}" || return
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000
alias ls=ls\ --color=auto
alias ll=ls\ --color=auto\ -lhap
echo \${PATH} | grep ":\${HOME}/bin" >/dev/null || export PATH="\${PATH}:\${HOME}/bin"
if [ \$(id -u) -eq 0 ]; then
    export PS1='\[\033[01;41m\]\u@\h:\[\033[01;44m\] \W \[\033[01;41m\] #\[\033[0m\] '
else
    export PS1='\[\033[01;33m\]\u@\h\[\033[01;0m\]:\[\033[01;34m\]\W\[\033[01;0m\]$ '
fi
source /home/rally/openrc
EOF

ID=$(docker images | awk '/rally/{print $3}')
echo "ID: ${ID}"
DOCK_ID=$(docker run -tid -v /var/lib/rally-tempest-container-home-dir:/home/rally --net host "$ID")
echo "DOCK ID: ${DOCK_ID}"
# Workaround for 8.0 Release

if [[ "$(fuel --version)" == "8.0.0" ]]; then
    sed -i "s|:5000|:5000/v2.0|g" /var/lib/rally-tempest-container-home-dir/openrc
fi
# Magic for encrease tempest results

docker exec -u root "$DOCK_ID" sed -i "s|\#swift_operator_role = Member|swift_operator_role=SwiftOperator|g" /etc/rally/rally.conf
docker exec "$DOCK_ID" setup-tempest
file=`find / -name tempest.conf`
echo "backup = False" >> $file
sed -i "95i ironic = False" $file
sed -i "79i max_template_size = 5440000" $file
sed -i "80i max_resources_per_stack = 20000" $file
sed -i "81i max_json_body_size = 10880000" $file

env_id=$(fuel env | tail -1 | awk '{print $1}')
fuel --env ${env_id} settings --download
volumes_lvm=$(cat settings_${env_id}.yaml | grep -A 7 "volumes_lvm:" | awk '/value:/{print $2}')
volumes_ceph=$(cat settings_${env_id}.yaml | grep -A 7 "volumes_ceph:" | awk '/value:/{print $2}')

if ${volumes_ceph}; then
    echo "[volume]" >> $file
    echo "build_timeout = 300" >> $file
    echo "storage_protocol = ceph" >> $file
fi

if ${volumes_lvm}; then
    echo "[volume]" >> $file
    echo "build_timeout = 300" >> $file
    echo "storage_protocol = iSCSI" >> $file
fi

# Run!
docker exec "$DOCK_ID" bash -c "source /home/rally/openrc && rally verify start --system-wide"
docker exec "$DOCK_ID" bash -c "rally verify results --json --output-file output.json"
docker exec "$DOCK_ID" bash -c "rm -rf rally_json2junit && git clone https://github.com/EduardFazliev/rally_json2junit.git && python rally_json2junit/rally_json2junit/results_parser.py output.json"