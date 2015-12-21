#!/bin/bash -e
# Based on the method described here:
# http://troubleshootingrange.blogspot.com/2012/09/hosting-simple-apt-repository-on-centos.html

ARCH=amd64
REPO_PATH=$1
REPONAME=$2

BINDIR=${REPO_PATH}/dists/${REPONAME}/main
release_header=$(sed '/MD5Sum:/,$d' ${REPO_PATH}/dists/${REPONAME}/Release)

override_main="indices/override.${REPONAME}.main"
override_udeb="indices/override.${REPONAME}.main.debian-installer"
override_extra="indices/override.${REPONAME}.extra.main"

if [ -f "${REPO_PATH}/${override_main}" ]; then
    binoverride="${override_main}"
else
    binoverride=""
fi
if [ -f "${REPO_PATH}/${override_udeb}" ]; then
    binoverride_udeb="${override_udeb}"
else
    binoverride_udeb=""
fi
if [ -f "${REPO_PATH}/${override_extra}" ]; then
    extraoverride="--extra-override ${override_extra}"
else
    extraoverride=""
fi

package_deb=${BINDIR}/binary-${ARCH}/Packages
package_udeb=${BINDIR}/debian-installer/binary-${ARCH}/Packages

cd ${REPO_PATH}

# Scan *.deb packages
echo "#############################################"
echo "           Scan *.deb packages"
echo "#############################################"

echo "dpkg-scanpackages  -m --extra-override ${extraoverride} -a ${ARCH} pool/main ${binoverride} | sudo tee ${package_deb}.tmp &>/dev/null"
dpkg-scanpackages  -m ${extraoverride} -a ${ARCH} pool/main ${binoverride} 2>/dev/null | sudo tee ${package_deb}.tmp &>/dev/null
echo "---------------------------------------------"
echo "DONE"

echo "gzip -9c ${package_deb}.tmp | sudo tee ${package_deb}.gz.tmp"
gzip -9c ${package_deb}.tmp | sudo tee ${package_deb}.gz.tmp 1>/dev/null
echo "---------------------------------------------"
echo "DONE"

echo "bzip2 -ckz ${package_deb}.tmp | sudo tee ${package_deb}.bz2.tmp"
bzip2 -ckz ${package_deb}.tmp | sudo tee ${package_deb}.bz2.tmp 1>/dev/null
echo "---------------------------------------------"
echo "DONE"

# Replace original files with new ones
echo "#############################################"
echo "    Replace original .deb files with new ones"
echo "#############################################"
sudo mv --backup -f ${package_deb}.tmp ${package_deb}
sudo mv --backup -f ${package_deb}.gz.tmp ${package_deb}.gz
sudo mv --backup -f ${package_deb}.bz2.tmp ${package_deb}.bz2
echo "---------------------------------------------"
echo "DONE"

if [ -d "${BINDIR}/debian-installer/binary-${ARCH}/" ]; then
    # Scan *.udeb packages
    echo "#############################################"
    echo "           Scan *.udeb packages"
    echo "#############################################"

    echo "dpkg-scanpackages -t udeb -m -a ${ARCH} pool/debian-installer ${binoverride_udeb} | sudo tee ${package_udeb}.tmp &>/dev/null"
    dpkg-scanpackages -t udeb -m -a ${ARCH} pool/debian-installer ${binoverride_udeb} 2>/dev/null | sudo tee ${package_udeb}.tmp &>/dev/null
    echo "---------------------------------------------"
    echo "DONE"

    echo "gzip -9c ${package_udeb}.tmp | sudo tee ${package_udeb}.gz.tmp"
    gzip -9c ${package_udeb}.tmp | sudo tee ${package_udeb}.gz.tmp 1>/dev/null
    echo "---------------------------------------------"
    echo "DONE"

    echo "bzip2 -ckz ${package_udeb}.tmp | sudo tee ${package_udeb}.bz2.tmp"
    bzip2 -ckz ${package_udeb}.tmp | sudo tee ${package_udeb}.bz2.tmp 1>/dev/null
    echo "---------------------------------------------"
    echo "DONE"

    # Replace original files with new ones
    echo "#############################################"
    echo "   Replace original .udeb files with new ones"
    echo "#############################################"
    sudo mv --backup -f ${package_udeb}.tmp ${package_udeb}
    sudo mv --backup -f ${package_udeb}.gz.tmp ${package_udeb}.gz
    sudo mv --backup -f ${package_udeb}.bz2.tmp ${package_udeb}.bz2
    echo "---------------------------------------------"
    echo "DONE"
fi

# Generate release file
echo "#############################################"
echo "           Generate release file"
echo "#############################################"
cd ${REPO_PATH}/dists/${REPONAME}
echo "$release_header" > /tmp/Release.tmp

# Generate hashes
c1=(MD5Sum: SHA1: SHA256: SHA512:)
c2=(md5 sha1 sha256 sha512)

i=0
while [ $i -lt ${#c1[*]} ]; do
    echo ${c1[i]}
        for hashme in `find main -type f \( -not -name "*~" -name "Package*" -o -name "Release*" \)`; do
        ohash=`openssl dgst -${c2[$i]} ${hashme}`
        chash="${ohash##* }"
        size=`stat -c %s ${hashme}`
        echo " ${chash} ${size} ${hashme}"
    done
    i=$(( $i + 1));
done >> /tmp/Release.tmp

sudo mv --backup -f /tmp/Release.tmp Release
echo "---------------------------------------------"
echo "DONE"
