# -----------------------
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
    __swarm_prefixed_hosts | foreach docker-machine ls --filter name={} --format '{{ .State }}' | count Running | contains "^$SWARM_SIZE$" \
        || log_error_exit "Setup swarm nodes $(__swarm_prefixed_hosts | to_string) and ensure they are running." 
    docker-machine use $(swarm_master)
    __swarm_prefixed_hosts \
        | foreach docker node ls --filter name={} --format '{{ .Status }}' | count Ready | contains "^$SWARM_SIZE$" \
        || { docker-machine active | grep $SWARM_NODE_PREFIX-node \
              || log_error_exit "Ensure having a cluster node activated, e.g.: docker-machine set $(swarm_master)"
           }  || log_error_exit "Ensure $(__swarm_prefixed_hosts | to_string) are members of the swarm."
           
    docker-machine use --unset
}
