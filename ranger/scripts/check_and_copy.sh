#!/bin/bash

# Must match the works picker writer (ClinicalNotesSystem/bin/works), which
# writes to RAM-backed tmpfs to keep patient-identifying paths off disk.
FILE=$(cat /dev/shm/works_selected)

if [ -e "$FILE" ]; then
    install -m 0755 "$FILE" "$1"
else
    dialog --msgbox "Error: File does not exist" 6 40
    clear
fi

