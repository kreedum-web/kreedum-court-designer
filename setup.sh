#!/usr/bin/env bash
# Kreedum Construction - one-time project setup (macOS / Linux)
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/5] Generating Android project files (existing files are kept)..."
flutter create --org com --project-name kreedum_construction --platforms android .
echo "[2/5] Fetching packages..."
flutter pub get
echo "[3/5] Generating app icons..."
dart run flutter_launcher_icons
echo "[4/5] Generating splash screen..."
dart run flutter_native_splash:create

echo "[5/5] Adding release signing config..."
G=android/app/build.gradle.kts
if [ -f "$G" ] && ! grep -q 'key.properties' "$G"; then
  perl -0pi -e 's/^/import java.io.FileInputStream\nimport java.util.Properties\n\n/' "$G"
  perl -0pi -e 's/    buildTypes \{/    signingConfigs {\n        create("release") {\n            val props = Properties()\n            val propsFile = rootProject.file("key.properties")\n            if (propsFile.exists()) {\n                props.load(FileInputStream(propsFile))\n                keyAlias = props["keyAlias"] as String\n                keyPassword = props["keyPassword"] as String\n                storeFile = file(props["storeFile"] as String)\n                storePassword = props["storePassword"] as String\n            }\n        }\n    }\n\n    buildTypes {/' "$G"
  perl -0pi -e 's/signingConfig = signingConfigs.getByName\("debug"\)/signingConfig = if (rootProject.file("key.properties").exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")/' "$G"
  echo "Signing config added to $G"
fi
echo "Done. Edit lib/config/app_config.dart, then: flutter run"
