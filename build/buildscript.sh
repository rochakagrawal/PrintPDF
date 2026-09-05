#!/bin/bash

# Builds PrintPDF. By default this creates an unsigned installer package.
# Set PRINTPDF_SIGN_RELEASE=1 plus Developer ID identities to produce a
# Developer ID signed package suitable for Apple notarization.
# Based on RWTS PDFwriter's build script by Rodney I. Yager.

set -euo pipefail
export COPYFILE_DISABLE=1

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_TEMP="$(mktemp -d /tmp/PrintPDF-build.XXXXXX)"
PACKAGE_TEMP="$(mktemp -d /tmp/PrintPDF-package.XXXXXX)"

cleanup() {
    rm -rf "$BUILD_TEMP" "$PACKAGE_TEMP"
}
trap cleanup EXIT

PDFWRITERDIR="$PACKAGE_TEMP/pkgroot/Library/Printers/PrintPDF"
UTILITIESDIR="$PDFWRITERDIR/Utilities"
PPDDIR="$PACKAGE_TEMP/pkgroot/Library/Printers/PPDs/Contents/Resources"
UTILITYAPP="PrintPDF Utility.app"
PDFWRITER="pdfwriter"
BUILDTEMP="$BUILD_TEMP/Install"
SIGN_RELEASE="${PRINTPDF_SIGN_RELEASE:-0}"
APP_IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
INSTALLER_IDENTITY="${DEVELOPER_ID_INSTALLER:-}"

if [ "$SIGN_RELEASE" = "1" ]; then
    if [ -z "$APP_IDENTITY" ] || [ -z "$INSTALLER_IDENTITY" ]; then
        echo "ERROR: Signed release requires DEVELOPER_ID_APPLICATION and DEVELOPER_ID_INSTALLER." >&2
        exit 1
    fi
fi

echo "#### building PrintPDF (this may take some time)"
xcodebuild -project "$PROJECT_DIR/PDFWriter.xcodeproj" \
    -alltargets archive -jobs 1 \
    CODE_SIGNING_ALLOWED=NO \
    MACOSX_DEPLOYMENT_TARGET=12.0 \
    OBJROOT="$BUILD_TEMP/Intermediates" \
    SYMROOT="$BUILD_TEMP/Products" \
    DSTROOT="$BUILDTEMP" \
    > "$SCRIPT_DIR/build.log" 2>&1

echo "#### constructing installer package"
mkdir -p "$PDFWRITERDIR" "$UTILITIESDIR" "$PPDDIR" \
    "$PACKAGE_TEMP/resources" "$PACKAGE_TEMP/scripts"
chmod 755 "$PDFWRITERDIR" "$UTILITIESDIR" "$PPDDIR"

mv "$BUILDTEMP/$PDFWRITER" "$PDFWRITERDIR/"
mv "$BUILDTEMP/$UTILITYAPP" "$UTILITIESDIR/"
cp "$UTILITIESDIR/$UTILITYAPP/Contents/Resources/AppIcon.icns" "$PDFWRITERDIR/PrintPDF.icns"
cp "$SCRIPT_DIR/uninstall" "$SCRIPT_DIR/PDFfolder.png" \
    "$SCRIPT_DIR/pdfwriter-mover.sh" "$PDFWRITERDIR/"
ppdc -d "$PPDDIR" -z "$SCRIPT_DIR/PDFWriter.drv"

chmod 700 "$PDFWRITERDIR/$PDFWRITER"
chmod 755 "$PDFWRITERDIR/uninstall" "$PDFWRITERDIR/pdfwriter-mover.sh" \
    "$SCRIPT_DIR/postinstall" "$SCRIPT_DIR/preinstall"

if [ "$SIGN_RELEASE" = "1" ]; then
    echo "#### signing executable components"
    codesign --force --timestamp --options runtime \
        --sign "$APP_IDENTITY" \
        "$PDFWRITERDIR/$PDFWRITER"

    codesign --force --timestamp --options runtime \
        --sign "$APP_IDENTITY" \
        "$UTILITIESDIR/$UTILITYAPP"

    codesign --verify --strict --verbose=2 "$PDFWRITERDIR/$PDFWRITER"
    codesign --verify --deep --strict --verbose=2 "$UTILITIESDIR/$UTILITYAPP"
fi

cp "$SCRIPT_DIR/PDFWriter.iconset/icon_256x256.png" "$PACKAGE_TEMP/resources/background.png"
cp "$PROJECT_DIR/LICENSE" "$PACKAGE_TEMP/resources/"
cp "$SCRIPT_DIR/postinstall" "$SCRIPT_DIR/preinstall" "$PACKAGE_TEMP/scripts/"

# Prevent Finder metadata and provenance attributes from becoming AppleDouble
# files in the installer payload.
xattr -cr "$PACKAGE_TEMP/pkgroot" || true
dot_clean -m "$PACKAGE_TEMP/pkgroot" || true

pkgbuild --root "$PACKAGE_TEMP/pkgroot" \
    --component-plist "$SCRIPT_DIR/component" \
    --identifier com.printpdf.pkg \
    --ownership recommended \
    --scripts "$PACKAGE_TEMP/scripts" \
    --version 1.1 \
    "$PACKAGE_TEMP/printpdf-component.pkg" >/dev/null

productbuild --synthesize \
    --product "$SCRIPT_DIR/requirements" \
    --package "$PACKAGE_TEMP/printpdf-component.pkg" \
    "$PACKAGE_TEMP/distribution.dist" >/dev/null

sed -i '' '3 a\
\    <title>PrintPDF</title>\
\    <background file="background.png" alignment="bottomleft" scaling="none"/>\
\    <license file="LICENSE"/>\
\    <readme file="README.rtfd"  />
' "$PACKAGE_TEMP/distribution.dist"

productbuild --distribution "$PACKAGE_TEMP/distribution.dist" \
    --package-path "$PACKAGE_TEMP" \
    --resources "$PACKAGE_TEMP/resources" \
    "$PACKAGE_TEMP/product.pkg" >/dev/null

pkgutil --expand "$PACKAGE_TEMP/product.pkg" "$PACKAGE_TEMP/expanded"
cp -R "$SCRIPT_DIR/README.rtfd" "$PACKAGE_TEMP/expanded/Resources/"
pkgutil --flatten "$PACKAGE_TEMP/expanded" "$PACKAGE_TEMP/PrintPDF-unsigned.pkg"

if [ "$SIGN_RELEASE" = "1" ]; then
    echo "#### signing installer package"
    productsign --sign "$INSTALLER_IDENTITY" \
        "$PACKAGE_TEMP/PrintPDF-unsigned.pkg" \
        "$PROJECT_DIR/PrintPDF.pkg"
    pkgutil --check-signature "$PROJECT_DIR/PrintPDF.pkg"
else
    mv "$PACKAGE_TEMP/PrintPDF-unsigned.pkg" "$PROJECT_DIR/PrintPDF.pkg"
fi

echo "#### Installer package is located at"
echo "    $PROJECT_DIR/PrintPDF.pkg"
