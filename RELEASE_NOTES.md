# PrintPDF 1.0

Initial PrintPDF release, based on RWTS PDFwriter 3.1d.

## Highlights

- Appears as a normal macOS printer named PrintPDF.
- Saves PDFs to a folder chosen by each user.
- Supports local and cloud-synced destination folders.
- Moves completed PDFs into the selected folder as real files instead of using
  RWTS PDFwriter's destination-folder symbolic link.
- Lets users change the destination later through PrintPDF Utility.
- Preserves existing files by adding numeric filename suffixes.
- Contains universal Intel and Apple Silicon binaries.
- Requires macOS 12 or newer.

## Distribution note

The locally produced `PrintPDF.pkg` is unsigned. It should be signed and
notarized with the publisher's Apple Developer ID before a general public
release.
