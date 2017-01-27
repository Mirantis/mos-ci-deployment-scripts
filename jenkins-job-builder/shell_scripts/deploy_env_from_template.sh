# This script deploy MirantisOpenStak from templates
git clone https://github.com/Mirantis/mos-ci-deployment-scripts.git
pushd mos-ci-deployment-scripts
git checkout stable/9.0

# change fuel-qa version to stable/mitaka

if [[ "$USE_IPMI" == 'TRUE' ]]; then
    export MOSQA_IPMI_USER="$IPMI_USER"
    export MOSQA_IPMI_PASSWORD="$IPMI_PASSWORD"
fi

if [[ "$USE_9_0" != 'TRUE' ]]; then
    # export 9.x repos
    source /home/jenkins/env_inject.properties
    export EXTRA_DEB_REPOS
    export EXTRA_RPM_REPOS
    export UPDATE_FUEL_MIRROR
    export UPDATE_MASTER
fi


if [[ -n $ISO_URL ]]; then
    pushd $(mktemp -d)
    #Download provided iso into tmp folder
    if [[ $ISO_URL == *magnet_link* ]]; then
        aria2c $ISO_URL
        export `cat $(ls | grep .*txt$)`
        ISO_URL=$MAGNET_LINK
    fi
    aria2c --seed-time=0 $ISO_URL
    ISO_NAME=$(ls | grep .*iso$)
    ISO_NAME=$(echo $ISO_NAME | sed 's/.torrent//')
    ISO_PATH=$PWD/$(ls | grep .*iso$)
    popd
else
    ISO_NAME=$(ls "$ISO_DIR")
    ISO_PATH="$ISO_DIR/$ISO_NAME"
fi

# TBD ISO_ID will be missed for jobs without deploy
ISO_ID=$(echo "$ISO_NAME" | cut -f3 -d-)
echo "ISO_ID=$ISO_ID" > "$ENV_INJECT_PATH"

# Not exiting from shell if error happens
set +e
./deploy_template.sh $CONFIG_PATH

# Exit from the repo folder
popd
