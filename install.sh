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

declare -A BROWSER_SETTINGS_URLS=(
  ["Google Chrome"]="chrome://settings/downloads"
  ["Chromium"]="chrome://settings/downloads"
  ["Brave"]="brave://settings/downloads"
  ["Vivaldi"]="vivaldi://settings/downloads"
  ["Microsoft Edge"]="edge://settings/downloads"
)

echo "Checking Chrome's \"Ask where to save each file\" setting..."
prompt_warnings=()
for browser in "${!BROWSER_DIRS[@]}"; do
  config_dir="${BROWSER_DIRS[$browser]}"
  prefs_file="$config_dir/Default/Preferences"
  if [ -f "$prefs_file" ] && grep -q '"prompt_for_download":true' "$prefs_file" 2>/dev/null; then
    prompt_warnings+=("  - $browser: open ${BROWSER_SETTINGS_URLS[$browser]} and turn off \"Ask where to save each file before downloading\"")
  fi
done

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

echo "Disabling KGet's own per-transfer notification..."
# KGet only fires this event if the transfer was still non-Finished the
# first time its UI observed it -- small/fast downloads routinely finish
# before that, so KGet silently skips it for them. kget_capture_host.py
# shows its own "Download complete" notification (via notify-send) for
# every capture instead, driven by polling actual transfer progress, so it
# fires reliably regardless of download speed. Disable KGet's copy here to
# avoid a duplicate popup on the transfers that are slow enough for it to
# fire on its own.
if command -v kwriteconfig6 >/dev/null 2>&1; then
  kwriteconfig6 --file knotifyrc --group "Event/kget/finished" --key Action None
  echo "Done -- KGet Capture's own notification will be used instead"
else
  echo "Skipped: 'kwriteconfig6' not found (not on KDE Plasma?) -- KGet's own notification, if any, is left as configured"
fi

echo "Checking for 'notify-send' (used for the download-complete notification)..."
if ! command -v notify-send >/dev/null 2>&1; then
  echo "WARNING: 'notify-send' not found -- captures will still work, but you won't get a notification when they finish"
fi

cat <<EOF

Install complete.

If you installed the extension from the Chrome Web Store, you're done --
reopen its toolbar popup and click "I ran it, check again" to confirm.

If you're loading it unpacked for development instead:
  1. Open chrome://extensions (or the equivalent for your browser)
  2. Enable "Developer mode" (top-right toggle)
  3. Click "Load unpacked" and select: $SCRIPT_DIR/extension
  4. Chrome will assign this unpacked copy its own ID, different from the
     published extension's. Find it on chrome://extensions and add it to
     "allowed_origins" in ~/.config/<browser>/NativeMessagingHosts/com.kget_capture.host.json
     so the native host will accept connections from it too.

Make sure KGet is running (or set to autostart) for captures to work.
EOF

if [ "${#prompt_warnings[@]}" -gt 0 ]; then
  cat <<EOF

WARNING: "Ask where to save each file before downloading" is ON for:
$(printf '%s\n' "${prompt_warnings[@]}")

Chrome shows that dialog itself, before the extension ever gets a chance to
intercept the download -- no extension API can read or suppress it. Turn it
off in each browser above or captures will keep prompting for a location.
EOF
fi
