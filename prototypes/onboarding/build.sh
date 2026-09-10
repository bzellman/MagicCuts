#!/usr/bin/env bash
set -euo pipefail
prototype_root="$(cd "$(dirname "$0")" && pwd)"
prototype_output="${1:-/tmp/MagicCutsOnboardingPreview}"
prototype_sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
mkdir -p "$prototype_output/OnboardingPreview.app"
SDKROOT="$prototype_sdk" xcrun --sdk iphonesimulator swiftc -warnings-as-errors -parse-as-library -O -sdk "$prototype_sdk" -target arm64-apple-ios26.0-simulator \
  "$prototype_root/OnboardingPreview.swift" "$prototype_root/InstrumentTiles.swift" -o "$prototype_output/OnboardingPreview.app/OnboardingPreview"
cat > "$prototype_output/OnboardingPreview.app/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.magiccuts.onboarding-preview</string>
<key>CFBundleName</key><string>Motion Preview</string>
<key>CFBundleExecutable</key><string>OnboardingPreview</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>MinimumOSVersion</key><string>26.0</string>
<key>UIDeviceFamily</key><array><integer>1</integer><integer>2</integer></array>
<key>UILaunchScreen</key><dict/>
<key>UISupportedInterfaceOrientations</key><array><string>UIInterfaceOrientationPortrait</string><string>UIInterfaceOrientationLandscapeLeft</string><string>UIInterfaceOrientationLandscapeRight</string></array>
</dict></plist>
PLIST
codesign --force --sign - "$prototype_output/OnboardingPreview.app"
printf '%s\n' "$prototype_output/OnboardingPreview.app"
