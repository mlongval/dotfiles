#!/usr/bin/env bash
# Claude Code statusline — hands off to the active status theme's script.
# Switch themes with `statustheme use <Name>`; see ~/dotfiles/themes/README.md.
DOTFILES="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
theme="${XDG_CONFIG_HOME:-$HOME/.config}/statusthemes/active"
[ -e "$theme/claude-statusline.sh" ] || theme="$DOTFILES/themes/default"
exec bash "$theme/claude-statusline.sh"
