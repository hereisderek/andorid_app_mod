#!/usr/bin/env bash

target_dir="$1"

if [ -z "$target_dir" ]; then
    echo "Error: google-ads-removal.sh requires a directory argument"
    exit 1
fi

echo "Disabling Google Ads in $target_dir..."

# 1. Remove AdActivity from AndroidManifest.xml
manifest_file="${target_dir}/AndroidManifest.xml"
if [ -f "$manifest_file" ]; then
    echo "Removing AdActivity from AndroidManifest.xml..."
    # Use perl to remove the entire multi-line activity block
    # Matches <activity ... com.google.android.gms.ads.AdActivity ... />
    perl -i -0777 -pe 's/\s*<activity[^>]*com\.google\.android\.gms\.ads\.AdActivity[^>]*\/>//gs' "$manifest_file"
    
    # Also remove MobileAdsInitProvider to prevent auto-initialization
    perl -i -0777 -pe 's/\s*<provider[^>]*com\.google\.android\.gms\.ads\.MobileAdsInitProvider[^>]*\/>//gs' "$manifest_file"
else
    echo "Warning: AndroidManifest.xml not found in $target_dir"
    # Not necessarily a failure if we just want to patch smali, but usually critical.
    # Let's return 0 but warn, or 1 if strict. Assuming 0 for generic patch safety.
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

exit 0
