# wrappers and aliases

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
