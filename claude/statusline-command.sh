#!/usr/bin/env bash
# Claude Code status line — catppuccin mocha pill style (matches tmux)
#
# Per-instance project label — priority order:
#   1. CLAUDE_LABEL env var (highest — use workas() or inline):
#        workas LuaLaTeX
#        CLAUDE_LABEL="LuaLaTeX" CLAUDE_ICON="󰈙" claude
#   2. .clauderc file in the project tree (drop a file, zero shell setup):
#        echo 'LABEL=Homepage' > ~/containers/homepage/.clauderc
#   3. cwd basename matched against the icon lookup table
#   4. Raw cwd basename with generic folder icon (last resort)

input=$(cat)

# Catppuccin Mocha palette (R;G;B)
THM_BG="30;30;46"
THM_FG="205;214;244"
THM_GRAY="49;50;68"
THM_MAGENTA="203;166;247"  # host
THM_PINK="245;194;231"     # project
THM_BLUE="137;180;250"     # context
THM_TEAL="148;226;213"     # distrobox
THM_YELLOW="249;226;175"   # effort
THM_GREEN="166;227;161"    # claude-code-plus

# Powerline glyphs
L_CAP=$'\ue0b6'  # left rounded cap
R_CAP=$'\ue0b4'  # right rounded cap

pill() {
  local color="$1" icon="$2" text="$3"
  printf "\e[38;2;%sm\e[49m%s" "$color" "$L_CAP"
  printf "\e[48;2;%sm\e[38;2;%sm%s " "$color" "$THM_BG" "$icon"
  printf "\e[48;2;%sm\e[38;2;%sm %s" "$THM_GRAY" "$THM_FG" "$text"
  printf "\e[38;2;%sm\e[49m%s" "$THM_GRAY" "$R_CAP"
  printf "\e[0m"
}

# Icon lookup table — keyed on lowercase label or directory basename.
# Used when CLAUDE_ICON is not set. Add entries freely.
icon_for() {
  local key
  key=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  case "$key" in
    lualatex|latex)          echo "󰈙" ;;  # nf-md-file_document_edit
    homepage)                echo "󰋜" ;;  # nf-md-home
    jellyfin)                echo "󰎁" ;;  # nf-md-music_box_multiple
    immich)                  echo "󰉏" ;;  # nf-md-image_multiple
    paperless|paperless-ngx) echo "󱧶" ;;  # nf-md-file_cabinet
    calibre|calibre-web)     echo "󰂺" ;;  # nf-md-bookshelf
    nextcloud)               echo "󰅧" ;;  # nf-md-cloud
    containers|docker)       echo "󰡨" ;;  # nf-md-docker
    work)                    echo "󰢬" ;;  # nf-md-briefcase_lock
    backups|backup|bin)      echo "󰆍" ;;  # nf-md-backup_restore
    documents)               echo "󰈙" ;;  # nf-md-file_document_edit
    *)                       echo "󰉋" ;;  # nf-md-folder (default)
  esac
}

# Resolve label and icon — four-tier priority:
#   1. CLAUDE_LABEL env var (manual override, highest priority)
#   2. .clauderc file found by walking up from $PWD
#   3. cwd basename icon lookup table (smart fallback)
#   4. raw dirname (last resort, handled by icon_for's default case)
#
# .clauderc is a simple KEY=VALUE shell file, e.g.:
#   LABEL=Homepage
#   ICON=󰋜
# ICON is optional — omitting it falls through to the lookup table.

cwd_raw=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')

if [ -n "$CLAUDE_LABEL" ]; then
  # Tier 1: env var
  LABEL="$CLAUDE_LABEL"
  ICON="${CLAUDE_ICON:-$(icon_for "$CLAUDE_LABEL")}"
else
  # Tier 2: walk up from cwd looking for .clauderc
  _proj_label=""
  _proj_icon=""
  _dir="${cwd_raw:-$PWD}"
  while [ "$_dir" != "/" ]; do
    if [ -f "$_dir/.clauderc" ]; then
      # Source into local vars only — unset after to avoid polluting env
      _tmp_LABEL=""
      _tmp_ICON=""
      # Read the file safely without sourcing arbitrary code paths
      while IFS='=' read -r _k _v; do
        case "$_k" in
          LABEL) _tmp_LABEL="$_v" ;;
          ICON)  _tmp_ICON="$_v"  ;;
        esac
      done < "$_dir/.clauderc"
      _proj_label="$_tmp_LABEL"
      _proj_icon="$_tmp_ICON"
      break
    fi
    _dir=$(dirname "$_dir")
  done

  if [ -n "$_proj_label" ]; then
    # Tier 2 hit: use file values, fall back to lookup table for icon if absent
    LABEL="$_proj_label"
    ICON="${_proj_icon:-$(icon_for "$_proj_label")}"
  else
    # Tier 3/4: cwd basename + lookup table (generic folder if no match)
    LABEL=$(basename "$cwd_raw")
    ICON=$(icon_for "$LABEL")
  fi
fi

host=$(hostname -s)
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

printf " "
pill "$THM_MAGENTA" "󰒋" "$host"
printf " "
pill "$THM_PINK" "$ICON" "$LABEL"

if [ -n "$CONTAINER_ID" ]; then
  printf " "
  pill "$THM_TEAL" "󰆧" "$CONTAINER_ID"
fi

if [ -n "$used" ]; then
  used_int=$(printf "%.0f" "$used")
  if   [ "$used_int" -ge 90 ]; then mood="😱"
  elif [ "$used_int" -ge 75 ]; then mood="😅"
  elif [ "$used_int" -ge 50 ]; then mood="🤔"
  elif [ "$used_int" -ge 25 ]; then mood="🙂"
  else                               mood="😌"
  fi
  printf " "
  pill "$THM_BLUE" "$mood" "${used_int}%"
fi

if [ -n "$CLAUDE_CODE_PLUS" ]; then
  printf " "
  pill "$THM_GREEN" "󰐅" "CCPlus"
fi

effort=$(echo "$input" | jq -r '.effort // empty')
if [ -n "$effort" ]; then
  case "$effort" in
    low)    effort_icon="󰓅" ;;  # speedometer low
    medium) effort_icon="󰓅" ;;  # speedometer mid
    high)   effort_icon="󰓅" ;;  # speedometer high
    *)      effort_icon="󰓅" ;;
  esac
  printf " "
  pill "$THM_YELLOW" "$effort_icon" "$effort"
fi
