#!/bin/bash

# PrintPDF per-user mover.
# Moves completed CUPS jobs into the destination selected in PrintPDF Utility.
# Logs successful deliveries and shows a macOS notification when delivery fails.

USER_NAME="$(/usr/bin/id -un)"
SOURCE_DIR="${PRINTPDF_SOURCE_DIR:-/private/var/spool/printpdf/$USER_NAME}"
CONFIG_FILE="${PRINTPDF_CONFIG_FILE:-$HOME/Library/Application Support/PrintPDF/destination.txt}"
LOG_FILE="$HOME/Library/Logs/PrintPDF.log"

log_message() {
    /bin/mkdir -p "$HOME/Library/Logs"
    printf '%s %s\n' "$(/bin/date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE"
}

notify_user() {
    local message="$1"
    /usr/bin/osascript -e "display notification \"$message\" with title \"PrintPDF problem\"" >/dev/null 2>&1 || true
}

[ -d "$SOURCE_DIR" ] || exit 0

shopt -s nullglob
PDF_FILES=("$SOURCE_DIR"/*.pdf)
[ ${#PDF_FILES[@]} -gt 0 ] || exit 0

if [ ! -r "$CONFIG_FILE" ]; then
    log_message "ERROR: PrintPDF destination configuration is missing."
    notify_user "PDF created, but the destination folder is not configured."
    exit 1
fi

IFS= read -r DEST_DIR < "$CONFIG_FILE" || {
    log_message "ERROR: Could not read destination configuration."
    notify_user "PDF created, but PrintPDF could not read its destination."
    exit 1
}

if [ -z "$DEST_DIR" ] || [ "${DEST_DIR#/}" = "$DEST_DIR" ]; then
    log_message "ERROR: Invalid destination: $DEST_DIR"
    notify_user "PDF created, but the configured destination is invalid."
    exit 1
fi

if [ "$DEST_DIR" = "$SOURCE_DIR" ]; then
    log_message "ERROR: Destination and spool directory are identical."
    notify_user "PrintPDF destination configuration is invalid."
    exit 1
fi

if ! /bin/mkdir -p "$DEST_DIR"; then
    log_message "ERROR: Destination unavailable: $DEST_DIR"
    notify_user "PDF created, but the destination folder is unavailable."
    exit 1
fi

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

for pdf in "${PDF_FILES[@]}"; do
    destination="$(unique_destination "$pdf")"
    if /bin/mv "$pdf" "$destination"; then
        log_message "OK: Moved $(/usr/bin/basename "$pdf")"
    else
        log_message "ERROR: Failed to move $(/usr/bin/basename "$pdf") to $DEST_DIR"
        notify_user "PDF was created but could not be moved to your PrintPDF folder."
    fi
done

REMAINING=("$SOURCE_DIR"/*.pdf)
if [ ${#REMAINING[@]} -gt 0 ]; then
    log_message "WARNING: ${#REMAINING[@]} PDF file(s) remain in the PrintPDF spool."
    notify_user "${#REMAINING[@]} PDF file(s) are stuck in PrintPDF."
fi

exit 0
