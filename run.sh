#!/bin/bash
NAME="bhack-website"
PORT=10001

if [ -z "${1}" ]; then
  echo "You must provide a docker image tag to launch"
  exit 1
fi

if ! docker inspect --type=image ${NAME}:${1} > /dev/null 2>&1; then
  echo "docker image ${NAME}:${1} does not exist, chickening out."
  exit 1
fi

docker stop ${NAME}
docker rm ${NAME}
docker run \
  --name=${NAME} \
  --restart=unless-stopped \
  -v /srv/ballarathackerspace.org.au/data:/data \
  -v /srv/ballarathackerspace.org.au/blog:/blog \
  -p ${PORT}:3000 \
  -e BHACKD_CONFIG=/data/bhackd.conf \
  -e TZ=Australia/Melbourne \
  -d bhack-website:$1

