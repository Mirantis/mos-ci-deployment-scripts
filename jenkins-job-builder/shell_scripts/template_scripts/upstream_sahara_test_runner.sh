set +e

virtualenv --clear venv
. venv/bin/activate
pip install -U pip
pip install tox
pip install -U python_subunit junitxml
#pip install git+git://github.com/openstack/python-saharaclient
pip install git+git://github.com/openstack/python-openstackclient

images_folder='sahara-images'
images_list="\
http://172.18.173.8:8080/jenkins/view/System%20Jobs/job/get_sahara_images/lastSuccessfulBuild/artifact/sahara-mitaka-spark-1.6.0-ubuntu.qcow2 \
http://172.18.173.8:8080/jenkins/view/System%20Jobs/job/get_sahara_images/lastSuccessfulBuild/artifact/sahara-mitaka-spark-1.3.1-ubuntu.qcow2 \
http://172.18.173.8:8080/jenkins/view/System%20Jobs/job/get_sahara_images/lastSuccessfulBuild/artifact/sahara-mitaka-mapr-5.1.0-ubuntu.qcow2 \
http://172.18.173.8:8080/jenkins/view/System%20Jobs/job/get_sahara_images/lastSuccessfulBuild/artifact/sahara-mitaka-ambari-2.2-centos-6.7.qcow2 \
"

rm -rf ${images_folder}
mkdir ${images_folder}

for url in $images_list; do
	wget -P ${images_folder} $url
done

#a hack to allow the image create use --location key
#export OS_IMAGE_API_VERSION=1

for file in ${images_folder}/*; do
    image_name=`basename ${file} | sed "s/.qcow2//g"`
    openstack image create --disk-format qcow2 --container-format bare --public --file ${file} ${image_name}
    #openstack dataprocessing image register ${image_name} --username ubuntu
    #openstack dataprocessing image tags add ${image_name} --tag "1.6.0"
    #openstack dataprocessing image tags add ${image_name} --tag "spark"

    #sahara image-register --id ${image_id} --username ubuntu    
    #sahara image-add-tag --id ${image_id} --tag "1.6.0"
    #sahara image-add-tag --id ${image_id} --tag "spark"
done

rm -rf ${images_folder}

echo '[DEFAULT]' > sahara-conf
echo 'network_type: neutron' >> sahara-conf
echo 'network_private_name: admin_internal_net' >> sahara-conf
echo 'network_public_name: admin_floating_net' >> sahara-conf
echo 'image_username: ubuntu' >> sahara-conf
echo 'cluster_name: test' >> sahara-conf
echo 'vanilla_two_seven_one_image: vanilla271' >> sahara-conf
echo 'ambari_2_1_image: sahara-mitaka-ambari-2.2-centos-6.7' >> sahara-conf
echo 'mapr_500mrv2_image: sahara-mitaka-mapr-5.1.0-ubuntu' >> sahara-conf
echo 'spark_1_3_image: sahara-mitaka-spark-1.3.1-ubuntu' >> sahara-conf
echo 'spark_1_6_image: sahara-mitaka-spark-1.6.0-ubuntu' >> sahara-conf
#echo 'vanilla_two_six_image: centos_sahara_vanilla_hadoop_2_6_latest' >> sahara-conf
#echo 'cdh_5_4_0_image: cdh540' >> sahara-conf
#echo 'cdh_5_5_0_image=cdh_5.5.0' >> sahara-conf

echo 'ci_flavor_id: '\''2'\'' ' >> sahara-conf
echo 'medium_flavor_id: '\''3'\'' ' >> sahara-conf
echo 'large_flavor_id: '\''5'\'' ' >> sahara-conf


tox -e venv -- sahara-scenario -p spark -v 1.6.0 -V sahara-conf --verbose --report \ 
| subunit2junitxml \
    --forward \
    --output-to=$REPORT_FILE \
| subunit2pyunit

#sahara-scenario -p spark -v 1.6.0

deactivate
