#!/usr/bin/env bash

[ "$1" == force ] || set -e
source common/helpers.sh
ensure_swarm_is_ready

docker-machine use $(swarm_master)

# remove registrator
swarm_prefixed_hosts | foreach-ssh 1 docker rm --force registrator 

# remove consul
docker stack rm envoy

# remove envoy network
docker network rm envoy
