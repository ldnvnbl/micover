#!/bin/bash
set -e

# =============================================================================
# notarize.sh - macOS App Notarization Workflow
# =============================================================================
# This script archives the app, exports it with Developer ID signing,
# submits it to Apple's notarization service, and staples the ticket.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# -----------------------------------------------------------------------------
# Load environment variables
# -----------------------------------------------------------------------------
if [ ! -f ".env" ]; then
    echo "Error: .env file not found in $SCRIPT_DIR"
    echo "Please copy .env.example to .env and fill in your credentials."
    exit 1
fi

source .env

# Validate required environment variables
REQUIRED_VARS=("APPLE_ID" "APP_PASSWORD" "TEAM_ID" "APP_NAME")
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: $var is not set in .env"
        exit 1
    fi
done

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
WORKSPACE="$SCRIPT_DIR/../MicOver.xcworkspace"
SCHEME="macOS"
CONFIGURATION="Release"

BUILD_DIR="$SCRIPT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_PATH="$BUILD_DIR/Export"
APP_PATH="$EXPORT_PATH/$APP_NAME.app"
ZIP_PATH="$BUILD_DIR/$APP_NAME.zip"

# -----------------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------------
log() {
    echo ""
    echo "========================================"
    echo "$1"
    echo "========================================"
}

cleanup() {
    log "Cleaning up temporary files..."
    rm -f "$ZIP_PATH"
    echo "Done."
}

# -----------------------------------------------------------------------------
# Main workflow
# -----------------------------------------------------------------------------

# Step 1: Clean build directory
log "Step 1: Preparing build directory"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Step 2: Archive the app
log "Step 2: Archiving $APP_NAME (Release configuration)"
xcodebuild archive \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH" \
    -quiet

echo "Archive created at: $ARCHIVE_PATH"

# Step 3: Export the archive
log "Step 3: Exporting signed app"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "ExportOptions.plist" \
    -quiet

echo "App exported to: $APP_PATH"

# Verify the app was exported
if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found at $APP_PATH"
    exit 1
fi

# Step 4: Create zip for notarization
log "Step 4: Creating zip archive for notarization"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
echo "Zip created at: $ZIP_PATH"

# Step 5: Submit to notarization service
log "Step 5: Submitting to Apple notarization service"
echo "This may take several minutes..."

xcrun notarytool submit "$ZIP_PATH" \
    --apple-id "$APPLE_ID" \
    --password "$APP_PASSWORD" \
    --team-id "$TEAM_ID" \
    --wait

# Step 6: Staple the notarization ticket
log "Step 6: Stapling notarization ticket"
xcrun stapler staple "$APP_PATH"

# Verify stapling
echo ""
echo "Verifying stapled app..."
xcrun stapler validate "$APP_PATH"

# Step 7: Cleanup
cleanup

# -----------------------------------------------------------------------------
# Success
# -----------------------------------------------------------------------------
log "Notarization Complete!"
echo ""
echo "The notarized app is ready at:"
echo "  $APP_PATH"
echo ""
echo "Next steps:"
echo "  1. Run ./build-dmg.sh to create a distributable DMG"
echo "  2. Run ./check-dmg.sh to verify the DMG"
echo ""
