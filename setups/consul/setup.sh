#!/usr/bin/env bash

[ "$1" == force ] || set -e
source common/lib/private/helpers.sh
ensure_swarm_is_ready

docker-machine use $(swarm_master)

# setup envoy network
docker network create -d overlay --attachable --scope swarm envoy

# setup consul
docker stack deploy $DOCKERAUTH -c setups/consul/consul.yml envoy

# install registrator
__swarm_prefixed_hosts | foreach-ssh 1 \
    docker run \
        -d --name registrator \
        -v /var/run/docker.sock:/tmp/docker.sock \
        --restart unless-stopped \
        --net envoy iktech/registrator \
        -internal=true \
        -cleanup \
        -explicit=true \
        -tags "tbn-cluster" \
        -resync=5 \
        consul://consul:8500

log_emphasize "Access to Consul: http://$(node_ips | head -1):8500"
