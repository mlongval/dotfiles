#!/usr/bin/env bash
# Claude Code statusline — hands off to the active status theme's script.
# Switch themes with `statustheme use <Name>`; see ~/dotfiles/themes/README.md.
# A K4510 terminal gets VT220's line whatever the theme, as zsh and tmux do
# (names as in zsh/statustheme.zsh; inside tmux, the client viewing the pane).
DOTFILES="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
theme="${XDG_CONFIG_HOME:-$HOME/.config}/statusthemes/active"
[ -e "$theme/claude-statusline.sh" ] || theme="$DOTFILES/themes/default"
term=$TERM
[ -n "$TMUX" ] && term=$(tmux display-message -p -t "$TMUX_PANE" '#{client_termname}' 2>/dev/null)
case $term in
    xterm-color|vt100|vt220|ansi) theme="$DOTFILES/themes/VT220.theme" ;;
esac
exec bash "$theme/claude-statusline.sh"
