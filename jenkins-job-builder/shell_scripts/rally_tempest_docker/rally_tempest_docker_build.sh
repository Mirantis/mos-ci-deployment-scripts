#!/usr/bin/env bash
#### Remove old docker container and docker files ####
set +e
sudo docker rmi rally-tempest
rm -rf dockerfiles rally_tempest_image
set -e
git clone https://review.fuel-infra.org/fuel-infra/dockerfiles

##### Change rally version and add option to genconfig ####
sed -i 's|FROM rallyforge/rally:latest|FROM rallyforge/rally:0.7.0|g' \
       dockerfiles/rally-tempest/latest/Dockerfile

sed -i 's|rally verify genconfig|rally verify genconfig --add-options tempest_config|g' \
       dockerfiles/rally-tempest/latest/setup_tempest.sh


#### Build and save new docker container ####
sudo docker build --no-cache -t rally-tempest dockerfiles/rally-tempest/latest
sudo docker save -o ./rally_tempest_image rally-tempest
