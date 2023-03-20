#!/usr/bin/env bash

[ "$1" == force ] || set -e
source common/helpers.sh
ensure_command_exists docker-machine

docker-machine ls \
    | grep -E $(swarm_prefixed_hosts | to_string | to_or_rexp) \
    | awk '{print $1}'   \
    | xargs -n1 docker-machine rm -y 
