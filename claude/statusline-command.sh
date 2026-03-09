#!/usr/bin/env bash
# Claude Code status line — shows hostname, cwd, and context usage

input=$(cat)

host=$(hostname -s)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
# Abbreviate home directory
cwd=$(echo "$cwd" | sed "s|^$HOME|~|")
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Build context string only when data is available
if [ -n "$used" ]; then
  used_int=$(printf "%.0f" "$used")
  ctx_str=" | ctx ${used_int}%"
else
  ctx_str=""
fi

printf "%s | %s%s" "$host" "$cwd" "$ctx_str"
