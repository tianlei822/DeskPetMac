#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

product_name="DeskPetMac"
bundle_id="local.deskpet.mac"
configuration="release"
app_path=".build/${configuration}/${product_name}.app"
contents_path="${app_path}/Contents"
macos_path="${contents_path}/MacOS"
resources_path="${contents_path}/Resources"
icon_source_path="Resources/AppIcon.icns"

swift build -c "${configuration}" --product "${product_name}" >&2

if [[ ! -f "${icon_source_path}" ]]; then
    scripts/generate-app-icon.swift >&2
fi

rm -rf "${app_path}"
mkdir -p "${macos_path}" "${resources_path}"
cp ".build/${configuration}/${product_name}" "${macos_path}/${product_name}"
chmod +x "${macos_path}/${product_name}"
cp "${icon_source_path}" "${resources_path}/AppIcon.icns"

cat > "${contents_path}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>DeskPet</string>
    <key>CFBundleExecutable</key>
    <string>${product_name}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${bundle_id}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>DeskPet</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSLocationUsageDescription</key>
    <string>DeskPet uses your approximate location to fetch local weather and switch its animation.</string>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>DeskPet uses your approximate location to fetch local weather and switch its animation.</string>
    <key>NSUserNotificationUsageDescription</key>
    <string>DeskPet sends stand and stretch reminders while you work.</string>
    <key>NSHumanReadableCopyright</key>
    <string>Local personal project</string>
</dict>
</plist>
EOF

codesign --force --deep --sign - "${app_path}" >&2

echo "${PWD}/${app_path}"
