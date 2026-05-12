# Statuslines — design notes

Hand-built statuslines across **nvim**, **tmux**, **zsh**, and the **Claude
Code statusline**. Goal: usable in a portrait-mode terminal where horizontal
space is the binding constraint.

No Powerlevel10k, no Airline, no Lualine presets. Each surface is a small,
config-driven script we control end-to-end.

---

## Constraints

- **Target width:** assume the terminal is ~60–80 columns wide. Anything
  wider is a bonus, not a baseline.
- **One row only.** No multi-line prompts, no two-row tmux status, no nvim
  winbar duplicating the statusline.
- **No decorative glyphs that take a column.** Powerline arrows, rounded
  caps, and segment chevrons cost 1–2 cells each and add up fast across 5–6
  segments. Use a plain separator instead.
- **Color carries meaning, not decoration.** A segment changes color only
  when its *state* matters (mode, dirty repo, error). Static segments stay
  in a neutral foreground.

## Inclusion test

For every candidate segment, answer: *would I take action on this in the
next 10 seconds?* If no, cut it.

Keep:
- State that changes silently and matters (mode, modified flag, git
  dirtiness, exit code of last command, current model).
- Identity that disambiguates (cwd basename, file basename, tmux session,
  nvim filetype when it drives behavior).
- Position only where you actually use it (nvim line:col yes; tmux clock
  no).

Cut:
- File encoding, fileformat, percentage-through-buffer.
- Hostname when you're always on one machine.
- Battery, CPU, load average — `btop` exists.
- Time, unless it's the only clock you see (tmux ok, zsh no).
- Anything that's almost always the same value (`utf-8[unix]`, `master`).

## Shared visual language

| Element        | Choice                                                |
| -------------- | ----------------------------------------------------- |
| Separator      | `` · `` (middle dot, space-padded) between segments   |
| Modified flag  | `+` suffix on the name, never `[Modified]`            |
| Readonly flag  | `!` suffix                                            |
| Empty segment  | omit entirely — never render an empty pair of seps    |
| Palette        | catppuccin-mocha (already loaded in nvim/tmux)        |
| State color    | red = error / dirty, yellow = warn, neutral otherwise |
| Truncation     | `…` ellipsis on the *left* of paths, right of names   |

## Config-driven assembly

Every surface uses the same shape:

```
segments = [
  { id, enabled, order, render() -> string, color }
  ...
]
```

A `rebuild()` filters by `enabled`, sorts by `order`, joins with the
shared separator, drops empty results, and writes the surface's native
format (`&statusline`, `status-format`, `PROMPT`, statusline JSON).

Visibility is a boolean per segment. Reordering is editing one number.
No segment is hardwired into the assembly code.

---

## Per-surface targets

### nvim

Drop airline. Build `&statusline` from a Lua table.

| Segment   | Keep | Notes                                              |
| --------- | ---- | -------------------------------------------------- |
| mode      | yes  | 1-letter (`N I V R C`), color-tinted               |
| file      | yes  | basename + `+` / `!` flags; full path only on `<leader>?` |
| align     | yes  | `%=`                                               |
| filetype  | maybe| only when not derivable from extension (clinote)   |
| diag      | yes  | only if `>0` — counts as `E:n W:n`                 |
| position  | yes  | `L:C` only, no percentage                          |
| encoding  | no   | always utf-8                                       |
| fileformat| no   | always unix                                        |
| branch    | no   | use the tmux/zsh one                               |

### tmux

Keep the **window list** as the main event. Status-left and status-right
are heavily trimmed.

| Slot          | Keep                  | Cut                          |
| ------------- | --------------------- | ---------------------------- |
| status-left   | session name (short)  | hostname, user               |
| window list   | always — this is why we have a status bar | — |
| status-right  | clock `HH:MM`         | date, cpu, battery, uptime   |

Linked-session marker (see `tmux_wrapper_linked_sessions`) gets a single
character prefix, not a word.

### zsh

Single-line prompt. Newline before input is fine (it buys vertical
clarity without costing horizontal cells).

| Segment   | Keep | Notes                                              |
| --------- | ---- | -------------------------------------------------- |
| cwd       | yes  | last 2 path components, `…/` prefix if truncated   |
| git       | yes  | branch + `*` if dirty; omit if not a repo          |
| venv      | yes  | only when active                                   |
| sudo      | yes  | only when `toggle-sudo` window is open (existing p10k segment) |
| exit code | yes  | only when non-zero, in red                         |
| user@host | no   | drop unless on a remote                            |
| time      | no   | tmux has it                                        |
| jobs      | no   | rarely used                                        |

### Claude Code statusline

Already hand-built (`~/bin/claude-statusline` or wherever the wrapper
points). Audit against this doc:

| Segment   | Keep | Notes                                              |
| --------- | ---- | -------------------------------------------------- |
| label     | yes  | the project tag from `claude-init`                 |
| model     | yes  | short form (`opus47`, `sonnet46`)                  |
| cost      | yes  | session $ only, not lifetime                       |
| context % | yes  | only when `>50%`                                   |
| cwd       | no   | the shell shows it                                 |
| branch    | no   | the shell shows it                                 |

---

## Order of work

1. nvim — replace airline with a Lua statusline module driven by a table.
2. zsh — strip p10k down or replace with a small handwritten prompt.
3. tmux — trim status-left/right, leave window list alone.
4. Claude statusline — audit against the table above, remove duplicates.

Each step keeps the same separator, palette, and inclusion test so the
four surfaces read as one system.
