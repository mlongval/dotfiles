#!/usr/bin/env bash
# Terminal startup machine selector
# Presents an fzf menu to SSH into another Tailscale machine.
# Skips automatically if already in an SSH session or a subshell.

# Detect current machine via tailscale, fall back to hostname
_current_machine() {
    local name
    name=$(tailscale status --json 2>/dev/null \
        | grep -o '"Self":{[^}]*}' \
        | grep -o '"HostName":"[^"]*"' \
        | cut -d'"' -f4 \
        | tr '[:upper:]' '[:lower:]')
    echo "${name:-$(hostname -s | tr '[:upper:]' '[:lower:]')}"
}

_machine_connect() {
    # Guards — return is valid here whether sourced or executed
    [[ $- != *i* ]] && return          # non-interactive shell
    [[ -n "$SSH_CONNECTION" ]] && return  # already remote
    [[ "${SHLVL:-1}" -gt 1 ]] && return  # subshell

    # label:tailscale-host
    local -a entries=(
        "Local:"
        "Ubuntu-s1  [server]:ubuntu-s1"
        "hdieu  [hospital]:hdieu"
        "t480p15  [laptop]:t480p15"
    )

    local current
    current=$(_current_machine)

    # Build option list excluding current machine
    local -a options=()
    local entry label host
    for entry in "${entries[@]}"; do
        label="${entry%%:*}"
        host="${entry##*:}"
        # Skip if this entry matches the current machine
        if [[ -n "$host" && "$current" == *"$host"* ]]; then
            continue
        fi
        options+=("$label")
    done

    # Nothing to offer (only Local, or unrecognised machine showing all)
    [[ ${#options[@]} -le 1 ]] && return

    local choice
    choice=$(printf '%s\n' "${options[@]}" \
        | fzf \
            --height=~10 \
            --layout=reverse \
            --border=rounded \
            --prompt="  Connect to: " \
            --no-sort)

    # Empty or Local → stay here
    [[ -z "$choice" || "$choice" == "Local"* ]] && return

    # Resolve tailscale hostname from chosen label
    for entry in "${entries[@]}"; do
        label="${entry%%:*}"
        host="${entry##*:}"
        if [[ "$label" == "$choice" ]]; then
            exec ssh "$host"
        fi
    done
}

_machine_connect
unset -f _machine_connect _current_machine
