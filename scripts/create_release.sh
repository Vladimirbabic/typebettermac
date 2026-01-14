#!/bin/bash

# Create Release Script for TypeBetter
# This script builds, signs, and packages a release for GitHub Releases

set -e

# === CONFIGURATION ===
# Set your GitHub repo (or use environment variable)
GITHUB_REPO="${GITHUB_REPO:-Vladimirbabic/typebettermac}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RELEASES_DIR="$PROJECT_DIR/Releases"
KEYS_DIR="$PROJECT_DIR/SparkleKeys"

echo "=== TypeBetter Release Builder ==="
echo ""
echo "GitHub Repo: $GITHUB_REPO"
echo ""

# Get version from Info.plist
VERSION=$(defaults read "$PROJECT_DIR/Reword/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0")
BUILD=$(defaults read "$PROJECT_DIR/Reword/Info.plist" CFBundleVersion 2>/dev/null || echo "1")

echo "Current version: $VERSION (build $BUILD)"
echo ""

# Create releases directory
mkdir -p "$RELEASES_DIR"

# Check for built app
APP_PATH=""
ARCHIVE_PATH=""

# Look in common build locations
if [ -d "$PROJECT_DIR/build/Release/TypeBetter.app" ]; then
    APP_PATH="$PROJECT_DIR/build/Release/TypeBetter.app"
elif [ -d "/tmp/TypeBetter.app" ]; then
    APP_PATH="/tmp/TypeBetter.app"
fi

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "No built app found."
    echo ""
    echo "Please build the app first:"
    echo "  1. Open Xcode"
    echo "  2. Select 'Any Mac' as destination"
    echo "  3. Product → Archive"
    echo "  4. Distribute App → Copy App"
    echo "  5. Save to: $PROJECT_DIR/build/Release/"
    echo ""
    echo "Or build from command line:"
    echo "  xcodebuild -project Reword.xcodeproj -scheme TypeBetter -configuration Release build CONFIGURATION_BUILD_DIR=$PROJECT_DIR/build/Release"
    exit 1
fi

echo "Found app at: $APP_PATH"

# Create zip
ZIP_NAME="TypeBetter-$VERSION.zip"
ZIP_PATH="$RELEASES_DIR/$ZIP_NAME"

echo "Creating zip: $ZIP_NAME"
cd "$(dirname "$APP_PATH")"
ditto -c -k --keepParent "$(basename "$APP_PATH")" "$ZIP_PATH"

# Get file size
FILE_SIZE=$(ls -l "$ZIP_PATH" | awk '{print $5}')
echo "Zip size: $FILE_SIZE bytes"

# Sign if keys exist
if [ -f "$KEYS_DIR/eddsa_private_key" ]; then
    echo ""
    echo "Signing update..."

    # Find sign_update tool
    SIGN_UPDATE=$(find "$HOME/Library/Developer/Xcode/DerivedData" -name "sign_update" -type f 2>/dev/null | head -1)

    if [ -n "$SIGN_UPDATE" ] && [ -f "$SIGN_UPDATE" ]; then
        SIGNATURE=$("$SIGN_UPDATE" "$ZIP_PATH" -f "$KEYS_DIR/eddsa_private_key" 2>&1)

        echo ""
        echo "=== Release Created Successfully ==="
        echo ""
        echo "File: $ZIP_PATH"
        echo "Size: $FILE_SIZE bytes"
        GITHUB_DOWNLOAD_URL="https://github.com/$GITHUB_REPO/releases/download/v$VERSION/$ZIP_NAME"

        echo ""
        echo "=== NEXT STEPS ==="
        echo ""
        echo "1. Add this to appcast.xml:"
        echo ""
        cat << EOF
<item>
    <title>Version $VERSION</title>
    <description><![CDATA[
        <h2>What's New</h2>
        <ul>
            <li>Update description here</li>
        </ul>
    ]]></description>
    <pubDate>$(date -R)</pubDate>
    <sparkle:version>$BUILD</sparkle:version>
    <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
    <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
    <enclosure
        url="$GITHUB_DOWNLOAD_URL"
        sparkle:edSignature="$SIGNATURE"
        length="$FILE_SIZE"
        type="application/octet-stream"/>
</item>
EOF
        echo ""
        echo "2. Create GitHub Release:"
        echo "   gh release create v$VERSION '$ZIP_PATH' --title 'v$VERSION' --notes 'Release notes here'"
        echo ""
        echo "3. Commit and push appcast.xml to your repo"
        echo ""
    else
        echo ""
        echo "sign_update tool not found. Build the project in Xcode first."
        echo "Zip created at: $ZIP_PATH"
    fi
else
    echo ""
    echo "No signing keys found. Run setup_sparkle.sh first."
    echo "Zip created at: $ZIP_PATH (unsigned)"
fi
