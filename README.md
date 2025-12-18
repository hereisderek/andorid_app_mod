# Okam Patcher

This project provides automation tools to monitor, download, and patch the **OkSmart** Android application (`com.okampro.oksmart`). It includes scripts to check for updates on the Google Play Store and a rebuilding utility to modify the APK, specifically focusing on removing Google Ads and applying binary patches.

## Features

- **Automated Update Checking**: Monitors the Google Play Store for new versions of configured apps.
- **Split APK Support**: Automatically merges XAPK, APKM, and APKS files into a single APK before processing.
- **APK Rebuilding**: Tools to decompile, patch, and rebuild APK files.
- **Ad Removal**: Automated scripts to strip Google Ads (`AdActivity`, `MobileAdsInitProvider`) and disable ad loading in Smali code (`AdView.loadAd`, `InterstitialAd.load`).
- **Binary Patching**: Applies specific hex patches to `libOKSMARTJIAMI.so`.
- **Signing & Alignment**: Automatically zipaligns and signs the modified APK.

## Project Structure

- `apps.json`: Configuration file listing the apps to monitor (App ID and current version).
- `automation/`: Contains Node.js scripts for checking updates.
- `rebuild.sh`: Bash script for processing the APK file (Merge -> Decompile -> Patch -> Rebuild -> Sign).

## Usage

### Checking for Updates

The update checker uses `google-play-scraper` to find the latest version.

```bash
cd automation
npm install
node check_updates.js
```

### Rebuilding & Patching

The `rebuild.sh` script handles the modification of the APK file. It requires `APKEditor` (jar), `zipalign`, and `apksigner`.

```bash
./rebuild.sh <path_to_input_apk> [output_directory]
```

**Patches applied:**
1.  **Ad Removal:**
    - Removes `com.google.android.gms.ads.AdActivity` from `AndroidManifest.xml`.
    - Removes `com.google.android.gms.ads.MobileAdsInitProvider` from `AndroidManifest.xml`.
    - Patches Smali code to disable `loadAd` methods for both Banner and Interstitial ads.
2.  **Binary Patch:**
    - Modifies `lib/armeabi-v7a/libOKSMARTJIAMI.so` with a specific hex replacement.

### Signing

The script expects a `key.keystore` file in the working directory to sign the APK.
Default credentials used in the script:
- Keystore: `key.keystore`
- Password: `mypassword123`
- Alias: `key`

You can generate a compatible keystore using:
```bash
keytool -genkey -v \
  -keystore key.keystore \
  -alias key \
  -keyalg RSA \
  -keysize 2048 \
  -validity 18250 \
  -storepass mypassword123 \
  -keypass mypassword123 \
  -dname "CN=Android Debug, O=Android, C=US"
```

## Configuration

Edit `apps.json` to track different apps or update the current version manually.

```json
{
  "apps": [
    {
      "id": "com.okampro.oksmart",
      "current_version": "0.0.0"
    }
  ]
}
```

## Disclaimer

This tool is for educational purposes only. Modifying applications may violate their Terms of Service. Use at your own risk.
