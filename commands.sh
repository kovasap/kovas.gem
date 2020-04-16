#!/bin/bash
#
# Commands to execute before ProfileGem finishes loading.
#
# Executed last, and only included in interactive terminals.
#


# --- MISC ---
# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize
# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"
# setup bash completions
if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
      . /etc/bash_completion
fi


# --- COMMAND HISTORY ---
# make history infinite
HISTSIZE= 
HISTFILESIZE=
# ignore duplicate commands in history
export HISTCONTROL=ignoreboth:erasedups
# always give option to edit history commands before executing them
shopt -s histverify
# this code makes it so that commands are appended to history right after
# execution, so that new shells will always have the most up to date history
# possible
# see
# https://unix.stackexchange.com/questions/1288/preserve-bash-history-in-multiple-terminal-windows
# for more detail
_bash_history_sync() {
  builtin history -a
  python3 ~/filter_history.py
  HISTFILESIZE=$HISTSIZE
  # uncomment these to make existing shells sync with each other (as opposed to
  # just new shells syncing with all currently open ones)
  # builtin history -c
  # builtin history -r
}
history() {
  _bash_history_sync
  builtin history "$@"
}
PROMPT_COMMAND+="_bash_history_sync;$PROMPT_COMMAND"
# on startup, write bash history to backup file, in case any problems arise
python3 ~/filter_history.py ~/.bash_history.bak &


# --- VI MODE ---
# use vi mode for command line editing
set -o vi
# when in vi command mode, yy will copy the current line to the clipboard
_xyank() {
  echo "$READLINE_LINE" | xclip -selection clipboard
}
bind -m vi -x '"yy": _xyank'


# --- FZF ---
source ~/.fzf/shell/completion.bash
# browse chrome history with fzf (see
# https://junegunn.kr/2015/04/browsing-chrome-history-with-fzf/)
ch() {
  local cols sep
  cols=$(( COLUMNS / 3 ))
  sep='{::}'

  cp -rf .config/google-chrome/Default/History /tmp/ch

  sqlite3 -separator $sep /tmp/ch \
    "select substr(title, 1, $cols), url
     from urls order by last_visit_time desc" |
  awk -F $sep '{printf "%-'$cols's  \x1b[36m%s\x1b[m\n", $1, $2}' |
  fzf --ansi --multi | sed 's#.*\(https*://\)#\1#' | xargs xdg-open
  rm -r /tmp/ch
}

_fzf_complete_hg_up() {
  # Useful reference: http://hgbook.red-bean.com/read/customizing-the-output-of-mercurial.html
  _fzf_complete --multi --reverse --prompt="revs> " -- "$@" < <(
    # Get all cl descriptions that are not "unstable" (have 0 instabilities)
    hg heads --template '{instabilities|count} {desc|firstline} {node|short}\n' | awk '/^0/ {$1 = ""; print $0}'
  )
}

_fzf_complete_hg_up_post() {
  # Get last token, which is the hg "node" or revision hash
  awk -F" " '{print $NF}'
}

[ -n "$BASH" ] && complete -F _fzf_complete_hg_up -o default -o bashdefault hg up

__fzf_select__() {
  local cmd="${FZF_CTRL_T_COMMAND:-"command find -L . -mindepth 1 \\( -path '*/\\.*' -o -fstype 'sysfs' -o -fstype 'devfs' -o -fstype 'devtmpfs' -o -fstype 'proc' \\) -prune \
    -o -type f -print \
    -o -type d -print \
    -o -type l -print 2> /dev/null | cut -b3-"}"
  eval "$cmd" | FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} --reverse $FZF_DEFAULT_OPTS $FZF_CTRL_T_OPTS" fzf -m "$@" | while read -r item; do
    printf '%q ' "$item"
  done
  echo
}

if [[ $- =~ i ]]; then

__fzf_use_tmux__() {
  [ -n "$TMUX_PANE" ] && [ "${FZF_TMUX:-0}" != 0 ] && [ ${LINES:-40} -gt 15 ]
}

__fzfcmd() {
  __fzf_use_tmux__ &&
    echo "fzf-tmux -d${FZF_TMUX_HEIGHT:-40%}" || echo "fzf"
}

