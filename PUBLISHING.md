# Publishing PrintPDF

PrintPDF is licensed under GNU GPL version 2. Use this checklist for every
public release.

## Required

- Publish the complete source for the exact released package.
- Include the unmodified `License` file.
- Keep `NOTICE.md` and upstream copyright notices.
- Describe PrintPDF as a modified fork of RWTS PDFwriter.
- Apply GNU GPL version 2 to the modified source.
- Publish the source archive and installer from the same release page.

Do not publish only the compiled package. A GitHub repository plus a GitHub
Release containing both `PrintPDF.pkg` and the matching source archive is the
simplest distribution arrangement.

## Recommended before sharing widely

- Join the Apple Developer Program.
- Sign the utility and printer backend with your Developer ID Application
  identity.
- Sign the installer with your Developer ID Installer identity.
- Submit the installer to Apple's notarization service and staple the result.
- Test the final stapled installer on a clean Intel Mac and a clean Apple
  Silicon Mac supported by the release.
- Publish the SHA-256 checksum from the release build.

Never instruct users to disable macOS security protections. Until signing and
notarization are complete, label the package clearly as an unsigned development
build.

## Safe unsigned-install instructions

After attempting to open the package once, users can open **System Settings →
Privacy & Security**, scroll to **Security**, and select **Open Anyway**. They
then authenticate and confirm **Open**. Link to Apple's instructions rather
than suggesting Terminal commands:

https://support.apple.com/en-asia/guide/mac-help/mh40617/mac

Tell users not to disable Gatekeeper, alter global security policy, run
`spctl --master-disable`, or strip quarantine attributes. Managed Macs may not
permit the exception.

## Suggested repository description

> A macOS virtual printer that saves PDFs to a folder chosen by each user. A
> GPLv2 fork of RWTS PDFwriter.
