#!/bin/bash

ID=$(docker images | awk '/rally/{print $3}')
echo "ID: ${ID}"
DOCK_ID=$(docker run -tid -v /var/lib/rally-tempest-container-home-dir:/home/rally --net host "$ID")
echo "DOCK ID: ${DOCK_ID}"
docker exec "$DOCK_ID" bash -c "source /home/rally/openrc && rally verify start --system-wide"
docker exec "$DOCK_ID" bash -c "rally verify results --json --output-file output.json"
docker exec "$DOCK_ID" bash -c "rm -rf rally_json2junit && git clone https://github.com/EduardFazliev/rally_json2junit.git && python rally_json2junit/rally_json2junit/results_parser.py output.json"
