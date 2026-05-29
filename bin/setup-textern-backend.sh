#!/usr/bin/env bash
# setup-textern-backend.sh — install + verify the Textern native messaging host
# so a browser textbox can be edited in Neovim (inside Ptyxis), then show the
# Firefox preferences that must be entered by hand.
#
# Run-once / idempotent: succeeds at most once per machine. The success marker
# lives in ~/.local/state (XDG state) which is NOT synced via dotfiles — so one
# machine finishing never blocks the others. Auto-launched from a
# ~/.config/autostart entry; a no-op on headless machines (e.g. ubuntu-s1).
#
# Set TEXTERN_SETUP_NO_POPUP=1 to run everything but suppress the GUI dialog.
set -uo pipefail

REPO_URL="https://github.com/jlebon/textern"
HOST_PY="$HOME/.local/libexec/textern/textern.py"
MANIFEST="$HOME/.mozilla/native-messaging-hosts/textern.json"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"
SENTINEL="$STATE_DIR/textern-backend-setup.done"
LOG="$STATE_DIR/textern-backend-setup.log"

EDITOR_PREF='["ptyxis", "--standalone", "--maximize", "--", "nvim", "+call cursor(%l,%c)"]'
SHORTCUT_PREF="Ctrl+Shift+D"
EXT_PREF="md"

mkdir -p "$STATE_DIR"
log() { printf '%s [textern-setup] %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$LOG" >&2; }

# --- Guard 1: graphical session only (skips ubuntu-s1 / any headless box) ---
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ -z "${DISPLAY:-}" ]; then
    log "no graphical session detected; skipping."
    exit 0
fi

# --- Guard 2: already set up and the host is still in place ---
if [ -f "$SENTINEL" ] && [ -f "$HOST_PY" ] && [ -f "$MANIFEST" ]; then
    log "already done ($SENTINEL); nothing to do."
    exit 0
fi

log "starting setup on $(hostname)"

# --- Required build tools ---
for t in git make python3; do
    command -v "$t" >/dev/null 2>&1 || { log "FATAL: missing build tool '$t'"; exit 1; }
done

# --- Runtime deps: don't try sudo/dnf from a GUI session (would hang on a
#     password prompt); just note anything missing and surface it in the popup.
MISSING=""
for t in ptyxis nvim; do
    command -v "$t" >/dev/null 2>&1 || MISSING="$MISSING $t"
done

# --- Clone + install the native host ---
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
log "cloning $REPO_URL"
git clone --depth 1 "$REPO_URL" "$TMP/textern" >>"$LOG" 2>&1 \
    || { log "FATAL: git clone failed (see $LOG)"; exit 1; }
log "fetching submodule + running native-install"
git -C "$TMP/textern" submodule update --init >>"$LOG" 2>&1 \
    || { log "FATAL: submodule fetch failed"; exit 1; }
make -C "$TMP/textern" USER=1 native-install >>"$LOG" 2>&1 \
    || { log "FATAL: native-install failed"; exit 1; }

# --- Patch for Python 3.12+ (asyncio.get_event_loop no longer auto-creates a
#     loop when none is running). No-op once upstream ships a fix. ---
python3 - "$HOST_PY" <<'PY' >>"$LOG" 2>&1
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
needle = ("        loop = asyncio.get_event_loop()\n"
          "        loop.add_reader(sys.stdin.buffer, handle_stdin, tmp_mgr)")
repl = ("        loop = asyncio.new_event_loop()\n"
        "        asyncio.set_event_loop(loop)\n"
        "        loop.add_reader(sys.stdin.buffer, handle_stdin, tmp_mgr)")
if needle in s:
    open(p, "w", encoding="utf-8").write(s.replace(needle, repl, 1))
    print("patched textern.py for python 3.12+")
else:
    print("no asyncio patch needed")
PY

# --- Verify the host pipeline end to end (dummy non-interactive editor, no GUI
#     needed). Only a verified round-trip counts as success. ---
log "verifying host pipeline"
if python3 - "$HOST_PY" <<'PY' >>"$LOG" 2>&1
import json, struct, subprocess, sys, os, select, time
host = sys.argv[1]
editor = json.dumps(["bash", "-c", 'echo EDITED >> "$1"', "_"])
msg = {"type": "new_text", "payload": {"text": "x", "url": "https://example/",
       "caret": 0, "id": 1, "prefs": {"extension": "md", "editor": editor}}}
raw = json.dumps(msg).encode()
p = subprocess.Popen([sys.executable, host], stdin=subprocess.PIPE,
                     stdout=subprocess.PIPE, stderr=subprocess.PIPE)
p.stdin.write(struct.pack("@I", len(raw)) + raw); p.stdin.flush()
buf = b""; ok = False; end = time.time() + 5
while time.time() < end:
    r, _, _ = select.select([p.stdout], [], [], 0.4)
    if r:
        c = os.read(p.stdout.fileno(), 65536)
        if not c: break
        buf += c
        while len(buf) >= 4:
            n = struct.unpack("@I", buf[:4])[0]
            if len(buf) < 4 + n: break
            m = json.loads(buf[4:4+n]); buf = buf[4+n:]
            if m.get("type") == "text_update" and "EDITED" in m.get("payload", {}).get("text", ""):
                ok = True
p.terminate()
sys.exit(0 if ok else 1)
PY
then
    log "pipeline verified OK"
else
    log "FATAL: pipeline verification failed (see $LOG)"; exit 1
fi

# --- Mark success (machine-local; never synced) ---
{
    echo "host: $(hostname)"
    echo "date: $(date -Is)"
    echo "commit: $(git -C "$TMP/textern" rev-parse HEAD 2>/dev/null || echo unknown)"
} > "$SENTINEL"
log "wrote sentinel $SENTINEL"

# --- Show the Firefox prefs the user must enter by hand ---
WARN=""
if [ -n "$MISSING" ]; then
    WARN="

WARNING — missing on this machine:$MISSING
Install these or the editor won't actually launch."
fi
CLIP=""
if command -v wl-copy >/dev/null 2>&1 && printf '%s' "$EDITOR_PREF" | wl-copy 2>/dev/null; then
    CLIP=" (copied to clipboard)"
fi

BODY=$(cat <<EOF
The Textern native host is installed and verified on $(hostname).

In Firefox -> Add-ons -> Textern -> Preferences, set:

External editor$CLIP:
$EDITOR_PREF

Shortcut:            $SHORTCUT_PREF
Document extension:  $EXT_PREF

Then grant Textern site access if prompted, reload the page, click into a
textbox and press $SHORTCUT_PREF.$WARN
EOF
)

if [ -n "${TEXTERN_SETUP_NO_POPUP:-}" ]; then
    log "popup suppressed; info follows:"
    printf '%s\n' "$BODY" | tee -a "$LOG" >&2
elif command -v zenity >/dev/null 2>&1; then
    zenity --info --no-wrap --width=560 \
        --title="Textern to Neovim is ready" --text="$BODY" >/dev/null 2>&1 || true
elif command -v notify-send >/dev/null 2>&1; then
    notify-send "Textern to Neovim is ready" "$BODY"
    printf '%s\n' "$BODY" > "$HOME/textern-setup-info.txt"
else
    printf '%s\n' "$BODY" > "$HOME/textern-setup-info.txt"
fi

log "done"
