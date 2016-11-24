 set -x

 sshpass -p r00tme scp jenkins-job-builder/shell_scripts/run_stepler_on_cfg01.sh root@172.16.10.100:
 sshpass -p r00tme ssh root@172.16.10.100 "bash run_stepler_on_cfg01.sh"
