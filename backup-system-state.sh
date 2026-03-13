#!/usr/bin/env bash
# Snapshot the current system state into the dotfiles repo.
# Run this periodically — especially before wiping a machine — to keep
# the repo current. Commit the results afterward.
#
# Covers:
#   - Homebrew packages    → Brewfile
#   - Flatpak apps         → flatpaks.txt
#   - GNOME settings       → dconf-backup.ini  (includes extension configs)

set -e

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

echo "==> Homebrew packages..."
brew bundle dump --force --file="$DOTFILES/Brewfile"
echo "    Written to Brewfile"

echo "==> Flatpak apps..."
flatpak list --app --columns=application > "$DOTFILES/flatpaks.txt"
echo "    Written to flatpaks.txt"

echo "==> GNOME settings (dconf)..."
dconf dump / > "$DOTFILES/dconf-backup.ini"
echo "    Written to dconf-backup.ini"

echo ""
echo "Done. Review and commit:"
echo "  git -C $DOTFILES diff --stat"
echo "  git -C $DOTFILES add Brewfile flatpaks.txt dconf-backup.ini"
echo "  git -C $DOTFILES commit -m 'chore: update system state snapshot'"
