# Status theme for zsh — which theme this shell shows, and following
# `statustheme use` in shells already open.  Sourced by zshrc; see
# ~/dotfiles/themes/README.md.
#
# A shell on a K4510 terminal gets the ASCII VT220 prompt whatever the
# machine's theme (JIM draws CP437, not Nerd Font icons).  Every other shell
# gets the active theme, and picks up a switch at its next prompt.

typeset -g _st_active=~/.config/statusthemes/active
typeset -g _st_vt220=~/dotfiles/themes/VT220.theme
typeset -g _st_k4510=0 _st_dir=
typeset -ga _st_precmd _st_preexec    # the hooks the loaded theme added

# The names the K4510 gives a host: TELNET offers XTERM-COLOR first, the `!`
# shell (and SSH through it) sets xterm-color.  Inside tmux TERM is tmux's
# own, so ask tmux what the attaching client is.
_st_term=$TERM
[[ -n $TMUX ]] && _st_term=$(tmux display-message -p -t "$TMUX_PANE" '#{client_termname}' 2>/dev/null)
[[ $_st_term == (xterm-color|vt100|vt220|ansi) ]] && _st_k4510=1
unset _st_term

# The theme this shell should show, in REPLY.
_st_resolve() {
  if (( _st_k4510 )); then
    REPLY=$_st_vt220
  elif [[ -e $_st_active/zsh.zsh ]]; then
    REPLY=${_st_active:A}
  else
    REPLY=~/dotfiles/themes/default
    REPLY=${REPLY:A}
  fi
}

# Source a theme's zsh.zsh, noting the hooks it adds so a switch can take
# them away again.
_st_load() {
  local -a pre=($precmd_functions) pex=($preexec_functions)
  _st_dir=$1
  source $1/zsh.zsh
  _st_precmd=(${precmd_functions:|pre})
  _st_preexec=(${preexec_functions:|pex})
}

# precmd: the active theme changed under this shell -> unload, load the new.
# The new theme's own precmd hooks were added too late for this round, so
# they are run here, each seeing the last command's status as it would.
_st_follow() {
  local st=$? f
  (( _st_k4510 )) && return
  _st_resolve
  [[ $REPLY == $_st_dir ]] && return
  (( $+functions[prompt_powerlevel9k_teardown] )) && prompt_powerlevel9k_teardown
  precmd_functions=(${precmd_functions:|_st_precmd})
  preexec_functions=(${preexec_functions:|_st_preexec})
  PROMPT='%# ' RPROMPT=
  _st_load $REPLY
  for f in $_st_precmd; do
    _st_status $st
    $f
  done
  return $st
}
_st_status() { return $1 }

_st_resolve
_st_dir=$REPLY
