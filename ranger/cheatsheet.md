# Ranger Custom Commands Cheatsheet

Open this cheatsheet:  **Z**

All custom commands use the **,** leader.

---

## Date Operations

| Key | Action | Notes |
|-----|--------|-------|
| `,r` | Rename file: update date in filename to today (DD.MM.YYYY) | Only renames if a date already exists in the name |
| `,z` | Zip selected files into `DD.MM.YYYY.zip` | |

---

## File Operations

| Key | Action | Notes |
|-----|--------|-------|
| `,d` | Duplicate file as `name_copy1.duplicate` | Increments counter if copy already exists |
| `pv` | Paste from clipboard path with existence check | Uses `check_and_copy.sh` |
| `pc` | Paste + chmod (preserve permissions) | |
| `px` | Paste + chmod 755 | |
| `,L` | chmod 600 on selected file | Lock file — owner read/write only (medical notes) |

---

## Permissions (cr prefix)

| Key | Action |
|-----|--------|
| `cro` | chmod -w (make read-only) |
| `crw` | chmod +w +r (make read/write) |
| `cri` | chattr +i (make immutable — cannot modify, delete, or rename) |
| `cre` | Rename prompt (console rename) |

---

## Open With

| Key | Action |
|-----|--------|
| `,p` | Open in Evince (PDF viewer) |

---

## Workflow / Send

| Key | Action |
|-----|--------|
| `,1` | Send selected file(s) to Julie (`send_julie`) |
| `,2` | Send selected file(s) to Mike (`send_mike`) |
| `,0` | Run `make_report` |
| `,n` | Create new clinical note in current directory (nvim) |
