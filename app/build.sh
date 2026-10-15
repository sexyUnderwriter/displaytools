#!/bin/bash
# Builds "Display Hot Switcher.app", a menu bar wrapper around ../setdisplay.sh.
#
# Usage: ./build.sh [--install] [--open]
#   --install  Copy the finished app to ~/Applications. Quits any running copy,
#              removes every other installed copy (e.g. a stale one in
#              /Applications), and points the Login Item at the new build.
#   --open     Launch the app after building (or after installing).
#
# Requires only the Xcode Command Line Tools (xcode-select --install).
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Display Hot Switcher"
EXECUTABLE="DisplayHotSwitcher"
BUNDLE_ID="local.displaytools.DisplayHotSwitcher"
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
  installed="$dest/$APP_NAME.app"
  mkdir -p "$dest"

  # Quit any running copy so the user doesn't keep using an old build.
  if pgrep -xq "$EXECUTABLE"; then
    printf 'Quitting running %s...\n' "$APP_NAME"
    osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 \
      || pgrep -x "$EXECUTABLE" | xargs kill 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      pgrep -xq "$EXECUTABLE" || break
      sleep 0.5
    done
  fi

  # Remove every other installed copy. Spotlight knows about bundles by id, so
  # this also catches copies the user dragged somewhere unexpected.
  while IFS= read -r stale; do
    [[ -n "$stale" ]] || continue
    case "$stale" in
      "$installed" | "$PWD/$APP") continue ;;
    esac
    printf 'Removing stale copy at %s\n' "$stale"
    rm -rf "$stale"
  done < <(
    { mdfind "kMDItemCFBundleIdentifier == '$BUNDLE_ID'" 2>/dev/null
      ls -d "/Applications/$APP_NAME.app" 2>/dev/null; } | sort -u
  )

  rm -rf "$installed"
  cp -R "$APP" "$dest/"
  target="$installed"
  printf 'Installed to %s\n' "$target"

  # Repoint the Login Item (if any) so it launches this build, not a stale one.
  if osascript -e 'tell application "System Events" to get the path of login item "'"$APP_NAME"'"' >/dev/null 2>&1; then
    osascript >/dev/null <<EOF
tell application "System Events"
  delete login item "$APP_NAME"
  make login item at end with properties {path:"$target", hidden:false}
end tell
EOF
    printf 'Login Item now points at %s\n' "$target"
  fi
fi

if $open_app; then
  open "$target"
fi
