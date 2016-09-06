FUEL_MASTER_MAC=$(virsh domiflist ${ENV_NAME}_admin | grep -m1 network | awk '{ print $5 }')
FUEL_MASTER_IP=$(ip neigh | grep ${FUEL_MASTER_MAC} | awk '{ print $1 }')

echo "FUEL_MASTER_IP=$FUEL_MASTER_IP" > "$ENV_INJECT_PATH"
