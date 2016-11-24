MK22_CFG01_MAC=$(virsh domiflist ${ENV_NAME}_cfg01.mk22-lab-basic.local | grep -m1 network | awk '{ print $5 }')
MK22_CFG01_IP=$(ip neigh | grep ${MK22_CFG01_MAC} | awk '{ print $1 }')

echo "MK22_CFG01_IP=$MK22_CFG01_IP" >> "$ENV_INJECT_PATH"
