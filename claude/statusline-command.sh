#!/usr/bin/env bash
# Claude Code status line — catppuccin mocha pill style (matches tmux)

input=$(cat)

# Catppuccin Mocha palette (R;G;B)
THM_BG="30;30;46"
THM_FG="205;214;244"
THM_GRAY="49;50;68"
THM_MAGENTA="203;166;247"  # host
THM_PINK="245;194;231"     # directory
THM_BLUE="137;180;250"     # context
THM_TEAL="148;226;213"    # distrobox

# Powerline glyphs
L_CAP=$'\ue0b6'  # left rounded cap
R_CAP=$'\ue0b4'  # right rounded cap

pill() {
  local color="$1" icon="$2" text="$3"
  # Left rounded cap: module color on transparent bg
  printf "\e[38;2;%sm\e[49m%s" "$color" "$L_CAP"
  # Icon area: module color bg, thm_bg fg
  printf "\e[48;2;%sm\e[38;2;%sm%s " "$color" "$THM_BG" "$icon"
  # Text area: thm_gray bg, thm_fg fg
  printf "\e[48;2;%sm\e[38;2;%sm %s" "$THM_GRAY" "$THM_FG" "$text"
  # Right rounded cap: thm_gray fg, transparent bg
  printf "\e[38;2;%sm\e[49m%s" "$THM_GRAY" "$R_CAP"
  printf "\e[0m"
}

host=$(hostname -s)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
cwd=$(echo "$cwd" | sed "s|^$HOME|~|")
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

printf " "
pill "$THM_MAGENTA" "󰒋" "$host"
printf " "
pill "$THM_PINK" "" "$cwd"

if [ -n "$CONTAINER_ID" ]; then
  printf " "
  pill "$THM_TEAL" "󰆧" "$CONTAINER_ID"
fi

if [ -n "$used" ]; then
  used_int=$(printf "%.0f" "$used")
  printf " "
  pill "$THM_BLUE" "󰾪" "${used_int}%"
fi
