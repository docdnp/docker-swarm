shopt -s expand_aliases

source common/helpers.sh
source common/lib/private/deploy.sh
source common/lib/private/ensure.sh

swarm_master () { __swarm_prefixed_hosts 1; }
