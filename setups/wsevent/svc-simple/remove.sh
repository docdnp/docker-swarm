#!/usr/bin/env bash

source common/helpers.sh
ensure_command_exists docker-machine

docker-machine use $(swarm_master)

PROJECT="$(basename $BASEDIR)"

echo Removing project: $PROJECT

for-swarm-configs -r \
    | xargs -i echo docker stack rm $PROJECT--\$\(basename "{}" .yml \
                            \| sed -re "'s|^[0-9]+-\|-.*||g'"\) \
    | bash

docker-machine use --unset
for-compose-configs \
    | foreach echo "docker-compose -f {} down" \
    | bash
