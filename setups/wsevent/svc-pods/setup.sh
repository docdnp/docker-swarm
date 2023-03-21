#!/usr/bin/env bash

[ "$1" == force ] || set -e
source common/helpers.sh
ensure_command_exists docker-machine

docker-machine use $(swarm_master)
HOST_IP=$(virtual-box-host-ip)

PROJECT="$(basename $BASEDIR)"

echo Setting up project: $PROJECT

for-swarm-configs \
    | foreach echo sed -re "\"s|192.168.57.10|$HOST_IP|\"" {} \
                        \| docker stack deploy $DOCKERAUTH -c - $PROJECT--\$\(basename "{}" .yml \
                        \| sed -re "'s|^[0-9]+-\|-.*||g'"\) \
    | bash

docker-machine use --unset
for-compose-configs \
    | foreach echo "docker-compose -f {} up -d" \
    | bash

log_emphasize "To test services of $PROJECT, call:

    docker run --rm -it --network host thednp/wsevent \\
        -consume-address $(node_ips 1):10080 \\
        -consume-path dackservice-events \\
        --no-produce"
