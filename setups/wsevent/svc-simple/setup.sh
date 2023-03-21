#!/usr/bin/env bash

source common/helpers.sh
ensure_command_exists docker-machine

project-setup && \
log_emphasize "To test services of $PROJECT, call:

    docker run --rm -it --network host thednp/wsevent \\
        -consume $(node_ips 1):10080/dackservice-events -no-produce
"
