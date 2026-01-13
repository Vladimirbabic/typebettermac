#!/bin/bash
set -e

# === CONFIGURATION ===
APP_NAME="Reword"
SCHEME="Reword"
BUNDLE_ID="com.reword.app"
KEYCHAIN_PROFILE="RewordNotarize"  # Created with: xcrun notarytool store-credentials

# === PATHS ===
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
APP_PATH="$EXPORT_PATH/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"

# === COLORS ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_step() { echo -e "${GREEN}==>${NC} $1"; }
echo_warn() { echo -e "${YELLOW}Warning:${NC} $1"; }
echo_error() { echo -e "${RED}Error:${NC} $1"; exit 1; }

# === CLEANUP ===
echo_step "Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# === REGENERATE PROJECT ===
echo_step "Regenerating Xcode project..."
cd "$PROJECT_DIR"
xcodegen generate

# === BUILD ARCHIVE ===
echo_step "Building archive..."
xcodebuild -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  archive \
  | xcpretty || xcodebuild -scheme "$SCHEME" -configuration Release -archivePath "$ARCHIVE_PATH" archive

# === EXPORT APP ===
echo_step "Exporting app..."

# Create export options plist
cat > "$BUILD_DIR/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
  | xcpretty || xcodebuild -exportArchive -archivePath "$ARCHIVE_PATH" -exportPath "$EXPORT_PATH" -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist"

# === VERIFY SIGNATURE ===
echo_step "Verifying code signature..."
codesign --verify --deep --strict "$APP_PATH"
echo "  Signature: OK"

codesign -dv --verbose=2 "$APP_PATH" 2>&1 | grep "Authority"

# === NOTARIZE ===
echo_step "Submitting for notarization..."
echo "  This may take a few minutes..."

xcrun notarytool submit "$APP_PATH" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --wait

# === STAPLE ===
echo_step "Stapling notarization ticket..."
xcrun stapler staple "$APP_PATH"

# === VERIFY NOTARIZATION ===
echo_step "Verifying notarization..."
spctl --assess --type execute --verbose "$APP_PATH"

# === CREATE DMG (optional) ===
echo_step "Creating DMG..."
hdiutil create -volname "$APP_NAME" \
  -srcfolder "$APP_PATH" \
  -ov -format UDZO \
  "$DMG_PATH"

# Notarize DMG too
echo_step "Notarizing DMG..."
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --wait

xcrun stapler staple "$DMG_PATH"

# === DONE ===
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  BUILD COMPLETE${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "  App: $APP_PATH"
echo "  DMG: $DMG_PATH"
echo ""
echo "  Ready for distribution!"
