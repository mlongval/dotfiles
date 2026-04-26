#!/usr/bin/env bash
# Installs uv and pynvim for the Neovim Python provider.
# Safe to run multiple times — skips steps already done.

set -e

# Install uv if missing
if ! command -v uv &>/dev/null; then
    echo "==> Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
else
    echo "==> uv already installed ($(uv --version))"
fi

# Install pynvim via uv if missing
if ! uv tool list 2>/dev/null | grep -q pynvim; then
    echo "==> Installing pynvim..."
    uv tool install pynvim
else
    echo "==> pynvim already installed"
fi

echo "==> Neovim Python provider ready."
