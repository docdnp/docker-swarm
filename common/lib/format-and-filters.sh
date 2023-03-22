# -----------------------
# simple converters and filters
to_list               () { tr ' ' "\n" ; }
to_string             () { tr "\n" ' ' | sed 's/ $//'; }
to_or_rexp            () { tr ' ' "|"; }
contains              () { grep -E "$@" >&/dev/null; }
count                 () { grep -c "$@" ; }
