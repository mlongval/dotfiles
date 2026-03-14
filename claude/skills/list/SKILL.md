---
name: list
description: Print the MEMORY.md index for the current project, numbered from 000
user-invocable: true
---

Read the `MEMORY.md` index file from the current project's memory directory (visible in the system context). Print each memory entry numbered with a zero-padded 3-digit index starting at `000`. Format each line as:

```
000  filename.md — description
001  filename.md — description
...
```

Use the order the entries appear in MEMORY.md. Do not summarize or reword — use the description text as written. No preamble, just the numbered list.
