#!/bin/bash

# Builds the unsigned PrintPDF installer package.
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

cp "$SCRIPT_DIR/PDFWriter.iconset/icon_256x256.png" "$PACKAGE_TEMP/resources/background.png"
cp "$PROJECT_DIR/License" "$PACKAGE_TEMP/resources/"
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
    --version 1.0 \
    "$PACKAGE_TEMP/printpdf-component.pkg" >/dev/null

productbuild --synthesize \
    --product "$SCRIPT_DIR/requirements" \
    --package "$PACKAGE_TEMP/printpdf-component.pkg" \
    "$PACKAGE_TEMP/distribution.dist" >/dev/null

sed -i '' '3 a\
\    <title>PrintPDF</title>\
\    <background file="background.png" alignment="bottomleft" scaling="none"/>\
\    <license file="License"/>\
\    <readme file="README.rtfd"  />
' "$PACKAGE_TEMP/distribution.dist"

productbuild --distribution "$PACKAGE_TEMP/distribution.dist" \
    --package-path "$PACKAGE_TEMP" \
    --resources "$PACKAGE_TEMP/resources" \
    "$PACKAGE_TEMP/product.pkg" >/dev/null

pkgutil --expand "$PACKAGE_TEMP/product.pkg" "$PACKAGE_TEMP/expanded"
cp -R "$SCRIPT_DIR/README.rtfd" "$PACKAGE_TEMP/expanded/Resources/"
pkgutil --flatten "$PACKAGE_TEMP/expanded" "$PROJECT_DIR/PrintPDF.pkg"

echo "#### Installer package is located at"
echo "    $PROJECT_DIR/PrintPDF.pkg"
