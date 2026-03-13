#!/usr/bin/env bash
# Snapshot the current system state into the dotfiles repo.
# Run this periodically — especially before wiping a machine — to keep
# the repo current. Commit the results afterward.
#
# Usage: backup-system-state.sh [-n|--dry-run]
#
# Covers (per machine, written to snapshots/<hostname>/):
#   - Homebrew packages    → Brewfile
#   - Flatpak apps         → flatpaks.txt
#   - apt packages         → apt-packages.txt        (Debian/Ubuntu)
#   - rpm-ostree packages  → rpm-ostree-packages.txt (Bluefin/uBlue)
#   - dnf packages         → dnf-packages.txt        (plain Fedora)
#   - GNOME extensions     → gnome-extensions.txt
#   - GNOME settings       → dconf-backup.ini        (full dconf dump)

set -e

DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        -n|--dry-run) DRY_RUN=true ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
SNAPSHOT="$DOTFILES/snapshots/$(hostname)"

run() {
    # run <description> <output_file> <cmd> [args...]
    local desc="$1" outfile="$2"; shift 2
    echo "==> $desc"
    if $DRY_RUN; then
        echo "    [dry-run] would run: $*"
        echo "    [dry-run] would write to: $outfile"
        echo "    [dry-run] preview:"
        "$@" | sed 's/^/        /'
    else
        "$@" > "$outfile"
        echo "    Written to $(basename "$outfile")"
    fi
}

if $DRY_RUN; then
    echo "==> DRY RUN — no files will be written"
else
    mkdir -p "$SNAPSHOT"
fi
echo "==> Snapshotting $(hostname) into snapshots/$(hostname)/"

run "Homebrew packages..." "$SNAPSHOT/Brewfile" \
    brew bundle dump --force --file=/dev/stdout 2>/dev/null

run "Flatpak apps..." "$SNAPSHOT/flatpaks.txt" \
    flatpak list --app --columns=application

if command -v apt &>/dev/null; then
    run "apt packages..." "$SNAPSHOT/apt-packages.txt" \
        apt-mark showmanual
elif command -v rpm-ostree &>/dev/null; then
    run "rpm-ostree layered packages..." "$SNAPSHOT/rpm-ostree-packages.txt" \
        bash -c 'rpm-ostree status --json | python3 -c "
import json, sys
data = json.load(sys.stdin)
pkgs = data[\"deployments\"][0].get(\"requested-packages\", [])
print(\"\n\".join(pkgs))
"'
elif command -v dnf &>/dev/null; then
    run "dnf packages..." "$SNAPSHOT/dnf-packages.txt" \
        dnf repoquery --userinstalled --queryformat '%{name}'
fi

run "GNOME extensions..." "$SNAPSHOT/gnome-extensions.txt" \
    bash -c 'gnome-extensions list --enabled | sort'

run "GNOME settings (dconf)..." "$SNAPSHOT/dconf-backup.ini" \
    dconf dump /

echo ""
if $DRY_RUN; then
    echo "Dry run complete. No files were written."
else
    echo "Done. Review and commit:"
    echo "  git -C $DOTFILES diff --stat"
    echo "  git -C $DOTFILES add snapshots/$(hostname)/"
    echo "  git -C $DOTFILES commit -m 'chore: update system snapshot for $(hostname)'"
fi
