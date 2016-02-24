#!/bin/bash

REPORT_PATH="${REPORT_PREFIX}/long_living_tempest_${VERSION}"
echo "$REPORT_PATH" > ./param.pm

wget https://raw.githubusercontent.com/Mirantis/mos-ci-deployment-scripts/master/jenkins-job-builder/maintenance/helpers/run_rally.sh

chmod +x run_rally.sh

sshpass -p 'r00tme' scp -o "StrictHostKeyChecking no" run_rally.sh root@10.20.1.2:/root/
echo 'chmod +x /root/run_rally.sh && /bin/bash -xe /root/run_rally.sh > /root/log.log' | sshpass -p 'r00tme' ssh -T root@10.20.1.2