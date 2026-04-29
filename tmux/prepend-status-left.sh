#!/usr/bin/env bash
# Prepend one space to tmux status-left so the catppuccin bar aligns
# with the Claude Code statusline (which has 1 char of built-in left padding).
# Strip any previously-prepended spaces first so reloads don't accumulate.
current=$(tmux show-option -gv status-left 2>/dev/null)
current="${current#"${current%%[! ]*}"}"  # strip leading spaces
tmux set -g status-left " $current"
