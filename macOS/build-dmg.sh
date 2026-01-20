#!/bin/bash
set -e

# =============================================================================
# build-dmg.sh - Create Distributable DMG
# =============================================================================
# This script creates a beautifully styled DMG from the notarized app.
# Requires: brew install create-dmg
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
REQUIRED_VARS=("APP_NAME")
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: $var is not set in .env"
        exit 1
    fi
done

# -----------------------------------------------------------------------------
# Check dependencies
# -----------------------------------------------------------------------------
if ! command -v create-dmg &> /dev/null; then
    echo "Error: create-dmg is not installed"
    echo "Please install it with: brew install create-dmg"
    exit 1
fi

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
BUILD_DIR="$SCRIPT_DIR/build"
EXPORT_PATH="$BUILD_DIR/Export"
APP_PATH="$EXPORT_PATH/$APP_NAME.app"

# Get version from app bundle
if [ -d "$APP_PATH" ]; then
    VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "1.0.0")
else
    echo "Error: App not found at $APP_PATH"
    echo "Please run ./notarize.sh first to build and notarize the app."
    exit 1
fi

DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

# -----------------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------------
log() {
    echo ""
    echo "========================================"
    echo "$1"
    echo "========================================"
}

# -----------------------------------------------------------------------------
# Main workflow
# -----------------------------------------------------------------------------

# Step 1: Verify the app exists and is notarized
log "Step 1: Verifying notarized app"
if ! xcrun stapler validate "$APP_PATH" &> /dev/null; then
    echo "Warning: App may not be properly notarized."
    echo "Consider running ./notarize.sh first."
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "App is properly notarized."
fi

# Step 2: Remove existing DMG if present
log "Step 2: Preparing DMG output"
rm -f "$DMG_PATH"

# Step 3: Create DMG
log "Step 3: Creating DMG"
echo "Building: $DMG_NAME"

create-dmg \
    --volname "$APP_NAME" \
    --volicon "$APP_PATH/Contents/Resources/AppIcon.icns" \
    --window-pos 200 120 \
    --window-size 660 400 \
    --icon-size 80 \
    --icon "$APP_NAME.app" 180 190 \
    --hide-extension "$APP_NAME.app" \
    --app-drop-link 480 190 \
    --no-internet-enable \
    "$DMG_PATH" \
    "$APP_PATH"

echo "DMG created at: $DMG_PATH"

# Step 4: Sign the DMG (optional, but recommended)
log "Step 4: Signing DMG"
if [ -n "$IDENTITY" ]; then
    codesign --force --sign "$IDENTITY" "$DMG_PATH"
    echo "DMG signed with: $IDENTITY"
else
    echo "Skipping DMG signing (IDENTITY not set in .env)"
    echo "The DMG will still work, but signing is recommended for distribution."
fi

# Step 5: Notarize the DMG
log "Step 5: Notarizing DMG"
if [ -n "$APPLE_ID" ] && [ -n "$APP_PASSWORD" ] && [ -n "$TEAM_ID" ]; then
    echo "Submitting DMG to Apple notarization service..."
    echo "This may take several minutes..."

    xcrun notarytool submit "$DMG_PATH" \
        --apple-id "$APPLE_ID" \
        --password "$APP_PASSWORD" \
        --team-id "$TEAM_ID" \
        --wait

    echo "Stapling notarization ticket to DMG..."
    xcrun stapler staple "$DMG_PATH"

    echo "DMG notarized successfully."
else
    echo "Skipping DMG notarization (credentials not set in .env)"
fi

# -----------------------------------------------------------------------------
# Success
# -----------------------------------------------------------------------------
log "DMG Build Complete!"
echo ""
echo "The distributable DMG is ready at:"
echo "  $DMG_PATH"
echo ""
echo "File size: $(du -h "$DMG_PATH" | cut -f1)"
echo ""
echo "Next steps:"
echo "  1. Run ./check-dmg.sh to verify the DMG"
echo "  2. Test the DMG by double-clicking to mount it"
echo "  3. Upload to your distribution platform"
echo ""
