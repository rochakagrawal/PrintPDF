# Publishing PrintPDF

PrintPDF is licensed under GNU GPL version 2. Use this checklist for every
public release.

## Required

- Publish the complete source for the exact released package.
- Include the unmodified `LICENSE` file.
- Keep `NOTICE.md` and upstream copyright notices.
- Describe PrintPDF as a modified fork of RWTS PDFwriter.
- Apply GNU GPL version 2 to the modified source.
- Publish the source archive and installer from the same release page.

Do not publish only the compiled package. A GitHub repository plus a GitHub
Release containing both `PrintPDF.pkg` and the matching source archive is the
simplest distribution arrangement.

## Developer ID signing and notarization

For public binary releases, use Apple's Developer ID and notarization service.
The repository supports both an unsigned development build and a signed,
notarized release build.

### One-time Apple setup

1. In Apple Developer Certificates, Identifiers & Profiles, create both:
   - `Developer ID Application`
   - `Developer ID Installer`
2. Install both certificates and their private keys in Keychain Access.
3. Confirm the exact identities with:

   ```bash
   security find-identity -v -p codesigning
   ```

4. Create an app-specific password for the Apple Account used with the
   notarization service, or store notarization credentials in a local
   `notarytool` keychain profile.

### Local notarized release

Set the exact certificate identities shown by Keychain Access:

```bash
export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)"
export DEVELOPER_ID_INSTALLER="Developer ID Installer: Your Name (TEAMID)"
```

For notarization, either create a keychain profile once:

```bash
xcrun notarytool store-credentials "PrintPDF-notary" \
  --apple-id "YOUR_APPLE_ID" \
  --team-id "YOUR_TEAM_ID" \
  --password "YOUR_APP_SPECIFIC_PASSWORD"
export NOTARY_KEYCHAIN_PROFILE="PrintPDF-notary"
```

or set `APPLE_ID`, `APPLE_TEAM_ID`, and `APPLE_APP_SPECIFIC_PASSWORD` as
environment variables.

Then run:

```bash
bash build/notarize-release.sh
```

The script builds PrintPDF, signs the utility and CUPS backend with the
Developer ID Application identity, signs `PrintPDF.pkg` with the Developer ID
Installer identity, submits it using `notarytool`, waits for Apple's result,
staples the ticket, validates it, and writes `PrintPDF-SHA256.txt`.

### Manual GitHub Actions release

`.github/workflows/notarized-release.yml` is intentionally manual only. It has
no push, pull request, tag, or scheduled trigger. Starting it requires opening
GitHub Actions, selecting **Build signed and notarized PrintPDF**, choosing
**Run workflow**, and typing `NOTARIZE`.

Before using it, configure these GitHub Actions repository secrets:

- `BUILD_CERTIFICATE_BASE64`: a base64-encoded PKCS#12 (`.p12`) export containing
  the Developer ID Application and Developer ID Installer certificates and
  their private keys.
- `P12_PASSWORD`: password used when exporting that `.p12`.
- `KEYCHAIN_PASSWORD`: a random password used only for the temporary CI
  keychain.
- `DEVELOPER_ID_APPLICATION`: exact Developer ID Application identity name.
- `DEVELOPER_ID_INSTALLER`: exact Developer ID Installer identity name.
- `APPLE_ID`: Apple Account used for notarization.
- `APPLE_TEAM_ID`: Apple Developer Team ID.
- `APPLE_APP_SPECIFIC_PASSWORD`: app-specific password for notarization.

The workflow creates a temporary keychain on the GitHub macOS runner, imports
the certificates, runs the signed/notarized release script, and uploads the
stapled installer plus SHA-256 file as a workflow artifact. It does not publish
a GitHub Release automatically.

## Release checklist

- Sign the utility and printer backend with Developer ID Application.
- Sign the installer with Developer ID Installer.
- Submit the installer to Apple's notarization service and require an Accepted
  result.
- Staple and validate the notarization ticket.
- Test the final stapled installer on a clean Intel Mac and a clean Apple
  Silicon Mac supported by the release.
- Publish the SHA-256 checksum.
- Publish the exact corresponding GPLv2 source alongside the installer.

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
