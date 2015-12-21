#!/bin/bash -xe

RALLY_CONTAINER=rallyforge/rally
RALLY_VERSION=0.0.4

RALLY_IMAGE=''

find_rally_image() {
    RALLY_IMAGE=`docker images | awk -v NAME=${RALLY_CONTAINER} -v VERSION=${RALLY_VERSION} '$1 == NAME && $2 == VERSION {print $3}'`
}

# Remove existing Rally image
find_rally_image
test -n "${RALLY_IMAGE}" && docker rmi -f ${RALLY_IMAGE}

# Download Rally image
docker pull ${RALLY_CONTAINER}:${RALLY_VERSION}

# Fix failing cinder scenario for nested snapshots (not needed for Rally > 0.0.4)
docker rm -fv rally || :
docker run -i --name=rally --user=root ${RALLY_CONTAINER}:${RALLY_VERSION} <<RALLY_ROOT
sed -ri '344 a\        size = random.randint(size["min"], size["max"])\n' /usr/local/lib/python2.7/dist-packages/rally/benchmark/scenarios/cinder/volumes.py
RALLY_ROOT

# Commit fix to image
docker commit rally ${RALLY_CONTAINER}:${RALLY_VERSION}

# Remove container
docker rm -fv rally

# Prepare shared storage of ISO images
LXC_PATH=$(lxc-config lxc.lxcpath)
[ -d ${LXC_PATH}/images ] || mkdir ${LXC_PATH}/images

# Save image for futher use
docker save -o ${LXC_PATH}/images/rally-${RALLY_VERSION}.tar ${RALLY_CONTAINER}

chown -R 1000:1000 ${LXC_PATH}/images
