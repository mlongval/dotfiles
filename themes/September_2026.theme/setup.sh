#!/usr/bin/env bash
# Run by `statustheme use` — installs what this theme needs, if missing.
set -euo pipefail

p10k="${XDG_DATA_HOME:-$HOME/.local/share}/powerlevel10k"
if [ ! -r "$p10k/powerlevel10k.zsh-theme" ] && [ ! -r "$HOME/dotfiles/powerlevel10k/powerlevel10k.zsh-theme" ]; then
    echo "==> Installing powerlevel10k to $p10k"
    git clone -q --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k"
fi

catppuccin="$HOME/.tmux/plugins/catppuccin-tmux"
if [ ! -d "$catppuccin" ]; then
    echo "==> Installing catppuccin-tmux to $catppuccin"
    git clone -q https://github.com/mlongval/catppuccin-tmux.git "$catppuccin"
fi
