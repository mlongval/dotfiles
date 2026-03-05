# dotfiles

Personal configuration files for zsh, tmux, vim, nvim, and ranger.

## New machine setup

Paste this into a terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/mlongval/dotfiles/master/bootstrap.sh -o /tmp/bootstrap.sh && bash /tmp/bootstrap.sh "machine-name"
```

Replace `machine-name` with something descriptive (e.g. `laptop`, `work-pc`). The script will:

1. Create an SSH key if one doesn't exist
2. Install Homebrew and the `gh` CLI if needed
3. Walk you through GitHub login
4. Upload your SSH key to GitHub
5. Clone this repo to `~/dotfiles`
6. Run `makelinks.sh` to symlink everything into place

## Manual installation (if you already have GitHub SSH access)

```sh
git clone --recurse-submodules git@github.com:mlongval/dotfiles.git ~/dotfiles
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
| `vim/` | Vim (plugins managed by vim-plug, not tracked) |
| `ranger/` | ranger file manager |
| `powerlevel10k/` | p10k prompt theme (submodule) |
| `tmux/plugins/tpm` | Tmux Plugin Manager (submodule) |

## Tmux plugins

Plugins are managed by [TPM](https://github.com/tmux-plugins/tpm) and tracked as git submodules. After `makelinks.sh` runs they are already present — no need to install them manually. To update plugins inside a tmux session: `prefix + U`.

## Vim plugins

Plugins are managed by [vim-plug](https://github.com/juniper/vim-plug) and are **not** tracked in this repo. On a new machine, open vim and run `:PlugInstall` to install them.

## SSH agent

The zshrc automatically starts the SSH agent and loads `~/.ssh/id_ed25519` on login. This means `git push/pull` will work without manual `ssh-add` after the first shell session.
