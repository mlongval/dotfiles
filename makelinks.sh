#!/bin/sh
set -e

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

# Init submodules (tpm, powerlevel10k, tmux plugins)
git -C "$DOTFILES" submodule update --init --recursive

# Ensure ~/.config exists
mkdir -p "$HOME/.config"

link() {
    ln -sf "$1" "$2"
    echo "  $2 -> $1"
}

echo "Linking dotfiles..."
link "$DOTFILES/bash/bash_aliases"      "$HOME/.bash_aliases"
link "$DOTFILES/bash/bash_functions"    "$HOME/.bash_functions"
link "$DOTFILES/bash/profile"           "$HOME/.bash_profile"
link "$DOTFILES/bash/bashrc"            "$HOME/.bashrc"
link "$DOTFILES/bash/bash_functions"    "$HOME/.functions"
link "$DOTFILES/bash/profile"           "$HOME/.profile"
link "$DOTFILES/tmux"                   "$HOME/.tmux"
link "$DOTFILES/tmux/tmux.conf"         "$HOME/.tmux.conf"
link "$DOTFILES/vim"                    "$HOME/.vim"
link "$DOTFILES/zsh/zshrc"             "$HOME/.zshrc"
link "$DOTFILES/tmux"                   "$HOME/.config/tmux"
link "$DOTFILES/nvim"                   "$HOME/.config/nvim"
link "$DOTFILES/ranger"                 "$HOME/.config/ranger"
link "$DOTFILES/p10k/p10k.zsh"           "$HOME/.p10k.zsh"

echo "Done."
