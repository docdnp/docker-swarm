#!/usr/bin/env bash

[ "$1" == force ] || set -e
source common/helpers.sh
ensure_swarm_is_ready

docker-machine use $(swarm_master)

# setup portainer
docker stack deploy $DOCKERAUTH -c setups/portainer/portainer.yml portainer

log_emphasize "Access to Portainer: http://$(node_ips | head -1):9000"
