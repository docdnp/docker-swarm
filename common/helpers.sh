## This file is intended to either be sourced in this project's scripts
## or directly by a user's bash.
SWARM_NODE_PREFIX=${SWARM_NODE_PREFIX:-test}
SWARM_SIZE=${SWARM_SIZE:-3}
LOCALHOST=192.168.57.10
DOCKERAUTH=${DOCKERAUTH:-}

# -----------------------
# prefix handling
__prefix                () { local PREFIX=${1:-$SWARM_NODE_PREFIX}; sed -re "s/(.*)/$PREFIX-\1/"; }
__prefix_set            () { export SWARM_NODE_PREFIX=${1:-$SWARM_NODE_PREFIX}; }
__prefix_get            () { echo SWARM_NODE_PREFIX: $SWARM_NODE_PREFIX   ; }

# -----------------------
# node information
__node_ips              () { local nodes=${1:-$SWARM_SIZE} from=${2:-1}; docker-machine ls --format '{{.URL}}' | sed -re 's|.*//\|:.*||g' | head -$(($nodes)) | tail -$from; }

# -----------------------
# swarm and docker handling and information
__swarm_size_get        () { echo SWARM_SIZE: $SWARM_SIZE; }
__swarm_size_set        () { export SWARM_SIZE=${1:-$SWARM_SIZE}; }
__swarm_hosts           () { local nodes=${1:-$SWARM_SIZE} from=${2:-1}; eval "echo node-{$from..$nodes}" ; }
__swarm_prefixed_hosts  () { local nodes=${1:-$SWARM_SIZE} from=${2:-1}; __swarm_hosts $nodes $from | to_list | __prefix; }
__swarm_start           () { local nodes=${1:-$SWARM_SIZE} from=${2:-1}; __swarm_prefixed_hosts $nodes $from | __swarm_node start; }
__swarm_stop            () { local nodes=${1:-$SWARM_SIZE} from=${2:-1}; __swarm_prefixed_hosts $nodes $from | __swarm_node stop;  }
__swarm_node            () { xargs -n1 docker-machine "$@" ; }
__swarm_docker_auth     () { 
    [ "$1" == "on"  ] && { 
        local DOCKER_USER DOCKER_PASSWORD
        read  -p "Your docker username: " DOCKER_USER
        read -sp "Your docker password: " DOCKER_PASSWORD
        export DOCKERAUTH=--with-registry-auth
        __swarm_prefixed_hosts | foreach-ssh echo "Host {}: Login to docker hub." \; docker login -u "$DOCKER_USER" -p "$DOCKER_PASSWORD"
    }
    [ "$1" == "off" ] && { unset DOCKERAUTH; return; }
    local auth=ON 
    [ -z "$1" ] && log_usage "swarm_docker_auth [on|off]"
    [ -z "$DOCKERAUTH" ] && auth=OFF
    log_info  "DockerHub authentication: $auth"
}

swarm () {
local subcmd="$1" arg="$2"
case $subcmd in
    get) case $arg in
            prefix) __prefix_get                       ;;
            size)   __swarm_size_get                   ;;
         esac ;;
    set) case $arg in
            prefix) shift 2; __prefix_set     "$@"     ;;
            size)   shift 2; __swarm_size_set "$@"     ;;
         esac ;;
    hosts)  __swarm_prefixed_hosts                     ;;
    start)  __swarm_start                              ;;
    stop)   __swarm_stop                               ;;
    status) __docker-machine ls                        ;;
    auth)   shift; __swarm_docker_auth "$@"            ;;
    ips) case $arg in          
            all) __node_ips $SWARM_SIZE $SWARM_SIZE    ;;
            *)   shift 2; __node_ips $arg 1            ;;
            esac ;;
    stacks)  shift; _stacks_manage "$@"                ;;
    *) cat <<EOF
Usage: swarm <subcmd> [args]

  Subcommands:
    get    (prefix|size)    get the cluster node prefix or the number of nodes
    set    (prefix|size)    set the cluster node prefix or the number of nodes
    hosts                   get the names of the of the cluster nodes
    start  <node-name>      start a given node
    stop   <node-name>      stop a given node
    status                  dump a simple overview status of node clusters
    auth                    register cluster to your docker hub account
    ips    (all|<node-num>) returns the number IPs of all or given cluster nodes
    stack  <subcmd>         setup, deploy, redeploy or list your service stacks

EOF
esac
}

___swarm_docker_auth () {
    local IFS=$'\n' WORD="${COMP_WORDS[$COMP_CWORD]}"
    [ "$COMP_CWORD" == 1 ] && 
        COMPREPLY=($(compgen -W "$(echo -e 'on\noff')"  -- "$WORD" ))
}
complete -o nosort -F __swarm_docker_auth swarm_docker_auth


__swarm_comp_nodes () {
    echo -e "all\n$(eval \\"echo {1..$SWARM_SIZE}" | to_list)"
}
__swarm () {
local IFS=$'\n'
local POS=$COMP_CWORD
local NWORD="${COMP_WORDS[1]}" 
local WORD="${COMP_WORDS[$POS]}" 
local PWORD="${COMP_WORDS[$((POS-1))]}"

[ x$NWORD == xstacks ] && [ $POS -gt 2 ] && PWORD=$NWORD
[ x$NWORD == xauth ]   && [ $POS -gt 2 ] && PWORD=$NWORD
[[ "$NWORD" =~ ^set|get$ ]]   && [ $POS -gt 2 ] && return

case $PWORD in
    set|get) case $WORD in
            prefix|size);;
            *) COMPREPLY=($(compgen -W "$(echo -e 'prefix\nsize')"  -- "$WORD" ));;
         esac ;;
    hosts)  [ $POS -lt 2 ] && __swarm_prefixed_hosts   ;;
    start)  [ $POS -lt 2 ] && __swarm_start            ;;
    stop)   [ $POS -lt 2 ] && __swarm_stop             ;;
    status) [ $POS -lt 2 ] && __docker-machine ls      ;;
    auth)   
        COMP_WORDS=( ${COMP_WORDS[@]:1} )
        COMP_CWORD=$((COMP_CWORD-1))
        ___swarm_docker_auth      ;;
    ips) case $WORD in          
            all) node_ips $SWARM_SIZE                  ;;
            *)   COMPREPLY=($(compgen -W "$(__swarm_comp_nodes)" -- $WORD ));;
            esac ;;
    stacks) 
        COMP_WORDS=( ${COMP_WORDS[@]:1} )
        COMP_CWORD=$((COMP_CWORD-1))
        __stacks_manage 
        ;;
    *) COMPREPLY=($(compgen -W "$(echo -e 'get\nset\nhosts\nstart\nstop\nstatus\nauth\nips\nstacks')"  "$WORD" )) ;;
esac
}
complete -o nosort -F __swarm swarm

# -----------------------
# help interactive user
pnhelp () {
    echo The following list contains functions which are exposed by sourcing common/helpers.sh.
    echo In case you want to know more about a function call:
    echo
    echo "   declare -f <function-name>"

    grep -hv ^[[:blank:]] common/lib/stack-manage.sh common/lib/format-and-filters.sh common/lib/pipeable-loops.sh\
        | grep -Ev '^([_\{\}A-Z]|complete|shopt|export|source|##)' \
        | sed -re 's|\(\).*\|alias \|=.*||g' \
               -e '/^$/d' \
               -e 's/^(# -)/\n\1/'
}


source common/lib/format-and-filters.sh
source common/lib/stack-manage.sh
source common/lib/logging.sh
source common/lib/docker-machine.sh
