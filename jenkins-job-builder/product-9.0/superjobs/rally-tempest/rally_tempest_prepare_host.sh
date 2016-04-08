#!/bin/bash -xe

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

IS_TLS="$(ssh ${CONTROLLER_IP} ". openrc; openstack endpoint show identity 2>/dev/null | awk '/https/'")"
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
