## This file is intended to either be sourced in this project's scripts
## or directly by a user's bash.

BASEDIR="$(dirname $0)"
SWARM_NODE_PREFIX=${SWARM_NODE_PREFIX:-test}
SWARM_SIZE=${SWARM_SIZE:-3}
LOCALHOST=192.168.57.10
DOCKERAUTH=${DOCKERAUTH:-}

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
log_error              () { printf "%-8s: " Error   ; echo -e "$@" ; }
log_warning            () { printf "%-8s: " Warning ; echo -e "$@" ; }
log_info               () { printf "%-8s: " Info    ; echo -e "$@" ; }
log_exec               () { printf "%-8s: " Execute ; echo -e "$@" ; }
log_usage              () { printf "%-8s: " Usage   ; echo -e "$@" ; }
log_error_exit         () { log_error "$@" ; exit 1; }
log_hline              () { echo "================================================================================"; }
log_emphasize          () { log_hline; echo -e "$@"; log_hline; }

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
__for_swarm_compose_loop () {
    echo "[[[$@]]]" >> /tmp/XXX
    local opt1="$1" opt2="$2" opt3="$3"
    [ -n "$opt2" ] && [ -n "$opt3" ] && { ls -1 "$BASEDIR/$opt3"; return; }
    [ -n "$opt1" ] && [ "$opt1" != -r ] && [ -n "$opt2" ] \
        && { ls -1 "$BASEDIR/$opt2"; return; }
    echo "[[[OPT1: $opt1]]]" >> /tmp/XXX
    [ "$opt1" == -r ] || opt1=""
    ls -1 $BASEDIR/*.yml | sort $opt1 | tee -a /tmp/XXX
}
for-swarm-configs     () { __for_swarm_compose_loop "$@" | grep -v local; }
for-compose-configs   () { __for_swarm_compose_loop "$@" | grep local; }

# virtual box information
virtual-box-host-ip   () { echo $LOCALHOST; }

# ensure preconditions 
# (ATTENTION: calls exit)
ensure_command_exists () { 
 local action=install message="" log=log_error_exit
 local installed=$(command -v $1 >&/dev/null && echo true || echo false)
 
 [[ "$2" =~ ^(--)ensure-missing$ ]] \
  && action=remove log=log_error_exit \
  && message="Nothing to do. \"$1\" was found. Returning."
  
  $installed && {
    [ "$action" == remove ] \
        &&   message="Please remove \"$1\"." \
        || { message="OK. \"$1\" was found."; log=log_info; }
  } || {
    [ "$action" == remove ] \
        && { message="OK. \"$1\" wasn't found."; log=log_info; } \
        ||   message="Please install \"$1\"."
  }
  $log "$message"
}
    
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
    [ "$1" == "ls" ] && {
        docker stack ls | grep -v NAME | awk '{print $1}' \
            | sed -re 's/--.*//' | sort -u | foreach bash -c \
                "find setups -type f -name '*.sh' | grep {} >&/dev/null && echo {}"
        return
    }
    [ -z "$2" ] || ! [[ "$1" =~ ^setup|remove|redeploy$ ]] && { 
        log_usage "stacks_manage <setup|remove|redeploy> <STACK_NAME> [force]" ; return 1
    }
    local basedir="$2" composefile
    [ -f "$2" ] && basedir="$(dirname $2)" && composefile=$(basename "$2")
    [ "$1" == redeploy ] && {
        echo "Redeploying: $basedir $composefile"
        stacks_manage remove "$basedir" "$composefile" || return 1
        stacks_manage setup  "$basedir" "$composefile" || return 1
        return 0
    }
    find setups -name $1.sh | sort | grep "$basedir" \
        | foreach bash -c "source common/helpers.sh; log_emphasize Calling: {} $composefile $3; {} $basedir $composefile $3" || return 1
    return 0
}
stacks_list   () { local p='\1'; [ "$1" == / ] && p='\1\n\1/'; find setups -name setup.sh | sed -re 's|^./\|/setup.sh||g' -e 's|^(.*)$|'"$p"'|'; }

