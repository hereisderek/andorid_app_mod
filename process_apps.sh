#!/usr/bin/env bash

# Configuration
BIN_DIR="$(dirname "$0")/bin"
OUTPUT_DIR="$(dirname "$0")/output"
mkdir -p "$BIN_DIR"
mkdir -p "$OUTPUT_DIR"

# Ensure rebuild.sh is executable
REBUILD_SCRIPT="$(dirname "$0")/rebuild.sh"
chmod +x "$REBUILD_SCRIPT"

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

# Function to setup and verify apkeep
setup_apkeep() {
    if [ -f "$APK_KEEP_PATH" ]; then
        if [[ "$OS" == "Darwin" ]]; then xattr -c "$APK_KEEP_PATH" 2>/dev/null || true; fi
        chmod +x "$APK_KEEP_PATH"
        return 0
    fi

    echo "Attempting to download apkeep ($APK_KEEP_ASSET)..."
    local max_retries=3
    local retry_delay=5
    local attempt=1
    local success=false

    while [ $attempt -le $max_retries ]; do
        echo "Download attempt $attempt of $max_retries..."
        if curl -L -f -o "$APK_KEEP_PATH" "$APK_KEEP_URL"; then
            chmod +x "$APK_KEEP_PATH"
            if [[ "$OS" == "Darwin" ]]; then xattr -c "$APK_KEEP_PATH" 2>/dev/null || true; fi
            success=true
            break
        else
            echo "Download attempt $attempt failed."
            rm -f "$APK_KEEP_PATH"
            if [ $attempt -lt $max_retries ]; then
                echo "Waiting $retry_delay seconds before next attempt..."
                sleep $retry_delay
            fi
        fi
        ((attempt++))
    done

    if [ "$success" = true ]; then
        echo "apkeep downloaded successfully."
        return 0
    else
        echo "GitHub download failed after $max_retries attempts."
        # Fallback: Check if a local binary exists
        LOCAL_FALLBACK="$BIN_DIR/apkeep-aarch64-apple-darwin"
        if [ "$OS" == "Darwin" ] && [ "$ARCH" == "arm64" ] && [ -f "$LOCAL_FALLBACK" ]; then
            echo "Using local fallback: $LOCAL_FALLBACK"
            cp "$LOCAL_FALLBACK" "$APK_KEEP_PATH"
            xattr -c "$APK_KEEP_PATH" 2>/dev/null || true
            chmod +x "$APK_KEEP_PATH"
            return 0
        else
            echo "Error: apkeep download failed and no usable fallback available."
            exit 1
        fi
    fi
}

# Usage function
usage() {
    echo "Usage: $0 [options] <app_id[@version] | local_file_path | local_directory> [...]"
    echo ""
    echo "Options:"
    echo "  -n, --non-interactive  Run in non-interactive mode"
    echo ""
    echo "Examples:"
    echo "  $0 com.okampro.oksmart@3.0.13"
    echo "  $0 ./my_app.apk"
    echo "  $0 ./my_split_apks_folder/"
    echo "  $0 com.example.app /path/to/another.xapk"
    exit 1
}

# Parse flags
REBUILD_FLAGS=""
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--non-interactive)
      REBUILD_FLAGS="--non-interactive"
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}"

if [ ${#POSITIONAL_ARGS[@]} -eq 0 ]; then
    usage
fi

# Main Processing Loop
for TARGET in "${POSITIONAL_ARGS[@]}"; do
    echo "=================================================="
    
    # Check if target is a local file or directory
    if [ -f "$TARGET" ] || [ -d "$TARGET" ]; then
        if [ -f "$TARGET" ]; then
            echo "Target identified as local file: $TARGET"
        else
            echo "Target identified as local directory (split APKs): $TARGET"
        fi
        INPUT_FILE="$TARGET"
        # Extract ID from filename/dirname or use a generic one
        APP_ID=$(basename "$TARGET" | cut -d'_' -f1 | cut -d'-' -f1 | sed 's/\.[^.]*$//')
        VERSION_NAME=""
    else
        # Target is an App ID for download
        APP_SPEC="$TARGET"
        if [[ "$APP_SPEC" == *"@"* ]]; then
            APP_ID="${APP_SPEC%@*}"
            VERSION_NAME="${APP_SPEC#*@}"
        else
            APP_ID="$APP_SPEC"
            VERSION_NAME=""
        fi

        echo "Target identified as App ID: $APP_ID"
        setup_apkeep

        # Create a temp download dir
        TEMP_DOWNLOAD_DIR="$OUTPUT_DIR/temp_$APP_ID"
        rm -rf "$TEMP_DOWNLOAD_DIR"
        mkdir -p "$TEMP_DOWNLOAD_DIR"

        echo "Downloading APK for $APP_SPEC..."
        "$APK_KEEP_PATH" -a "$APP_SPEC" "$TEMP_DOWNLOAD_DIR"

        # Find the downloaded file
        INPUT_FILE=$(find "$TEMP_DOWNLOAD_DIR" -type f \( -name "*.apk" -o -name "*.xapk" -o -name "*.apkm" -o -name "*.apks" \) | head -n 1)

        if [ -z "$INPUT_FILE" ]; then
            echo "Error: Failed to download APK for $APP_ID"
            rm -rf "$TEMP_DOWNLOAD_DIR"
            continue
        fi
        echo "Downloaded: $INPUT_FILE"
    fi

    # Load optional pins from apps.json
    PIN_VC=""
    PIN_VN=""
    if [ -f "apps.json" ]; then
        PIN_VC=$(jq -r ".apps[] | select(.id == \"$APP_ID\") | .pin_versionCode // empty" apps.json)
        PIN_VN=$(jq -r ".apps[] | select(.id == \"$APP_ID\") | .pin_versionName // empty" apps.json)
        
        [ -n "$PIN_VC" ] && echo "Found versionCode pin in apps.json: $PIN_VC"
        [ -n "$PIN_VN" ] && echo "Found versionName pin in apps.json: $PIN_VN"
    fi

    # Run rebuild.sh
    echo "Running patcher on $INPUT_FILE..."
    APP_ID="$APP_ID" VERSION="$VERSION_NAME" PIN_VERSION_CODE="$PIN_VC" PIN_VERSION_NAME="$PIN_VN" "$REBUILD_SCRIPT" $REBUILD_FLAGS "$INPUT_FILE" "$OUTPUT_DIR"

    if [ $? -eq 0 ]; then
        echo "Successfully processed $APP_ID"
    else
        echo "Error processing $APP_ID"
    fi

    # Cleanup temp download if it was a download
    if [ -n "$TEMP_DOWNLOAD_DIR" ] && [ -d "$TEMP_DOWNLOAD_DIR" ]; then
        rm -rf "$TEMP_DOWNLOAD_DIR"
        unset TEMP_DOWNLOAD_DIR
    fi
    echo ""
done

echo "All tasks completed. Check $OUTPUT_DIR for results."
