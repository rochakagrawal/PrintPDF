#!/bin/bash

# PrintPDF delivery health monitor.
#
# Runs every 30 seconds as the per-user LaunchAgent com.printpdf.health and
# warns the logged-in user when a printed page cannot reach the destination:
#
#   1. the PrintPDF CUPS queue is missing or disabled
#   2. the CUPS backend symlink is missing
#   3. a CUPS job has been sitting in the queue for more than 60 seconds
#   4. the destination folder is not configured or not usable
#   5. the per-user mover agent is not running (the agent that delivers PDFs).
#      It is reloaded automatically, because a mover that is not running can
#      never report its own failure.
#   6. finished PDFs have been sitting in the spool folder for too long
#
# Every check has its own key. A failing check alerts once, is remembered in
# local state and is forgotten as soon as it passes again, so a persistent
# problem never floods the user with notifications and one problem never hides
# another.

LOG_FILE="$HOME/Library/Logs/PrintPDF.log"
STATE_DIR="$HOME/Library/Application Support/PrintPDF"
STATE_FILE="$STATE_DIR/health-last-alert.txt"
ATTEMPT_FILE="$STATE_DIR/health-mover-attempt.txt"
DESTINATION_FILE="$STATE_DIR/destination.txt"

QUEUE="PrintPDF"
BACKEND="/usr/libexec/cups/backend/printpdf"

MOVER_LABEL="com.printpdf.mover"
MOVER_AGENT="$HOME/Library/LaunchAgents/$MOVER_LABEL.plist"
MOVER_SCRIPT="/Library/Printers/PrintPDF/pdfwriter-mover.sh"

UID_NUMBER="$(/usr/bin/id -u)"
USER_NAME="$(/usr/bin/id -un)"
SPOOL_DIR="${PRINTPDF_SOURCE_DIR:-/private/var/spool/printpdf/$USER_NAME}"

# A finished PDF older than this many seconds means delivery is broken.
BACKLOG_SECONDS="${PRINTPDF_BACKLOG_SECONDS:-120}"
# Do not try to reload the mover more often than this.
RETRY_SECONDS="${PRINTPDF_RETRY_SECONDS:-300}"
# A CUPS job older than this never produced a PDF.
CUPS_STUCK_SECONDS="${PRINTPDF_CUPS_STUCK_SECONDS:-60}"

NOW="$(/bin/date +%s)"

mkdir -p "$HOME/Library/Logs" "$STATE_DIR"

log_message() {
    printf '%s %s\n' "$(/bin/date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE"
}

alert_is_active() {
    [ -r "$STATE_FILE" ] || return 1
    /usr/bin/grep -qx "$1" "$STATE_FILE"
}

remember_alert() {
    alert_is_active "$1" && return 0
    printf '%s\n' "$1" >> "$STATE_FILE"
}

forget_alert() {
    local key="$1"
    local temporary="$STATE_FILE.tmp"

    [ -r "$STATE_FILE" ] || return 0
    if /usr/bin/grep -vx "$key" "$STATE_FILE" > "$temporary" 2>/dev/null; then
        /bin/mv "$temporary" "$STATE_FILE"
    else
        : > "$temporary"
        /bin/mv "$temporary" "$STATE_FILE"
    fi
}

notify_once() {
    local key="$1"
    local message="$2"

    alert_is_active "$key" && return 0
    remember_alert "$key"
    log_message "ERROR: $message"
    /usr/bin/osascript -e "display notification \"$message\" with title \"PrintPDF problem\"" >/dev/null 2>&1 || true
}

# 1. The queue must exist and be enabled.
if ! /usr/bin/lpstat -p "$QUEUE" >/dev/null 2>&1; then
    notify_once "queue-missing" "PrintPDF printer queue is missing."
    exit 1
fi
forget_alert "queue-missing"

if /usr/bin/lpstat -p "$QUEUE" 2>&1 | /usr/bin/grep -qi 'disabled'; then
    notify_once "queue-disabled" "PrintPDF printer queue is disabled."
    exit 1
fi
forget_alert "queue-disabled"

# 2. The CUPS backend is intentionally root-owned and may not be executable by
#    the logged-in user. Check that the symlink resolves to an existing backend
#    instead of using a user-context executable permission test.
BACKEND_TARGET="$(/usr/bin/readlink "$BACKEND" 2>/dev/null || true)"
if [ ! -L "$BACKEND" ] || [ -z "$BACKEND_TARGET" ] || [ ! -f "$BACKEND_TARGET" ]; then
    notify_once "backend-missing" "PrintPDF backend is missing."
    exit 1
fi
forget_alert "backend-missing"

# 3. A job still queued after a minute never produced a PDF. CUPS timestamps are
#    locale-dependent, so use the spool control files as the reliable signal.
CUPS_STUCK=0
for control in /private/var/spool/cups/c*; do
    [ -e "$control" ] || continue
    if /usr/bin/strings "$control" 2>/dev/null | /usr/bin/grep -q "$QUEUE"; then
        MTIME="$(/usr/bin/stat -f %m "$control" 2>/dev/null || echo "$NOW")"
        if [ $((NOW - MTIME)) -ge "$CUPS_STUCK_SECONDS" ]; then
            CUPS_STUCK=1
            break
        fi
    fi
done
if [ "$CUPS_STUCK" = 1 ]; then
    notify_once "cups-stuck" "A PrintPDF job has been stuck in CUPS for more than $CUPS_STUCK_SECONDS seconds."
