#!/usr/bin/env bash
# Claude Code statusline — flat catppuccin-mocha style.
# See ~/dotfiles/STATUSLINES.md for design notes.
#
# Per-instance project label — priority order:
#   1. CLAUDE_LABEL env var (highest):
#        workas LuaLaTeX
#        CLAUDE_LABEL="LuaLaTeX" CLAUDE_ICON="󰈙" claude
#   2. .clauderc in the project tree:
#        echo 'LABEL=Homepage' > ~/containers/homepage/.clauderc
#   3. cwd basename matched against the icon lookup table
#   4. Raw cwd basename with generic folder icon

input=$(cat)

# Catppuccin-mocha palette (R;G;B for 24-bit ANSI)
THM_FG="205;214;244"       # text     — neutral label colour
THM_MAGENTA="203;166;247"  # mauve    — host
THM_PINK="245;194;231"     # pink     — project
THM_BLUE="137;180;250"     # blue     — context
THM_TEAL="148;226;213"     # teal     — distrobox
THM_YELLOW="249;226;175"   # yellow   — effort
THM_GREEN="166;227;161"    # green    — claude-code-plus

SEP=' · '

# seg <color_rgb> <icon> <text>
# Icon in its segment colour, label in neutral fg. Resets at the end.
seg() {
  local color="$1" icon="$2" text="$3"
  printf '\e[38;2;%sm%s\e[38;2;%sm %s\e[0m' "$color" "$icon" "$THM_FG" "$text"
}

# Tracks whether to emit a leading separator for subsequent segments.
_first=1
emit() {
  if [ "$_first" -eq 1 ]; then
    _first=0
  else
    printf '%s' "$SEP"
  fi
  seg "$@"
}

# Icon lookup table — keyed on lowercase label or directory basename.
icon_for() {
  local key
  key=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  case "$key" in
    lualatex|latex)          echo "󰈙" ;;
    homepage)                echo "󰋜" ;;
    jellyfin)                echo "󰎁" ;;
    immich)                  echo "󰉏" ;;
    paperless|paperless-ngx) echo "󱧶" ;;
    calibre|calibre-web)     echo "󰂺" ;;
    nextcloud)               echo "󰅧" ;;
    containers|docker)       echo "󰡨" ;;
    work)                    echo "󰢬" ;;
    backups|backup|bin)      echo "󰆍" ;;
    documents)               echo "󰈙" ;;
    *)                       echo "󰉋" ;;
  esac
}

# Resolve label and icon (four-tier priority — see header).
cwd_raw=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')

if [ -n "$CLAUDE_LABEL" ]; then
  LABEL="$CLAUDE_LABEL"
  ICON="${CLAUDE_ICON:-$(icon_for "$CLAUDE_LABEL")}"
else
  _proj_label=""
  _proj_icon=""
  _found_dir=""
  _dir="${cwd_raw:-$PWD}"
  while [ "$_dir" != "/" ]; do
    if [ -f "$_dir/.clauderc" ]; then
      _tmp_LABEL=""
      _tmp_ICON=""
      while IFS='=' read -r _k _v; do
        case "$_k" in
          LABEL) _tmp_LABEL="$_v" ;;
          ICON)  _tmp_ICON="$_v"  ;;
        esac
      done < "$_dir/.clauderc"
      _proj_label="$_tmp_LABEL"
      _proj_icon="$_tmp_ICON"
      _found_dir="$_dir"
      break
    fi
    _dir=$(dirname "$_dir")
  done

  # Skip ~/.clauderc when cwd is a subdirectory — fall through to basename.
  if [ "$_found_dir" = "$HOME" ] && [ "${cwd_raw:-$PWD}" != "$HOME" ]; then
    _proj_label=""
    _proj_icon=""
  fi

  if [ -n "$_proj_label" ]; then
    LABEL="$_proj_label"
    ICON="${_proj_icon:-$(icon_for "$_proj_label")}"
  else
    LABEL=$(basename "$cwd_raw")
    ICON=$(icon_for "$LABEL")
  fi
fi

host=$(hostname -s)
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

emit "$THM_MAGENTA" "󰒋" "$host"
emit "$THM_PINK"    "$ICON" "$LABEL"

if [ -n "$CONTAINER_ID" ]; then
  emit "$THM_TEAL" "󰆧" "$CONTAINER_ID"
fi

if [ -n "$used" ]; then
  used_int=$(printf "%.0f" "$used")
  if   [ "$used_int" -ge 90 ]; then mood="😱"
  elif [ "$used_int" -ge 75 ]; then mood="😅"
  elif [ "$used_int" -ge 50 ]; then mood="🤔"
  elif [ "$used_int" -ge 25 ]; then mood="🙂"
  else                               mood="😌"
  fi
  emit "$THM_BLUE" "$mood" "${used_int}%"
fi

if [ -n "$CLAUDE_CODE_PLUS" ]; then
  emit "$THM_GREEN" "󰐅" "CCPlus"
fi

effort=$(echo "$input" | jq -r '(.effort | if type == "object" then .level else . end) // empty')
if [ -n "$effort" ]; then
  emit "$THM_YELLOW" "󰓅" "$effort"
fi
