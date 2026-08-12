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
