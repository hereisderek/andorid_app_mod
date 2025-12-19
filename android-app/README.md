# Patched Apps Manager - Android Companion App

An Android companion application for discovering, installing, and updating patched APKs from GitHub releases.

## Features

- Browse available patched apps from a GitHub repository
- Compare installed app versions with available versions
- Download and install APK files
- Signature verification
- Configurable repository URL
- Material 3 design

## Setup

### Prerequisites

- Android Studio Hedgehog or later
- JDK 17
- Android SDK (API 24+)

### Building

1. Open the `android-app` directory in Android Studio
2. Sync Gradle files
3. Build and run on an Android device or emulator

### Default Configuration

The app defaults to fetching apps from: `https://github.com/hereisderek/andorid_app_mod/`

You can change this in the Settings screen within the app.

## Architecture

- **MVVM** with Jetpack Compose
- **Hilt** for dependency injection
- **Retrofit** for networking
- **Kotlin Coroutines** and **Flow** for async operations

## Project Structure

```
app/src/main/java/com/hereisderek/patchedappsmanager/
├── data/
│   ├── model/          # Data models
│   ├── remote/         # API interfaces
│   └── repository/     # Repository layer
├── di/                 # Dependency injection modules
├── ui/
│   ├── screens/        # Composable screens
│   ├── theme/          # UI theme
│   └── viewmodel/      # ViewModels
├── MainActivity.kt
└── PatchedAppsManagerApp.kt
```

## Permissions

- `INTERNET` - For downloading APKs and fetching app data
- `REQUEST_INSTALL_PACKAGES` - For installing APK files
- `QUERY_ALL_PACKAGES` - For checking installed apps

## TODO

- [x] Implement APK download functionality
- [x] Implement APK installation with FileProvider
- [x] Add signature verification
- [x] Handle signature mismatches with error message
- [ ] Add app icons display
- [x] Implement pull-to-refresh
- [x] Add search and filter functionality
- [x] Persist settings with DataStore

## License

See parent repository for license information.
