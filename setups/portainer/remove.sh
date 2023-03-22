#!/usr/bin/env bash

[ "$1" == force ] || set -e
source common/lib/private/helpers.sh
ensure_swarm_is_ready

docker-machine use $(swarm_master)

# remove portainer
docker stack rm portainer
