# Build and test

Toolchain used: Flutter 3.35.5, Dart 3.9.2. Android project: Gradle 8.12, AGP 8.9.1, compileSdk 36, targetSdk 35, minSdk 24, NDK 27.0.12077973. Use a full JDK 17 (including javac), Android SDK platforms 34/35/36, build tools 35/36 and CMake 3.22.1 as required by the plugins.

```sh
flutter pub get
flutter analyze
flutter test --reporter expanded
flutter build bundle --debug --no-pub
flutter build apk --release
```

On Linux tests require libsqlite3 (Ubuntu: libsqlite3-dev). FFI tests execute actual SQLite, not a mock. They do not execute Android's SQLCipher native driver. Configure android/local.properties with local sdk.dir and flutter.sdk. No SDK paths or proxy settings are shipped.

Do not run flutter create over the included native project. MainActivity extends FlutterFragmentActivity and explicitly invokes GeneratedPluginRegistrant, preventing the native registration problem in the initial release. Run **flutter pub get**, not only dart pub get, after adding plugins. SQLCipher ProGuard keep rules are included. No INTERNET permission is declared in the release application manifest.

Android release signing uses private/clinic-release.jks and private/signing-password.txt, preserved from 0.1.1. Never replace the key for an in-place update. APK 0.4.0 is delivered separately from this source archive. See docs/RELEASE_040_AR.md for the schema 2 → 4 migration and financial semantics. The old 0.2 release was validated independently; current native build and emulator upgrade validation are recorded in docs/VALIDATION.md.

```sh
# Regenerate the executable SQL schema from the canonical Dart schema:
dart run tool/export_schema.dart
# Optional logo re-tracing, assets are already generated:
# Python packages: opencv-python-headless, numpy, cairosvg
python3 tool/trace_logo.py
```

The iOS project is inherited and not built/validated here. iOS deployment still requires platform privacy permissions, signing, SQLCipher/CocoaPods validation, backup exclusions and app-switcher privacy review.

Dependencies: https://pub.dev/packages/sqflite_sqlcipher (native encrypted SQLite), https://pub.dev/packages/provider (state), https://pub.dev/packages/flutter_svg (vector rendering). Exact resolved versions and package hashes are pinned in pubspec.lock.


Release 0.4.0 uses pubspec 0.4.0+4 and explicitly pins Android versionName 0.4.0 / versionCode 4 in android/app/build.gradle.kts. Keep these values in sync for future releases. The package remains com.tarraf.clinic and uses the inherited release signing key.
