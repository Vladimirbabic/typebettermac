#!/bin/bash

# Sign Update Script for TypeBetter
# Usage: ./sign_update.sh path/to/TypeBetter-X.X.zip

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
KEYS_DIR="$PROJECT_DIR/SparkleKeys"
PRIVATE_KEY="$KEYS_DIR/eddsa_private_key"

if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-update.zip>"
    echo ""
    echo "Example: $0 ~/Desktop/TypeBetter-1.1.zip"
    exit 1
fi

UPDATE_FILE="$1"

if [ ! -f "$UPDATE_FILE" ]; then
    echo "Error: File not found: $UPDATE_FILE"
    exit 1
fi

if [ ! -f "$PRIVATE_KEY" ]; then
    echo "Error: Private key not found at $PRIVATE_KEY"
    echo "Run setup_sparkle.sh first to generate keys."
    exit 1
fi

# Find sign_update tool
SIGN_UPDATE=""
if [ -f "/usr/local/bin/sign_update" ]; then
    SIGN_UPDATE="/usr/local/bin/sign_update"
elif [ -d "$HOME/Library/Developer/Xcode/DerivedData" ]; then
    SIGN_UPDATE=$(find "$HOME/Library/Developer/Xcode/DerivedData" -name "sign_update" -type f 2>/dev/null | head -1)
fi

if [ -z "$SIGN_UPDATE" ] || [ ! -f "$SIGN_UPDATE" ]; then
    echo "Sparkle sign_update tool not found."
    echo "Build the project in Xcode first, then try again."
    exit 1
fi

echo "Signing: $UPDATE_FILE"
echo ""

# Get file size
FILE_SIZE=$(ls -l "$UPDATE_FILE" | awk '{print $5}')

# Sign the update
SIGNATURE=$("$SIGN_UPDATE" "$UPDATE_FILE" -f "$PRIVATE_KEY" 2>&1)

echo "=== Update Signed Successfully ==="
echo ""
echo "File: $(basename "$UPDATE_FILE")"
echo "Size: $FILE_SIZE bytes"
echo ""
echo "Add this to your appcast.xml:"
echo ""
echo "<enclosure"
echo "    url=\"https://typebetter.app/downloads/$(basename "$UPDATE_FILE")\""
echo "    sparkle:edSignature=\"$SIGNATURE\""
echo "    length=\"$FILE_SIZE\""
echo "    type=\"application/octet-stream\"/>"
echo ""
