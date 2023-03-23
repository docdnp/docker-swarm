shopt -s expand_aliases

BASEDIR="$(dirname $0)"

source common/helpers.sh
source common/lib/private/deploy.sh
source common/lib/private/ensure.sh

node_ips () { swarm ips "$@"; }

swarm_master () { __swarm_prefixed_hosts 1; }
