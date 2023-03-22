#!/usr/bin/env bash

[ "$1" == force ] || set -e
source common/lib/private/helpers.sh
ensure_command_exists docker-machine

sudo rm -f /usr/local/bin/docker-machine
for i in docker-machine-prompt.bash docker-machine-wrapper.bash docker-machine.bash ; do 
    sudo rm -f /etc/bash_completion.d/$i
done
