#!/usr/bin/env bash
# Install GNOME extensions listed in snapshots/<hostname>/gnome-extensions.txt
# via gnome-extensions-cli (gext). Idempotent — skips already-installed.
#
# Usage: restore-gnome-extensions.sh [hostname]
#   Defaults to the current hostname. Pass another snapshot dir name to
#   reuse another machine's extension set.

set -e

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
HOST="${1:-$(hostname)}"
LIST="$DOTFILES/snapshots/$HOST/gnome-extensions.txt"

if [ ! -f "$LIST" ]; then
    echo "==> No extensions snapshot at $LIST, skipping"
    exit 0
fi

if ! command -v gnome-extensions &>/dev/null; then
    echo "==> gnome-extensions not found (not a GNOME session?), skipping"
    exit 0
fi

if ! command -v gext &>/dev/null; then
    echo "==> gnome-extensions-cli (gext) not found."
    echo "    Install with: pipx install gnome-extensions-cli"
    echo "    Then re-run this script."
    exit 1
fi

echo "==> Restoring GNOME extensions from snapshots/$HOST/"
while IFS= read -r ext; do
    [ -z "$ext" ] && continue
    if gnome-extensions list | grep -qx "$ext"; then
        echo "  [skip] $ext (already installed)"
    else
        echo "  [install] $ext"
        gext install "$ext" || echo "    !! failed: $ext"
    fi
    gext enable "$ext" 2>/dev/null || true
done < "$LIST"

echo "==> Done. Log out/in (Wayland) or Alt+F2 → r (X11) to load extensions."