__fzf_select_tmux__() {
  local height
  height=${FZF_TMUX_HEIGHT:-40%}
  if [[ $height =~ %$ ]]; then
    height="-p ${height%\%}"
  else
    height="-l $height"
  fi

  tmux split-window $height "cd $(printf %q "$PWD"); FZF_DEFAULT_OPTS=$(printf %q "$FZF_DEFAULT_OPTS") PATH=$(printf %q "$PATH") FZF_CTRL_T_COMMAND=$(printf %q "$FZF_CTRL_T_COMMAND") FZF_CTRL_T_OPTS=$(printf %q "$FZF_CTRL_T_OPTS") bash -c 'source \"${BASH_SOURCE[0]}\"; RESULT=\"\$(__fzf_select__ --no-height)\"; tmux setb -b fzf \"\$RESULT\" \\; pasteb -b fzf -t $TMUX_PANE \\; deleteb -b fzf || tmux send-keys -t $TMUX_PANE \"\$RESULT\"'"
}

fzf-file-widget() {
  if __fzf_use_tmux__; then
    __fzf_select_tmux__
  else
    local selected="$(__fzf_select__)"
    READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}$selected${READLINE_LINE:$READLINE_POINT}"
    READLINE_POINT=$(( READLINE_POINT + ${#selected} ))
  fi
}

__fzf_cd__() {
  local cmd dir
  cmd="${FZF_ALT_C_COMMAND:-"command find -L . -mindepth 1 \\( -path '*/\\.*' -o -fstype 'sysfs' -o -fstype 'devfs' -o -fstype 'devtmpfs' -o -fstype 'proc' \\) -prune \
    -o -type d -print 2> /dev/null | cut -b3-"}"
  dir=$(eval "$cmd" | FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} --reverse $FZF_DEFAULT_OPTS $FZF_ALT_C_OPTS" $(__fzfcmd) +m) && printf 'cd %q' "$dir"
}

__fzf_history__() {
  local output
  output=$(
    builtin fc -lnr -2147483648 |
      last_hist=$(HISTTIMEFORMAT='' builtin history 1) perl -p -l0 -e 'BEGIN { getc; $/ = "\n\t"; $HISTCMD = $ENV{last_hist} + 1 } s/^[ *]//; $_ = $HISTCMD - $. . "\t$_"' |
      FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} $FZF_DEFAULT_OPTS --tiebreak=index --bind=ctrl-r:toggle-sort $FZF_CTRL_R_OPTS +m --read0" $(__fzfcmd) --query "$READLINE_LINE"
  ) || return
  READLINE_LINE=${output#*$'\t'}
  if [ -z "$READLINE_POINT" ]; then
    echo "$READLINE_LINE"
  else
    READLINE_POINT=0x7fffffff
  fi
}

# Required to refresh the prompt after fzf
bind -m emacs-standard '"\er": redraw-current-line'

bind -m vi-command '"\C-z": emacs-editing-mode'
bind -m vi-insert '"\C-z": emacs-editing-mode'
bind -m emacs-standard '"\C-z": vi-editing-mode'

if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
  # CTRL-T - Paste the selected file path into the command line
  if __fzf_use_tmux__; then
    bind -m emacs-standard '"\C-t": " \C-b\C-k \C-u`__fzf_select_tmux__`\e\C-e\C-a\C-y\C-h\C-e\e \C-y\ey\C-x\C-x\C-f"'
  else
    bind -m emacs-standard '"\C-t": " \C-b\C-k \C-u`__fzf_select__`\e\C-e\er\C-a\C-y\C-h\C-e\e \C-y\ey\C-x\C-x\C-f"'
  fi
  bind -m vi-command '"\C-t": "\C-z\C-t\C-z"'
  bind -m vi-insert '"\C-t": "\C-z\C-t\C-z"'

  # CTRL-R - Paste the selected command from history into the command line
  bind -m emacs-standard '"\C-r": "\C-e \C-u\C-y\ey\C-u"$(__fzf_history__)"\e\C-e\er"'
  bind -m vi-command '"\C-r": "\C-z\C-r\C-z"'
  bind -m vi-insert '"\C-r": "\C-z\C-r\C-z"'
else
  # CTRL-T - Paste the selected file path into the command line
  bind -m emacs-standard -x '"\C-t": fzf-file-widget'
  bind -m vi-command -x '"\C-t": fzf-file-widget'
  bind -m vi-insert -x '"\C-t": fzf-file-widget'

  # CTRL-R - Paste the selected command from history into the command line
  bind -m emacs-standard -x '"\C-r": __fzf_history__'
  bind -m vi-command -x '"\C-r": __fzf_history__'
  bind -m vi-insert -x '"\C-r": __fzf_history__'
fi

# ALT-C - cd into the selected directory
bind -m emacs-standard '"\ec": " \C-b\C-k \C-u`__fzf_cd__`\e\C-e\er\C-m\C-y\C-h\e \C-y\ey\C-x\C-x\C-d"'
bind -m vi-command '"\ec": "\C-z\ec\C-z"'
bind -m vi-insert '"\ec": "\C-z\ec\C-z"'

fi


# --- Python ---
export WORKON_HOME=$HOME/.virtualenvs
export PROJECT_HOME=$HOME
export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python3
source /usr/share/virtualenvwrapper/virtualenvwrapper.sh


# --- Kitty ---
# kitty ssh fix (if kitty is installed)
if [ -x "$(which kitty)" ]; then
  alias ssh='kitty +kitten ssh'
fi


# --- X ---
# useful tip about dmenu since starting last month, I've noticed that dmenu is
# often very slow to start. From reading /var/log/apt/history.log and
# /var/log/dpkg.log, it seems like some apt or dpkg command is automatically run
# between 30 and 100 times per day - some significant percent of those modify
# binaries. dmenu keeps a cache and, if any directory in your path has changed
# since that file was last written, it updates the cache at that time. You can
# read the dmenu_path script to see the details.  so, the trivial solution is
# just to run dmenu_path after every dpkg invocation. Run this to tell dpkg to
# to update your dmenu cache every time something installs a package.
#
# echo "post-invoke='sudo -u $USER dmenu_path > /dev/null'" > /etc/dpkg/dpkg.cfg.d/dmenu-path-update-hook
#
# That seems to have solved the problem for me. Some sort of inotify watch would
# be more thorough as it would catch changes due to reasons other than package
# installs, so if you heavily use (e.g.) hackage, you may want that. This has
# been good enough for me lately.


# --- PROMPT.GEM CONFIGURATION ---
virtualenv_prompt() {
  if [[ $VIRTUAL_ENV != "" ]]; then
    # Strip out the path and just leave the env name
    echo "(${VIRTUAL_ENV##*/})"
  fi
}
# find the first .hg or .git directory looking backward from the current dir
_find_hggit_repo() {
  local dir
  dir=$PWD
  while [[ "$dir" != "/" ]]
  do
    [[ -e "$dir/.git" ]] && echo "${dir}+git" && return
    [[ -e "$dir/.hg" ]] && echo "${dir}+hg" && return
    dir="$(dirname "$dir")"
  done
  return 1
}
# Prints the current branch, colored by status, of a Mercurial/Git repo
vc_prompt() {
  local repo vc vc_and_repo
  if [[ $(pwd) == /google/src/cloud* ]]; then
    vc="hg"
    cd /google/src/cloud/kovas/chamber_regression_replication || return
  else
    vc_and_repo=$(_find_hggit_repo) || return 0
    repo=$(echo $vc_and_repo | cut -f1 -d+)
    vc=$(echo $vc_and_repo | cut -f2 -d+)
    cd "$repo" || return # so Mercurial/git don't have to do the same find we just did
  fi
  if [[ "$vc" == "hg" ]]; then
    local branch num_heads heads
    branch=$(hg branch 2> /dev/null) || return 0
    num_heads=$(hg heads --template '{rev} ' 2> /dev/null | wc -w) || return 0
    if (( num_heads > 1 )); then
      heads='*'
    fi

    local color=GREEN
    if [[ -n "$(hg stat --modified --added --removed --deleted)" ]]; then
      color=LRED
    elif [[ -n "$(hg stat --unknown)" ]]; then
      color=PURPLE
    fi
    printf "hg:$(pcolor $color)%s%s$(pcolor)" "$branch" "$heads"
  elif [[ "$vc" == "git" ]]; then
    local label
    # http://stackoverflow.com/a/12142066/113632
    label=$(git rev-parse --abbrev-ref HEAD 2> /dev/null) || return 0
    if [[ "$label" == "HEAD" ]]; then
      # http://stackoverflow.com/a/18660163/113632
      label=$(git describe --tags --exact-match 2> /dev/null)
    fi

    local color
    local status
    status=$(git status --porcelain | cut -c1-2)
    if [[ -z "$status" ]]; then
      color=GREEN
    elif echo "$status" | cut -c2 | grep -vq -e ' ' -e '?'; then
      color=RED # unstaged
    elif echo "$status" | cut -c1 | grep -vq -e ' ' -e '?'; then
      color=YELLOW # staged
    elif echo "$status" | grep -q '?'; then
      color=PURPLE # untracked
    fi
    printf "git:$(pcolor $color)%s$(pcolor)" "$label"
  fi
  cd - > /dev/null
} && bc::cache vc_prompt PWD

ENV_INFO+=("time_prompt" "virtualenv_prompt" "vc_prompt")
HOST_COLOR="GREEN BOLD"

