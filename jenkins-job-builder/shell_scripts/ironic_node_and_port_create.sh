#!/bin/bash
export SSH_OPTS='-o UserKnownHostsFile=/dev/null  -o StrictHostKeyChecking=no'
export FUEL_MASTER_IP="10.109.2.2"
export CONTROLLER_ID=4

##### Get IRONIC variable from env #####  	
IRONIC_NODE_MAC=$(virsh dumpxml MOS_CI_MirantisOpenStack-9.0.iso_ironic_ceph_slave-06 | grep -B1 ironic_ceph_ironic | head -n1 | cut -d "'" -f 2)	
IRONIC_LIBVIRT_NETWORK=$(virsh net-dumpxml MOS_CI_MirantisOpenStack-9.0.iso_ironic_ceph_ironic | grep "ip address" | cut -d "'" -f 2)
	
####Addinging script for Ironic node and port creating #####    	
cat << EOF > /tmp/ironic_node_create.sh	
#!/bin/bash
source /root/openrc

nova flavor-create bm_flavor auto 3072 150 1

curl https://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64.tar.gz | tar -xzp

glance image-create \
--name virtual_trusty_ext4 \
--disk-format raw \
--container-format bare \
--file trusty-server-cloudimg-amd64.img \
--visibility public \
--progress \
--property cpu_arch='x86_64' \
--property hypervisor_type='baremetal' \
--property fuel_disk_info='[{"name": "vda", "extra": [], "free_space": 11000, "type": "disk", "id": "vda", "size": 11000, "volumes": [{"mount": "/", "type": "partition", "file_system": "ext4", "size": 10000}]}]'

ironic node-create \
-d fuel_libvirt \
-i deploy_kernel=\$(nova image-list|grep ironic-deploy-linux|awk '{print \$2}') \
-i deploy_ramdisk=\$(nova image-list|grep ironic-deploy-initramfs|awk '{print \$2}') \
-i deploy_squashfs=\$(nova image-list|grep ironic-deploy-squashfs|awk '{print \$2}') \
-i libvirt_uri=qemu+tcp://$IRONIC_LIBVIRT_NETWORK/system \
-u 1d964c7f-8adc-440c-a03d-fc1fda09ee52 \
-p cpus=1 \
-p memory_mb=3072 \
-p local_gb=150 \
-p cpu_arch=x86_64 \
-n bare
EOF	
echo "ironic port-create -a $IRONIC_NODE_MAC -n 1d964c7f-8adc-440c-a03d-fc1fda09ee52" >> /tmp/ironic_node_create.sh	
	
##### Copying script for ironic to master node, then to controller #####	
sshpass -p 'r00tme' scp $SSH_OPTS /tmp/ironic_node_create.sh root@"$FUEL_MASTER_IP":/tmp/ironic_node_create.sh	
echo "scp /tmp/ironic_node_create.sh node-$CONTROLLER_ID:/tmp/ironic_node_create.sh" | sshpass -p 'r00tme' ssh $SSH_OPTS -T root@"$FUEL_MASTER_IP"
	
##### Executing ironic script from admin node on controller node: #####	
EXEC_CMD="echo 'bash -xe /tmp/ironic_node_create.sh' | ssh -T node-$CONTROLLER_ID"    	
echo "$EXEC_CMD" | sshpass -p 'r00tme' ssh $SSH_OPTS -T root@"$FUEL_MASTER_IP"
