#!/bin/bash

set -euox pipefail

ref_name=$1
ref=$2
linux=$3

source ${SCRIPT_DIR}/utils.sh

echo "Building $1 $2 $3"

container="otp-build-${linux}-${ref_name}"
image="bob-otp"
tag=${linux}
date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

docker build -t ${image}:${tag} -f ${SCRIPT_DIR}/otp/otp-${linux}.dockerfile ${SCRIPT_DIR}
docker rm ${container} || true
docker run -t -e OTP_REF=${ref_name} --name=${container} ${image}:${tag}

docker cp ${container}:/home/build/out/${ref_name}.tar.gz ${ref_name}.tar.gz

docker rm -f ${container}
docker rmi -f ${image}:${tag}

aws s3 cp ${ref_name}.tar.gz s3://s3.hex.pm/builds/otp/${linux}/${ref_name}.tar.gz --cache-control "public,max-age=3600" --metadata "{\"surrogate-key\":\"otp-builds-${linux}-${ref_name}\",\"surrogate-control\":\"public,max-age=604800\"}"

aws s3 cp s3://s3.hex.pm/builds/otp/${linux}/builds.txt builds.txt || true
touch builds.txt
sed -i "/^${ref_name} /d" builds.txt
echo -e "${ref_name} ${ref} $(date -u '+%Y-%m-%dT%H:%M:%SZ')\n$(cat builds.txt)" > builds.txt
sort -u -k1,1 -o builds.txt builds.txt
aws s3 cp builds.txt s3://s3.hex.pm/builds/otp/${linux}/builds.txt --cache-control "public,max-age=3600" --metadata '{"surrogate-key":"otp-builds-txt","surrogate-control":"public,max-age=604800"}'

fastly_purge $BOB_FASTLY_SERVICE_HEXPM "otp-builds-${linux}-${ref_name}"
fastly_purge $BOB_FASTLY_SERVICE_HEXPM "otp-builds-txt"
