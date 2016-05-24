function waitForSSH {

local server_ip="$1"

local BOOT_TIMEOUT=180

local CHECK_TIMEOUT=30

local cur_time=0



LOG_FINISHED="1"

while [[ "${LOG_FINISHED}" == "1" ]]; do

sleep $CHECK_TIMEOUT

time=$(($cur_time+$CHECK_TIMEOUT))

LOG_FINISHED=$(nc -w 2 $server_ip 22; echo $?)

if [ ${cur_time} -ge $BOOT_TIMEOUT ]; then

echo "Can't get to VM in $BOOT_TIMEOUT sec"

exit 1

fi

done

}




function addPublicToFuel {
FUEL_ADM_IP="$1"
FUEL_PUB_IP="$2"
PUB_NET_PREFIX="$3"
PUB_GATEWAY="$4"

SSH_OPTS='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'

SSH_CMD="sshpass -p r00tme ssh ${SSH_OPTS} root@${FUEL_ADM_IP}"

waitForSSH "$FUEL_ADM_IP"

# PUB_INTERFACE=$(${SSH_CMD} 'ifconfig -a ' | grep -E "(flags=|Link encap)" |grep -v  "docker" | sed '2!d' | awk {'print $1'} | cut -d ":" -f1)
PUB_INTERFACE='eth1'
IFCFG_PATH="/etc/sysconfig/network-scripts"
IFCFG_PUB_FILE="$IFCFG_PATH/ifcfg-$PUB_INTERFACE"

${SSH_CMD} "sed -i "s/ONBOOT=no/ONBOOT=yes/" ${IFCFG_PUB_FILE};
sed -i "s/BOOTPROTO=dhcp/BOOTPROTO=static/" ${IFCFG_PUB_FILE};
sed -i "s/NM_CONTROLLED=yes/NM_CONTROLLED=no/" ${IFCFG_PUB_FILE};
sed -i "s/IPADDR=.*/IPADDR=$FUEL_PUB_IP/" ${IFCFG_PUB_FILE}; grep -q "IPADDR" ${IFCFG_PUB_FILE} || echo "IPADDR=$FUEL_PUB_IP" >> ${IFCFG_PUB_FILE};
sed -i "s/PREFIX=.*/PREFIX=$PUB_NET_PREFIX/" ${IFCFG_PUB_FILE}; grep -q "PREFIX" ${IFCFG_PUB_FILE} || echo "PREFIX=$PUB_NET_PREFIX" >> ${IFCFG_PUB_FILE};
sed -i "s/GATEWAY/\#GATEWAY/" $IFCFG_PATH/ifcfg-*;
sed -i "s/GATEWAY=.*/GATEWAY=$PUB_GATEWAY/" /etc/sysconfig/network; grep -q "GATEWAY" /etc/sysconfig/network || echo "GATEWAY=$PUB_GATEWAY" >> ${IFCFG_PUB_FILE};
/etc/init.d/network restart;
"

${SSH_CMD} "/etc/init.d/network restart;"

${SSH_CMD} "sed -i \"3i nameserver 10.109.2.2\" /etc/resolv.conf"

# SSH Listen on all interfaces
${SSH_CMD} "sed -i 's/ListenAddress.*/ListenAddress 0.0.0.0/' /etc/ssh/sshd_config;
service sshd restart;
"
}


set +e

ISO_NAME=`ls "$ISO_DIR"`
ENV_NAME=MOS_CI_"$ISO_NAME"

#Get Fuel adm IP
FUEL_ADM_IP=$(virsh net-dumpxml ${ENV_NAME}_admin | grep -P "(\d+\.){3}" -o | awk '{print ""$0"2"}')
#Get pub net
PUB_NET=$(dos.py net-list $ENV_NAME |grep "public" | grep -P "(\d+\.){3}(\d+)" -o )
#Get pub net prefix
PUB_NET_PREFIX=$(dos.py net-list $ENV_NAME |grep "public" | awk '{print $2}' |cut -d "/" -f 2)
#Get pub net last octet
PUB_LAST_OCTET=$(expr ${PUB_NET##*.} + 2)

#Get pub first IP - Gateway
PUB_GATEWAY=$(virsh net-dumpxml ${ENV_NAME}_public | grep -P "(\d+\.){3}(\d+)" -o)
#Get pub net second IP - Fuel
# FUEL_PUB_IP=$(virsh net-dumpxml ${ENV_NAME}_public | grep -P "(\d+\.){3}" -o | awk '{print $0}')${PUB_LAST_OCTET}
FUEL_PUB_IP=10.109.4.254


dos.py start $ENV_NAME

addPublicToFuel "${FUEL_ADM_IP}" "${FUEL_PUB_IP}" "${PUB_NET_PREFIX}" "${PUB_GATEWAY}"
