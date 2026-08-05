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

Package snapshots are per-machine, under `snapshots/<hostname>/` (see `backup-system-state.sh` below). Substitute your machine's snapshot dir — e.g. `snapshots/t480i5/` — below, or use the closest match if this is a new machine.

**Terminal + preview tools** — Ghostty, plus chafa/poppler-utils for ranger's image/PDF previews:
```sh
~/dotfiles/bin/install-ghostty.sh
```

**Homebrew** (tracked in `snapshots/<hostname>/Brewfile`):
```sh
brew bundle install --file=~/dotfiles/snapshots/<hostname>/Brewfile
```

**Flatpaks** (tracked in `snapshots/<hostname>/flatpaks.txt`):
```sh
xargs -a ~/dotfiles/snapshots/<hostname>/flatpaks.txt flatpak install -y flathub
```

**GNOME settings** — restores all desktop settings and extension configuration:
```sh
dconf load / < ~/dotfiles/snapshots/<hostname>/dconf-backup.ini
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

`backup-system-state.sh` captures the current state of packages and GNOME settings into `snapshots/$(hostname)/`:

```sh
~/dotfiles/backup-system-state.sh
```

This updates, depending on what's present on the machine:
- `Brewfile` — all currently installed Homebrew formulae and casks
- `flatpaks.txt` — all installed Flatpak apps
- `apt-packages.txt` / `dnf-packages.txt` / `rpm-ostree-packages.txt` — native distro packages
- `gnome-extensions.txt` — enabled GNOME Shell extensions
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
| `tmux/plugins/tpm` | Tmux Plugin Manager (submodule) |
| `bin/install-ghostty.sh` | Installs Ghostty + chafa/poppler-utils for ranger previews |
| `snapshots/<hostname>/` | Per-machine Brewfile / flatpaks.txt / dconf-backup.ini / native package lists (auto-generated) |

---

## Tmux plugins

Managed by [TPM](https://github.com/tmux-plugins/tpm), tracked as git submodules. After `install.sh` runs they are already present — no manual install needed. To update plugins inside a tmux session: `prefix + U`.

## Vim plugins

Managed by [vim-plug](https://github.com/juniper/vim-plug), **not** tracked in this repo. On a new machine, open vim and run `:PlugInstall`.

## SSH agent

The zshrc automatically starts the SSH agent and loads `~/.ssh/id_ed25519` on login. `git push/pull` will work without manual `ssh-add` after the first shell session.

## Ghostty

`ranger`'s image and PDF previews (`ranger/plugins/chafa_ghostty.py`, `ranger/plugins/pdf_pager.py`) only activate inside Ghostty — they detect it via `$GHOSTTY_RESOURCES_DIR` and are a silent no-op in any other terminal.

On a graphical machine that doesn't have Ghostty yet, opening a new local (non-SSH) shell will prompt once per shell to install it, until you answer yes or no (see `ghostty_offer_install` in `bash/bash_functions`). To install manually, or to pick up chafa/poppler-utils for the ranger previews without the prompt:
```sh
~/dotfiles/bin/install-ghostty.sh
```
