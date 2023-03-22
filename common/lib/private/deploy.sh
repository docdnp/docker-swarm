shopt -s expand_aliases

source common/lib/logging.sh
source common/lib/format-and-filters.sh
source common/lib/pipeable-loops.sh

# -----------------------
# setup and remove stacks and local compose deployments
# -----------------------

# loop compose files
__for_swarm_compose_loop () {
    local opt1="$1" opt2="$2" opt3="$3"
    [ -n "$opt2" ] && [ -n "$opt3" ] && { ls -1 "$BASEDIR/$opt3"; return; }
    [ -n "$opt1" ] && [ "$opt1" != -r ] && [ -n "$opt2" ] \
        && { ls -1 "$BASEDIR/$opt2"; return; }
    [ "$opt1" == -r ] || opt1=""
    ls -1 $BASEDIR/*.yml | sort $opt1
}
for-swarm-configs     () { __for_swarm_compose_loop "$@" | grep -v local; }
for-compose-configs   () { __for_swarm_compose_loop "$@" | grep local; }


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
