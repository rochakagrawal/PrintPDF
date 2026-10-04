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
