#!/usr/bin/env sh
# Install Ghostty and the CLI tools ranger's image/PDF preview needs
# (chafa, poppler-utils) via the host's native package manager.
# Idempotent — safe to re-run; each branch skips what's already there.
set -e

have() { command -v "$1" >/dev/null 2>&1; }

install_linux_native() {
    # shellcheck disable=SC1091
    . /etc/os-release
    case "$ID" in
        fedora)
            sudo dnf install -y ghostty chafa poppler-utils
            ;;
        ubuntu|debian|pop)
            sudo apt-get update
            sudo apt-get install -y chafa poppler-utils
            if ! have flatpak; then
                echo "No flatpak found — install it (sudo apt-get install -y flatpak) to get" \
                     "Ghostty on $ID, or see https://ghostty.org/docs/install for other options."
                return 1
            fi
            flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
            flatpak list --app 2>/dev/null | grep -q com.mitchellh.ghostty \
                || flatpak install -y flathub com.mitchellh.ghostty
            ;;
        arch|endeavouros|manjaro)
            sudo pacman -S --needed --noconfirm ghostty chafa poppler
            ;;
        *)
            echo "Don't know how to install Ghostty on '$ID' — see https://ghostty.org/docs/install"
            return 1
            ;;
    esac
}

install_macos() {
    have brew || { echo "Homebrew not found — install it first (see README.md)."; return 1; }
    for pkg in chafa poppler; do
        brew list "$pkg" >/dev/null 2>&1 || brew install "$pkg"
    done
    brew list --cask ghostty >/dev/null 2>&1 || brew install --cask ghostty
}

case "$(uname -s)" in
    Darwin) install_macos ;;
    Linux)  install_linux_native ;;
    *) echo "Unsupported OS: $(uname -s)"; exit 1 ;;
esac

echo "Done."
have ghostty && ghostty --version | head -1
