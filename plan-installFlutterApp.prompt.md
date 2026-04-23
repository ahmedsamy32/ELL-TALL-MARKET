# Plan: Install Flutter App on Mobile Device

## Overview
Install the Ell Tall Market Flutter application on an Android device with updated version 1.0.1+2.

## Prerequisites
- Flutter SDK installed and configured
- Android device connected via USB
- USB debugging enabled on the device
- Device authorized for debugging
- Android SDK and build tools properly configured

## Steps

### 1. Update Version Number
**Status:** ✅ Completed
- Updated `pubspec.yaml` version to `1.0.1+2`
- Version format: `major.minor.patch+buildNumber`

### 2. Clean Build (if needed)
**Command:**
```powershell
flutter clean
```
**Note:** This removes build artifacts and .dart_tool directory. Some files may be locked on Windows, which is normal.

### 3. Get Dependencies
**Command:**
```powershell
flutter pub get
```
**Purpose:** Resolves and downloads all package dependencies specified in pubspec.yaml

### 4. Build Release APK
**Command:**
```powershell
flutter build apk --release
```
**Output Location:** `build\app\outputs\flutter-apk\app-release.apk`
**Expected Size:** ~100-120 MB
**Features:**
- Tree-shaking enabled (reduces font and asset sizes)
- Release mode optimizations
- Code obfuscation for production

### 5. Install on Device
**Method A: Using Gradle (Recommended)**
```powershell
cd android
.\gradlew.bat installRelease
```

**Method B: Using ADB**
```powershell
adb install build\app\outputs\flutter-apk\app-release.apk
```

**Method C: Using Flutter**
```powershell
flutter install
```

### 6. Verify Installation
- Check the app appears in device app drawer
- Launch the app and verify version number
- Test basic functionality

## Troubleshooting

### Issue: gradlew.bat not recognized
**Solution:** In PowerShell, use `.\gradlew.bat` instead of `gradlew.bat` when in the android directory.

### Issue: Device not detected
**Solutions:**
- Check USB cable connection
- Verify USB debugging is enabled
- Accept authorization prompt on device
- Run `adb devices` to list connected devices
- Try different USB port or cable

### Issue: Build fails due to signing
**Solutions:**
- Ensure `key.properties` file exists in android directory
- Verify keystore file path and credentials
- Check `android/app/build.gradle.kts` signing configuration

### Issue: Locked files during clean
**Solution:** Normal on Windows. Close IDE/editors or use Task Manager to end Java/Gradle processes if needed.

## Additional Options

### Install Debug Build (Faster)
```powershell
flutter build apk --debug
cd android
.\gradlew.bat installDebug
```

### Install Specific Build Variant
```powershell
# Split APKs per ABI (smaller size)
flutter build apk --split-per-abi --release

# Install specific ABI
adb install build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
```

### Generate App Bundle (for Play Store)
```powershell
flutter build appbundle --release
```
**Output:** `build\app\outputs\bundle\release\app-release.aab`

## File Locations
- **Source:** `E:\FlutterProjects\Ell Tall Market`
- **APK Output:** `build\app\outputs\flutter-apk\app-release.apk`
- **Bundle Output:** `build\app\outputs\bundle\release\app-release.aab`
- **Gradle Wrapper:** `android\gradlew.bat`
- **Version Config:** `pubspec.yaml` (line 21)

## Version Information
- **App Name:** Ell Tall Market (التل ماركت)
- **Current Version:** 1.0.1+2
- **Version Name:** 1.0.1 (displayed to users)
- **Build Number:** 2 (internal tracking)

## Next Steps After Installation
1. Launch app on device
2. Test core functionality
3. Verify all features work as expected
4. Check for any runtime errors or crashes
5. Monitor performance and memory usage

## Distribution
To share the APK with others:
1. Copy `app-release.apk` from build directory
2. Share via email, cloud storage, or direct transfer
3. Recipients must enable "Install from Unknown Sources" in Android settings
4. Alternatively, publish to Google Play Store using the app bundle

## Notes
- Release builds are optimized and minified
- Debug symbols are removed for security
- ProGuard/R8 obfuscation is applied
- Always increment version number for new releases
- Test thoroughly before distributing to users
