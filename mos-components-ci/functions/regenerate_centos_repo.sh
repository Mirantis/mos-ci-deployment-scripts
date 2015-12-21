#!/bin/bash -e

REPO_PATH=$1

COMPSXML=$(awk -F'"' '$4 ~ /comps.xml$/{print $4; exit}' ${REPO_PATH}/repodata/repomd.xml)

sudo createrepo -g ${REPO_PATH}/$COMPSXML -o ${REPO_PATH} ${REPO_PATH}
