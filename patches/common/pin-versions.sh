#!/usr/bin/env bash

TARGET_DIR="$1"
VERSION_CODE="$2"
MANIFEST_FILE="${TARGET_DIR}/AndroidManifest.xml"

if [ ! -f "$MANIFEST_FILE" ]; then
    exit 0
fi

# Pin Version Code
if [ -n "$PIN_VERSION_CODE" ]; then
    echo "  Pinning versionCode to $PIN_VERSION_CODE..."
    perl -i -pe "s/versionCode=\"[^\"]*\"/versionCode=\"$PIN_VERSION_CODE\"/" "$MANIFEST_FILE"
fi

# Pin Version Name
if [ -n "$PIN_VERSION_NAME" ]; then
    echo "  Pinning versionName to $PIN_VERSION_NAME..."
    perl -i -pe "s/versionName=\"[^\"]*\"/versionName=\"$PIN_VERSION_NAME\"/" "$MANIFEST_FILE"
fi

exit 0
