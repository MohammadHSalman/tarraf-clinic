# Smaller Android packages — 0.4.0

The universal APK contains ARM64, ARM32 and x86_64 native libraries. They occupy approximately 76.8 MB of the 79.3 MB package. Each phone needs only its matching architecture.

Delivered phone variants:

| Package | Download size (decimal MB) | Reduction vs universal |
| --- | ---: | ---: |
| ARM64 | 28.6 | 64.0% |
| ARM32 | 25.1 | 68.3% |

Choose according to the device ABI. ARM32 is not supported on ARM64-only Android devices. The universal release remains available separately for compatibility with all original ABIs, including x86_64 emulators.

These APKs are architecture-specific packages of the existing validated release. Their manifest, Dart AOT code, DEX, images, fonts, resources and matching native libraries are byte-for-byte unchanged. Only libraries for other architectures, old signature metadata and redundant ZIP metadata are removed. Each package is aligned for 16 KB native library loading and signed again with the inherited clinic certificate. Version remains 0.4.0 / build 4. This is a packaging-only update; the database and migration logic are unchanged.

Libraries remain uncompressed, preserving direct loading from the APK rather than increasing installed storage with a separate extracted copy. This reduces package/storage size; RAM use and screen responsiveness have not been newly benchmarked on a physical phone. No feature removal or replacement of clinical/encryption code was performed.

Validation: ZIP integrity, APK v2/v3 signature verification, unchanged signing certificate, 16 KB ZIP alignment, exactly one ABI per package, exact retained-entry set equality and SHA/byte equality of every retained payload against the universal release. No new ARM hardware execution test was performed for these packaging variants. Functional test evidence for the unchanged 0.4.0 application is in VALIDATION.md.

To compile future small releases through Flutter normally:

```sh
flutter build apk --release --split-per-abi --target-platform=android-arm,android-arm64
```

Or run `sh tool/build_small_apks.sh`. Keep the Android version in sync with pubspec for future releases.

The Linux helper `tool/package_small_apks.py` can also reproduce these packages from an existing universal APK, with Android Build Tools 35+ and JDK 17:

```sh
python3 tool/package_small_apks.py /path/to/universal.apk \
  --tools /path/to/android-sdk/build-tools/35.0.0 \
  --keystore private/clinic-release.jks \
  --password-file private/signing-password.txt \
  --output /path/to/output
```

Back up patient data before updating; install the correct ABI package over the existing app without uninstalling it. Architecture-specific packages are standalone APKs, not Play Store split-install bundles.
