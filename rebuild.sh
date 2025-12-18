#!/usr/bin/env bash

# Configuration
APK_EDITOR_JAR="${APK_EDITOR_JAR:-/Users/derek/.config/APKEditor/APKEditor-1.4.6.jar}"
APK_EDITOR="java -jar $APK_EDITOR_JAR"

# Usage function
usage() {
    echo "Usage: $0 <input_file> [work_directory]"
    echo ""
    echo "Arguments:"
    echo "  input_file      Path to the APK, XAPK, APKM, or APKS file."
    echo "  work_directory  (Optional) Directory for output. Defaults to input file's directory."
    echo ""
    exit 1
}

disableGoogleAds() {
    echo "Disabling Google Ads..."
    
    local target_dir="$1"
    
    if [ -z "$target_dir" ]; then
        echo "Error: disableGoogleAds requires a directory argument"
        return 1
    fi

    # 1. Remove AdActivity from AndroidManifest.xml
    local manifest_file="${target_dir}/AndroidManifest.xml"
    if [ -f "$manifest_file" ]; then
        echo "Removing AdActivity from AndroidManifest.xml..."
        # Use perl to remove the entire multi-line activity block
        # Matches <activity ... com.google.android.gms.ads.AdActivity ... />
        perl -i -0777 -pe 's/\s*<activity[^>]*com\.google\.android\.gms\.ads\.AdActivity[^>]*\/>//gs' "$manifest_file"
        
        # Also remove MobileAdsInitProvider to prevent auto-initialization
        perl -i -0777 -pe 's/\s*<provider[^>]*com\.google\.android\.gms\.ads\.MobileAdsInitProvider[^>]*\/>//gs' "$manifest_file"
    fi

    # 2. Patch Smali to disable loadAd calls
    echo "Patching Smali files to disable ad loading..."

    # Iterate through all smali directories (smali, smali_classes2, etc.)
    find "$target_dir" -maxdepth 1 -name "smali*" -type d | while read -r smali_dir; do
        # A. Disable standard AdView.loadAd
        grep -lR "\.method public loadAd(Lcom/google/android/gms/ads/AdRequest;)V" "$smali_dir" 2>/dev/null | while read -r file; do
            echo "  Disabling AdView.loadAd in $(basename "$file")"
            # Replace entire method body with empty return-void to avoid syntax errors with .param/.annotation
            perl -i -0777 -pe 's/(\.method public loadAd\(Lcom\/google\/android\/gms\/ads\/AdRequest;\)V)([\s\S]*?)(\.end method)/$1\n    .locals 0\n    return-void\n$3/g' "$file"
        done
        
        # B. Disable InterstitialAd.load
        grep -lR "\.method public static load(Landroid/content/Context;Ljava/lang/String;Lcom/google/android/gms/ads/AdRequest;Lcom/google/android/gms/ads/interstitial/InterstitialAdLoadCallback;)V" "$smali_dir" 2>/dev/null | while read -r file; do
            echo "  Disabling InterstitialAd.load in $(basename "$file")"
            # Replace entire method body with empty return-void
            perl -i -0777 -pe 's/(\.method public static load\(Landroid\/content\/Context;Ljava\/lang\/String;Lcom\/google\/android\/gms\/ads\/AdRequest;Lcom\/google\/android\/gms\/ads\/interstitial\/InterstitialAdLoadCallback;\)V)([\s\S]*?)(\.end method)/$1\n    .locals 0\n    return-void\n$3/g' "$file"
        done
    done
}

# 1. Check arguments
if [ -z "$1" ]; then
    usage
    exit 1
fi

