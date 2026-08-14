#!/bin/bash

# PrintPDF per-user mover.
# Moves completed CUPS jobs into the destination selected in PrintPDF Utility.

USER_NAME="$(/usr/bin/id -un)"
SOURCE_DIR="${PRINTPDF_SOURCE_DIR:-/private/var/spool/printpdf/$USER_NAME}"
CONFIG_FILE="${PRINTPDF_CONFIG_FILE:-$HOME/Library/Application Support/PrintPDF/destination.txt}"

[ -d "$SOURCE_DIR" ] || exit 0
[ -r "$CONFIG_FILE" ] || exit 0

IFS= read -r DEST_DIR < "$CONFIG_FILE" || exit 0
[ -n "$DEST_DIR" ] || exit 0
[ "${DEST_DIR#/}" != "$DEST_DIR" ] || exit 1
[ "$DEST_DIR" != "$SOURCE_DIR" ] || exit 1

/bin/mkdir -p "$DEST_DIR" || exit 1

unique_destination() {
    local source_file="$1"
    local filename base candidate index
    filename="$(/usr/bin/basename "$source_file")"
    base="${filename%.pdf}"
    candidate="$DEST_DIR/$filename"
    index=1

    while [ -e "$candidate" ]; do
        candidate="$DEST_DIR/${base}-${index}.pdf"
        index=$((index + 1))
    done
    printf '%s\n' "$candidate"
}

shopt -s nullglob
for pdf in "$SOURCE_DIR"/*.pdf; do
    destination="$(unique_destination "$pdf")"
    /bin/mv "$pdf" "$destination"
done
