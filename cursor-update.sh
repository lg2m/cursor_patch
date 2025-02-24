#!/bin/bash
set -euo pipefail

UPDATER_URL="https://downloads.cursor.com/production/appimageupdatetool/linux/x64/appimageupdatetool_x64.AppImage"
ZSYNC_URL="zsync|https://downloads.cursor.com/production/client/linux/x64/appimage/cursor-latest.appimage.zsync"
SEARCH_DIR="$HOME/Applications"
APPIMAGETOOL="$HOME/Applications/appimagetool-x86_64.AppImage"
TEMP_UPDATER="/tmp/appimageupdatetool_$(date +%s).AppImage"
TARGET_APPIMAGE=""

error_exit() {
  echo "error: $1" >&2
  exit 1
}

find_appimage() {
  find "$SEARCH_DIR" -maxdepth 1 \( -name 'cursor*AppImage' -o -name 'Cursor*AppImage' \) \
        -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-
}

update_appimage() {
  echo "updating $TARGET_APPIMAGE to latest"
  if ! "$TEMP_UPDATER" -u "$ZSYNC_URL" -O "$TARGET_APPIMAGE"; then
    error_exit "failed to update $TARGET_APPIMAGE, either no update is available or this script is broken"
  fi
  rm "$TEMP_UPDATER"
}

extract_appimage() {
  echo "extracting $TARGET_APPIMAGE"
  if ! "$TARGET_APPIMAGE" --appimage-extract; then
    error_exit "failed to extract $TARGET_APPIMAGE"
  fi
  rm "$TARGET_APPIMAGE"
}

patch_appimage() {
  local target_file="squashfs-root/usr/share/cursor/resources/app/out/main.js"
  if ! sed -i 's/,minHeight/,frame:false,minHeight/g' "$target_file"; then
    error_exit "failed to patch AppImage"
  fi
}

# validate x86_64 architecture
if [ "$(uname -m)" != "x86_64" ]; then
  error_exit "this script is only supported on x86_64 architecture"
fi

# validate appimagetool
if [ ! -f "$APPIMAGETOOL" ]; then
  error_exit "appimagetool not found"
fi

# find existing AppImage
echo "searching for AppImage in $SEARCH_DIR"
TARGET_APPIMAGE=$(find_appimage)
if [ -z "$TARGET_APPIMAGE" ]; then
  error_exit "no existing AppImage found"
fi
echo "found $TARGET_APPIMAGE"

# Download updater tool and update AppImage
echo "downloading AppImageUpdate tool"
if ! curl -L "$UPDATER_URL" -o "$TEMP_UPDATER"; then
  error_exit "failed to download AppImageUpdate tool"
fi

echo "making $TEMP_UPDATER executable"
if ! chmod +x "$TEMP_UPDATER"; then
  error_exit "failed to make $TEMP_UPDATER executable"
fi

# update, extract, and patch AppImage
update_appimage
extract_appimage
patch_appimage

# repack AppImage using appimagetool
ARCH=x86_64
if [ -f "$APPIMAGETOOL" ] && "$APPIMAGETOOL" squashfs-root "$HOME/Applications/cursor.AppImage"; then
  echo "repacked to $HOME/Applications/cursor.AppImage"
else
  error_exit "failed to repack $HOME/Applications/cursor.AppImage"
fi

# clean up
[ -d "squashfs-root" ] && rm -r "squashfs-root"

# run AppImage
echo "launching $HOME/Applications/cursor.AppImage"
"$HOME/Applications/cursor.AppImage" &

echo "cursor patch complete"