## bash_completion
__stacks_manage () {
    local IFS=$'\n' WORD="${COMP_WORDS[$COMP_CWORD]}" PWORD="${COMP_WORDS[$((COMP_CWORD-1))]}"
    {   echo " WORD: $WORD";
        echo "PWORD: $PWORD";
        echo "COMP_CWORD: $COMP_CWORD";
    } >> /tmp/XXX
    [ "$COMP_CWORD" == 1 ] && {
        COMPREPLY=($(compgen -W "$(echo -e 'setup\nremove\nredeploy\nls')"  -- "$WORD" ))
        return
    }
    [ "$COMP_CWORD" == 2 ] && [[ "$PWORD" =~ ^ls$ ]] && return
    [ "$COMP_CWORD" == 2 ] && [[ "$PWORD" =~ ^remove|redeploy$ ]] && {
        local CANDIDATES="$(echo -e $(stacks_manage ls) $(stacks_list) | tr ' ' '\n')"
        COMPREPLY=($(compgen -W "$CANDIDATES"  -- "$WORD" ))
        return
    }
    [ "$COMP_CWORD" == 2 ] && [[ "$WORD" =~ /$ ]] && [ -e "$WORD/setup.sh" ] && {
        COMPREPLY=($(compgen -o default -W "$(find $(dirname $WORD) -name '*.yml')"  -- "$WORD" ))
        return
    }
    [ "$COMP_CWORD" == 2 ] && {
        COMPREPLY=($(compgen -W "$(stacks_list)"  -- "$WORD" ))
        [ ${#COMPREPLY[@]} == 0 ] && [ -n "$(dirname $WORD)" ] && {
            COMPREPLY=($(compgen -o default -W "$(find $(dirname $WORD) -name '*.yml')"  -- "$WORD" ))
            return
        }
        [ ${#COMPREPLY[@]} == 1 ] && [ -e "${COMPREPLY[0]}"/setup.sh ] && 
            COMPREPLY=($(compgen -W "$(stacks_list /)"  -- "$WORD" ))
        return
    }
    [ "$COMP_CWORD" == 3 ] && [[ "$PWORD" =~ /$ ]] && {
        [[ "$PWORD" =~ /$ ]] && COMPREPLY=($(compgen -W "$(ls -1 $PWORD/)"  -- "$WORD" )) \
            || COMPREPLY=($(compgen -W "$(echo 'force')"  -- "$WORD" ))
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

# setup and remove stacks and local compose deployments
foreach-exec () {
    local A
    while read A; do 
        bash -c "echo \"Execute : $A\"; $A" || return 1
    done
}

__stacks_setup () {
 log_info Setting up swarm service stacks
 log_info triggered by: "$@"
 docker-machine use $(swarm_master)
 local PROJECT="$(basename $BASEDIR)" A
 for-swarm-configs "$@" \
     | foreach echo docker stack deploy $DOCKERAUTH -c {} \
             $PROJECT--$\(basename {} .yml \| sed -re "'s|^[0-9]+-\\\\|-.*||g'" \) \
         | foreach-exec
}

__compose_setup () {
 log_info Setting up local compose services
 log_info triggered by: "$@"
 docker-machine use $(swarm_master)
 local PROJECT="$(basename $BASEDIR)" A
 docker-machine use --unset
 for-compose-configs "$@" \
     | foreach echo "docker-compose -f {} up -d" \
            | foreach-exec
}


__remove-all-stacks () {
 docker-machine use $(swarm_master)
 local PROJECT="$(basename $BASEDIR)" A
 for-swarm-configs -r "$@" \
     | foreach echo docker stack rm \
         $PROJECT--\$\(basename {} .yml \| sed -re "'s|^[0-9]+-\\\\|-.*||g'" \) \
            | foreach-exec
}

__stacks_remove () {
    log_info Removing swarm service stacks
    log_info triggered by: "$@"
    for i in {1..10} ; do
        [ $i == 1 ] \
            || log_emphasize "WARN: Failed to remove stack... [RETRY ($i/10)]"
        __remove-all-stacks "$@" && return 0
        sleep $i
    done
    return 1
}

__compose_remove () {
    log_info Removing local compose services
    log_info triggered by: "$@"
    local PROJECT="$(basename $BASEDIR)"
    docker-machine use --unset
    for-compose-configs "$@" \
        | foreach echo "docker-compose -f {} down --remove-orphans" \
            | foreach-exec
}

project-setup () { 
    [ -n "$1" ] && [ -f "$1/$2" ] && BASEDIR=$1
    PROJECT="$(basename $BASEDIR)"
    log_info Setting up project: $PROJECT
    log_info triggered by: "$@"
    if __stacks_setup "$@" && __compose_setup "$@" ; then
        echo ; log_emphasize "SUCCESS : Stacks of \"$PROJECT\" were deployed sucessfully."
        return 0
    fi
    log_emphasize "FAIL    : Couldn't setup project: $PROJECT"
    return 1
}
project-remove () {
    [ -n "$1" ] && [ -f "$1/$2" ] && BASEDIR=$1
    PROJECT="$(basename $BASEDIR)"
    log_info Removing project: $PROJECT
    log_info triggered by: "$@"
    if __stacks_remove "$@" && __compose_remove "$@" ; then
        echo ; log_emphasize "SUCCESS: Stacks of \"$PROJECT\" were removed sucessfully."
        return 0
    fi
    log_emphasize "FAIL    : Couldn't remove project: $PROJECT"
    return 1
}