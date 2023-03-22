#!/usr/bin/env bash

[ x$(eval "echo \$$#") == xforce ] || set -e
source common/lib/private/helpers.sh
ensure_swarm_is_ready

docker-machine use $(swarm_master)

# remove registrator
__swarm_prefixed_hosts | foreach-ssh 1 docker rm --force registrator 

# remove consul
docker stack rm envoy

# remove envoy network
for i in {1..10} ; do 
    docker network rm envoy && exit
    sleep $i
done
