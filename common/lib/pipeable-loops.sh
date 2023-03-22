alias foreach="PATH=$PATH xargs -i"

foreach-ssh () { 
    local SLEEP=${1:-0}
    [[ "$SLEEP" =~ ^[0-9]+$ ]] \
        && shift \
        || SLEEP=0
    PATH=$PATH xargs -i \
        docker-machine ssh {} -- sleep $SLEEP \; "$@" ; 
}

foreach-exec () {
    local A
    while read A; do 
        bash -c "echo \"Execute : $A\"; $A" || return 1
    done
}
