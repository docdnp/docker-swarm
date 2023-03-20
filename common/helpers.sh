## This file is intended to either be sourced in this project's scripts
## or directly by a user's bash.

BASEDIR="$(dirname $0)"
SWARM_NODE_PREFIX=${SWARM_NODE_PREFIX:-test}
SWARM_SIZE=${SWARM_SIZE:-3}
LOCALHOST=192.168.57.10
DOCKERAUTH=

# wrappers and aliases
shopt -s expand_aliases
__docker_machine_wrapper () { 
    if [[ "$1" == use ]]; then
        shift 1
        eval "$(docker-machine env "$@")"
        return
    fi
    command docker-machine "$@";
}

export PATH=$PWD/common/bin:$PATH

alias docker-machine='__docker_machine_wrapper'
alias foreach="PATH=$PATH xargs -i"
foreach-ssh () { local SLEEP=${1:-0}; [[ "$SLEEP" =~ ^[0-9]+$ ]] && shift || SLEEP=0; PATH=$PATH xargs -i docker-machine ssh {} -- sleep $SLEEP \; "$@" ; }

# simple converters and filters
to_list               () { tr ' ' "\n" ; }
to_string             () { tr "\n" ' ' | sed 's/ $//'; }
to_or_rexp            () { tr ' ' "|"; }
contains              () { grep -E "$@" >&/dev/null; }
count                 () { grep -c "$@" ; }

# simple logging functions
log_error                 () { echo "Error  : " "$@" ; }
log_warning               () { echo "Warning: " "$@" ; }
log_info                  () { echo "Info   : " "$@" ; }
log_usage                 () { echo "Usage: " "$@" ; }
log_error_exit            () { log_error "$@" ; exit 1; }
log_hline                 () { echo "==================================================================="; }
log_emphasize             () { log_hline; echo -e "$@"; log_hline; }

# prefix handling
prefix                () { local PREFIX=${1:-$SWARM_NODE_PREFIX}; sed -re "s/(.*)/$PREFIX-\1/"; }
prefix_set            () { export SWARM_NODE_PREFIX=${1:-$SWARM_NODE_PREFIX}; }

# node information
nodes_known           () { local attr=${1:-Name}; docker-machine ls --format "{{ .$attr  }}" ; }
nodes_unknown         () { local nodes=${1:-$SWARM_SIZE} from=${2:-1}; nodes_known | grep -Ev "$(swarm_hosts $nodes $from | to_or_rexp)" ; }
node_ips              () { local nodes=${1:-$SWARM_SIZE} from=${2:-1}; docker-machine ls --format '{{.URL}}' | sed -re 's|.*//\|:.*||g' | head -$(($nodes-$from+1)); }

# swarm and docker handling and information
swarm_size_set        () { export SWARM_SIZE=${1:-$SWARM_SIZE}; }
swarm_hosts           () { local nodes=${1:-$SWARM_SIZE} from=${2:-1}; eval "echo node-{$from..$nodes}" ; }
swarm_prefixed_hosts  () { local nodes=${1:-$SWARM_SIZE} from=${2:-1}; swarm_hosts $nodes $from | to_list | prefix; }
swarm_status          () { docker-machine ls; }
swarm_start           () { local nodes=${1:-$SWARM_SIZE} from=${2:-1}; swarm_prefixed_hosts $nodes $from | swarm_node start; }
swarm_stop            () { local nodes=${1:-$SWARM_SIZE} from=${2:-1}; swarm_prefixed_hosts $nodes $from | swarm_node stop;  }
swarm_node            () { xargs -n1 docker-machine "$@" ; }
swarm_master          () { swarm_prefixed_hosts 1; }
swarm_docker_auth     () { 
    [ "$1" == "on"  ] && { 
        local DOCKER_USER DOCKER_PASSWORD
        read  -p "Your docker username: " DOCKER_USER
        read -sp "Your docker password: " DOCKER_PASSWORD
        export DOCKERAUTH=--with-registry-auth
        swarm_prefixed_hosts | foreach-ssh echo "Host {}: Login to docker hub." \; docker login -u "$DOCKER_USER" -p "$DOCKER_PASSWORD"
    }
    [ "$1" == "off" ] && { unset DOCKERAUTH; return; }
    local auth=ON 
    [ -z "$1" ] && log_usage "swarm_docker_auth [on|off]"
    [ -z "$DOCKERAUTH" ] && auth=OFF
    log_info  "DockerHub authentication: $auth"
}

