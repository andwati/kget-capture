#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$HOME/.local/share/kget-capture"

BROWSER_DIRS=(
  "$HOME/.config/google-chrome"
  "$HOME/.config/chromium"
  "$HOME/.config/BraveSoftware/Brave-Browser"
  "$HOME/.config/vivaldi"
  "$HOME/.config/microsoft-edge"
)

for config_dir in "${BROWSER_DIRS[@]}"; do
  manifest="$config_dir/NativeMessagingHosts/com.kget_capture.host.json"
  if [ -f "$manifest" ]; then
    rm -f "$manifest"
    echo "Removed $manifest"
  fi
done

if [ -d "$INSTALL_DIR" ]; then
  rm -rf "$INSTALL_DIR"
  echo "Removed $INSTALL_DIR"
fi

cat <<EOF

Uninstall complete.

Note: this does not remove the unpacked extension itself. Remove it manually
via chrome://extensions (or the equivalent for your browser).
EOF
