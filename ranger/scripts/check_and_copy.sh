#!/bin/bash

FILE=$(cat /tmp/works_selected)

if [ -e "$FILE" ]; then
    install -m 0755 "$FILE" "$1"
else
    dialog --msgbox "Error: File does not exist" 6 40
    clear
fi

