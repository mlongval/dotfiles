# Status themes

A theme styles three things together: the **zsh prompt**, the **tmux status
bar** and the **Claude Code statusline**. Each theme is a folder here; each
machine picks one via the symlink `~/.config/statusthemes/active` (not
tracked, so machines can differ). Without it, `default` is used.

```sh
statustheme                      # list themes, * = active
statustheme use September_2026   # switch this machine
statustheme toggle               # to VT220 and back to the theme before (alias: vt)
statustheme new Autumn_2026      # copy the active theme, then edit it
```

`use` runs the theme's `setup.sh` (installs missing dependencies), repoints
the symlink and reloads tmux. Claude picks it up on its next refresh; zsh in
every open shell at its next prompt (`zsh/statustheme.zsh` notices the
symlink changed, takes the old theme's hooks away and loads the new one).

**The K4510.** A shell on a K4510 terminal shows the VT220 prompt whatever
the machine's theme: TERM is `xterm-color` (the `!` shell, SSH, TELNET), or
`vt220`/`vt100`/`ansi`; inside tmux the attaching client's terminal is asked
instead. tmux does the same for its bar: `tmux/k4510-clients.sh`, run by
client hooks in `tmux.conf`, lays VT220's `tmux-post.conf` over the session a
K4510 client is on (`bin/tmux` gives each client its own session in a group),
so the K4510 gets one ASCII row and the other terminals keep their theme.
`vt` is for making VT220 the machine's theme everywhere.

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
- **VT220** — ASCII only, the eight ANSI colours plus bold/reverse, for a
  terminal with no UTF-8 or Nerd Font (the K4510's JIM): two-line prompt
  (`host cwd (branch*) [exit]` / `$`), one-row reverse-video tmux bar,
  `host | project | ctx 42% | effort` Claude line.
