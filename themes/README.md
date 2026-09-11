# Status themes

A theme styles three things together: the **zsh prompt**, the **tmux status
bar** and the **Claude Code statusline**. Each theme is a folder here; each
machine picks one via the symlink `~/.config/statusthemes/active` (not
tracked, so machines can differ). Without it, `default` is used.

```sh
statustheme                      # list themes, * = active
statustheme use September_2026   # switch this machine
statustheme new Autumn_2026      # copy the active theme, then edit it
```

`use` runs the theme's `setup.sh` (installs missing dependencies), repoints
the symlink and reloads tmux. Claude picks it up on its next refresh; zsh in
new shells (`exec zsh` in open ones).

## Theme folder

| File                   | Used by                                      | Required |
| ---------------------- | -------------------------------------------- | -------- |
| `meta`                 | `statustheme list` (`description=`, `origin=`, `captured=`) | no |
| `zsh-early.zsh`        | top of `zshrc` (e.g. p10k instant prompt)    | no       |
| `zsh.zsh`              | `zshrc`, where the prompt is set up          | yes      |
| `tmux-pre.conf`        | `tmux.conf`, before TPM runs (`@plugin` lines, plugin options) | no |
| `tmux-post.conf`       | `tmux.conf`, after TPM (status options)      | no       |
| `claude-statusline.sh` | `claude/statusline-command.sh` dispatcher    | yes      |
| `setup.sh`             | `statustheme use`, before switching          | no       |

`tmux.conf` resets every status/border/message option before loading a
theme, so switching on a running server leaves nothing behind. If a theme
sets an option not in that reset list, add it there.

## Themes

- **September_2026** — catppuccin pills: powerlevel10k rainbow prompt, the
  `mlongval/catppuccin-tmux` plugin, pill-style Claude line. Captured from
  `dell`.
- **Summer_2026** — flat catppuccin: hand-built prompt, two-row handwritten
  tmux bar, flat Claude line (design notes in `STATUSLINES.md`). Captured from
  `ubuntu-s1`. This is `default`.
