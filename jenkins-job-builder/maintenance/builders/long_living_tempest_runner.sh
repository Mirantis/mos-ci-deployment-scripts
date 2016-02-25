#!/bin/bash

REPORT_PATH="${REPORT_PREFIX}/long_living_tempest_${VERSION}"
echo "$REPORT_PATH" > ./param.pm
wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/maintenance/helpers/long_living_rally_run.sh

chmod +x long_living_rally_run.sh

sshpass -p 'r00tme' scp -o "StrictHostKeyChecking no" long_living_rally_run.sh root@10.20.1.2:/root/
echo 'chmod +x /root/long_living_rally_run.sh && /bin/bash -xe /root/long_living_rally_run.sh > /root/log.log' | sshpass -p 'r00tme' ssh -T root@10.20.1.2
sshpass -p 'r00tme' scp -o "StrictHostKeyChecking no" root@10.20.1.2:/root/log.log ./
sshpass -p 'r00tme' scp -o "StrictHostKeyChecking no" root@10.20.1.2:/var/lib/rally-tempest-container-home-dir/verification.xml ./