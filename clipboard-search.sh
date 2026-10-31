#!/bin/bash
# Clipboard picker: Cliphist + Fuzzel (handles both text AND images)

tmpfile=$(mktemp) || exit 1
trap 'rm -f "$tmpfile"' EXIT

# Format cliphist entries for fuzzel display
cliphist list | while IFS=$'\t' read -r id preview; do
    # Image entries
    if [[ "$preview" =~ ^UNIQUE-COPY-[0-9]+$ ]] || [[ -z "$preview" ]]; then
        printf "%s\t🖼️  Image\n" "$id"
    elif [[ "$preview" == *"binary data"* ]]; then
        # e.g. [[ binary data 15 KiB png 551x349 ]]
        info="${preview#\[\[ binary data }"
        info="${info% \]\]}"
        printf "%s\t🖼️  %s\n" "$id" "$info"
    else
        # Text entry — truncate long previews
        clean="${preview//$'\t'/  }"
        printf "%s\t📋  %s\n" "$id" "${clean:0:120}"
    fi
done > "$tmpfile"

[[ ! -s "$tmpfile" ]] && exit 0

# Let user pick
selected=$(fuzzel --dmenu --prompt="Clipboard > " < "$tmpfile")
[[ -z "$selected" ]] && exit 0

# Extract ID and copy to clipboard
id=$(cut -f1 <<< "$selected")
cliphist decode "$id" | wl-copy
