#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.local/share/kget-capture"
HOST_SCRIPT_SRC="$SCRIPT_DIR/native-host/kget_capture_host.py"
HOST_SCRIPT_DEST="$INSTALL_DIR/kget_capture_host.py"
MANIFEST_TEMPLATE="$SCRIPT_DIR/native-host/com.kget_capture.host.json"
GENERATED_MANIFEST="$INSTALL_DIR/com.kget_capture.host.json"

echo "Checking dependencies..."
for dep in python3 dbus-send; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    echo "ERROR: '$dep' is required but not found on PATH." >&2
    exit 1
  fi
done

echo "Installing native host script to $HOST_SCRIPT_DEST"
mkdir -p "$INSTALL_DIR"
cp "$HOST_SCRIPT_SRC" "$HOST_SCRIPT_DEST"
chmod +x "$HOST_SCRIPT_DEST"

echo "Generating native messaging host manifest..."
sed "s|__HOST_SCRIPT_PATH__|$HOST_SCRIPT_DEST|" "$MANIFEST_TEMPLATE" > "$GENERATED_MANIFEST"

declare -A BROWSER_DIRS=(
  ["Google Chrome"]="$HOME/.config/google-chrome"
  ["Chromium"]="$HOME/.config/chromium"
  ["Brave"]="$HOME/.config/BraveSoftware/Brave-Browser"
  ["Vivaldi"]="$HOME/.config/vivaldi"
  ["Microsoft Edge"]="$HOME/.config/microsoft-edge"
)

registered_any=false
for browser in "${!BROWSER_DIRS[@]}"; do
  config_dir="${BROWSER_DIRS[$browser]}"
  if [ -d "$config_dir" ]; then
    target_dir="$config_dir/NativeMessagingHosts"
    mkdir -p "$target_dir"
    cp "$GENERATED_MANIFEST" "$target_dir/com.kget_capture.host.json"
    echo "Registered native host for $browser"
    registered_any=true
  fi
done

if [ "$registered_any" = false ]; then
  echo "WARNING: no supported browser config directories were found. Checked:"
  for browser in "${!BROWSER_DIRS[@]}"; do
    echo "  - ${BROWSER_DIRS[$browser]}"
  done
fi

echo "Checking KGet's default download folder..."
python3 - <<'PYEOF'
import configparser
import os
import subprocess

kgetrc = os.path.expanduser("~/.config/kgetrc")
key = "LastDirectory[$e]"

home = os.path.expanduser("~")
try:
    result = subprocess.run(["xdg-user-dir", "DOWNLOAD"], capture_output=True, text=True, timeout=5)
    downloads = result.stdout.strip()
except (FileNotFoundError, subprocess.TimeoutExpired):
    downloads = ""
# xdg-user-dir falls back to bare $HOME (not $HOME/Downloads) when there's
# no ~/.config/user-dirs.dirs at all -- treat that the same as "not found".
if not downloads or downloads.rstrip("/") == home.rstrip("/"):
    downloads = os.path.join(home, "Downloads")

cp = configparser.ConfigParser(interpolation=None)
cp.optionxform = str
if os.path.exists(kgetrc):
    cp.read(kgetrc)

if not cp.has_section("Internal"):
    cp.add_section("Internal")

if key in cp["Internal"]:
    print(f"KGet's default download folder is already set ({cp['Internal'][key]}), leaving it as-is")
else:
    cp["Internal"][key] = downloads + "/"
    os.makedirs(os.path.dirname(kgetrc), exist_ok=True)
    with open(kgetrc, "w") as f:
        cp.write(f)
    print(f"Set KGet's default download folder to {downloads}")
    print("(If KGet is currently running, restart it for this to take effect.)")
PYEOF

echo "Checking KGet's download-finished notification..."
KNOTIFYRC="$HOME/.config/knotifyrc"
if [ -f "$KNOTIFYRC" ] && grep -q '^\[Event/kget/finished\]' "$KNOTIFYRC"; then
  echo "KGet's download-finished notification is already configured, leaving it as-is"
elif command -v kwriteconfig6 >/dev/null 2>&1; then
  kwriteconfig6 --file knotifyrc --group "Event/kget/finished" --key Action Popup
  echo "Enabled a desktop popup notification for KGet's \"Download Finished\" event"
else
  echo "Skipped: 'kwriteconfig6' not found (not on KDE Plasma?) -- no popup notification set up"
fi

EXT_ID=$(cat "$SCRIPT_DIR/keys/extension-id.txt")

cat <<EOF

Install complete.

Extension ID: $EXT_ID

Next steps:
  1. Open chrome://extensions (or the equivalent for your browser)
  2. Enable "Developer mode" (top-right toggle)
  3. Click "Load unpacked" and select: $SCRIPT_DIR/extension
  4. Confirm the loaded extension's ID matches: $EXT_ID

Make sure KGet is running (or set to autostart) for captures to work.
EOF
