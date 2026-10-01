#!/bin/bash
# Builds "Display Hot Switcher.app", a menu bar wrapper around ../setdisplay.sh.
#
# Usage: ./build.sh [--install] [--open]
#   --install  Copy the finished app to ~/Applications (replacing any old copy).
#   --open     Launch the app after building (or after installing).
#
# Requires only the Xcode Command Line Tools (xcode-select --install).
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Display Hot Switcher"
EXECUTABLE="DisplayHotSwitcher"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"
SCRIPT="../setdisplay.sh"

install=false
open_app=false
for arg in "$@"; do
  case "$arg" in
    --install) install=true ;;
    --open) open_app=true ;;
    -h|--help)
      sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$arg" >&2
      exit 64
      ;;
  esac
done

[[ -f "$SCRIPT" ]] || {
  printf 'Cannot find %s next to the app folder.\n' "$SCRIPT" >&2
  exit 1
}

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

printf 'Compiling %s...\n' "$EXECUTABLE"
swiftc -O -framework AppKit -o "$APP/Contents/MacOS/$EXECUTABLE" "$EXECUTABLE.swift"

cp Info.plist "$APP/Contents/Info.plist"
cp "$SCRIPT" "$APP/Contents/Resources/setdisplay.sh"
chmod +x "$APP/Contents/Resources/setdisplay.sh"

# Ad-hoc signature so Gatekeeper and TCC treat the bundle as a stable identity.
codesign --force --sign - "$APP" >/dev/null
printf 'Built %s\n' "$APP"

target="$APP"
if $install; then
  dest="$HOME/Applications"
  mkdir -p "$dest"
  rm -rf "$dest/$APP_NAME.app"
  cp -R "$APP" "$dest/"
  target="$dest/$APP_NAME.app"
  printf 'Installed to %s\n' "$target"
fi

if $open_app; then
  open "$target"
fi
