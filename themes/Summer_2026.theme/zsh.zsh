# Hand-built zsh prompt — flat catppuccin-mocha style.
# See ~/dotfiles/STATUSLINES.md for design notes.
#
# Visual language shared with tmux + claude statuslines:
#   - separator: " · " (overlay grey)
#   - palette:   catppuccin-mocha hex
#   - flags:     `+` modified, `!` readonly, `*` dirty
#   - rule:      color only when state matters

setopt PROMPT_SUBST
autoload -Uz add-zsh-hook

# -------- catppuccin-mocha palette ------------------------------------------
typeset -g _P_FG='#cdd6f4'       # text
typeset -g _P_DIM='#a6adc8'      # overlay1 — separator
typeset -g _P_PINK='#f5c2e7'     # project / cwd
typeset -g _P_MAUVE='#cba6f7'    # prompt char ok
typeset -g _P_BLUE='#89b4fa'     # host (unused here, kept for symmetry)
typeset -g _P_TEAL='#94e2d5'     # venv / distrobox
typeset -g _P_GREEN='#a6e3a1'    # git clean
typeset -g _P_YELLOW='#f9e2af'   # warn / sudo
typeset -g _P_RED='#f38ba8'      # error / dirty
typeset -g _P_PEACH='#fab387'    # git branch

typeset -g _P_SEP=" %F{$_P_DIM}·%f "

# -------- distro detection (one-shot at source time) ------------------------
typeset -g _P_DISTRO_ICON='' _P_DISTRO_COLOR=$_P_BLUE
if [[ -r /etc/os-release ]]; then
  _p_id=$(awk -F= '$1=="ID"{gsub(/"/,"",$2); print tolower($2)}' /etc/os-release)
  case "$_p_id" in
    fedora)             _P_DISTRO_ICON=''  ;;  # nf-linux-fedora
    ubuntu)             _P_DISTRO_ICON=''  ;;  # nf-linux-ubuntu
    debian)             _P_DISTRO_ICON=''  ;;
    arch|cachyos|endeavouros) _P_DISTRO_ICON='' ;;
    nixos)              _P_DISTRO_ICON=''  ;;
    *)                  _P_DISTRO_ICON=''  ;;  # nf-linux-tux
  esac
  unset _p_id
fi

# -------- captured state ----------------------------------------------------
typeset -g _P_LAST_EXIT=0
_p_capture_exit() { _P_LAST_EXIT=$? }
add-zsh-hook precmd _p_capture_exit

# Set terminal title to user@host:cwd so it stays correct after ssh disconnects.
_p_set_title() { print -Pn -- $'\e]0;%n@%m: %~\a' }
add-zsh-hook precmd _p_set_title

# -------- segments ----------------------------------------------------------
# Each _p_seg_* echoes the rendered segment or empty string. The assembler
# joins non-empty results with $_P_SEP.

_p_seg_distro() {
  [[ -n "$_P_DISTRO_ICON" ]] || return
  print -n -- "%F{$_P_DISTRO_COLOR}${_P_DISTRO_ICON}%f"
}

_p_seg_cwd() {
  # Last 2 path components, `…/` prefix when truncated. $HOME → `~`.
  local p="${PWD/#$HOME/~}"
  local short
  if [[ "$p" == "~" || "$p" == "/" ]]; then
    short="$p"
  else
    local parts=("${(@s:/:)p}")
    if (( ${#parts} > 2 )); then
      short="…/${parts[-2]}/${parts[-1]}"
    else
      short="$p"
    fi
  fi
  print -n -- "%F{$_P_PINK}󰉋%f %F{$_P_FG}${short}%f"
}

_p_seg_git() {
  # Resolve branch (or short SHA when detached). Bail when not in a repo.
  local branch
  branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) \
    || branch=$(git rev-parse --short HEAD 2>/dev/null) \
    || return

  # Dirty = any staged, unstaged, or untracked change. Single `*` flag,
  # yellow when dirty, green when clean. One `git status` call, parsed in
  # the shell — no extra forks.
  local dirty_flag='' dirty_color=$_P_GREEN
  local status_out
  status_out=$(git status --porcelain 2>/dev/null)
  if [[ -n "$status_out" ]]; then
    dirty_flag='*'
    dirty_color=$_P_YELLOW
  fi

  print -n -- "%F{$_P_PEACH}%f %F{$dirty_color}${branch}${dirty_flag}%f"
}

_p_seg_venv() {
  [[ -n "$VIRTUAL_ENV" ]] || return
  print -n -- "%F{$_P_TEAL}%f %F{$_P_FG}${VIRTUAL_ENV:t}%f"
}

_p_seg_sudo() {
  [[ -f /etc/sudoers.d/doc-nopasswd ]] || return
  print -n -- "%F{$_P_YELLOW}󰌿%f"
}

_p_seg_exit() {
  (( _P_LAST_EXIT == 0 )) && return
  print -n -- "%F{$_P_RED}✗ ${_P_LAST_EXIT}%f"
}

# -------- assembler ---------------------------------------------------------
_p_build() {
  local -a segs out
  segs=(distro cwd git venv sudo exit)
  local s rendered
  for s in $segs; do
    rendered=$(_p_seg_$s)
    [[ -n "$rendered" ]] && out+=("$rendered")
  done
  local IFS=
  print -n -- "${(pj.$_P_SEP.)out}"
}

# -------- prompt ------------------------------------------------------------
# Line 1: blank — vertical breathing room between commands.
# Line 2: assembled segments.
# Line 3: prompt char, mauve when last command ok, red when failed.
PROMPT='
  $(_p_build)
  %(?.%F{'$_P_MAUVE'}.%F{'$_P_RED'})❯%f '

RPROMPT=''
