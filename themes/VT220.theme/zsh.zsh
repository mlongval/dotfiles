# VT220 — ASCII-only prompt for terminals with no UTF-8 and no Nerd Font
# (the K4510's JIM: a VT220 with colour, CP437 glyphs).  The eight ANSI
# colours plus bold, so it still reads on a monochrome VT220.
#
#   ubuntu-s1 .../K4510/guide-build/k4510 (master*) [1]
#   $
#
# Flags as in the other themes: `*` dirty tree, [n] the last exit code
# when it was not 0.  A failure shows in reverse video, not red: red on the
# K4510's blue is 1.3:1, and a muddy brown to protan eyes (Doc's).

setopt PROMPT_SUBST

_vt_git() {
  local b
  b=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) \
    || b=$(git rev-parse --short HEAD 2>/dev/null) \
    || return
  [[ -n $(git status --porcelain 2>/dev/null) ]] && b+='*'
  print -n -- " %F{yellow}(${b//\%/%%})%f"
}

_vt_venv() {
  [[ -n $VIRTUAL_ENV ]] || return
  print -n -- " %F{magenta}(${VIRTUAL_ENV:t})%f"
}

# Line 1: host, cwd (.../ and the last three parts when deeper), git, venv,
#         exit code.  Line 2: the prompt character.
PROMPT='%B%F{green}%m%f%b %F{cyan}%(4~|.../%3~|%~)%f$(_vt_git)$(_vt_venv)%(?.. %B%S[%?]%s%b)
%B%(!.#.$)%b '
RPROMPT=''
