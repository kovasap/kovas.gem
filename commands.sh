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

export FZF_ALT_C_COMMAND='find . -printf "%P\\n"'
export FZF_CTRL_T_COMMAND='find . -printf "%P\\n"'

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

__fzf_history__() (
  local line
  shopt -u nocaseglob nocasematch
  line=$(
    HISTTIMEFORMAT= history |
    FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} $FZF_DEFAULT_OPTS --tac --sync -n2..,.. --tiebreak=index --bind=ctrl-r:toggle-sort $FZF_CTRL_R_OPTS +m" $(__fzfcmd) |
    command grep '^ *[0-9]') &&
    if [[ $- =~ H ]]; then
      sed 's/^ *\([0-9]*\)\** .*/!\1/' <<< "$line"
    else
      sed 's/^ *\([0-9]*\)\** *//' <<< "$line"
    fi
)

if [[ ! -o vi ]]; then
  # Required to refresh the prompt after fzf
  bind '"\er": redraw-current-line'
  bind '"\e^": history-expand-line'

  # CTRL-T - Paste the selected file path into the command line
  if [ $BASH_VERSINFO -gt 3 ]; then
    bind -x '"\C-t": "fzf-file-widget"'
  elif __fzf_use_tmux__; then
    bind '"\C-t": " \C-u \C-a\C-k`__fzf_select_tmux__`\e\C-e\C-y\C-a\C-d\C-y\ey\C-h"'
  else
    bind '"\C-t": " \C-u \C-a\C-k`__fzf_select__`\e\C-e\C-y\C-a\C-y\ey\C-h\C-e\er \C-h"'
  fi

  # CTRL-R - Paste the selected command from history into the command line
  bind '"\C-r": " \C-e\C-u\C-y\ey\C-u`__fzf_history__`\e\C-e\er\e^"'

  # ALT-C - cd into the selected directory
  bind '"\ec": " \C-e\C-u`__fzf_cd__`\e\C-e\er\C-m"'
else
  # We'd usually use "\e" to enter vi-movement-mode so we can do our magic,
  # but this incurs a very noticeable delay of a half second or so,
  # because many other commands start with "\e".
  # Instead, we bind an unused key, "\C-x\C-a",
  # to also enter vi-movement-mode,
  # and then use that thereafter.
  # (We imagine that "\C-x\C-a" is relatively unlikely to be in use.)
  bind '"\C-x\C-a": vi-movement-mode'

  bind '"\C-x\C-e": shell-expand-line'
  bind '"\C-x\C-r": redraw-current-line'
  bind '"\C-x^": history-expand-line'

  # CTRL-T - Paste the selected file path into the command line
  # - FIXME: Selected items are attached to the end regardless of cursor position
  if [ $BASH_VERSINFO -gt 3 ]; then
    bind -x '"\C-t": "fzf-file-widget"'
  elif __fzf_use_tmux__; then
    bind '"\C-t": "\C-x\C-a$a \C-x\C-addi`__fzf_select_tmux__`\C-x\C-e\C-x\C-a0P$xa"'
  else
    bind '"\C-t": "\C-x\C-a$a \C-x\C-addi`__fzf_select__`\C-x\C-e\C-x\C-a0Px$a \C-x\C-r\C-x\C-axa "'
  fi
  bind -m vi-command '"\C-t": "i\C-t"'

  # CTRL-R - Paste the selected command from history into the command line
  bind '"\C-r": "\C-x\C-addi`__fzf_history__`\C-x\C-e\C-x\C-r\C-x^\C-x\C-a$a"'
  bind -m vi-command '"/": "i\C-r"'

  # ALT-C - cd into the selected directory
  bind '"\ec": "\C-x\C-addi`__fzf_cd__`\C-x\C-e\C-x\C-r\C-m"'
  # bind -m vi-command '"c": "ddi`__fzf_cd__`\C-x\C-e\C-x\C-r\C-m"'
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
  # do not try to get repo status when in citc clients - is very slow!
  if [[ $(pwd) == /google/src/cloud* ]]; then
    return 0
  fi
  local repo vc vc_and_repo
  vc_and_repo=$(_find_hggit_repo) || return 0
  repo=$(echo $vc_and_repo | cut -f1 -d+)
  vc=$(echo $vc_and_repo | cut -f2 -d+)
  cd "$repo" || return # so Mercurial/git don't have to do the same find we just did
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

