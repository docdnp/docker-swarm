#!/usr/bin/env bash

[ "$1" == force ] || set -e
source common/lib/private/helpers.sh
ensure_debian

pgrep VBox* 2>&1 && sudo pkill VBox*
sudo apt-key remove 5CDFA2F683C52980AECF
sudo apt-key remove D9C954422A4B98AB5139
sudo apt purge -y 'virtualbox*'
sudo rm -f /etc/apt/sources.list.d/virtualbox.list /usr/share/keyrings/oracle-virtualbox-2016.gpg
