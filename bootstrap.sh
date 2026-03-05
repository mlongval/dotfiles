#!/usr/bin/env bash
set -e

GITHUB_USER="mlongval"
DOTFILES_REPO="git@github.com:$GITHUB_USER/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"
SSH_KEY="$HOME/.ssh/id_ed25519"

echo "==> Checking for SSH key..."
if [ ! -f "$SSH_KEY" ]; then
    ssh-keygen -t ed25519 -f "$SSH_KEY" -N ""
    echo "    Created $SSH_KEY"
else
    echo "    Found existing $SSH_KEY"
fi

echo "==> Checking for brew..."
if ! command -v brew &>/dev/null; then
    echo "    Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

echo "==> Checking for gh CLI..."
if ! command -v gh &>/dev/null; then
    brew install gh
fi

echo "==> Logging into GitHub (follow the prompts)..."
gh auth login -h github.com -p ssh || true
gh auth refresh -h github.com -s admin:public_key || true

echo "==> Uploading SSH key to GitHub..."
MACHINE_NAME="${1:-$(hostname)}"
gh ssh-key add "$SSH_KEY.pub" --title "$MACHINE_NAME" || echo "    Key may already be uploaded, continuing..."

echo "==> Starting SSH agent..."
eval "$(ssh-agent -s)" > /dev/null
ssh-add "$SSH_KEY"

echo "==> Testing GitHub SSH connection..."
ssh -T git@github.com 2>&1 || true

echo "==> Cloning dotfiles..."
if [ -d "$DOTFILES_DIR" ]; then
    echo "    $DOTFILES_DIR already exists, pulling latest..."
    git -C "$DOTFILES_DIR" pull
else
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

echo "==> Running makelinks..."
bash "$DOTFILES_DIR/makelinks.sh"

echo ""
echo "Done! Open a new shell to load your config."
