# APK Patching System - Instructions

## Project Overview

This project provides an automated system for downloading, decompiling, patching, and rebuilding Android APK files. It features a modular patch system with support for batch processing and CI/CD automation.

## Directory Structure

```
.
├── bin/                          # Auto-downloaded binaries (gitignored except fallbacks)
│   ├── APKEditor.jar            # Auto-downloaded APK decompiler/compiler
│   └── apkeep-aarch64-apple-darwin  # Fallback for macOS ARM64
├── patches/                      # Patch scripts directory
│   ├── common/                  # Applied to ALL apps (e.g., pin-versions.sh)
│   ├── google-ads-removal.sh    # Generic reusable patch
│   └── com.okampro.oksmart.sh   # App-specific patch
├── output/                       # Generated APKs and project folders
│   └── com.id-vX.Y/             # Project folder with version suffix
├── rebuild.sh                    # Main patching script (Merge -> Decompile -> Patch -> Build)
├── process_apps.sh              # Download and batch processing script
└── apps.json                     # App configuration and version pinning

```

## Patch System Architecture

### Three Patch Categories

1. **Common Patches** (`patches/common/`)
   - Applied to **all** apps automatically
   - Place `.sh` files here for universal patches
   - Example use: Remove debug logging, apply global security fixes

2. **General Patches** (`patches/`)
   - Reusable patches that can be applied to multiple apps
   - Must be explicitly requested in `get_patches_for_app()`
   - Example: `google-ads-removal.sh`

3. **App-Specific Patches** (`patches/`)
   - Named after the app's bundle ID
   - Example: `com.okampro.oksmart.sh`
   - Applied only to their specific app

### How Patches Are Applied

Edit the `get_patches_for_app()` function in `rebuild.sh`:

```bash
get_patches_for_app() {
    local id="$1"
    case "$id" in
        "com.okampro.oksmart")
            echo "google-ads-removal.sh com.okampro.oksmart.sh"
            ;;
        "com.example.app")
            echo "google-ads-removal.sh"
            ;;
        *)
            echo ""
            ;;
    esac
}
```

### Creating New Patches

All patch scripts must:
1. Be executable (`chmod +x patches/yourpatch.sh`)
2. Accept a directory path as the first argument (`$1`)
3. Accept an optional version code as the second argument (`$2`)
4. Return exit code 0 on success, non-zero on failure

Example template:

```bash
#!/usr/bin/env bash

TARGET_DIR="$1"
VERSION_CODE="$2"

if [ -z "$TARGET_DIR" ]; then
    echo "Error: patch requires a directory argument"
    exit 1
fi

echo "Applying patch for version ${VERSION_CODE:-unknown}..."

# Your patching logic here
# ...

exit 0
```

## Usage Guide

### Option 1: Single APK Processing (`rebuild.sh`)

```bash
# Interactive mode (pauses for manual changes in decompile_xml/)
./rebuild.sh path/to/app.apk

# Non-interactive mode (skips pause)
./rebuild.sh --non-interactive path/to/app.apk
```

### Option 2: Automated Download and Process (`process_apps.sh`)

```bash
# Process an app using latest available version
./process_apps.sh com.okampro.oksmart

# Process a specific version
./process_apps.sh com.okampro.oksmart@3.0.13

# Batch process multiple apps non-interactively
./process_apps.sh -n com.okampro.oksmart com.another.app
```

## Version Pinning

You can force a specific `versionCode` or `versionName` by modifying `apps.json`:

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

This is handled by `patches/common/pin-versions.sh` and is useful when you need to bypass version checks or spoof a specific release internally.
./rebuild.sh --non-interactive path/to/app.apk

