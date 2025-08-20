#!/usr/bin/env bash
set -e

VERSION=$1
if [ -z "$VERSION" ]; then
    echo "usage: $0 <version>"
    exit 1
fi

# ===== configuration =====
APP_NAME="AppFlowy"
ARCH="x86_64"
APP_DIR="AppDir"
OUTPUT="${APP_NAME}-${VERSION}-${ARCH}.AppImage"

# ===== 1. clear and prepare AppDir =====
echo "==> clear old AppDir..."
rm -rf "$APP_DIR" || true

echo "==> copy application files..."
cp -r appflowy_flutter/build/linux/x64/release/bundle "$APP_DIR"

echo "==> copy icons..."
mkdir -p "$APP_DIR/usr/share/icons/hicolor/scalable/apps"
cp scripts/linux_distribution/packaging/appflowy.svg \
   "$APP_DIR/usr/share/icons/hicolor/scalable/apps/"
cp scripts/linux_distribution/packaging/appflowy.svg \
   "$APP_DIR/appflowy.svg"

# ===== 2. create AppRun =====
echo "==> create AppRun..."
cat > "$APP_DIR/AppRun" <<EOF
#!/bin/bash
DIR="\$(dirname "\$(readlink -f "\$0")")"
exec "\$DIR/${APP_NAME}" "\$@"
EOF
chmod +x "$APP_DIR/AppRun"

# ===== 3. create desktop file =====
echo "==> create desktop file..."
mkdir -p "$APP_DIR/usr/share/applications"
cat > "$APP_DIR/usr/share/applications/${APP_NAME}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${APP_NAME}
Exec=${APP_NAME}
Icon=appflowy
Comment=${APP_NAME} Application
Categories=Utility;
EOF

# ===== 4. download appimagetool =====
APPIMAGETOOL="./appimagetool-${ARCH}.AppImage"
if [ ! -f "$APPIMAGETOOL" ]; then
    echo "==> download appimagetool..."
    wget -O "$APPIMAGETOOL" \
        "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${ARCH}.AppImage"
    chmod +x "$APPIMAGETOOL"
fi

# ===== 5. create AppImage =====
echo "==> start packaging..."
cp "$APP_DIR/usr/share/applications/${APP_NAME}.desktop" \
    "$APP_DIR/"
"$APPIMAGETOOL" "$APP_DIR" "$OUTPUT"
echo "==> packaging completed!: $OUTPUT"