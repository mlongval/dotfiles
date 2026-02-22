# dotfiles

Personal configuration files for zsh, tmux, vim, nvim, and ranger.

## Installation

```sh
git clone --recurse-submodules <your-repo-url> ~/dotfiles
~/dotfiles/makelinks.sh
```

`makelinks.sh` will initialise all submodules and symlink every config file into place. It is safe to re-run on an existing machine.

## Contents

| Path | Config for |
|------|-----------|
| `zsh/zshrc` | zsh |
| `bash/` | bash aliases, functions, profile |
| `tmux/tmux.conf` | tmux (plugins via TPM) |
| `nvim/` | Neovim |
| `vim/` | Vim |
| `ranger/` | ranger file manager |
| `powerlevel10k/` | p10k prompt theme (submodule) |
| `tmux/plugins/tpm` | Tmux Plugin Manager (submodule) |

## Tmux plugins

Plugins are managed by [TPM](https://github.com/tmux-plugins/tpm) and tracked as git submodules. After `makelinks.sh` runs they are already present — no need to install them manually. To update plugins inside a tmux session: `prefix + U`.
