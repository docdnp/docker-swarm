# simple logging functions
log_error              () { printf "%-8s: " Error   ; echo -e "$@" ; }
log_warning            () { printf "%-8s: " Warning ; echo -e "$@" ; }
log_info               () { printf "%-8s: " Info    ; echo -e "$@" ; }
log_exec               () { printf "%-8s: " Execute ; echo -e "$@" ; }
log_usage              () { printf "%-8s: " Usage   ; echo -e "$@" ; }
log_error_exit         () { log_error "$@" ; exit 1; }
log_hline              () { echo "================================================================================"; }
log_emphasize          () { log_hline; echo -e "$@"; log_hline; }
