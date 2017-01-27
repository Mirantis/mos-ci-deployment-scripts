ENV_NAME="MOS_CI_MirantisOpenStack-${MILESTONE}${ENV_CHANGER}"

CONFIG_FOLDER=$(basename $(dirname $CONFIG_PATH))
CONFIG_FILE=$(basename $CONFIG_PATH)
CONFIG_NAME="${CONFIG_FILE%.*}"
SNAPSHOT_NAME="$CONFIG_FOLDER"_"$CONFIG_NAME"

if [[ -n $ISO_URL ]]; then
    pushd $(mktemp -d --tmpdir=.)
    #In case if URL contains link to magnet_link.txt file
    #which format is 'MAGNET_LINK=magnet.....'
    if [[ $ISO_URL == *magnet_link* ]]; then
        aria2c $ISO_URL
        export `cat $(ls | grep .*txt$)`
        ISO_URL=$MAGNET_LINK
    fi
    #Download provided iso into tmp folder
    aria2c --seed-time=0 $ISO_URL
    ISO_NAME=$(ls | grep .*iso$)
    export ISO_NAME=$(echo $ISO_NAME | sed 's/.torrent//')
    export ISO_PATH=$PWD/$(ls | grep .*iso$)
    popd
else
    export ISO_NAME=$(ls "$ISO_DIR")
    export ISO_PATH="$ISO_DIR/$ISO_NAME"
fi

ISO_ID=$(echo "$ISO_NAME" | cut -f3 -d-)

echo "ENV_NAME=$ENV_NAME" > "$ENV_INJECT_PATH"
echo "SNAPSHOT_NAME=$SNAPSHOT_NAME" >> "$ENV_INJECT_PATH"
echo "ISO_PATH=$ISO_PATH" >> "$ENV_INJECT_PATH"
if [[ -n $ISO_ID ]]; then
   echo "ISO_ID=$ISO_ID" >> "$ENV_INJECT_PATH"
fi
