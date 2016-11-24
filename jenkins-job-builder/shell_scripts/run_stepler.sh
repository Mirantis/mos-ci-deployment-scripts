 set -x

 sshpass -p r00tme scp jenkins-job-builder/shell_scripts/run_stepler_on_cfg01.sh root@$CFG_NODE_IP:
 sshpass -p r00tme ssh root@$CFG_NODE_IP "bash run_stepler_on_cfg01.sh"
