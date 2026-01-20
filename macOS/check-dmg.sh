#!/bin/bash

# =============================================================================
# check-dmg.sh - DMG Verification Script
# =============================================================================
# This script verifies the code signing and notarization status of the DMG
# and the app inside it.
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
if [ -z "$APP_NAME" ]; then
    echo "Error: APP_NAME is not set in .env"
    exit 1
fi

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
BUILD_DIR="$SCRIPT_DIR/build"
EXPORT_PATH="$BUILD_DIR/Export"
APP_PATH="$EXPORT_PATH/$APP_NAME.app"

# Find the DMG file
DMG_PATH=$(ls -t "$BUILD_DIR"/*.dmg 2>/dev/null | head -1)

# -----------------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------------
log() {
    echo ""
    echo "========================================"
    echo "$1"
    echo "========================================"
}

check_result() {
    if [ $? -eq 0 ]; then
        echo "  [PASS] $1"
        return 0
    else
        echo "  [FAIL] $1"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Checks
# -----------------------------------------------------------------------------
PASS_COUNT=0
FAIL_COUNT=0

# Check 1: Verify exported app exists
log "Check 1: Exported App"
if [ -d "$APP_PATH" ]; then
    echo "  [PASS] App found at: $APP_PATH"
    ((PASS_COUNT++))
else
    echo "  [FAIL] App not found at: $APP_PATH"
    echo "  Please run ./notarize.sh first."
    ((FAIL_COUNT++))
fi

# Check 2: App code signature
log "Check 2: App Code Signature"
if [ -d "$APP_PATH" ]; then
    if codesign --verify --deep --strict "$APP_PATH" 2>/dev/null; then
        echo "  [PASS] App code signature is valid"
        ((PASS_COUNT++))

        # Show signing details
        echo ""
        echo "  Signing details:"
        codesign -dv "$APP_PATH" 2>&1 | grep -E "(Authority|TeamIdentifier|Identifier)" | sed 's/^/    /'
    else
        echo "  [FAIL] App code signature is invalid"
        codesign --verify --deep --strict "$APP_PATH" 2>&1 | sed 's/^/    /'
        ((FAIL_COUNT++))
    fi
else
    echo "  [SKIP] App not found"
fi

# Check 3: App notarization (stapler)
log "Check 3: App Notarization (Stapler)"
if [ -d "$APP_PATH" ]; then
    if xcrun stapler validate "$APP_PATH" 2>/dev/null; then
        echo "  [PASS] App has valid notarization ticket stapled"
        ((PASS_COUNT++))
    else
        echo "  [FAIL] App does not have a valid notarization ticket"
        echo "  Please run ./notarize.sh to notarize the app."
        ((FAIL_COUNT++))
    fi
else
    echo "  [SKIP] App not found"
fi

# Check 4: Gatekeeper assessment for app
log "Check 4: Gatekeeper Assessment (App)"
if [ -d "$APP_PATH" ]; then
    if spctl --assess --type execute "$APP_PATH" 2>/dev/null; then
        echo "  [PASS] App passes Gatekeeper assessment"
        ((PASS_COUNT++))
    else
        echo "  [FAIL] App fails Gatekeeper assessment"
        spctl --assess --type execute -vv "$APP_PATH" 2>&1 | sed 's/^/    /'
        ((FAIL_COUNT++))
    fi
else
    echo "  [SKIP] App not found"
fi

# Check 5: DMG exists
log "Check 5: DMG File"
if [ -n "$DMG_PATH" ] && [ -f "$DMG_PATH" ]; then
    echo "  [PASS] DMG found at: $DMG_PATH"
    echo "  File size: $(du -h "$DMG_PATH" | cut -f1)"
    ((PASS_COUNT++))
else
    echo "  [FAIL] No DMG found in $BUILD_DIR"
    echo "  Please run ./build-dmg.sh to create the DMG."
    ((FAIL_COUNT++))
fi

# Check 6: DMG code signature
log "Check 6: DMG Code Signature"
if [ -n "$DMG_PATH" ] && [ -f "$DMG_PATH" ]; then
    if codesign --verify "$DMG_PATH" 2>/dev/null; then
        echo "  [PASS] DMG code signature is valid"
        ((PASS_COUNT++))

        # Show signing details
        echo ""
        echo "  Signing details:"
        codesign -dv "$DMG_PATH" 2>&1 | grep -E "(Authority|TeamIdentifier)" | sed 's/^/    /'
    else
        echo "  [WARN] DMG is not signed (optional)"
        echo "  The DMG will still work, but signing is recommended."
    fi
else
    echo "  [SKIP] DMG not found"
fi

# Check 7: DMG notarization
log "Check 7: DMG Notarization (Stapler)"
if [ -n "$DMG_PATH" ] && [ -f "$DMG_PATH" ]; then
    if xcrun stapler validate "$DMG_PATH" 2>/dev/null; then
        echo "  [PASS] DMG has valid notarization ticket stapled"
        ((PASS_COUNT++))
    else
        echo "  [WARN] DMG does not have a notarization ticket (optional)"
        echo "  The app inside is notarized, so this is usually fine."
    fi
else
    echo "  [SKIP] DMG not found"
fi

# Check 8: Mount and verify DMG contents
log "Check 8: DMG Contents Verification"
if [ -n "$DMG_PATH" ] && [ -f "$DMG_PATH" ]; then
    # Create a temporary mount point
    MOUNT_POINT=$(mktemp -d)

    # Mount the DMG
    if hdiutil attach "$DMG_PATH" -mountpoint "$MOUNT_POINT" -nobrowse -quiet 2>/dev/null; then
        DMG_APP="$MOUNT_POINT/$APP_NAME.app"

        if [ -d "$DMG_APP" ]; then
            echo "  [PASS] App found inside DMG"
            ((PASS_COUNT++))

            # Verify the app inside DMG
            if spctl --assess --type execute "$DMG_APP" 2>/dev/null; then
                echo "  [PASS] App inside DMG passes Gatekeeper assessment"
                ((PASS_COUNT++))
            else
                echo "  [FAIL] App inside DMG fails Gatekeeper assessment"
                ((FAIL_COUNT++))
            fi
        else
            echo "  [FAIL] App not found inside DMG"
            ((FAIL_COUNT++))
        fi

        # Unmount the DMG
        hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null
    else
        echo "  [FAIL] Could not mount DMG"
        ((FAIL_COUNT++))
    fi

    # Clean up mount point
    rmdir "$MOUNT_POINT" 2>/dev/null
else
    echo "  [SKIP] DMG not found"
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
log "Verification Summary"
echo ""
echo "  Passed: $PASS_COUNT"
echo "  Failed: $FAIL_COUNT"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo "All checks passed! The DMG is ready for distribution."
    exit 0
else
    echo "Some checks failed. Please review the issues above."
    exit 1
fi
