#!/usr/bin/env bash

source common/lib/private/helpers.sh
ensure_command_exists docker-machine

__swarm_prefixed_hosts \
    | xargs -i docker-machine create -d virtualbox --engine-label type={} --virtualbox-hostonly-cidr $LOCALHOST/24 {}

docker-machine use $(swarm_master)
docker swarm init --advertise-addr $(node_ips | head -1)

JOIN_CMD="$(docker swarm join-token manager | grep docker)"
__swarm_prefixed_hosts 3 2 \
    | xargs -i docker-machine ssh {} -- $JOIN_CMD
