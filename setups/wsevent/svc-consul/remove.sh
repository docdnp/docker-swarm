#!/usr/bin/env bash

source common/lib/private/helpers.sh
ensure_command_exists docker-machine

project-remove "$@"
