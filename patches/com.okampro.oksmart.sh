#!/usr/bin/env bash

TARGET_DIR="$1"
VERSION_CODE="$2"
EXIT_CODE=0

if [ -z "$TARGET_DIR" ]; then
    echo "Error: $(basename "$0") requires a directory argument"
    exit 1
fi

echo "Applying patches for com.okampro.oksmart (Version: ${VERSION_CODE:-unknown})..."

# --- Helper Functions ---
# Load shared utilities
UTILS_SH="$(dirname "$0")/util/utils.sh"
if [ -f "$UTILS_SH" ]; then
    source "$UTILS_SH"
else
    echo "Error: Shared utilities not found at $UTILS_SH"
    exit 1
fi

# --- Version Specific Patches ---

# Previous known version patch
patch_v1() {
    local so_file="${TARGET_DIR}/root/lib/armeabi-v7a/libOKSMARTJIAMI.so"
    local res=0
    
    # Existing SO patch
    apply_hex_patch "libOKSMARTJIAMI (v1)" "$so_file" \
        "28 46 41 46 ff f7 ce ec 00 28 08 bf" \
        "28 46 41 46 00 bf 00 bf 00 28 08 bf" || res=1
    return $res
}

patch_remove() {
    local so_file="${TARGET_DIR}/root/lib/armeabi-v7a/libOKSMARTJIAMI.so"
    local res=0
    # AppCrypto patches
    echo "  Applying AppCrypto bypasses..."
    patch_smali_return_input "com/vstarcam/AppCrypto" "decrypt" || res=1
    patch_smali_return_input "com/vstarcam/AppCrypto" "decryptOld" || res=1
    patch_smali_return_input "com/vstarcam/AppCrypto" "deviceKey" || res=1
    patch_smali_return_input "com/vstarcam/AppCrypto" "encrypt" || res=1
    
    return $res
}

# --- Main Logic ---

# 1. Try version-specific patches if version is known
MATCHED=false
if [ -n "$VERSION_CODE" ]; then
    case "$VERSION_CODE" in
        "51"|"50") # 51 is v3.0.13
            patch_v1 && MATCHED=true
            ;;

        "52") # 51 is v3.0.13
            patch_v1 && MATCHED=true
            ;;
        # Add more mappings as they are discovered
    esac
fi

# 2. If no version match OR version-specific patch failed, try all known patches
if [ "$MATCHED" = false ]; then
    echo "  No version-specific match. Trying all available patches..."
    
    # Try v1
    if patch_v1; then
        echo "  Successfully applied v1 patch."
        MATCHED=true
    fi

    if patch_remove; then
        echo "  Successfully applied removal patches."
        MATCHED=true
    fi
    
    # Try more here as they are added
    # if [ "$MATCHED" = false ] && patch_v2; then MATCHED=true; fi
fi

if [ "$MATCHED" = false ]; then
    echo "  Error: No applicable patches found for com.okampro.oksmart."
    EXIT_CODE=1
fi

exit $EXIT_CODE