else
    forget_alert "cups-stuck"
fi

# 4. Look at what is waiting in the spool. A PDF that stays here is a PDF the
#    user never received.
SPOOL_COUNT=0
SPOOL_OLDEST_AGE=0
if [ -d "$SPOOL_DIR" ]; then
    for pdf in "$SPOOL_DIR"/*.pdf; do
        [ -e "$pdf" ] || continue
        SPOOL_COUNT=$((SPOOL_COUNT + 1))
        MTIME="$(/usr/bin/stat -f %m "$pdf" 2>/dev/null || echo "$NOW")"
        AGE=$((NOW - MTIME))
        if [ "$AGE" -gt "$SPOOL_OLDEST_AGE" ]; then
            SPOOL_OLDEST_AGE="$AGE"
        fi
    done
fi

# 5. The destination must be usable. It is only reported while a PDF is waiting,
#    because that is when the user is actually affected. The state keys are
#    always kept accurate so a repaired folder stops alerting.
DESTINATION=""
if [ -r "$DESTINATION_FILE" ]; then
    IFS= read -r DESTINATION < "$DESTINATION_FILE" || DESTINATION=""
fi

DESTINATION_PROBLEM=""
DESTINATION_MESSAGE=""
if [ -z "$DESTINATION" ]; then
    DESTINATION_PROBLEM="destination-missing"
    DESTINATION_MESSAGE="PDFs are waiting but PrintPDF has no destination folder. Open PrintPDF Utility and choose one."
elif [ "${DESTINATION#/}" = "$DESTINATION" ]; then
    DESTINATION_PROBLEM="destination-invalid"
    DESTINATION_MESSAGE="The PrintPDF destination folder is not a valid path."
elif [ ! -d "$DESTINATION" ]; then
    DESTINATION_PROBLEM="destination-unavailable"
    DESTINATION_MESSAGE="The PrintPDF destination folder is unavailable: $DESTINATION"
elif [ ! -w "$DESTINATION" ]; then
    DESTINATION_PROBLEM="destination-unwritable"
    DESTINATION_MESSAGE="PrintPDF cannot write to its destination folder: $DESTINATION"
fi

for key in destination-missing destination-invalid destination-unavailable destination-unwritable; do
    if [ "$key" = "$DESTINATION_PROBLEM" ] && [ "$DESTINATION_PROBLEM" != "" ] && [ "$SPOOL_COUNT" -gt 0 ]; then
        continue
    fi
    forget_alert "$key"
done

if [ "$DESTINATION_PROBLEM" != "" ] && [ "$SPOOL_COUNT" -gt 0 ]; then
    notify_once "$DESTINATION_PROBLEM" "$DESTINATION_MESSAGE"
fi

# 6. The mover agent is what actually delivers PDFs. If it is not running,
#    reload it, because a mover that is not loaded can never raise an alert.
mover_agent_is_loaded() {
    /bin/launchctl print "gui/$UID_NUMBER/$MOVER_LABEL" >/dev/null 2>&1 && return 0
    /bin/launchctl list "$MOVER_LABEL" >/dev/null 2>&1 && return 0
    return 1
}

MOVER_READY=0
if [ ! -x "$MOVER_SCRIPT" ] || [ ! -r "$MOVER_AGENT" ]; then
    notify_once "mover-files-missing" "The PrintPDF background mover is missing. Reinstall PrintPDF."
elif mover_agent_is_loaded; then
    MOVER_READY=1
    forget_alert "mover-unloaded"
else
    LAST_ATTEMPT=0
    if [ -r "$ATTEMPT_FILE" ]; then
        IFS= read -r LAST_ATTEMPT < "$ATTEMPT_FILE" || LAST_ATTEMPT=0
    fi
    case "$LAST_ATTEMPT" in
        ''|*[!0-9]*) LAST_ATTEMPT=0 ;;
    esac

    if [ $((NOW - LAST_ATTEMPT)) -ge "$RETRY_SECONDS" ]; then
        printf '%s\n' "$NOW" > "$ATTEMPT_FILE"
        log_message "WARNING: $MOVER_LABEL was not running. Reloading it."
        /bin/launchctl bootout "gui/$UID_NUMBER" "$MOVER_AGENT" >/dev/null 2>&1 || true
        /bin/sleep 1
        if /bin/launchctl bootstrap "gui/$UID_NUMBER" "$MOVER_AGENT" >/dev/null 2>&1; then
            log_message "OK: $MOVER_LABEL reloaded."
        fi
    fi

    if mover_agent_is_loaded; then
        MOVER_READY=1
        forget_alert "mover-unloaded"
        /bin/launchctl kickstart -k "gui/$UID_NUMBER/$MOVER_LABEL" >/dev/null 2>&1 || true
    else
        notify_once "mover-unloaded" "The PrintPDF background mover is not running, so PDFs cannot be delivered."
    fi
fi

# 7. Delivery must not pile up in the spool. This is the check that catches a
#    mover that is loaded but failing, or that was quietly unloaded.
if [ "$MOVER_READY" = 1 ]; then
    if [ "$SPOOL_COUNT" -gt 0 ] && [ "$SPOOL_OLDEST_AGE" -ge "$BACKLOG_SECONDS" ]; then
        notify_once "spool-backlog" "$SPOOL_COUNT PDF file(s) are stuck in the PrintPDF spool and were not delivered."
    else
        forget_alert "spool-backlog"
    fi
fi

exit 0
