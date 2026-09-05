# PrintPDF

PrintPDF is a macOS virtual printer that saves print jobs as PDF files. During
setup, each user chooses their own destination folder. The destination can be a
local folder, an iCloud Drive folder, or a folder managed by a sync provider
such as Google Drive or Dropbox.

> **PrintPDF 1.1 is signed with Apple Developer ID and notarized by Apple for direct macOS distribution.**

**Its main advantage over RWTS PDFwriter is that each completed PDF is moved as
a real file directly into the folder selected by the user. RWTS PDFwriter's
utility instead creates a symbolic link from the chosen location to its spool
folder. PrintPDF does not use a symbolic link for the destination.**

PrintPDF is a modified fork of
[RWTS PDFwriter](https://github.com/rodyager/RWTS-PDFwriter) by Rodney I.
Yager. RWTS PDFwriter was based on Lisanet PDFWriter by Simone Karin Lehmann,
which was based on CUPS-PDF. See [NOTICE.md](NOTICE.md) for attribution and
change information.

<img width="1810" height="894" alt="PrintPDF Utility working" src="https://github.com/user-attachments/assets/247ceee2-7479-46b1-aa95-ae3e832bce05" />

## Requirements

- macOS 12 or newer
- An administrator account for installation
- Intel or Apple Silicon Mac

## Installation

PrintPDF 1.1 is distributed as a Developer ID signed and Apple notarized
installer package. Download it only from the official GitHub release.

1. Download `PrintPDF.pkg` from the latest GitHub release.
2. Optionally verify it against the published SHA-256 checksum.
3. Double-click `PrintPDF.pkg` and complete the installer.
4. PrintPDF Utility opens automatically. Choose where PDFs should be saved.
5. Print from any application and select **PrintPDF** as the printer.

Because the release is Developer ID signed and notarized by Apple, a normal
macOS installation should not require the previous unsigned-package
**Open Anyway** workaround.

## Downloads

- [PrintPDF 1.1 signed and notarized installer](https://github.com/rochakagrawal/PrintPDF/releases/tag/v1.1)
- [All releases](https://github.com/rochakagrawal/PrintPDF/releases)

The earlier `v1.0` release is retained as the historical unsigned release.

The destination can be changed later by opening **PrintPDF Utility** from the
printer's Utility panel in **System Settings → Printers & Scanners**.

Print jobs are first written to a private per-user CUPS spool folder. A small
per-user LaunchAgent then moves completed PDFs into the selected destination.
Existing files are never overwritten; PrintPDF adds a numeric suffix when a
filename already exists.

## Privacy

PrintPDF works locally. It does not upload documents or include analytics. If a
cloud-synced destination is selected, that provider's software handles syncing.

## Building from source

Install the full Xcode application, accept its licence, and run:

```bash
./build/buildscript.sh
```

The unsigned installer is created as `PrintPDF.pkg` in the repository root.
For a signed release, the repository also includes the manual notarization
workflow used for the official distribution package.

## Uninstalling

Open PrintPDF Utility and select **Reveal Uninstall Script**, then run the
script. Uninstallation does not delete PDFs already saved in the destination.

## Licence

PrintPDF is free software distributed under the GNU General Public License,
version 2. The complete licence is in [LICENSE](LICENSE). Anyone distributing a
compiled package must also make the complete corresponding source available
under the same licence.
