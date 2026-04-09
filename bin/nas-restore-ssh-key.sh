#!/usr/bin/env bash
# nas-restore-ssh-key.sh
# Self-healing script: ensures ubuntu-s1's SSH key is installed on the WD NAS (192.168.2.175)
# Runs on boot and can be triggered manually.
#
# The NAS does not persist /home/root/.ssh/authorized_keys across reboots.
# This script detects that and re-adds the key via password auth.
#
# Usage: nas-restore-ssh-key.sh [--force]
#   --force  Re-add key even if key auth already works

set -euo pipefail

NAS_HOST="192.168.2.175"
NAS_USER="sshd"
NAS_PASS="zgna3_@jvgxpRzce!XHYx"
PUB_KEY_FILE="$HOME/.ssh/id_ed25519.pub"
LOG_FILE="$HOME/logs/nas-restore-ssh-key.log"
FORCE="${1:-}"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

if [ ! -f "$PUB_KEY_FILE" ]; then
  log "ERROR: Public key not found at $PUB_KEY_FILE"
  exit 1
fi

PUB_KEY="$(cat "$PUB_KEY_FILE")"

# Test if key auth already works
if [ "$FORCE" != "--force" ]; then
  if ssh -o ConnectTimeout=10 -o IdentitiesOnly=yes -i "${PUB_KEY_FILE%.pub}" \
       -o BatchMode=yes "$NAS_USER@$NAS_HOST" 'exit' 2>/dev/null; then
    log "SSH key auth already working — nothing to do."
    exit 0
  fi
fi

log "SSH key auth failed — re-adding key via password auth..."

if ! command -v sshpass &>/dev/null; then
  log "ERROR: sshpass not installed. Run: sudo apt install sshpass"
  exit 1
fi

sshpass -p "$NAS_PASS" ssh \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=15 \
  "$NAS_USER@$NAS_HOST" "
    mkdir -p /home/root/.ssh &&
    chmod 700 /home/root/.ssh &&
    grep -qF '${PUB_KEY}' /home/root/.ssh/authorized_keys 2>/dev/null \
      || echo '${PUB_KEY}' >> /home/root/.ssh/authorized_keys &&
    chmod 600 /home/root/.ssh/authorized_keys &&
    echo 'Key added.'
"

# Verify
if ssh -o ConnectTimeout=10 -o IdentitiesOnly=yes -i "${PUB_KEY_FILE%.pub}" \
     -o BatchMode=yes "$NAS_USER@$NAS_HOST" 'exit' 2>/dev/null; then
  log "SUCCESS: SSH key auth restored."
else
  log "ERROR: Key was added but auth still failing. Check NAS sshd_config."
  exit 1
fi
