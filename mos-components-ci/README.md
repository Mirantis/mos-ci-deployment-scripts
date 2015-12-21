mos_components_ci
==========

Need to enable gerrit and add codestyle checker:
shellcheck --exclude=SC2086,SC2034 *.sh
bashate *.sh
pep8 .

prepare lxc server
==================

Put mos-infra-ro key
 vim /root/.ssh/id_rsa
 chmod 600 /root/.ssh/id_rsa

Clone repo
 git clone ssh://mos-infra-ro@review.fuel-infra.org:29418/mos-infra/mos-components-ci /opt/mos-components-ci

Execute prepare script
 /opt/mos-components-ci/scripts/lxc_prepare_server.sh

add worker
==========
cd /opt/mos-components-ci/scripts
./lxc_create_worker.sh NUMBER
