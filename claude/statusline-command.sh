#!/usr/bin/env bash
# Claude Code statusline — hands off to the active status theme's script.
# Switch themes with `statustheme use <Name>`; see ~/dotfiles/themes/README.md.
# A K4510 terminal gets VT220's line whatever the theme, as zsh and tmux do
# (names as in zsh/statustheme.zsh; inside tmux, the client viewing the pane).
DOTFILES="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
theme="${XDG_CONFIG_HOME:-$HOME/.config}/statusthemes/active"
[ -e "$theme/claude-statusline.sh" ] || theme="$DOTFILES/themes/default"
# Through mosh every terminal is xterm-256color, so k4510-connect's marker,
# K4510_CLIENT=1, counts too: ours, or the tmux client's (2026-10-07).
term=$TERM k4510=$K4510_CLIENT
if [ -n "$TMUX" ]; then
    term=$(tmux display-message -p -t "$TMUX_PANE" '#{client_termname}' 2>/dev/null)
    pid=$(tmux display-message -p -t "$TMUX_PANE" '#{client_pid}' 2>/dev/null)
    k4510=; [ -n "$pid" ] && tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | grep -qx 'K4510_CLIENT=1' && k4510=1
fi
case $term in
    xterm-color|vt100|vt220|ansi) theme="$DOTFILES/themes/VT220.theme" ;;
esac
[ "$k4510" = 1 ] && theme="$DOTFILES/themes/VT220.theme"
exec bash "$theme/claude-statusline.sh"
