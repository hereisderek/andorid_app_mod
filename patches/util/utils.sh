#!/usr/bin/env bash

# Apply a hex patch to a file
# Arguments: label, file, search_hex, replace_hex
apply_hex_patch() {
    local label="$1"
    local file="$2"
    local search_hex="$3"
    local replace_hex="$4"

    if [ ! -f "$file" ]; then
        echo "  Warning: $file not found. Skipping $label."
        return 1
    fi

    echo "  Checking $label in $(basename "$file")..."

    # Convert hex space-separated strings to perl regex formats
    local search_regex=$(echo "$search_hex" | sed 's/ /\\x/g; s/^/\\x/')
    local replace_regex=$(echo "$replace_hex" | sed 's/ /\\x/g; s/^/\\x/')

    # Check if already patched
    if perl -0777 -ne "exit 0 if /$replace_regex/; exit 1" "$file"; then
        echo "    $label already patched."
        return 0
    fi

    # Check if target exists
    if perl -0777 -ne "exit 0 if /$search_regex/; exit 1" "$file"; then
        echo "    Target bytes found. Patching..."
        perl -i -pe "s/$search_regex/$replace_regex/g" "$file"
        
        # Verify
        if [ $? -eq 0 ] && perl -0777 -ne "exit 0 if /$replace_regex/; exit 1" "$file"; then
            echo "    $label applied successfully."
            return 0
        else
            echo "    Error: Failed to verify $label after patching."
            return 1
        fi
    else
        echo "    Target bytes not found for $label."
        return 1
    fi
}

# Patch a smali method to simply return the first argument (p0)
# Arguments: class_path, method_name
patch_smali_return_input() {
    local class_path="$1"
    local method_name="$2"
    local target_dir="$TARGET_DIR" # Expects TARGET_DIR to be set in environment
    
    echo "  Patching $class_path -> $method_name to return input..."
    
    # Find the smali file
    local smali_file=$(find "$target_dir" -name "$(basename "$class_path").smali" | grep "$class_path")
    
    if [ -f "$smali_file" ]; then
        # Use perl to match the method block and replace its body
        # Matches .method ... method_name(...)Ljava/lang/String; ... .end method
        perl -i -0777 -pe 's/(\.method public static '"$method_name"'\(Ljava\/lang\/String;Ljava\/lang\/String;\)Ljava\/lang\/String;)([\s\S]*?)(\.end method)/$1\n    .locals 0\n\n    return-object p0\n$3/g' "$smali_file"
        return 0
    else
        echo "    Warning: Smali file for $class_path not found."
        return 1
    fi
}
