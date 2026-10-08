#!/usr/bin/env bash
# The VT220 status bar for every tmux session a K4510 terminal is looking at,
# laid over the machine's theme as session options; taken away again when the
# session has no K4510 client left.  Each client has a session of its own
# (bin/tmux groups them), so the Dell keeps its bar while the K4510 has
# one ASCII row.  Run from tmux.conf: at load and on client hooks.
# K4510 terminals by name as in zsh/statustheme.zsh -- or, through mosh, which
# calls every terminal xterm-256color, by K4510_CLIENT=1 in the tmux client's
# environment (k4510-connect puts it there; 2026-10-07).
conf=~/dotfiles/themes/VT220.theme/tmux-post.conf
k4510=$(tmux list-clients -F '#{client_termname} #{client_pid} #{session_name}' |
        while read -r term pid sess; do
            case $term in xterm-color|vt100|vt220|ansi) echo "$sess"; continue ;; esac
            tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | grep -qx 'K4510_CLIENT=1' && echo "$sess"
        done)
opts=$(sed -n 's/^set -g \([a-z-]*\).*/\1/p' "$conf" | sort -u)
tmp=$(mktemp) && trap 'rm -f "$tmp"' EXIT
tmux list-sessions -F '#{session_name}' | while read -r s; do
    for o in $opts; do echo "set -u -t '=$s:' $o"; done
    grep -qxF -- "$s" <<<"$k4510" && sed -n "s/^set -g /set -t '=$s:' /p" "$conf"
done > "$tmp"
tmux source-file "$tmp"
