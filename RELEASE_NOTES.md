# PrintPDF 1.2.1

Silent delivery failure fix.

## What went wrong in 1.2

PrintPDF 1.2 could stop delivering PDFs without telling anyone. If the per-user
mover LaunchAgent was not registered with launchd, printed PDFs stayed in the
spool folder forever and no notification appeared, because the component that
raises the delivery notification was the component that was not running. The
CUPS health agent kept running and reported nothing, because it only checked the
queue, the backend and queued CUPS jobs. It never looked at the spool folder or
at the mover.

## Changes

- The health agent now watches the spool folder and warns once when a finished
  PDF has been waiting longer than two minutes.
- The health agent now checks that the mover LaunchAgent is registered and
  reloads it automatically when it is missing. This is what recovers delivery on
  its own. Reload attempts are throttled to one every five minutes.
- Alert state is now one key per problem, remembered and cleared independently,
  so a persistent problem does not re-notify and one problem cannot hide another.
- The health agent also warns when the destination folder is not configured,
  not a valid path, missing or not writable, but only when PDFs are waiting.
- The installer verifies that both LaunchAgents registered with launchd, retries
  the load, and reports a failure instead of discarding it. A failed load is
  written to the installer log, to
  `~/Library/Application Support/PrintPDF/install-warning.txt` and, as a
  notification, to the user.
- The Utility app verifies the mover after loading it, retries once, and reports
  the launchctl status instead of a generic message. It also repairs a missing
  mover every time it opens.
- The Utility app writes the same LaunchAgent plist as the installer, including
  the WatchPaths entry for the spool folder.
- The uninstaller now unloads and removes the health agent as well as the mover.

## Previous release

PrintPDF 1.2 was the reliability and failure monitoring release.

# PrintPDF 1.2

Reliability and failure monitoring release.

## Highlights

- Automatically installs and loads the per-user PrintPDF mover LaunchAgent.
- Watches the PrintPDF spool directory for new PDFs and also checks every 5 seconds as a fallback.
- Restores automatic delivery after login and restart through RunAtLoad.
- Writes delivery activity and failures to `~/Library/Logs/PrintPDF.log`.
- Shows a macOS notification when a PDF is created but the destination is missing, invalid, unavailable, or the move fails.
- Detects PDFs left behind in the spool and reports them as stuck.
- Adds a CUPS health monitor that detects disabled or stopped PrintPDF queues, backend errors, and jobs that remain queued without producing a PDF.
- Keeps the existing per-user destination and duplicate-safe filename behavior.
- Signed and notarized release workflow produces the installer and SHA-256 checksum.

## Previous release

PrintPDF 1.1 was the first Developer ID signed and Apple notarized release.
