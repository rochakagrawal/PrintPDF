# PrintPDF

PrintPDF is a macOS virtual printer that saves print jobs as PDF files. During
setup, each user chooses their own destination folder. The destination can be a
local folder, an iCloud Drive folder, or a folder managed by a sync provider
such as Google Drive or Dropbox.

PrintPDF is a modified fork of
[RWTS PDFwriter](https://github.com/rodyager/RWTS-PDFwriter) by Rodney I.
Yager. RWTS PDFwriter was based on Lisanet PDFWriter by Simone Karin Lehmann,
which was based on CUPS-PDF. See [NOTICE.md](NOTICE.md) for attribution and
change information.

<img width="1810" height="894" alt="image" src="https://github.com/user-attachments/assets/247ceee2-7479-46b1-aa95-ae3e832bce05" />

## Requirements

- macOS 12 or newer
- An administrator account for installation
- Intel or Apple Silicon Mac

## Installation

PrintPDF 1.0 is currently distributed as an unsigned open-source package.
Download the package, matching source archive, and checksum only from the
[official GitHub release](https://github.com/rochakagrawal/PrintPDF/releases/tag/v1.0).

1. Verify the package against the published SHA-256 checksum.
2. Double-click `PrintPDF.pkg`.
3. If macOS blocks it, dismiss the warning. Open **System Settings → Privacy &
   Security**, scroll to **Security**, and click **Open Anyway**. Authenticate
   and confirm **Open**. Apple says this option is normally available for about
   an hour after the blocked attempt.
4. Complete the installer.
5. PrintPDF Utility opens automatically. Choose where PDFs should be saved.
6. Print from any application and select **PrintPDF** as the printer.

## Downloads

- [PrintPDF 1.0 unsigned installer](https://github.com/rochakagrawal/PrintPDF/releases/download/v1.0/PrintPDF-1.0-unsigned.pkg)
- [PrintPDF 1.0 corresponding source](https://github.com/rochakagrawal/PrintPDF/releases/download/v1.0/PrintPDF-1.0-source.zip)
- [SHA-256 checksums](https://github.com/rochakagrawal/PrintPDF/releases/download/v1.0/PrintPDF-1.0-SHA256.txt)

The `v1.0` release preserves the exact source and downloads for this version.

Apple documents this per-package exception here:
[Open an app by overriding security settings](https://support.apple.com/en-asia/guide/mac-help/mh40617/mac).
Only proceed if you trust the download and its checksum. Do not disable
Gatekeeper, change global security policy, or remove quarantine attributes.

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
Signing and notarization are recommended but not required for source-based
community distribution. If the package remains unsigned, publish the matching
source, checksum, limitations, and Apple-approved manual-opening instructions.

## Uninstalling

Open PrintPDF Utility and select **Reveal Uninstall Script**, then run the
script. Uninstallation does not delete PDFs already saved in the destination.

## Licence

PrintPDF is free software distributed under the GNU General Public License,
version 2. The complete licence is in [License](License). Anyone distributing a
compiled package must also make the complete corresponding source available
under the same licence.
