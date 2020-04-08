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
alias sd='ssh -o ServerAliveInterval=60 kovas.c.googlers.com'

# faster google certification
alias gcert='gcert; ssh kovas.c.googlers.com prodaccess'

# kitty terminal aliases
alias icat='kitty +kitten icat'

# Faster mercurial startup time (see https://www.mercurial-scm.org/wiki/CHg)
alias hg='chg'

gp() {
    git add -u
    git commit -m "$1"
    git push
}

