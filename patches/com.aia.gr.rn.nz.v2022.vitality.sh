#!/usr/bin/env bash

TARGET_DIR="$1"
VERSION_CODE="$2"

if [ -z "$TARGET_DIR" ]; then
    echo "Error: patch requires a directory argument"
    exit 1
fi

echo "Applying patches for com.aia.gr.rn.nz.v2022.vitality (Version: ${VERSION_CODE:-unknown})..."

# Function to patch a method to return false (0x0) or any value
# This inserts an early return at the start of the method, after .locals/.registers
# AND ensures that .locals is at least 1 if we use v0
patch_to_false() {
    local file="$1"
    local method="$2"
    local val="${3:-0x0}" # Default false
    local target_file=$(find "$TARGET_DIR/smali" -name "$(basename "$file")" | grep "$file" | head -n 1)
    
    if [ -f "$target_file" ]; then
        echo "  Patching $method in $file to return $val..."
        
        # 1. Ensure method name is matched exactly (not as part of lambda$...)
        # We match: .method [access_flags] method_name(
        local method_regex="\.method [^ \n]*?\s\Q$method\E\("
        
        # 2. If it has .locals 0, change to .locals 1 for that specific method
        perl -0777 -i -pe "s/^($method_regex.*?\n\s*\.locals) 0/\$1 1/sm" "$target_file"
        
        # 3. Insert early return after .locals or .registers
        perl -0777 -i -pe "s/^($method_regex.*?\n\s*\.(locals|registers) \d+)/\$1\n\n    const\/4 v0, $val\n    return v0/sm" "$target_file"
    else
        echo "  Warning: $file not found."
    fi
}

# Function to patch a method to return void
patch_to_void() {
    local file="$1"
    local method="$2"
    local target_file=$(find "$TARGET_DIR/smali" -name "$(basename "$file")" | grep "$file" | head -n 1)
    
    if [ -f "$target_file" ]; then
        echo "  Patching $method in $file to return void..."
        local method_regex="\.method [^ \n]*?\s\Q$method\E\("
        
        # Insert early return after .locals or .registers
        # If no .locals/.registers found right after signature, it might be an empty method or abstract
        # but we assume standard methods here.
        perl -0777 -i -pe "s/^($method_regex.*?\n\s*\.(locals|registers) \d+)/\$1\n\n    return-void/sm" "$target_file"
    else
        echo "  Warning: $file not found."
    fi
}

# 1. JailMonkey Root Detection bypass
patch_to_false "be/c.smali" "c"

# 2. JailMonkey Hook Detection bypass
patch_to_false "zd/a.smali" "c"

# 3. JailMonkey Mock Location bypass
patch_to_false "ae/a.smali" "a"

# 4. JailMonkey External Storage bypass
patch_to_false "yd/a.smali" "a"

# 5. JailMonkey ADB bypass
patch_to_false "xd/a.smali" "a"

# 6. RootBeerNative (Direct library check) bypass
patch_to_false "com/scottyab/rootbeer/RootBeerNative.smali" "a"

# 7. PairIP License Check bypass (Google Play Services check)
LICENSE_ACTIVITY_FILE=$(find "$TARGET_DIR/smali" -name "LicenseActivity.smali" | grep "com/pairip/licensecheck/LicenseActivity.smali" | head -n 1)
if [ -f "$LICENSE_ACTIVITY_FILE" ]; then
    echo "  Patching LicenseActivity to bypass Google Play check..."
    patch_to_void "com/pairip/licensecheck/LicenseActivity.smali" "onStart"
    patch_to_void "com/pairip/licensecheck/LicenseActivity.smali" "closeApp"
fi

# 8. PairIP LicenseClient bypass
LICENSE_CLIENT_FILE=$(find "$TARGET_DIR/smali" -name "LicenseClient.smali" | grep "com/pairip/licensecheck/LicenseClient.smali" | head -n 1)
if [ -f "$LICENSE_CLIENT_FILE" ]; then
    echo "  Patching LicenseClient to neutralize checks..."
    patch_to_void "com/pairip/licensecheck/LicenseClient.smali" "initializeLicenseCheck"
    patch_to_false "com/pairip/licensecheck/LicenseClient.smali" "performLocalInstallerCheck" "0x1"
    
    # 9. Update hardcoded package name in LicenseClient if BUNDLE_ID is set
    if [ -n "$BUNDLE_ID" ]; then
        echo "  Updating hardcoded package name in LicenseClient to $BUNDLE_ID..."
        perl -i -pe "s/(packageName:Ljava\/lang\/String; = \")[^\"]*(\")/\${1}$BUNDLE_ID\${2}/g" "$LICENSE_CLIENT_FILE"
    fi
fi

exit 0
