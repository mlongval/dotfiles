---
name: load
description: Read and summarize project memory — all, or a single entry by 3-digit index
user-invocable: true
args: optional 3-digit index number (e.g. /load 003)
---

The args for this skill invocation are: {{args}}

**If no args were provided (or args is empty):**
Read all memory files listed in the project's `MEMORY.md` and print a clean summary of everything stored — user preferences, infrastructure, known issues, workflow notes, and any other context. After the summary, print a confirmation line listing every index and file loaded, e.g.:
`Loaded: 000 user_profile.md, 001 infrastructure.md, 002 backup_system.md, ...`

**If a number was provided (e.g. `3`, `03`, or `003`):**
1. Read `MEMORY.md` to get the numbered list of memory files (entries are zero-indexed from 000 in order of appearance).
2. Identify the file at the given index.
3. Read only that file and print its full contents as a clean summary.
4. End with a confirmation line, e.g.:
`Loaded: 003 backup_system.md — Nightly backup cron jobs on ubuntu-s1, sources, destinations, ntfy alerting`
