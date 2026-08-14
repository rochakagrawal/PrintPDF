# Draft Reddit post

## PrintPDF — a virtual PDF printer for macOS with a destination folder chooser

I made PrintPDF, a macOS virtual printer that lets you print from any app
directly into a PDF file. On first launch it asks where you want PDFs saved, and
you can change that destination later. Local folders and cloud-synced folders
such as iCloud Drive, Google Drive, and Dropbox can be selected.

PrintPDF is a GPLv2 fork of Rodney I. Yager's RWTS PDFwriter, with a portable
per-user folder chooser, background file mover, updated naming, and current
macOS build fixes. Full source, licence, attribution, installer, and checksum are
available here:

[Download PrintPDF 1.0 from GitHub](https://github.com/rochakagrawal/PrintPDF#downloads)

Requirements: macOS 12 or newer, Intel or Apple Silicon.

The installer is currently unsigned because this is a free community project.
macOS will therefore block the first opening. If you trust the source and have
verified the checksum, Apple documents the per-package **Open Anyway** option
under **System Settings → Privacy & Security**:

https://support.apple.com/en-asia/guide/mac-help/mh40617/mac

You do not need to disable Gatekeeper or change global security settings. Please
do not install it on a company-managed Mac without your administrator's
approval.
