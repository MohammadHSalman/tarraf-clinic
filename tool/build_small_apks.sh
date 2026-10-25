#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/.."
flutter pub get
flutter build apk --release --split-per-abi --target-platform=android-arm,android-arm64
