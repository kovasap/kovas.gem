#!/bin/bash
#
# Bash aliases
#

# enable color support of ls and other commands
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

alias nv='nvim'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# useful history searching alias
alias hgrep='history | grep'

# common ssh aliases
alias sd='ssh -o ServerAliveInterval=60 mrc.sea.corp.google.com'


##################################
# GOOGLE SPECIFIC OPTIONS
##################################

if [ -d /google ]; then
  # go to citc clients
  alias cdg='cd /google/src/cloud/kovas'

  # open all changed files in fig citc client (wrt last submitted code)
  nvc() {
    # '\'' closes string, appends single quote, then opens string again
    # base_cl_cmd='hg log -r smart --template '\''{node}\n'\' | tail -1'
    base_cl_cmd='hg log -r p4base --template '\''{node}\n'\'
    # -O4 opens in 4 vertical split windows
    nv -O4 $(hg st -n --rev $(eval $base_cl_cmd) | sed 's/^google3\///')
  }


  alias hgw='watch --color -n 1 '\''hg xl --color always; echo; hg st --color always'\'

  # prompt for prodaccess if needed
  prodcertstatus --quiet || { printf '\nNeed to prodaccess...\n'; prodaccess; }

  export P4MERGE=vimdiff

  alias perfgate=/google/data/ro/teams/perfgate/perfgate
  alias build_copier=/google/data/ro/projects/build_copier/build_copier
  alias lljob=/google/data/ro/projects/latencylab/clt/bin/lljob
  g4d chamber_regression_replication
fi
