#!/usr/bin/env bash
# Claude Code statusline — ASCII, eight ANSI colours (see zsh.zsh here).
#
#   ubuntu-s1 | k4510 | ctx 42% | high
#
# Project label as in Summer_2026: CLAUDE_LABEL, else LABEL= from the nearest
# .clauderc (not ~/.clauderc below $HOME), else the cwd's basename.

input=$(cat)

SEP=' | '
_first=1
# emit <SGR, e.g. 32 or 1;7> <text>
emit() {
  [ "$_first" -eq 1 ] && _first=0 || printf '%s' "$SEP"
  printf '\e[%sm%s\e[0m' "$1" "$2"
}

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
cwd=${cwd:-$PWD}

LABEL=$CLAUDE_LABEL
if [ -z "$LABEL" ]; then
  d=$cwd
  while [ "$d" != "/" ]; do
    if [ -f "$d/.clauderc" ]; then
      if [ "$d" != "$HOME" ] || [ "$cwd" = "$HOME" ]; then
        LABEL=$(sed -n 's/^LABEL=//p' "$d/.clauderc" | head -1)
      fi
      break
    fi
    d=$(dirname "$d")
  done
fi
LABEL=${LABEL:-$(basename "$cwd")}

emit 32 "$(hostname -s)"
emit 36 "$LABEL"

[ -n "$CONTAINER_ID" ] && emit 35 "$CONTAINER_ID"

used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$used" ]; then
  used_int=$(printf "%.0f" "$used")
  if   [ "$used_int" -ge 75 ]; then c='1;7'   # reverse, not red: see zsh.zsh
  elif [ "$used_int" -ge 50 ]; then c=33
  else                               c=0
  fi
  emit "$c" "ctx ${used_int}%"
fi

[ -n "$CLAUDE_CODE_PLUS" ] && emit 32 "CCPlus"

effort=$(echo "$input" | jq -r '(.effort | if type == "object" then .level else . end) // empty')
[ -n "$effort" ] && emit 35 "$effort"
