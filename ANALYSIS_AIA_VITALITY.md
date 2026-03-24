# Security Analysis: AIA Vitality (com.aia.gr.rn.nz.v2022.vitality)

This document details the root detection and environment security mechanisms found in the AIA Vitality Android application and the methods used to bypass them.

## Overview

Upon launch, the application performs several environment checks. If any check fails (e.g., the device is rooted, ADB is enabled, or a hook framework is detected), the app displays a "Device Security" screen and prevents the user from proceeding.

The application is built using **React Native**, and its security logic is split between a native Java/Kotlin layer and a JavaScript bundle.

## Security Detection Mechanisms

The application utilizes several well-known security libraries and custom logic to detect non-standard environments.

### 1. JailMonkey (React Native Library)
The primary bridge between the native security checks and the JavaScript UI is the `JailMonkey` library.
- **Bridge Class**: `com.gantix.JailMonkey.JailMonkeyModule`
- **Function**: Exposes a `getConstants()` method to JavaScript, providing a map of security flags including `isJailBroken`, `hookDetected`, `canMockLocation`, and `AdbEnabled`.

### 2. be/c & be/c$a (Custom Security Wrappers)
The `JailMonkey` module delegates its checks to these internal classes.

**Method `be/c->c()` (Main Entry Point):**
This method aggregates the results of various checks.
```smali
.method public c()Z
    .locals 1

    iget-boolean v0, p0, Lbe/c;->a:Z

    if-nez v0, :cond_1

    iget-object v0, p0, Lbe/c;->b:Lbe/c$a;

    invoke-virtual {v0}, Lbe/c$a;->a()Z

    move-result v0

    if-eqz v0, :cond_0

    goto :goto_0

    :cond_0
    const/4 v0, 0x0

    goto :goto_1
    # ...
.end method
```

### 3. Hook & Malicious App Detection (zd/a)
This class scans for hook frameworks (Xposed, Frida) and a hardcoded list of "malicious" packages.

**Method `zd/a->c(Landroid/content/Context;)Z` (Scanning Apps):**
```smali
.method public static c(Landroid/content/Context;)Z
    .locals 26

    invoke-virtual/range {p0 .. p0}, Landroid/content/Context;->getPackageManager()Landroid/content/pm/PackageManager;

    move-result-object v0

    const/16 v1, 0x80

    invoke-virtual {v0, v1}, Landroid/content/pm/PackageManager;->getInstalledApplications(I)Ljava/util/List;

    move-result-object v0

    const-string v24, "com.kingouser.com"
    const-string v25, "com.topjohnwu.magisk"
    const-string v1, "de.robv.android.xposed.installer"
    # ... List of 25+ packages ...

    # It then checks if any installed application's packageName is in this list.
    invoke-static {v1}, Ljava/util/Arrays;->asList([Ljava/lang/Object;)Ljava/util/List;
    move-result-object v3
    iget-object v2, v2, Landroid/content/pm/ApplicationInfo;->packageName:Ljava/lang/String;
    invoke-interface {v3, v2}, Ljava/util/List;->contains(Ljava/lang/Object;)Z
    # ...
.end method
```

### 4. Mock Locations Detection (ae/a)
Scans all installed applications for the `ACCESS_MOCK_LOCATION` permission.

**Method `ae/a->a(Landroid/content/Context;)Z`:**
```smali
.method public static a(Landroid/content/Context;)Z
    .locals 8
    # ...
    # Get all installed apps
    invoke-virtual {p0}, Landroid/content/Context;->getPackageManager()Landroid/content/pm/PackageManager;
    move-result-object v0
    const/16 v1, 0x80
    invoke-virtual {v0, v1}, Landroid/content/pm/PackageManager;->getInstalledApplications(I)Ljava/util/List;
    move-result-object v1
    # ... loop through apps and check permissions ...
    const-string v7, "android.permission.ACCESS_MOCK_LOCATION"
    invoke-virtual {v6, v7}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
.end method
```

### 5. ADB Detection (xd/a)
Checks system settings for `adb_enabled`.

**Method `xd/a->a(Landroid/content/Context;)Z`:**
```smali
.method public static a(Landroid/content/Context;)Z
    .locals 5
    # ...
    const-string v2, "adb_enabled"
    const/4 v3, 0x0
    invoke-static {v1, v2, v3}, Landroid/provider/Settings$Secure;->getInt(Landroid/content/ContentResolver;Ljava/lang/String;I)I
    # ... and also checks Settings$Global ...
.end method
```

### 6. External Storage Detection (yd/a)
Checks if the app is residing on an SD card or external mount point.

**Method `yd/a->a(Landroid/content/Context;)Z`:**
```smali
.method public static a(Landroid/content/Context;)Z
    .locals 4
    # ...
    invoke-virtual {p0}, Landroid/content/Context;->getPackageName()Ljava/lang/String;
    move-result-object v3
    invoke-virtual {v0, v3, v2}, Landroid/content/pm/PackageManager;->getPackageInfo(Ljava/lang/String;I)Landroid/content/pm/PackageInfo;
    # ... check applicationInfo flags for INSTALL_LOCATION_PREFER_EXTERNAL ...
    const/high16 v0, 0x40000
    and-int/2addr p0, v0
.end method
```

## Bypass Strategy

To bypass these checks without modifying the complex JavaScript logic in `index.android.bundle`, a "Surgical Smali Patch" approach was taken. By forcing the underlying native methods to always report a "safe" state (returning `false` or `0x0`), the JavaScript layer receives a clean bill of health.

### Applied Patches

The following methods were patched in the Smali code to always return `0x0` (boolean `false`):

| Class | Method | Description |
| :--- | :--- | :--- |
| `be/c` | `c()` | Global JailMonkey Root Check |
| `zd/a` | `c()` | Hook & Malicious App Detection |
| `ae/a` | `a()` | Mock Location Check |
| `yd/a` | `a()` | External Storage Check |
| `xd/a` | `a()` | ADB Enabled Check |
| `com.scottyab.rootbeer.RootBeerNative` | `a()` | Native RootBeer Flag |

### Example Smali Patch (be/c.smali)
Original method structure:
```smali
.method public c()Z
    # ... complex detection logic ...
    return v0
.end method
```

Patched method structure:
```smali
.method public c()Z
    .locals 1
    const/4 v0, 0x0
    return v0
.end method
```

## Conclusion

By neutralizing the core detection methods in the `JailMonkey` and `RootBeer` implementation, the application is effectively "blinded" to the device's actual security state, allowing it to run on rooted devices or environments with ADB/Hooks enabled.
