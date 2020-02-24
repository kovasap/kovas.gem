#!/bin/bash
#
# Bash environment
#
# Configure environment variables here. Often these should be set based on
# variables defined in base.conf.sh so that users and other gems can configure
# the behavior of this file.
#

export PATH=$PATH:~/bin:~/.local/bin

# Make neovim the default editor for everything.
export VISUAL=nvim
export EDITOR=nvim


repo_title() {
   hg log -r . --template "{desc}" 2>/dev/null
   git config --local remote.origin.url|sed -n 's#.*/\([^.]*\)\.git#\1#p' 2>/dev/null
}

TITLE_INFO=(hostname_title repo_title)
