#!/bin/bash

# Builds, signs, notarizes and staples a PrintPDF installer.
# Required environment variables:
#   DEVELOPER_ID_APPLICATION
#   DEVELOPER_ID_INSTALLER
# And either:
#   NOTARY_KEYCHAIN_PROFILE
# or all three:
#   APPLE_ID
#   APPLE_TEAM_ID
#   APPLE_APP_SPECIFIC_PASSWORD

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGE="$PROJECT_DIR/PrintPDF.pkg"

export PRINTPDF_SIGN_RELEASE=1

if [ -z "${DEVELOPER_ID_APPLICATION:-}" ] || [ -z "${DEVELOPER_ID_INSTALLER:-}" ]; then
    echo "ERROR: Set DEVELOPER_ID_APPLICATION and DEVELOPER_ID_INSTALLER first." >&2
    exit 1
fi

"$SCRIPT_DIR/buildscript.sh"

if [ ! -f "$PACKAGE" ]; then
    echo "ERROR: Expected package not found: $PACKAGE" >&2
    exit 1
fi

echo "#### submitting package to Apple notarization service"
if [ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]; then
    xcrun notarytool submit "$PACKAGE" \
        --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
        --wait
else
    : "${APPLE_ID:?Set APPLE_ID or NOTARY_KEYCHAIN_PROFILE}"
    : "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID or NOTARY_KEYCHAIN_PROFILE}"
    : "${APPLE_APP_SPECIFIC_PASSWORD:?Set APPLE_APP_SPECIFIC_PASSWORD or NOTARY_KEYCHAIN_PROFILE}"

    xcrun notarytool submit "$PACKAGE" \
        --apple-id "$APPLE_ID" \
        --team-id "$APPLE_TEAM_ID" \
        --password "$APPLE_APP_SPECIFIC_PASSWORD" \
        --wait
fi

echo "#### stapling notarization ticket"
xcrun stapler staple "$PACKAGE"
xcrun stapler validate "$PACKAGE"

echo "#### validating installer signature"
pkgutil --check-signature "$PACKAGE"

# syspolicy_check is Apple's newer distribution check where available.
if command -v syspolicy_check >/dev/null 2>&1; then
    syspolicy_check distribution "$PACKAGE" || true
fi

shasum -a 256 "$PACKAGE" | tee "$PROJECT_DIR/PrintPDF-SHA256.txt"

echo "#### notarized release ready"
echo "    $PACKAGE"
echo "    $PROJECT_DIR/PrintPDF-SHA256.txt"
