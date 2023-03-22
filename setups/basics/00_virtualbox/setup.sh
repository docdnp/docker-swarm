#!/usr/bin/env bash
# see https://www.virtualbox.org/wiki/Linux_Downloads

[ "$1" == force ] || set -e
source common/lib/private/helpers.sh
ensure_debian

VERSION_CODENAME=$(cat /etc/os-release | grep ^VER.*CO | sed 's|.*=||')

cat <<EOF | sudo tee /etc/apt/sources.list.d/virtualbox.list 
deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] https://download.virtualbox.org/virtualbox/debian $VERSION_CODENAME contrib
EOF

wget -O- https://www.virtualbox.org/download/oracle_vbox_2016.asc | sudo gpg --dearmor --yes --output /usr/share/keyrings/oracle-virtualbox-2016.gpg
sudo apt update
sudo apt install -y $(apt search virtualbox 2>&1 | grep ^virt.*/ | sed -re 's|^.*(virtualbox-[0-9\.]+)\/.*|\1|' | grep -v ' ' | tail -1)
sudo /sbin/vboxconfig

sudo usermod -a -G vboxusers $USER
