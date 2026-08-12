#!/usr/bin/env bash
# Fetches the latest release source archive and runs install.sh from it, so
# setup doesn't require a git clone:
#
#   curl -fsSL https://raw.githubusercontent.com/andwati/kget-capture/main/install-remote.sh | bash
#   wget -qO- https://raw.githubusercontent.com/andwati/kget-capture/main/install-remote.sh | bash
set -euo pipefail

REPO="andwati/kget-capture"

fetch_stdout() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$1"
  else
    echo "ERROR: this installer needs 'curl' or 'wget' on PATH." >&2
    exit 1
  fi
}

fetch_to_file() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  else
    wget -qO "$2" "$1"
  fi
}

echo "Looking up the latest release..."
tag="$(fetch_stdout "https://api.github.com/repos/$REPO/releases/latest" \
  | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')"
if [ -z "$tag" ]; then
  echo "ERROR: couldn't determine the latest release tag from GitHub." >&2
  exit 1
fi
echo "Latest release: $tag"

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: 'python3' is required but not found on PATH." >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

zip_path="$tmp_dir/kget-capture.zip"
zip_url="https://github.com/$REPO/releases/download/$tag/kget-capture-$tag.zip"
echo "Downloading $zip_url..."
fetch_to_file "$zip_url" "$zip_path"

echo "Extracting..."
src_dir="$tmp_dir/src"
python3 -c "
import sys, zipfile
zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])
" "$zip_path" "$src_dir"

echo "Running install.sh..."
bash "$src_dir/install.sh"
