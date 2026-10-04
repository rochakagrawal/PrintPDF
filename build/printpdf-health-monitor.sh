#!/bin/bash

# PrintPDF CUPS health monitor.
# Warns the logged-in user when the PrintPDF queue/backend fails before a PDF
# reaches the per-user spool. State is kept locally to avoid repeated alerts.

LOG_FILE="$HOME/Library/Logs/PrintPDF.log"
STATE_DIR="$HOME/Library/Application Support/PrintPDF"
STATE_FILE="$STATE_DIR/health-last-alert.txt"
QUEUE="PrintPDF"

mkdir -p "$HOME/Library/Logs" "$STATE_DIR"

log_message() {
    printf '%s %s\n' "$(/bin/date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE"
}

notify_once() {
    local key="$1"
    local message="$2"
    local previous=""
    [ -r "$STATE_FILE" ] && IFS= read -r previous < "$STATE_FILE"
    [ "$previous" = "$key" ] && return 0
    printf '%s\n' "$key" > "$STATE_FILE"
    log_message "ERROR: $message"
    /usr/bin/osascript -e "display notification \"$message\" with title \"PrintPDF problem\"" >/dev/null 2>&1 || true
}

clear_alert() {
    : > "$STATE_FILE"
}

if ! /usr/bin/lpstat -p "$QUEUE" >/dev/null 2>&1; then
    notify_once "queue-missing" "PrintPDF printer queue is missing."
    exit 1
fi

QUEUE_STATUS="$(/usr/bin/lpstat -p "$QUEUE" 2>&1)"
if printf '%s' "$QUEUE_STATUS" | /usr/bin/grep -qi 'disabled'; then
    notify_once "queue-disabled" "PrintPDF printer queue is disabled."
    exit 1
fi

if [ ! -x /usr/libexec/cups/backend/printpdf ]; then
    notify_once "backend-missing" "PrintPDF backend is missing or cannot run."
    exit 1
fi

# A job still shown as active after 60 seconds is suspicious. CUPS timestamps
# are locale-dependent, so use the spool control files as the reliable signal.
NOW="$(/bin/date +%s)"
for control in /private/var/spool/cups/c*; do
    [ -e "$control" ] || continue
    if /usr/bin/strings "$control" 2>/dev/null | /usr/bin/grep -q "$QUEUE"; then
        MTIME="$(/usr/bin/stat -f %m "$control" 2>/dev/null || echo "$NOW")"
        AGE=$((NOW - MTIME))
        if [ "$AGE" -ge 60 ]; then
            notify_once "cups-stuck" "A PrintPDF job has been stuck in CUPS for more than 60 seconds."
            exit 1
        fi
    fi
done

clear_alert
exit 0
