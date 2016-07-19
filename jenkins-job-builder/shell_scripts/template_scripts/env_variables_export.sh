ISO_NAME=`ls "$ISO_DIR"`
ENV_NAME=MOS_CI_"${{ISO_NAME}}${{ENV_CHANGER}}"
ISO_ID=`echo "$ISO_NAME" | cut -f4 -d-`
ISO_PATH="$ISO_DIR/$ISO_NAME"
CONFIG_FOLDER=$(basename $(dirname $CONFIG_PATH))
CONFIG_FILE=$(basename $CONFIG_PATH)
CONFIG_NAME="${{CONFIG_FILE%.*}}"
SNAPSHOT_NAME="$CONFIG_FOLDER"_"$CONFIG_NAME"


echo "ENV_NAME=$ENV_NAME" > "$ENV_INJECT_PATH"
echo "ISO_ID=$ISO_ID" >> "$ENV_INJECT_PATH"
echo "ISO_PATH=$ISO_PATH" >> "$ENV_INJECT_PATH"
echo "SNAPSHOT_NAME=$SNAPSHOT_NAME" >> "$ENV_INJECT_PATH"

# update fuel (9.0 -> 9.x)
sudo wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/shell_scripts/update_fuel.sh
sudo chmod +x update_fuel.sh
./update_fuel.sh
