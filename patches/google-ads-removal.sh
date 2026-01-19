#!/usr/bin/env bash

TARGET_DIR="$1"
VERSION_CODE="$2"

if [ -z "$TARGET_DIR" ]; then
    echo "Error: $(basename "$0") requires a directory argument"
    exit 1
fi

echo "Disabling Google Ads in $TARGET_DIR (Version: ${VERSION_CODE:-unknown})..."

# --- Helper Functions ---

remove_from_manifest() {
    local label="$1"
    local search_pattern="$2"
    local manifest_file="${TARGET_DIR}/AndroidManifest.xml"

    if [ -f "$manifest_file" ]; then
        echo "  Removing $label from AndroidManifest.xml..."
        perl -i -0777 -pe "s/\s*<activity[^>]*${search_pattern}[^>]*\/>//gs" "$manifest_file"
        perl -i -0777 -pe "s/\s*<provider[^>]*${search_pattern}[^>]*\/>//gs" "$manifest_file"
    fi
}

patch_smali_method() {
    local label="$1"
    local method_signature="$2"
    
    echo "  Patching Smali for $label..."
    find "$TARGET_DIR" -maxdepth 1 -name "smali*" -type d | while read -r smali_dir; do
        grep -lR "$method_signature" "$smali_dir" 2>/dev/null | while read -r file; do
            echo "    Disabling in $(basename "$file")"
            # escape parenthesis for perl regex if needed, but signature here is literal
            # We use a safer approach for the regex
            perl -i -0777 -pe "s/(\.method public (static )?$(echo "$method_signature" | sed 's/[]\/()$*.^|]/\\&/g'))([\s\S]*?)(\.end method)/\$1\n    .locals 0\n    return-void\n\$4/g" "$file"
        done
    done
}

# --- Patch Sets ---

patch_ads_v1() {
    remove_from_manifest "AdActivity" "com\.google\.android\.gms\.ads\.AdActivity"
    remove_from_manifest "MobileAdsInitProvider" "com\.google\.android\.gms\.ads\.MobileAdsInitProvider"

    patch_smali_method "AdView.loadAd" "loadAd(Lcom/google/android/gms/ads/AdRequest;)V"
    patch_smali_method "InterstitialAd.load" "load(Landroid/content/Context;Ljava/lang/String;Lcom/google/android/gms/ads/AdRequest;Lcom/google/android/gms/ads/interstitial/InterstitialAdLoadCallback;)V"
}

# --- Main Logic ---

# Google Ads removal is usually generic, but we can version it if needed.
# For now, we just run the generic one.
patch_ads_v1

exit 0
