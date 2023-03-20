#!/usr/bin/env bash
# see https://docs.docker.com.xy2401.com/machine/install-machine/

[ "$1" == force ] || set -e

source common/helpers.sh
ensure_command_exists virtualbox
ensure_command_exists curl
ensure_command_exists wget

# install docker-machine
base=https://github.com/docker/machine/releases/download/v0.16.0 &&
curl -L $base/docker-machine-$(uname -s)-$(uname -m) >/tmp/docker-machine &&
    sudo mv /tmp/docker-machine /usr/local/bin/docker-machine &&
    sudo chmod +x /usr/local/bin/docker-machine

# install docker-machine's bash-completion
base=https://raw.githubusercontent.com/docker/machine/v0.16.0
for i in docker-machine-prompt.bash docker-machine-wrapper.bash docker-machine.bash
do
  sudo wget "$base/contrib/completion/bash/${i}" -P /etc/bash_completion.d
done

echo "docker-machine was installed successfully. Reload bash completion if you like to."
