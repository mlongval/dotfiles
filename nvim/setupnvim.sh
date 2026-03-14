#!/bin/bash

# Define source and target directories
DOTFILES=~/dotfiles
VIM_DIR="$DOTFILES/vim"
NVIM_DIR="$DOTFILES/nvim"
CONFIG_DIR=~/.config/nvim

# Create target directories
mkdir -p "$NVIM_DIR"
#mkdir -p ~/.config

# Create symlinks from vim config to neovim config (relative, so they work across machines)
ln -sf ../vim/vimrc "$NVIM_DIR/init.vim"
ln -sf ../vim/functions.vim "$NVIM_DIR/functions.vim"

# Link the Neovim config directory to ~/.config
#ln -sf "$NVIM_DIR" "$CONFIG_DIR"

# Confirm result
echo "Symlinks created:"
echo "- Neovim init: $NVIM_DIR/init.vim -> $VIM_DIR/vimrc"
echo "- Neovim functions: $NVIM_DIR/functions.vim -> $VIM_DIR/functions.vim"
echo "- ~/.config/nvim -> $NVIM_DIR"

# Optional: install Plug for Neovim if not already present
if [ ! -f "$DOTFILES/vim/autoload/plug.vim" ]; then
  echo "Installing vim-plug..."
  curl -fLo "$DOTFILES/vim/autoload/plug.vim" --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

echo "Done. Launch Neovim with 'nvim' to verify."

