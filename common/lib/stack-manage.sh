source common/lib/pipeable-loops.sh

# -----------------------
# handling service stacks
_stacks_manage () {
    [ "$1" == "ls" ] && {

        docker stack ls 2>/dev/null | grep -v NAME | awk '{print $1}' \
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
        _stacks_manage remove "$basedir" "$composefile" || return 1
        _stacks_manage setup  "$basedir" "$composefile" || return 1
        return 0
    }
    find setups -name $1.sh | sort | grep "$basedir" \
        | foreach bash -c "source common/lib/private/helpers.sh; log_emphasize Calling: {} $composefile $3; {} $basedir $composefile $3" || return 1
    return 0
}
__stacks_list   () { local p='\1'; [ "$1" == / ] && p='\1\n\1/'; find setups -name setup.sh | sed -re 's|^./\|/setup.sh||g' -e 's|^(.*)$|'"$p"'|'; }

## bash_completion
__stacks_manage () {
    local IFS=$'\n' WORD="${COMP_WORDS[$COMP_CWORD]}" PWORD="${COMP_WORDS[$((COMP_CWORD-1))]}"

    [ "$COMP_CWORD" == 1 ] && {
        COMPREPLY=($(compgen -W "$(echo -e 'setup\nremove\nredeploy\nls')"  -- "$WORD" ))
        return
    }
    [ "$COMP_CWORD" == 2 ] && [[ "$PWORD" =~ ^ls$ ]] && return
    [ "$COMP_CWORD" == 2 ] && [[ "$PWORD" =~ ^remove|redeploy$ ]] && {
        local CANDIDATES="$(echo -e $(_stacks_manage ls) $(__stacks_list) | tr ' ' '\n')"
        COMPREPLY=($(compgen -W "$CANDIDATES"  -- "$WORD" ))
        return
    }

    [ "$COMP_CWORD" == 2 ] && [[ "$WORD" =~ /$ ]] && [ -e "$WORD/setup.sh" ] && {
        COMPREPLY=($(compgen -o default -W "$(find $(dirname $WORD) -name '*.yml')"  -- "$WORD" ))
        return
    }
    [ "$COMP_CWORD" == 2 ] && {
        COMPREPLY=($(compgen -W "$(__stacks_list)"  -- "$WORD" ))
        [ ${#COMPREPLY[@]} == 0 ] && [ -n "$(dirname $WORD)" ] && {
            COMPREPLY=($(compgen -o default -W "$(find $(dirname $WORD) -name '*.yml')"  -- "$WORD" ))
            return
        }
        [ ${#COMPREPLY[@]} == 1 ] && [ -e "${COMPREPLY[0]}"/setup.sh ] && 
            COMPREPLY=($(compgen -W "$(__stacks_list /)"  -- "$WORD" ))
        return
    }
    [ "$COMP_CWORD" == 3 ] && {
        COMPREPLY=($(compgen -W "$(echo 'force')"  -- "$WORD" ))
        return
    }
}
