# Okam Patcher

This project provides automation tools to monitor, download, and patch the **OkSmart** Android application (`com.okampro.oksmart`). It includes scripts to check for updates on the Google Play Store and a rebuilding utility to modify the APK, specifically focusing on removing Google Ads and applying binary patches.

## Features

- **Automated Update Checking**: Monitors the Google Play Store for new versions of configured apps.
- **Split APK Support**: Automatically merges XAPK, APKM, and APKS files into a single APK.
- **Version Pinning**: Force specific `versionCode` and `versionName` in `AndroidManifest.xml` via `apps.json`.
- **Flexible Batch Processing**: Download, patch, and rebuild multiple apps, including specific versions via `@version` tags.
- **Interactive Mode**: Pauses after decompilation and patching to allow for manual modifications.
- **Ad Removal**: Automated scripts to strip Google Ads components and calls.
- **Binary Patching**: Version-aware hex patches for native libraries.
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

The `rebuild.sh` script handles individual APK files, while `process_apps.sh` handles automated downloads and batch processing.

#### Single File (rebuild.sh)
```bash
./rebuild.sh [options] <path_to_input_apk> [output_directory]

Options:
  -n, --non-interactive  Skip interactive prompts and the manual modification pause.
```

#### Batch Processing & Download (process_apps.sh)
```bash
./process_apps.sh [options] <app_id[@version]> [app_id[@version] ...]

Example:
# Download latest and run interactively
./process_apps.sh com.okampro.oksmart

# Download specific version and run non-interactively
./process_apps.sh -n com.okampro.oksmart@3.0.13
```

**Patches applied:**
1.  **Common Patches:**
    - **Version Pinning:** If configured in `apps.json`, forces specific version info in the manifest.
2.  **Ad Removal:**
    - Removes `com.google.android.gms.ads.AdActivity` from `AndroidManifest.xml`.
    - Removes `com.google.android.gms.ads.MobileAdsInitProvider` from `AndroidManifest.xml`.
    - Patches Smali code to disable `loadAd` methods for both Banner and Interstitial ads.
3.  **Binary Patch:**
    - Modifies `lib/armeabi-v7a/libOKSMARTJIAMI.so` with version-aware hex replacements.

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

Edit `apps.json` to track apps or define version pins.

```json
{
  "apps": [
    {
      "id": "com.okampro.oksmart",
      "pin_versionCode": "64",
      "pin_versionName": "3.0.13"
    }
  ]
}
```

- `pin_versionCode`: (Optional) The `versionCode` to force in `AndroidManifest.xml`.
- `pin_versionName`: (Optional) The `versionName` to force in `AndroidManifest.xml`.

## Disclaimer

This tool is for educational purposes only. Modifying applications may violate their Terms of Service. Use at your own risk.