input_file="$1"
# Use absolute path for input file if possible
if [[ "$input_file" != /* ]]; then
    input_file="$(pwd)/$input_file"
fi

workdir="${2:-$(dirname "$input_file")}"
# Ensure workdir is absolute
if [[ "$workdir" != /* ]]; then
    workdir="$(pwd)/$workdir"
fi

# Create workdir if it doesn't exist
if [ ! -d "$workdir" ]; then
    echo "Creating work directory: $workdir"
    mkdir -p "$workdir" || { echo "Error: Could not create work directory '$workdir'"; exit 1; }
fi

# Check if file exists
if [ ! -f "$input_file" ]; then
    echo "Error: File '$input_file' not found."
    exit 1
fi

echo "Input: $input_file"
echo "Workdir: $workdir"

# 2. Get extension and filename
filename=$(basename -- "$input_file")
filename_no_ext="${filename%.*}"
extension="${filename##*.}"
extension_upper=$(echo "$extension" | tr '[:lower:]' '[:upper:]')

# 3. Check if extension is XAPK, APKM, APKS and run conversion
if [[ "$extension_upper" == "XAPK" || "$extension_upper" == "APKM" || "$extension_upper" == "APKS" ]]; then
    echo "Detected split APK archive ($extension). Preparing to merge..."
    
    # Create a temporary directory for cleaning
    temp_extract_dir="${workdir}/temp_extract_${filename_no_ext}"
    rm -rf "$temp_extract_dir"
    mkdir -p "$temp_extract_dir"
    
    echo "Extracting to temporary directory for cleaning: $temp_extract_dir"
    unzip -q "$input_file" -d "$temp_extract_dir"
    
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
        rm -rf "$temp_extract_dir"
        exit 1
    fi
    
    # Cleanup temp file
    rm -rf "$temp_extract_dir"
    
    # Update input_file to the merged APK for the subsequent steps
    input_file="$output_apk"
    filename=$(basename -- "$input_file")
    filename_no_ext="${filename%.*}"
    
    echo "Merge complete. New input: $input_file"
else
    echo "File is not a split APK archive, skipping merge."
fi

# 4. Decompile
# Structure: workdir/filename_no_ext/decompile_xml
project_dir="${workdir}/${filename_no_ext}"
decompile_dir="${project_dir}/decompile_xml"

mkdir -p "$project_dir"

# Remove previous decompile dir to ensure clean state
if [ -d "$decompile_dir" ]; then
    echo "Removing previous decompile directory..."
    rm -rf "$decompile_dir"
fi

echo "Decompiling to $decompile_dir..."
$APK_EDITOR d -i "$input_file" -o "$decompile_dir"

if [ $? -ne 0 ]; then
    echo "Error: Decompilation failed."
    exit 1
fi

# 5. Apply Patches
echo "Applying patches..."
# Patch libOKSMARTJIAMI.so
so_file="${decompile_dir}/root/lib/armeabi-v7a/libOKSMARTJIAMI.so"
if [ -f "$so_file" ]; then
    echo "Patching $so_file..."
    perl -i -pe 's/\x28\x46\x41\x46\xff\xf7\xce\xec\x00\x28\x08\xbf/\x28\x46\x41\x46\x00\xbf\x00\xbf\x00\x28\x08\xbf/g' "$so_file"
else
    echo "Warning: $so_file not found, skipping patch."
fi

disableGoogleAds "$decompile_dir"

# Clean up macOS metadata files from decompiled output
echo "Cleaning decompiled files..."
find "$project_dir" -name "._*" -delete

# 6. Build
repack_apk="${workdir}/${filename_no_ext}_repack.apk"
[[ -f "$repack_apk" ]] && rm -f "$repack_apk"
echo "Building to $repack_apk..."
$APK_EDITOR b -i "$decompile_dir" -o "$repack_apk"

if [ $? -ne 0 ]; then
    echo "Error: Build failed."
    exit 1
fi

rm -rf "$decompile_dir" 

# 7. Zipalign
repack_aligned_apk="${workdir}/${filename_no_ext}_repack_aligned.apk"
echo "Zipaligning to $repack_aligned_apk..."
[[ -f "$repack_aligned_apk" ]] && rm -f "$repack_aligned_apk"
zipalign -f -v 4 "$repack_apk" "$repack_aligned_apk" > /dev/null

# 8. Sign
echo "Signing..."
apksigner sign \
--ks key.keystore \
--ks-pass pass:mypassword123 \
--key-pass pass:mypassword123 \
--ks-key-alias key \
"$repack_aligned_apk"

echo "--------------------------------------------------"
echo "Success! Output file: $repack_aligned_apk"
echo "--------------------------------------------------"

# cleanup
[[ -f "$repack_apk" ]] && rm -f "$repack_apk"


# Optional: Logcat
# adb logcat -v process -e "com.okampro.oksmart"


# keytool -genkey -v \
#   -keystore key.keystore \
#   -alias key \
#   -keyalg RSA \
#   -keysize 2048 \
#   -validity 18250 \
#   -storepass mypassword123 \
#   -keypass mypassword123 \
#   -dname "CN=Android Debug, O=Android, C=US"