# Specify output directory
./rebuild.sh path/to/app.apk /path/to/output
```

**Interactive Mode Features:**
- Option to change Bundle ID
- Option to change App Name

### Option 2: Batch Processing

Download and patch multiple apps from Google Play Store:

```bash
./process_apps.sh "com.okampro.oksmart" "com.example.app"
```

This will:
1. Auto-download `apkeep` tool (first run)
2. Download each APK from Play Store
3. Apply patches in non-interactive mode
4. Save results to `output/` directory

### Requirements

**System Tools:**
- `java` (JDK 8+)
- `zipalign` (Android SDK build-tools)
- `apksigner` (Android SDK build-tools)
- `perl` (for regex operations)
- `curl` (for downloads)

**Auto-Downloaded:**
- APKEditor.jar (downloaded to `bin/` automatically)
- apkeep (downloaded to `bin/` automatically)

## Patch Verification & Error Handling

### Built-in Verification

Patches should verify their operations:

```bash
# Check if target exists before patching
if [ -f "$target_file" ]; then
    # Verify pattern exists
    if perl -0777 -ne 'exit 0 if /pattern/; exit 1' "$target_file"; then
        # Apply patch
        perl -i -pe 's/old/new/g' "$target_file"
        echo "Patch applied successfully."
    else
        echo "Pattern not found."
        exit 1
    fi
else
    echo "Target file not found."
    exit 1
fi
```

### Patch Statistics

After execution, `rebuild.sh` displays:
```
Patch Summary:
  Total Patches Attempted: 3
  Successful Patches:      3
```

## Environment Variables

### For rebuild.sh

```bash
# Use custom APKEditor.jar
APK_EDITOR_JAR=/path/to/APKEditor.jar ./rebuild.sh app.apk

# Use custom keystore
KS_FILE=/path/to/custom.keystore \
KS_PASS=password123 \
KEY_PASS=keypass123 \
KS_ALIAS=myalias \
./rebuild.sh app.apk

# Use custom output naming
APP_ID=com.custom.app VERSION=2.0.1 ./rebuild.sh app.apk
```

## CI/CD Integration

The project includes GitHub Actions workflow (`.github/workflows/auto-patch.yml`) for automated processing.

To add a new app to CI/CD, edit `apps.json`:

```json
{
  "apps": [
    {
      "id": "com.okampro.oksmart"
    },
    {
      "id": "com.newapp.package"
    }
  ]
}
```

## Troubleshooting

### Permission Denied on Patches
Fixed automatically - `rebuild.sh` now sets execute permissions at runtime.

### APKEditor Download Fails
- Check internet connection
- Verify GitHub releases URL is accessible
- Manually download and place in `bin/APKEditor.jar`

### apkeep Download Fails (macOS ARM64)
- The fallback `bin/apkeep-aarch64-apple-darwin` is included in the repo
- Script will automatically use it on ARM64 Macs

### Patch Not Applied
- Check patch script has correct shebang (`#!/usr/bin/env bash`)
- Verify patch returns correct exit codes
- Review patch output in console for specific errors

### Build Failures
- Ensure Android SDK build-tools are installed
- Verify `zipalign` and `apksigner` are in PATH
- Check keystore file exists and credentials are correct

## Examples

### Example: Add a New Generic Patch

1. Create patch file:
```bash
touch patches/remove-analytics.sh
chmod +x patches/remove-analytics.sh
```

2. Edit the patch:
```bash
#!/usr/bin/env bash
target_dir="$1"
# Remove analytics SDK references
find "$target_dir" -name "*.smali" -exec sed -i '' '/analytics/d' {} \;
exit 0
```

3. Apply to specific apps in `rebuild.sh`:
```bash
"com.example.app1")
    echo "google-ads-removal.sh remove-analytics.sh com.example.app1.sh"
    ;;
```

### Example: Batch Process with Custom Output

```bash
# Process multiple apps and save to custom directory
OUTPUT_DIR=./custom_output ./process_apps.sh "app1" "app2" "app3"
```

## Best Practices

1. **Test patches individually** before combining them
2. **Always verify** binary patches with both original and patched byte sequences
3. **Use non-interactive mode** for automation and CI/CD
4. **Version control** your patch scripts but not binaries
5. **Document** each patch's purpose and any app-specific requirements
6. **Handle missing files gracefully** in patches (return appropriate exit codes)

## Security Notes

- **Keystore**: Default `key.keystore` is for development only
- **Credentials**: Never commit real keystores or passwords to git
- **Output APKs**: The `output/` directory is gitignored by design
- **Downloaded APKs**: Verify authenticity before distribution
