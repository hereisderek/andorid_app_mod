# GEMINI.md - Okam Patcher & Manager

This project is a comprehensive system for monitoring, downloading, patching, and managing Android applications, specifically focused on the **OkSmart** app (`com.okampro.oksmart`). It consists of a patching engine, an automation layer, and a dedicated Android manager app.

## Project Overview

- **Core Purpose**: Automate the process of patching Android APKs to remove ads, apply binary patches, and manage versions.
- **Patching Engine**: Bash scripts (`rebuild.sh`, `process_apps.sh`) that leverage `APKEditor.jar` and `apkeep` for APK manipulation.
- **Automation**: Node.js scripts in `automation/` to monitor Google Play Store for updates.
- **Management**: A Kotlin/Android app in `android-app/` that provides a UI to download and install patched APKs from GitHub releases.
- **CI/CD**: GitHub Actions workflows for automated patching and release generation.

## Project Structure

### Root Directory
- `rebuild.sh`: Main script to Merge -> Decompile -> Patch -> Rebuild -> Sign APKs.
- `process_apps.sh`: Batch script to download and process apps listed in `apps.json`.
- `apps.json`: Central configuration for tracked apps and version pinning.
- `key.keystore`: Keystore used for signing patched APKs.
- `INSTRUCTIONS.md`: Detailed documentation for the patching system and patch development.

### Patching System (`patches/`)
- `common/`: Patches applied to ALL apps (e.g., `pin-versions.sh`).
- `google-ads-removal.sh`: Generic patch for removing Google Ads components.
- `com.okampro.oksmart.sh`: App-specific patches for OkSmart (including binary patches for `.so` files).

### Automation (`automation/`)
- `check_updates.js`: Node.js script using `google-play-scraper`.
- `package.json`: Defines dependencies for the automation tool.

### Android Manager App (`android-app/`)
- **Type**: Kotlin/Compose Multiplatform (though mostly Android-focused here).
- **Core Logic**: `AppsRepository.kt` handles fetching `apps.json` and GitHub releases, comparing versions, and installing APKs.
- **Architecture**: MVVM with Hilt for Dependency Injection.

### Xposed Module (`app/xposed/aia/`)
- **Purpose**: Dynamically bypass root detection and security checks for AIA Vitality using Xposed/LSPosed.
- **Key Files**: `MainHook.kt` contains the hook logic for `JailMonkey`, `RootBeer`, and `PairIP` license checks.
- **Targets**: `com.aia.gr.rn.nz.v2022.vitality` (and potentially patched versions with different bundle IDs).

## Development & Usage

### 1. Patching an APK
To patch a single APK file (or a directory of split APKs):
```bash
# Individual file
./rebuild.sh path/to/app.apk

# Directory of split APKs (will be merged first)
./rebuild.sh path/to/split_apks_folder/
```
Use `-n` for non-interactive mode (skips manual modification pause).

### 2. Batch Processing
To download and patch apps from Play Store (or process multiple local files/folders):
```bash
# Mix of downloads and local sources
./process_apps.sh com.okampro.oksmart ./local_folder/ ./another_app.apk
```

### 3. Monitoring Updates
```bash
cd automation && npm install && node check_updates.js
```

### 4. Android App Development
The Android app is located in `android-app/`. It can be built using Gradle:
```bash
cd android-app
./gradlew assembleDebug
```

## Patch Development Conventions

- **Modular**: Patches should be standalone shell scripts in `patches/`.
- **Arguments**: Patches receive `TARGET_DIR` as `$1` and `VERSION_CODE` as `$2`.
- **Verification**: Patches should verify file existence and patterns before applying changes using tools like `perl` or `sed`.
- **Exit Codes**: Return `0` on success, non-zero on failure.

## Key Technologies
- **Scripting**: Bash, Perl (regex).
- **Android Tools**: `APKEditor.jar`, `apksigner`, `zipalign`, `apkeep`.
- **Automation**: Node.js, `google-play-scraper`.
- **App Development**: Kotlin, Jetpack Compose, Retrofit, Hilt, Moshi.

## Troubleshooting

### `apkeep` Download Fails (macOS)
Recent versions of `apkeep` (0.17+) do not provide Darwin binaries on GitHub. The `process_apps.sh` script is configured to use the local fallback in `bin/apkeep-aarch64-apple-darwin` automatically on macOS ARM64.

### Permission Denied / macOS Quarantine
If you see "Permission denied" when running scripts or binaries (even with `+x`), it is likely due to macOS quarantine or extended attributes.
- The scripts attempt to clear this automatically using `xattr -c`.
- You can manually clear it with: `xattr -c bin/apkeep-aarch64-apple-darwin`

### Missing Build Tools
If `zipalign` or `apksigner` are not found, ensure the Android SDK build-tools are in your `PATH`.
