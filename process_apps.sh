#!/usr/bin/env bash

# Configuration
BIN_DIR="$(dirname "$0")/bin"
OUTPUT_DIR="$(dirname "$0")/output"
mkdir -p "$BIN_DIR"
mkdir -p "$OUTPUT_DIR"

APK_KEEP_VERSION="0.18.0"
APK_KEEP_NAME="apkeep"
APK_KEEP_PATH="$BIN_DIR/$APK_KEEP_NAME"

# Detect OS and Architecture for apkeep download
OS="$(uname -s)"
ARCH="$(uname -m)"

if [ "$OS" == "Darwin" ]; then
    if [ "$ARCH" == "arm64" ]; then
        APK_KEEP_ASSET="apkeep-aarch64-apple-darwin"
    else
        APK_KEEP_ASSET="apkeep-x86_64-apple-darwin"
    fi
elif [ "$OS" == "Linux" ]; then
    APK_KEEP_ASSET="apkeep-x86_64-unknown-linux-gnu"
else
    echo "Unsupported OS: $OS"
    exit 1
fi

APK_KEEP_URL="https://github.com/EFForg/apkeep/releases/download/$APK_KEEP_VERSION/$APK_KEEP_ASSET"

# Download apkeep if not present
if [ ! -f "$APK_KEEP_PATH" ]; then
    echo "Downloading apkeep ($APK_KEEP_ASSET)..."
    # Use -f to fail on HTTP errors (e.g. 404)
    if curl -L -f -o "$APK_KEEP_PATH" "$APK_KEEP_URL"; then
        chmod +x "$APK_KEEP_PATH"
    else
        echo "Download failed."
        rm -f "$APK_KEEP_PATH"
        
        # Fallback: Check if a local binary exists (e.g. for macOS arm64 which might be missing in releases)
        LOCAL_FALLBACK="$BIN_DIR/apkeep-aarch64-apple-darwin"
        
        if [ "$OS" == "Darwin" ] && [ "$ARCH" == "arm64" ] && [ -f "$LOCAL_FALLBACK" ]; then
            echo "Using local fallback: $LOCAL_FALLBACK"
            cp "$LOCAL_FALLBACK" "$APK_KEEP_PATH"
            chmod +x "$APK_KEEP_PATH"
        else
            echo "Error: apkeep download failed."
            exit 1
        fi
    fi
fi

# Check if arguments are provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <app_id_1> [app_id_2] ..."
    echo "Example: $0 com.okampro.oksmart com.example.app"
    exit 1
fi

# Iterate through provided App IDs
for APP_ID in "$@"; do
    echo "=================================================="
    echo "Processing App: $APP_ID"
    echo "=================================================="

    # Create a temp download dir for this app
    TEMP_DOWNLOAD_DIR="$OUTPUT_DIR/temp_$APP_ID"
    rm -rf "$TEMP_DOWNLOAD_DIR"
    mkdir -p "$TEMP_DOWNLOAD_DIR"

    echo "Downloading APK..."
    "$APK_KEEP_PATH" -a "$APP_ID" "$TEMP_DOWNLOAD_DIR"

    # Find the downloaded file (APK or XAPK)
    DOWNLOADED_FILE=$(find "$TEMP_DOWNLOAD_DIR" -type f \( -name "*.apk" -o -name "*.xapk" -o -name "*.apkm" -o -name "*.apks" \) | head -n 1)

    if [ -z "$DOWNLOADED_FILE" ]; then
        echo "Error: Failed to download APK for $APP_ID"
        rm -rf "$TEMP_DOWNLOAD_DIR"
        continue
    fi

    echo "Downloaded: $DOWNLOADED_FILE"

    # Run rebuild.sh
    # We use --non-interactive mode for automation
    echo "Running patcher..."
    ./rebuild.sh --non-interactive "$DOWNLOADED_FILE" "$OUTPUT_DIR"

    if [ $? -eq 0 ]; then
        echo "Successfully processed $APP_ID"
    else
        echo "Error processing $APP_ID"
    fi

    # Cleanup temp download
    rm -rf "$TEMP_DOWNLOAD_DIR"
    echo ""
done

echo "All tasks completed. Check $OUTPUT_DIR for results."
