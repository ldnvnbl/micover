#!/bin/bash
set -e

cd "$(dirname "$0")"

DERIVED_DATA_PATH=".build/DerivedData"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug/MicOver.app"

echo "🔨 Building macOS app..."
xcodebuild -workspace MicOver.xcworkspace -scheme macOS -configuration Debug -derivedDataPath "$DERIVED_DATA_PATH" build 2>&1 | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)" | head -20

echo "🛑 Killing existing MicOver..."
pkill -x MicOver 2>/dev/null || true

echo "🚀 Launching MicOver..."
open "$APP_PATH"
