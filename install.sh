#!/bin/sh
set -e

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

# =============================================================================
# Requirements: brew, zsh, neovim
# =============================================================================

# Install Homebrew if missing
if ! command -v brew >/dev/null 2>&1; then
    echo "==> Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for the rest of this script
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

for pkg in zsh neovim; do
    if ! brew list "$pkg" >/dev/null 2>&1; then
        echo "==> Installing $pkg via brew..."
        brew install "$pkg"
    fi
done

# =============================================================================

# Init submodules (tpm, powerlevel10k, tmux plugins)
git -C "$DOTFILES" submodule update --init --recursive

link() {
    ln -sfn "$1" "$2"
    echo "  $2 -> $1"
}

# Ensure required directories exist
mkdir -p "$HOME/.config"
mkdir -p "$HOME/.local/share/nvim/site/autoload"
mkdir -p "$HOME/.claude/skills"
mkdir -p "$HOME/.claude/commands"
mkdir -p "$HOME/bin"

ln -sf "$DOTFILES/vim/autoload/plug.vim" "$HOME/.local/share/nvim/site/autoload/plug.vim"

echo "Linking dotfiles..."

# ~/bin — all executable scripts in dotfiles/bin
for script in "$DOTFILES/bin/"*; do
    [ -f "$script" ] && link "$script" "$HOME/bin/$(basename "$script")"
done

# Shell
link "$DOTFILES/bash/bash_aliases"   "$HOME/.bash_aliases"
link "$DOTFILES/bash/bash_functions" "$HOME/.bash_functions"
link "$DOTFILES/bash/profile"        "$HOME/.bash_profile"
link "$DOTFILES/bash/bashrc"         "$HOME/.bashrc"
link "$DOTFILES/bash/bash_functions" "$HOME/.functions"
link "$DOTFILES/bash/profile"        "$HOME/.profile"
link "$DOTFILES/zsh/zshrc"          "$HOME/.zshrc"
link "$DOTFILES/p10k/p10k.zsh"      "$HOME/.p10k.zsh"

# Tmux
link "$DOTFILES/tmux"           "$HOME/.tmux"
link "$DOTFILES/tmux/tmux.conf" "$HOME/.tmux.conf"
link "$DOTFILES/tmux"           "$HOME/.config/tmux"

# Editors
link "$DOTFILES/vim"  "$HOME/.vim"
link "$DOTFILES/nvim" "$HOME/.config/nvim"

# Other tools
link "$DOTFILES/ranger" "$HOME/.config/ranger"

# Fontconfig — alias Adwaita Mono to Nerd Font variant for glyph support
mkdir -p "$HOME/.config/fontconfig/conf.d"
link "$DOTFILES/fontconfig/conf.d/99-adwaita-nerd.conf" "$HOME/.config/fontconfig/conf.d/99-adwaita-nerd.conf"

# Download AdwaitaMono Nerd Font if not already installed
FONT_DIR="$HOME/.fonts/AdwaitaMono"
if [ ! -d "$FONT_DIR" ]; then
    echo "==> Downloading AdwaitaMono Nerd Font..."
    mkdir -p "$FONT_DIR"
    tmp=$(mktemp /tmp/AdwaitaMono.XXXXXX.zip)
    curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/AdwaitaMono.zip" -o "$tmp"
    unzip -q "$tmp" -d "$FONT_DIR"
    rm "$tmp"
    echo "  installed to $FONT_DIR"
else
    echo "  AdwaitaMono Nerd Font already installed, skipping"
fi
fc-cache -f "$HOME/.fonts"

# Foot terminal
mkdir -p "$HOME/.config/foot"
link "$DOTFILES/foot/foot.ini" "$HOME/.config/foot/foot.ini"

# Fastfetch
mkdir -p "$HOME/.config/fastfetch"

# Claude Code
mkdir -p "$HOME/.claude/hooks"
link "$DOTFILES/claude/statusline-command.sh"                  "$HOME/.claude/statusline-command.sh"
link "$DOTFILES/claude/settings.json"                          "$HOME/.claude/settings.json"
link "$DOTFILES/claude/settings.local.json"                    "$HOME/.claude/settings.local.json"
link "$DOTFILES/claude/hooks/auto-approve-allowed-commands.sh" "$HOME/.claude/hooks/auto-approve-allowed-commands.sh"
# Skills and commands — link each entry individually so ~/.claude/{skills,commands}
# can still hold non-tracked items (e.g. auto-memory files generated at runtime)
for skill_dir in "$DOTFILES/claude/skills/"*/; do
    [ -d "$skill_dir" ] && link "$skill_dir" "$HOME/.claude/skills/$(basename "$skill_dir")"
done
for cmd_file in "$DOTFILES/claude/commands/"*.md; do
    [ -f "$cmd_file" ] && link "$cmd_file" "$HOME/.claude/commands/$(basename "$cmd_file")"
done

# Install git post-merge hook so uv+pynvim stay current after git pull
HOOK="$DOTFILES/.git/hooks/post-merge"
cat > "$HOOK" <<'EOF'
#!/usr/bin/env bash
bash "$(git -C "$(dirname "$0")/../.." rev-parse --show-toplevel)/bin/setup-neovim-python.sh"
EOF
chmod +x "$HOOK"
echo "  post-merge hook installed"

echo "==> Setting up Neovim Python provider (uv + pynvim)..."
bash "$DOTFILES/bin/setup-neovim-python.sh"

echo "Done."
