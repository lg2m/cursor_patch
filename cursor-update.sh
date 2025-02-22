#!/bin/bash
set -e

UPDATER_URL="https://downloads.cursor.com/production/appimageupdatetool/linux/x64/appimageupdatetool_x64.AppImage"
ZSYNC_URL="zsync|https://downloads.cursor.com/production/client/linux/x64/appimage/cursor-latest.appimage.zsync"
SEARCH_DIR="$HOME/Applications"
APPIMAGETOOL="$HOME/Applications/appimagetool-x86_64.AppImage"

find_appimage() {
  find "$SEARCH_DIR" -maxdepth 1 \( -name 'cursor*AppImage' -o -name 'Cursor*AppImage' \) \
        -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-
}

echo "searching for existing AppImage in $SEARCH_DIR"
TARGET_APPIMAGE=$(find_appimage)

if [ -z "$TARGET_APPIMAGE" ]; then
  echo "no existing AppImage found"
  exit 1
else
  echo "found existing AppImage: $TARGET_APPIMAGE"
fi

# Temporary updater name
TEMP_UPDATER="/tmp/appimageupdatetool_$(date +%s).AppImage"

# Download updater
echo "downloading AppImageUpdate tool"
curl -L "$UPDATER_URL" -o "$TEMP_UPDATER" || {
  echo "error: failed to download AppImageUpdate tool"
  exit 1
}

# Make executable
chmod +x "$TEMP_UPDATER" || {
  echo "error: failed to make updater executable"
  exit 1
}

# Start update
echo "updating AppImage"
"$TEMP_UPDATER" -u "$ZSYNC_URL" -O "$TARGET_APPIMAGE" || {
  echo "error: update failed or at latest"
  exit 1
}

echo "updated to latest"
rm "$TEMP_UPDATER"

"$TARGET_APPIMAGE" --appimage-extract
rm "$TARGET_APPIMAGE"

TARGET_FILE="squashfs-root/usr/share/cursor/resources/app/out/main.js"
sed -i 's/,minHeight/,frame:false,minHeight/g' "$TARGET_FILE"

ARCH=x86_64
"$APPIMAGETOOL" squashfs-root "$TARGET_APPIMAGE"

rm -r squashfs-root

"$TARGET_APPIMAGE" &

echo "cursor patch complete"
