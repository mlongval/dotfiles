#!/bin/sh
set -e

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

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

# Foot terminal
mkdir -p "$HOME/.config/foot"
link "$DOTFILES/foot/foot.ini" "$HOME/.config/foot/foot.ini"

# Fastfetch
mkdir -p "$HOME/.config/fastfetch"
link "$DOTFILES/fastfetch/bluefin.jsonc"        "$HOME/.config/fastfetch/bluefin.jsonc"
link "$DOTFILES/fastfetch/ublue-fastfetch.json" "$HOME/.config/ublue-fastfetch.json"
touch "$HOME/.config/no-show-user-motd"

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
