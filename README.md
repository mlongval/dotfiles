# dotfiles

Personal configuration files for zsh, tmux, vim, nvim, ranger, and Claude Code.

---

## Zero-day setup (fresh machine)

Paste this into a terminal — it handles everything from SSH key generation to cloning and linking:

```sh
curl -fsSL https://raw.githubusercontent.com/mlongval/dotfiles/master/bootstrap.sh -o /tmp/bootstrap.sh && bash /tmp/bootstrap.sh "machine-name"
```

Replace `machine-name` with something descriptive (e.g. `t480i5`, `hdieu`). The script will:

1. Generate an SSH key (`~/.ssh/id_ed25519`) if one doesn't exist
2. Install Homebrew and the `gh` CLI if needed
3. Walk you through GitHub login and upload your SSH key
4. Clone this repo to `~/dotfiles`
5. Run `install.sh` to symlink everything into place
6. Set up the Neovim Python provider (`uv` + `pynvim`)

After bootstrap completes, open a new shell and continue with the steps below.

### After bootstrap: install packages

**Homebrew** (tracked in `Brewfile`):
```sh
brew bundle install --file=~/dotfiles/Brewfile
```

**Flatpaks** (tracked in `flatpaks.txt`):
```sh
xargs -a ~/dotfiles/flatpaks.txt flatpak install -y flathub
```

**GNOME settings** — restores all desktop settings and extension configuration:
```sh
dconf load / < ~/dotfiles/dconf-backup.ini
```
> Note: install your GNOME extensions first (via the Extensions app or `gnome-extensions install`), then load dconf so their settings apply correctly.

**Claude Code** — install the native binary, then log in:
```sh
curl -fsSL https://claude.ai/install.sh | bash
claude login
```
Symlinks from `install.sh` will have already placed your settings, statusline, skills, commands, and hooks into `~/.claude/`.

---

## Manual installation (if you already have GitHub SSH access)

```sh
git clone --recurse-submodules git@github.com:mlongval/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

`install.sh` is safe to re-run at any time — it will update or recreate all symlinks without touching the underlying files.

> **Requires:** `curl` (to fetch `uv` on first run). `install.sh` automatically installs `uv` and `pynvim` for the Neovim Python provider (`UltiSnips`, etc.) via `bin/setup-neovim-python.sh`.

---

## Re-running install.sh

Whenever you add a new dotfile to the repo, re-run `install.sh` to link it into place:

```sh
~/dotfiles/install.sh
```

No arguments needed. Existing symlinks are refreshed, nothing is deleted.

---

## Keeping the system state snapshot current

`backup-system-state.sh` captures the current state of packages and GNOME settings:

```sh
~/dotfiles/backup-system-state.sh
```

This updates:
- `Brewfile` — all currently installed Homebrew formulae and casks
- `flatpaks.txt` — all installed Flatpak apps
- `dconf-backup.ini` — full GNOME settings dump (shell, keybindings, extension configs)

Run it before wiping a machine, or periodically to keep the repo current. Then commit the results.

---

## Contents

| Path | Config for |
|------|-----------|
| `zsh/zshrc` | zsh |
| `bash/` | bash aliases, functions, profile |
| `tmux/tmux.conf` | tmux (plugins via TPM) |
| `nvim/` | Neovim |
| `vim/` | Vim (plugins managed by vim-plug, not tracked) |
| `ranger/` | ranger file manager |
| `claude/` | Claude Code — statusline, settings, skills, commands, hooks |
| `powerlevel10k/` | p10k prompt theme (submodule) |
| `tmux/plugins/tpm` | Tmux Plugin Manager (submodule) |
| `Brewfile` | Homebrew package list (auto-generated) |
| `flatpaks.txt` | Flatpak app list (auto-generated) |
| `dconf-backup.ini` | GNOME settings dump (auto-generated) |

---

## Tmux plugins

Managed by [TPM](https://github.com/tmux-plugins/tpm), tracked as git submodules. After `install.sh` runs they are already present — no manual install needed. To update plugins inside a tmux session: `prefix + U`.

## Vim plugins

Managed by [vim-plug](https://github.com/juniper/vim-plug), **not** tracked in this repo. On a new machine, open vim and run `:PlugInstall`.

## SSH agent

The zshrc automatically starts the SSH agent and loads `~/.ssh/id_ed25519` on login. `git push/pull` will work without manual `ssh-add` after the first shell session.

## Bluefin / distrobox notes

On Bluefin (t480i5), the shell auto-enters the `DailyUse` distrobox on login. Inside that container, `/home/linuxbrew` is mounted **read-only** by design — Homebrew is intended to be managed from the host shell only.

A `brew()` function in `bash/bash_functions` handles this transparently: when called inside a distrobox container where `/home/linuxbrew` is not writable, it delegates to `distrobox-host-exec brew`. On all other systems (Ubuntu, plain Fedora, host Bluefin shell) it calls brew directly. No configuration needed.
