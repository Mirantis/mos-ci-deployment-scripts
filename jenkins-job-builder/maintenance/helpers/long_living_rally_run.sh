#!/bin/bash -ex

if [ -f mos_apply_mu.py ]; then rm mos_apply_mu.py ; fi

wget https://raw.githubusercontent.com/Mirantis/tools-sustaining/master/scripts/mos_apply_mu.py

python mos_apply_mu.py --all-envs --mos-prposed --mos-security --update

wait_offline_node() {
    set +e
    nc=${1}
    online_again=false
    for i in {1..30}; do
        ping -c 1 -w 1 node-${nc} &>/dev/null && echo "node ${nc} online" || break
        sleep 20
    done
    ping -c 1 -w 1 node-${nc} &>/dev/null && online_again=true
    set -e
    if ${online_again} ; then
        echo "node ${nc} online after 10 minutes"
        exit 30
     else
        echo "node ${nc} has gone offline"
    fi
}

wait_for_node_back_to_online() {
    set +e
    nc=${1}
    offline_again=false
    for i in {1..30}; do
        ssh -q node-${nc} exit && break || echo "node ${nc} offline"
        sleep 20
    done
    ssh -q node-${nc} exit || offline_again=true
    set -e
    if ${offline_again} ; then
        echo "node ${nc} offline after 10 minutes"
        exit 31
    else
        echo "node ${nc} has back online"
    fi
}

for i in {1..60}; do
    state=$(python mos_apply_mu.py --all-envs --check | awk '/Node/{print $4}' | sort -u)
    if [[ ${state} == "UPDATE=OK" ]]; then
        echo "Update of environment is successfully"
        break
    fi
    sleep 60
done
for i in state; do
    if [[ ${i} == "UPDATE=FAIL" ]]; then
        echo "Some nodes has Fail state after update."
        echo $(python mos_apply_mu.py --all-envs --check)
        exit 28
    elif [[ ${i} == "STARTED" ]]; then
        echo "Some nodes has Started state after 60 minutes."
        echo $(python mos_apply_mu.py --all-envs --check)
        exit 29
     fi
done

pcs_services=$(ssh node-$(fuel node | awk '/controller/{print $1}' | head -1) "pcs resource" | awk '/Clone Set/{print $4}' | sed 's/^\[//;s/\]*$//')
for controller in $(fuel node | awk '/controller/{print $1}'); do
    for service in ${pcs_services}; do
        echo "Stopping ${service} on node-${controller}"
        ssh node-${controller} "pcs resource ban ${service} node-${controller}.domain.tld  --wait"
    done
    ssh node-${controller} "shutdown -r now"
    wait_offline_node ${controller}
    wait_for_node_back_to_online ${controller}
    sleep 30
    for service in ${pcs_services}; do
        echo "Starting ${service} on node-${controller}"
        ssh node-${controller} "pcs resource clear ${service} node-${controller}.domain.tld  --wait"
    done
    sleep 30
done

for compute in $(fuel node | awk '/compute/{print $1}'); do
    ssh node-${compute} "shutdown -r now"
    wait_offline_node ${compute}
    wait_for_node_back_to_online ${compute}
done
sleep 180

ntp_server=$(awk '/^server/ && $2 !~ /127.*/ {print $2}' /etc/ntp.conf | head -1)
ntpdate -p 4 -t 0.2 -bu ${ntp_server}
for count in $(fuel nodes | awk '/controller|compute/{print $1}'); do
    ssh node-${count} "ntpdate -p 4 -t 0.2 -bu ${ntp_server}"
done

#TODO(vrovachev): need to check nova-manage service list

ID=$(docker images | awk '/rally/{print $3}')
echo "ID: ${ID}"
DOCK_ID=$(docker run -tid -v /var/lib/rally-tempest-container-home-dir:/home/rally --net host "$ID")
echo "DOCK ID: ${DOCK_ID}"
docker exec "$DOCK_ID" bash -c "source /home/rally/openrc && rally verify start --system-wide"
docker exec "$DOCK_ID" bash -c "rally verify results --json --output-file output.json"
docker exec "$DOCK_ID" bash -c "rm -rf rally_json2junit && git clone https://github.com/EduardFazliev/rally_json2junit.git && python rally_json2junit/rally_json2junit/results_parser.py output.json"
