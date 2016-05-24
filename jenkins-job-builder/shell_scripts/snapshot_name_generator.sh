set -x

boolean(){
    eval val=\$$1

    if [ -z "$val" ] || [ ${val^^} == 'FALSE' ]
    then
        echo 'false'
    elif [ ${val^^} == 'TRUE' ]
    then
        echo 'true'
    else
        echo "Please set env variable $1 to empty, 'TRUE' or 'FALSE'."
        exit 1
    fi
}

digit_from_range(){
    eval val=\$$1

    if [ -z ${val} ]; then
        # set default value
        val=$4
    fi

    if [ ${val} -ge $2 ] && [ ${val} -le $3 ]; then
        echo ${val}
    else
        echo "Error: variable $1 can be from $2 to $3 or empty (will be set to $4 in this case)."
        exit 1
    fi
}

set_default(){
    eval val=\$$1

    if [ -z ${val} ]; then
        eval $1=$2
    fi
}


ISO_NAME=`ls "$ISO_DIR"`
ENV_NAME=MOS_CI_"$ISO_NAME"
ISO_ID=`echo "$ISO_NAME" | cut -f4 -d-`

export ISO_PATH="$ISO_DIR"/"$ISO_NAME"
export ENV_NAME="$ENV_NAME"
export ERASE_PREV_ENV="$ERASE_PREV_ENV"
export SEGMENT_TYPE="$SEGMENT_TYPE"
export DVR_ENABLE="$DVR_ENABLE"
export L3_HA_ENABLE="$L3_HA_ENABLE"
export L2_POP_ENABLE="$L2_POP_ENABLE"
export LVM_ENABLE="$LVM_ENABLE"
export CINDER_ENABLE="$CINDER_ENABLE"
export CEPH_ENABLE="$CEPH_ENABLE"
export CEPH_GLANCE_ENABLE="$CEPH_GLANCE_ENABLE"
export RADOS_ENABLE="$RADOS_ENABLE"
export SAHARA_ENABLE="$SAHARA_ENABLE"
export MURANO_ENABLE="$MURANO_ENABLE"
export MONGO_ENABLE="$MONGO_ENABLE"
export CEILOMETER_ENABLE="$CEILOMETER_ENABLE"
export IRONIC_ENABLE="$IRONIC_ENABLE"
export DISABLE_SSL="$DISABLE_SSL"
export FUEL_DEV_VER="$FUEL_DEV_VER"
export COMPUTES_COUNT="$COMPUTES_COUNT"
export CONTROLLERS_COUNT="$CONTROLLERS_COUNT"
export IRONICS_COUNT="$IRONICS_COUNT"
export FUEL_QA_VER="$FUEL_QA_VER"
export NOVA_QUOTAS_ENABLED="$NOVA_QUOTAS_ENABLED"
export SLAVE_NODE_CPU="$SLAVE_NODE_CPU"
export SLAVE_NODE_MEMORY="$SLAVE_NODE_MEMORY"
export DEPLOYMENT_TIMEOUT="$DEPLOYMENT_TIMEOUT"
export INTERFACE_MODEL="$INTERFACE_MODEL"
export KVM_USE="$KVM_USE"



# set up segmet type
if [ "$SEGMENT_TYPE" == 'VLAN' ]
then
    SEGMENT_TYPE='vlan'
    SNAPSHOT_NAME='ha_deploy_VLAN'
elif [ "$SEGMENT_TYPE" == 'VxLAN' ]
then
    SEGMENT_TYPE='tun'
    SNAPSHOT_NAME='ha_deploy_VxLAN'
else
    echo "Please define env variable SEGMENT_TYPE as 'VLAN' or 'VxLAN'"
    exit 1
fi

# set up all vars which should be set to true or false
BOOL_VARS="L2_POP_ENABLE DVR_ENABLE L3_HA_ENABLE SAHARA_ENABLE MURANO_ENABLE CEILOMETER_ENABLE IRONIC_ENABLE RADOS_ENABLE CEPH_GLANCE_ENABLE"
PLUGINS="SEPARATE_SERVICE_RABBIT_ENABLE SEPARATE_SERVICE_DB_ENABLE SEPARATE_SERVICE_KEYSTONE_ENABLE FUEL_LDAP_PLUGIN_ENABLE"
for var in $BOOL_VARS $PLUGINS
do
    eval $var=$(boolean $var)
done
# Note: some params should be processed separately as
# they should be uncommented in config (not set to true or false as other)
MONGO_ENABLE=$(boolean 'MONGO_ENABLE')
CINDER_ENABLE=$(boolean 'CINDER_ENABLE')
# block storage (one of CEPH or LVM should be true)
CEPH_ENABLE=$(boolean 'CEPH_ENABLE')
LVM_ENABLE=$(boolean 'LVM_ENABLE')

# check limitations
# storage limitations

# set dependent vars
if [ ${LVM_ENABLE} == 'true' ]; then
    CINDER_ENABLE='true'
fi

# replace vars with its values in config files
for var in SEGMENT_TYPE $BOOL_VARS CEPH_ENABLE
do
    eval value=\$$var
    # replace variable in config with its value
    if [ ${value} == 'true' ]; then
         # Add the name of var without word '_ENABLE' to snapshot name
         SNAPSHOT_NAME="${SNAPSHOT_NAME}_$(echo ${var} | sed 's/_ENABLE//')"
    fi
done

# uncomment some roles if it is required
if [ ${MONGO_ENABLE} == 'true' ]
then
    SNAPSHOT_NAME="${SNAPSHOT_NAME}_MONGO"
fi

if [ ${CINDER_ENABLE} == 'true' ]
then
    SNAPSHOT_NAME="${SNAPSHOT_NAME}_CINDER"
fi

if [ ${SEPARATE_SERVICE_RABBIT_ENABLE} == 'true' ]
then
    SNAPSHOT_NAME="${SNAPSHOT_NAME}_RABBITMQ"
fi

if [ ${SEPARATE_SERVICE_DB_ENABLE} == 'true' ]
then
    SNAPSHOT_NAME="${SNAPSHOT_NAME}_DATABASE"
fi

if [ ${SEPARATE_SERVICE_KEYSTONE_ENABLE} == 'true' ]
then
    SNAPSHOT_NAME="${SNAPSHOT_NAME}_KEYSTONE"
fi

if [ ${FUEL_LDAP_PLUGIN_ENABLE} == 'true' ]
then
    SNAPSHOT_NAME="${SNAPSHOT_NAME}_LDAP"
fi

echo "SNAPSHOT_NAME=${SNAPSHOT_NAME}" >> "${ENV_INJECT_PATH}"