#!/usr/bin/env bash

# Configuration
BIN_DIR="$(dirname "$0")/bin"
mkdir -p "$BIN_DIR"
APK_EDITOR_JAR_NAME="APKEditor.jar"
APK_EDITOR_JAR_PATH="$BIN_DIR/$APK_EDITOR_JAR_NAME"
APK_EDITOR_URL="https://github.com/REAndroid/APKEditor/releases/download/V1.4.6/$APK_EDITOR_JAR_NAME"

if [ -z "$APK_EDITOR_JAR" ]; then
    if [ ! -f "$APK_EDITOR_JAR_PATH" ]; then
        echo "Downloading $APK_EDITOR_JAR_NAME..."
        curl -L -o "$APK_EDITOR_JAR_PATH" "$APK_EDITOR_URL" || { echo "Error downloading APKEditor"; exit 1; }
    fi
    APK_EDITOR_JAR="$APK_EDITOR_JAR_PATH"
fi

APK_EDITOR="java -jar $APK_EDITOR_JAR"
PATCHES_DIR="$(dirname "$0")/patches"

# Check for required dependencies
check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: Required command '$1' not found. Please ensure it's installed and in your PATH."
        exit 1
    fi
}

check_dependency "java"
# check_dependency "zipalign"
# check_dependency "apksigner"

# Ensure all patch scripts are executable
if [ -d "$PATCHES_DIR" ]; then
    chmod -R +x "$PATCHES_DIR"
fi

INTERACTIVE=true
TOTAL_PATCHES=0
SUCCESSFUL_PATCHES=0

# Usage function
usage() {
    echo "Usage: $0 [options] <input_file | input_directory> [work_directory]"
    echo ""
    echo "Arguments:"
    echo "  input_file      Path to the APK, XAPK, APKM, or APKS file."
    echo "  input_directory Path to a directory containing split APKs (will be merged first)."
    echo "  work_directory  (Optional) Directory for output. Defaults to input's parent directory."
    echo ""
    echo "Options:"
    echo "  -n, --non-interactive  Run in non-interactive mode (skip optional patches)."
    echo ""
    exit 1
}

# Parse arguments
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--non-interactive)
      INTERACTIVE=false
      shift # past argument
      ;;
    -*|--*)
      echo "Unknown option $1"
      usage
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

if [ ${#POSITIONAL_ARGS[@]} -lt 1 ]; then
    usage
fi

input_file="${POSITIONAL_ARGS[0]}"
# Use absolute path for input file if possible
if [[ "$input_file" != /* ]]; then
    input_file="$(pwd)/$input_file"
fi

workdir="${POSITIONAL_ARGS[1]:-$(dirname "$input_file")}"
# Ensure workdir is absolute
if [[ "$workdir" != /* ]]; then
    workdir="$(pwd)/$workdir"
fi

# Create workdir if it doesn't exist
if [ ! -d "$workdir" ]; then
    echo "Creating work directory: $workdir"
    mkdir -p "$workdir" || { echo "Error: Could not create work directory '$workdir'"; exit 1; }
fi

# Check if file or directory exists
if [ ! -f "$input_file" ] && [ ! -d "$input_file" ]; then
    echo "Error: Input '$input_file' not found (neither file nor directory)."
    exit 1
fi

echo "Input: $input_file"
echo "Workdir: $workdir"
echo "Interactive Mode: $INTERACTIVE"

# --- Helper Functions ---

get_bundle_id() {
    local manifest_file="$1"
    if [ -f "$manifest_file" ]; then
        grep -o 'package="[^"]*"' "$manifest_file" | cut -d'"' -f2
    fi
}

get_version_code() {
    local manifest_file="$1"
    if [ -f "$manifest_file" ]; then
        grep -o 'versionCode="[0-9]*"' "$manifest_file" | cut -d'"' -f2
    fi
}

get_version_name() {
    local manifest_file="$1"
    if [ -f "$manifest_file" ]; then
        grep -o 'versionName="[^"]*"' "$manifest_file" | cut -d'"' -f2
    fi
}

get_app_name() {
    local target_dir="$1"
    # Search for app_name or vid_name in strings.xml, preferring English/default values folder
    # Priority: values-en-rUS, values-en-rGB, values-en, values
    local strings_file=""
    local name_key=""
    for dir_suffix in "values-en-rUS" "values-en-rGB" "values-en" "values"; do
        strings_file=$(find "$target_dir" -path "*/$dir_suffix/strings.xml" | head -n 1)
        if [ -f "$strings_file" ]; then
            if grep -q 'name="app_name"' "$strings_file"; then
                name_key="app_name"
                break
            elif grep -q 'name="vid_name"' "$strings_file"; then
                name_key="vid_name"
                break
            fi
        fi
    done

    if [ -f "$strings_file" ]; then
        grep "name=\"$name_key\"" "$strings_file" | sed -n 's/.*>\([^<]*\)<\/string>.*/\1/p' | head -n 1
    fi
}

# Map of Bundle ID to list of patches
get_patches_for_app() {
    local id="$1"
    case "$id" in
        "com.okampro.oksmart")
            # Returns list of general and app-specific patches
            echo "google-ads-removal.sh com.okampro.oksmart.sh"
            ;;
        "com.huiyun.care.viewerpro.googleplay")
            echo "google-ads-removal.sh"
            ;;
        "com.aia.gr.rn.nz.v2022.vitality")
            echo "google-ads-removal.sh com.aia.gr.rn.nz.v2022.vitality.sh"
            ;;
        *)
            echo ""
            ;;
    esac
}