# loop compose files
for-swarm-configs     () { ls -1 $BASEDIR/*.yml | sort $1 | grep -v local; }
for-compose-configs   () { ls -1 $BASEDIR/*.yml | sort $1 | grep local; }

# virtual box information
virtual-box-host-ip   () { echo $LOCALHOST; }

# ensure preconditions 
# (ATTENTION: calls exit)
ensure_command_exists () { command -v $1 >&/dev/null || log_error_exit "Please install $1 first."; }
ensure_debian         () { grep ^ID.*debian /etc/os-release >& /dev/null || log_error_exit "This script is meant to be run on debian-like distributions." ; }
ensure_swarm_is_ready () {
    ensure_command_exists docker-machine
    swarm_prefixed_hosts | foreach docker-machine ls --filter name={} --format '{{ .State }}' | count Running | contains "^$SWARM_SIZE$" \
        || log_error_exit "Setup swarm nodes $(swarm_prefixed_hosts | to_string) and ensure they are running." 
    docker-machine use $(swarm_master)
    swarm_prefixed_hosts | foreach docker node ls --filter name={} --format '{{ .Status }}' | count Ready | contains "^$SWARM_SIZE$" \
        || log_error_exit "Ensure $(swarm_prefixed_hosts | to_string) are members of the swarm."
    docker-machine use --unset
}

# handling service stacks
stacks_manage () {
    [ -z "$2" ] || ! [[ "$1" =~ ^setup|remove$ ]] && { 
        log_usage "stacks_manage <setup|remove> <STACK_NAME> [force]" ; return 1
    }
    find -name $1.sh | sort | grep "$2" \
        | foreach bash -c "source common/helpers.sh; log_emphasize Calling: {} $3; {} $3"
}
stacks_list   () { find setups -name setup.sh | sed -re 's|^./\|/setup.sh||g'; }

## bash_completion
__stacks_manage () {
    local IFS=$'\n' WORD="${COMP_WORDS[$COMP_CWORD]}"
    [ "$COMP_CWORD" == 1 ] && {
        COMPREPLY=($(compgen -W "$(echo -e 'setup\nremove')"  -- "$WORD" ))
        return
    }
    [ "$COMP_CWORD" == 2 ] && {
        COMPREPLY=($(compgen -W "$(stacks_list)"  -- "$WORD" ))
        return
    }
    [ "$COMP_CWORD" == 3 ] && {
        COMPREPLY=($(compgen -W "$(echo 'force')"  -- "$WORD" ))
        return
    }
}
complete -o nosort -F __stacks_manage stacks_manage

__swarm_docker_auth () {
    local IFS=$'\n' WORD="${COMP_WORDS[$COMP_CWORD]}"
    [ "$COMP_CWORD" == 1 ] && {
        COMPREPLY=($(compgen -W "$(echo -e 'on\noff')"  -- "$WORD" ))
        return
    }
}
complete -o nosort -F __swarm_docker_auth swarm_docker_auth

# help interactive user
pnhelp () {
    grep -v ^[[:blank:]] common/helpers.sh \
        | grep -Ev '^[_\{\}A-Z]|complete|shopt|export|##' \
        | sed -re 's|\(\).*\|alias \|=.*||g'
}

# dummy svc logs
dummy_svc_logs () { swarm_prefixed_hosts | foreach-ssh docker ps \| grep dummy \| sed -re 's/.*dummy/dummy/' \| xargs -iXXX bash -c "'A=\"XXX\" ; docker logs \"XXX\" 2>&1 | sed -re \"s|(.*)|\$A: \\1|\"'" ; }
