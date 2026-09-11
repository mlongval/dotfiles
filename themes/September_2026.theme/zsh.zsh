# Powerlevel10k rainbow prompt (2 lines, round heads/tails).
# p10k.zsh next to this file is the wizard output; `p10k configure` rewrites
# ~/.p10k.zsh, so copy the result here if you re-run it.
_p10k_dir="${XDG_DATA_HOME:-$HOME/.local/share}/powerlevel10k"
[[ -r $_p10k_dir/powerlevel10k.zsh-theme ]] || _p10k_dir=~/dotfiles/powerlevel10k
if [[ -r $_p10k_dir/powerlevel10k.zsh-theme ]]; then
  source ${0:A:h}/p10k.zsh
  source $_p10k_dir/powerlevel10k.zsh-theme
else
  print -P "%F{yellow}statustheme: powerlevel10k not installed — run 'statustheme use September_2026'%f"
  PROMPT='%F{cyan}%~%f %# '
fi
unset _p10k_dir
