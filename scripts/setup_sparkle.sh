#!/bin/bash

# Sparkle Setup Script for TypeBetter
# This script generates signing keys for Sparkle updates

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
KEYS_DIR="$PROJECT_DIR/SparkleKeys"

echo "=== Sparkle Setup for TypeBetter ==="
echo ""

# Create keys directory
mkdir -p "$KEYS_DIR"

# Check if Sparkle is in DerivedData (after building the project)
SPARKLE_BIN=""

# Try to find generate_keys in common locations
if [ -f "/usr/local/bin/generate_keys" ]; then
    SPARKLE_BIN="/usr/local/bin/generate_keys"
elif [ -d "$HOME/Library/Developer/Xcode/DerivedData" ]; then
    SPARKLE_BIN=$(find "$HOME/Library/Developer/Xcode/DerivedData" -name "generate_keys" -type f 2>/dev/null | head -1)
fi

if [ -z "$SPARKLE_BIN" ] || [ ! -f "$SPARKLE_BIN" ]; then
    echo "Sparkle generate_keys tool not found."
    echo ""
    echo "Please follow these steps:"
    echo "1. Open the project in Xcode"
    echo "2. Build the project once (Cmd+B) to download Sparkle"
    echo "3. Run this script again"
    echo ""
    echo "Alternatively, download Sparkle manually:"
    echo "  https://github.com/sparkle-project/Sparkle/releases"
    echo "  Extract and use bin/generate_keys"
    exit 1
fi

echo "Found Sparkle tools at: $SPARKLE_BIN"
echo ""

# Check if keys already exist
if [ -f "$KEYS_DIR/eddsa_private_key" ]; then
    echo "Keys already exist in $KEYS_DIR"
    echo ""
    echo "Your public key (add this to Info.plist as SUPublicEDKey):"
    cat "$KEYS_DIR/eddsa_public_key"
    echo ""
    exit 0
fi

# Generate new keys
echo "Generating new EdDSA signing keys..."
cd "$KEYS_DIR"
"$SPARKLE_BIN" -p eddsa_private_key > eddsa_public_key 2>&1 || {
    # If that fails, try without -p flag
    "$SPARKLE_BIN" > key_output.txt 2>&1
    # Parse the output
    grep -A1 "Private" key_output.txt | tail -1 > eddsa_private_key 2>/dev/null || true
    grep -A1 "Public" key_output.txt | tail -1 > eddsa_public_key 2>/dev/null || true
    rm -f key_output.txt
}

if [ -f "$KEYS_DIR/eddsa_private_key" ] && [ -s "$KEYS_DIR/eddsa_private_key" ]; then
    echo ""
    echo "=== Keys Generated Successfully ==="
    echo ""
    echo "Private key saved to: $KEYS_DIR/eddsa_private_key"
    echo "  KEEP THIS SECRET! Do not commit to git!"
    echo ""
    echo "Public key (add this to Info.plist as SUPublicEDKey):"
    cat "$KEYS_DIR/eddsa_public_key"
    echo ""
    echo "Add to .gitignore:"
    echo "  SparkleKeys/"
    echo ""
else
    echo "Key generation may have failed. Check $KEYS_DIR for output."
fi
