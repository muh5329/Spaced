#!/bin/bash
# Reproducible local bundle. Uses the installed universal Godot runtime because
# this machine has web export templates only. No editor installation is required
# to play the resulting app; all project resources are inside its PCK.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
APP_DIR="$PROJECT_DIR/builds/Wayfarer.app"
cd "$PROJECT_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --import
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-pack macOS "$APP_DIR/Contents/Resources/Wayfarer.pck"
cp "$GODOT_BIN" "$APP_DIR/Contents/MacOS/WayfarerEngine"
cat > "$APP_DIR/Contents/MacOS/Wayfarer" <<'LAUNCHER'
#!/bin/bash
set -e
BUNDLE_CONTENTS="$(cd "$(dirname "$0")/.." && pwd)"
exec "$BUNDLE_CONTENTS/MacOS/WayfarerEngine" --main-pack "$BUNDLE_CONTENTS/Resources/Wayfarer.pck" "$@"
LAUNCHER
chmod +x "$APP_DIR/Contents/MacOS/Wayfarer"
cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Wayfarer</string>
<key>CFBundleDisplayName</key><string>Wayfarer</string>
<key>CFBundleIdentifier</key><string>games.orison.wayfarer</string>
<key>CFBundleExecutable</key><string>Wayfarer</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.1.0</string>
<key>CFBundleVersion</key><string>1.1.0</string>
<key>LSMinimumSystemVersion</key><string>12.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>LSApplicationCategoryType</key><string>public.app-category.adventure-games</string>
<key>CFBundleIconFile</key><string>Wayfarer.icns</string>
</dict></plist>
PLIST
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --script res://tools/make_icon.gd
ICON_DIR="$PROJECT_DIR/builds/Wayfarer.iconset"
mkdir -p "$ICON_DIR"
for pixels in 16 32 64 128 256 512; do
  sips -z "$pixels" "$pixels" "$PROJECT_DIR/builds/icon.png" --out "$ICON_DIR/icon_${pixels}x${pixels}.png" >/dev/null
done
cp "$PROJECT_DIR/builds/icon.png" "$ICON_DIR/icon_512x512@2x.png"
iconutil -c icns "$ICON_DIR" -o "$APP_DIR/Contents/Resources/Wayfarer.icns"
cp assets/fonts/OFL.txt "$APP_DIR/Contents/Resources/FONT-LICENSE.txt"
cp docs/GODOT-LICENSE.txt "$APP_DIR/Contents/Resources/GODOT-LICENSE.txt"
cp docs/GODOT-COPYRIGHT.txt "$APP_DIR/Contents/Resources/GODOT-COPYRIGHT.txt"
cp THIRD_PARTY.md "$APP_DIR/Contents/Resources/THIRD_PARTY.md"
mkdir -p "$APP_DIR/Contents/Resources/docs"
rm -f "$APP_DIR/Contents/Resources/docs/INTERIOR_ART_PROMPTS.md"
cp docs/INTERIOR_3D.md "$APP_DIR/Contents/Resources/docs/INTERIOR_3D.md"
cp docs/FRONTIER.md "$APP_DIR/Contents/Resources/docs/FRONTIER.md"
codesign --force --deep --sign - "$APP_DIR"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$PROJECT_DIR/builds/Wayfarer-macOS.zip"
echo "Built $APP_DIR"