apply_patches() {
    local bundle_id="$1"
    local target_dir="$2"
    local version_code="$3"
    
    # Export bundle_id so patch scripts can use it
    # We use the final_app_id which includes any overrides or changes
    export BUNDLE_ID="$final_app_id"
    
    echo "Applying patches for Bundle ID: $bundle_id (VersionCode: $version_code)"
    
    # 1. Apply Common Patches (Applied to ALL apps)
    echo "--- Common Patches ---"
    if [ -d "$PATCHES_DIR/common" ]; then
        # Check if directory is not empty
        if [ "$(ls -A "$PATCHES_DIR/common")" ]; then
            for patch_file in "$PATCHES_DIR/common"/*.sh; do
                if [ -f "$patch_file" ]; then
                    echo "Applying common patch: $(basename "$patch_file")"
                    ((TOTAL_PATCHES++))
                    "$patch_file" "$target_dir" "$version_code"
                    if [ $? -eq 0 ]; then
                        ((SUCCESSFUL_PATCHES++))
                    else
                        echo "Error: Patch $(basename "$patch_file") failed."
                    fi
                fi
            done
        else
            echo "No common patches found."
        fi
    fi

    # 2. Apply App Specific & General Patches (Returned by get_patches_for_app)
    echo "--- App Specific & General Patches ---"
    local specific_patches=$(get_patches_for_app "$bundle_id")
    for patch in $specific_patches; do
        local patch_file="$PATCHES_DIR/$patch"
        if [ -f "$patch_file" ]; then
            echo "Applying patch: $patch"
            ((TOTAL_PATCHES++))
            "$patch_file" "$target_dir" "$version_code"
            if [ $? -eq 0 ]; then
                ((SUCCESSFUL_PATCHES++))
            else
                echo "Error: Patch $patch failed."
            fi
        else
            echo "Warning: Patch file $patch_file not found."
        fi
    done
}

apply_optional_patches() {
    local target_dir="$1"
    local manifest_file="${target_dir}/AndroidManifest.xml"
    
    # 1. Handle Bundle ID
    local current_bid=$(get_bundle_id "$manifest_file")
    local new_bid="$OVERRIDE_BUNDLE_ID"
    
    if [ -z "$new_bid" ] && [ "$INTERACTIVE" = true ]; then
        echo ""
        echo "--- Optional Patches ---"
        read -p "Do you want to change the Bundle ID? (y/N): " change_bid
        if [[ "$change_bid" =~ ^[Yy]$ ]]; then
            read -p "Enter new Bundle ID [$current_bid]: " input_bid
            new_bid="${input_bid:-$current_bid}"
        fi
    fi

    if [ -n "$new_bid" ] && [ "$new_bid" != "$current_bid" ]; then
        echo "Changing Bundle ID from $current_bid to $new_bid..."
        # Update package attribute in AndroidManifest.xml
        NEW_BID="$new_bid" perl -i -pe 's/package="[^"]*"/"package=\"$ENV{NEW_BID}\""/e' "$manifest_file"
        
        # Update all occurrences of the old package name in the entire decompile directory
        echo "Updating package name references in decompile directory..."
        find "$target_dir" \( -name "*.xml" -o -name "AndroidManifest.xml" \) -type f -exec \
            sh -c 'OLD_BID="$1" NEW_BID="$2" perl -i -pe "s/\Q\$ENV{OLD_BID}\E/\$ENV{NEW_BID}/g" "$3"' \
            -- "$current_bid" "$new_bid" {} \;
    fi

    # 2. Handle App Name
    local current_name=$(get_app_name "$target_dir")
    local new_name="$OVERRIDE_APP_NAME"

    if [ -z "$new_name" ] && [ "$INTERACTIVE" = true ]; then
        read -p "Do you want to change the App Name? (y/N): " change_name
        if [[ "$change_name" =~ ^[Yy]$ ]]; then
            read -p "Enter new App Name [$current_name]: " input_name
            new_name="${input_name:-$current_name}"
        fi
    fi

    if [ -n "$new_name" ] && [ "$new_name" != "$current_name" ]; then
        echo "Changing App Name to $new_name..."
        # Search for app_name or vid_name in all strings.xml files
        find "$target_dir" -name "strings.xml" | while read -r strings_file; do
            if grep -qE 'name="(app_name|vid_name)"' "$strings_file"; then
                perl -i -pe "s/(<string name=\"(app_name|vid_name)\">)[^<]*<\/string>/\${1}$new_name<\/string>/" "$strings_file"
                echo "Updated $strings_file"
            fi
        done
    fi
}

# --- Main Logic ---

# 1. Get extension and filename
filename=$(basename -- "$input_file")
filename_no_ext="${filename%.*}"
extension="${filename##*.}"
extension_upper=$(echo "$extension" | tr '[:lower:]' '[:upper:]')

# 2. Check if extension is XAPK, APKM, APKS or if it's a directory, then run conversion
if [[ "$extension_upper" == "XAPK" || "$extension_upper" == "APKM" || "$extension_upper" == "APKS" || -d "$input_file" ]]; then
    if [ -d "$input_file" ]; then
        echo "Detected directory input. Preparing to merge split APKs from: $input_file"
        temp_extract_dir="$input_file"
        # We don't want to delete the user's directory at the end if they provided it directly
        provided_as_dir=true
    else
        echo "Detected split APK archive ($extension). Preparing to merge..."
        # Create a temporary directory for cleaning
        temp_extract_dir="${workdir}/temp_extract_${filename_no_ext}"
        rm -rf "$temp_extract_dir"
        mkdir -p "$temp_extract_dir"
        
        echo "Extracting to temporary directory for cleaning: $temp_extract_dir"
        unzip -q "$input_file" -d "$temp_extract_dir"
        provided_as_dir=false
    fi
    
    echo "Cleaning macOS metadata (._ files and __MACOSX)..."
    find "$temp_extract_dir" -name "._*" -delete
    find "$temp_extract_dir" -name "__MACOSX" -exec rm -rf {} +
    
    output_apk="${workdir}/${filename_no_ext}.apk"
    echo "Merging to $output_apk..."
    
    [[ -f "$output_apk" ]] && rm -f "$output_apk"
    $APK_EDITOR m -i "$temp_extract_dir" -o "$output_apk"
    
    # Check if merge was successful
    if [ $? -ne 0 ]; then
        echo "Error: Merge failed."
        [ "$provided_as_dir" = false ] && rm -rf "$temp_extract_dir"
        exit 1
    fi
    
    # Cleanup temp folder only if we created it
    [ "$provided_as_dir" = false ] && rm -rf "$temp_extract_dir"
    
    # Update input_file to the merged APK for the subsequent steps
    input_file="$output_apk"
    filename=$(basename -- "$input_file")
    filename_no_ext="${filename%.*}"
    
    echo "Merge complete. New input: $input_file"
else
    echo "Input is not a split archive or directory, skipping merge."
fi

# 3. Decompile
# Decompile first to a generic temp dir to detect info
temp_decompile_dir="${workdir}/temp_decompile_${filename_no_ext}"
rm -rf "$temp_decompile_dir"

echo "Decompiling for analysis: $input_file"
$APK_EDITOR d -i "$input_file" -o "$temp_decompile_dir"

if [ $? -ne 0 ]; then
    echo "Error: Initial decompilation failed."
    exit 1
fi

# Detect Info
manifest_file="${temp_decompile_dir}/AndroidManifest.xml"
bundle_id=$(get_bundle_id "$manifest_file")
version_code=$(get_version_code "$manifest_file")
version_name=$(get_version_name "$manifest_file")

# Use detected or provided app info
final_app_id="${APP_ID:-$bundle_id}"

# Priority: PROVIDED VERSION from command line (@version) > DETECTED version_name from APK
# Note: PIN_VERSION_NAME from apps.json only affects the manifest, not the output naming.
final_version="${VERSION:-$version_name}"

echo "Detected Bundle ID: $bundle_id (VersionCode: $version_code, VersionName: $version_name)"
[ -n "$PIN_VERSION_NAME" ] && echo "Pinning VersionName to: $PIN_VERSION_NAME"
[ -n "$PIN_VERSION_CODE" ] && echo "Pinning VersionCode to: $PIN_VERSION_CODE"

# Re-establish project directory with version suffix if possible
if [ -n "$final_version" ]; then
    project_dir="${workdir}/${final_app_id}-v${final_version}"
else
    project_dir="${workdir}/${final_app_id}"
fi
decompile_dir="${project_dir}/decompile_xml"

# Ensure clean state for move
mkdir -p "$project_dir"
rm -rf "$decompile_dir"

echo "Moving decompiled files to: $decompile_dir"
mv "$temp_decompile_dir" "$decompile_dir"

# 4. Apply Patches
echo "Applying patches..."

# Determine final app ID (detected or overridden)
# Priority: 1. OVERRIDE_BUNDLE_ID, 2. bundle_id from manifest
final_app_id="${OVERRIDE_BUNDLE_ID:-$bundle_id}"

# Export bundle_id so patch scripts can use it
export BUNDLE_ID="$final_app_id"

# Set environment variables for patches
export PIN_VERSION_CODE="$PIN_VERSION_CODE"
export PIN_VERSION_NAME="$PIN_VERSION_NAME"

apply_patches "$bundle_id" "$decompile_dir" "$version_code"
apply_optional_patches "$decompile_dir"

if [ "$INTERACTIVE" = true ]; then
    echo ""
    echo "Decompilation and automatic patching complete."
    echo "You can now make manual modifications in: $decompile_dir"
    read -p "Press [Enter] to continue with rebuilding..."
fi

# Clean up macOS metadata files from decompiled output
echo "Cleaning decompiled files..."
find "$project_dir" -name "._*" -delete

# 5. Build
repack_apk="${project_dir}/${final_app_id}_repack.apk"
[[ -f "$repack_apk" ]] && rm -f "$repack_apk"
echo "Building to $repack_apk..."
$APK_EDITOR b -i "$decompile_dir" -o "$repack_apk"

if [ $? -ne 0 ]; then
    echo "Error: Build failed."
    exit 1
fi

# 6. Zipalign
repack_aligned_apk="${workdir}/${final_app_id}-v${final_version}_repack_aligned.apk"

echo "Zipaligning to $repack_aligned_apk..."
[[ -f "$repack_aligned_apk" ]] && rm -f "$repack_aligned_apk"
if ! zipalign -f -v 4 "$repack_apk" "$repack_aligned_apk" > /dev/null; then
    echo "Error: zipalign failed."
    exit 1
fi

# 7. Sign
echo "Signing..."
# Use env overrides if provided; default to repo keystore
KEYSTORE="${KS_FILE:-key.keystore}"
KS_PASS="${KS_PASS:-mypassword123}"
KEY_PASS="${KEY_PASS:-mypassword123}"
KS_ALIAS="${KS_ALIAS:-key}"

if [ ! -f "$KEYSTORE" ]; then
    echo "Error: Keystore '$KEYSTORE' not found. Place key.keystore in repo root or set KS_FILE."
    exit 1
fi

if ! apksigner sign --ks "$KEYSTORE" --ks-pass pass:"$KS_PASS" --key-pass pass:"$KEY_PASS" --ks-key-alias "$KS_ALIAS" "$repack_aligned_apk"; then
    echo "Error: apksigner failed."
    exit 1
fi

echo "--------------------------------------------------"
echo "Success! Output file: $repack_aligned_apk"
echo "--------------------------------------------------"
echo "Details:"
echo "  Bundle ID:       $bundle_id"
echo "  Original Ver:    $version_name ($version_code)"
[ -n "$PIN_VERSION_NAME" ] && echo "  Pinned VerName:  $PIN_VERSION_NAME"
[ -n "$PIN_VERSION_CODE" ] && echo "  Pinned VerCode:  $PIN_VERSION_CODE"
echo "Patch Summary:"
echo "  Total Patches Attempted: $TOTAL_PATCHES"
echo "  Successful Patches:      $SUCCESSFUL_PATCHES"
echo "--------------------------------------------------"

# cleanup
[[ -f "$repack_apk" ]] && rm -f "$repack_apk"
# Keep decompile_dir for reference/manual work if desirable, but user usually wants cleanup
# For now, we clean it up if it's not a temp one we moved
# rm -rf "$decompile_dir" 
