#!/usr/bin/env python3
"""Native messaging host bridging Chrome to KGet's D-Bus service."""

import json
import os
import struct
import subprocess
import sys


def default_download_dir():
    home = os.path.expanduser("~")
    try:
        result = subprocess.run(
            ["xdg-user-dir", "DOWNLOAD"], capture_output=True, text=True, timeout=5
        )
        downloads = result.stdout.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired):
        downloads = ""
    # xdg-user-dir falls back to bare $HOME (not $HOME/Downloads) when
    # there's no ~/.config/user-dirs.dirs at all -- treat that as not found.
    if not downloads or downloads.rstrip("/") == home.rstrip("/"):
        return os.path.join(home, "Downloads")
    return downloads


def read_message():
    raw_length = sys.stdin.buffer.read(4)
    if len(raw_length) < 4:
        return None
    (length,) = struct.unpack("<I", raw_length)
    data = sys.stdin.buffer.read(length)
    return json.loads(data)


def write_message(message):
    data = json.dumps(message).encode("utf-8")
    sys.stdout.buffer.write(struct.pack("<I", len(data)))
    sys.stdout.buffer.write(data)
    sys.stdout.buffer.flush()


def add_transfer(url, filename):
    # A non-empty destDir makes KGet add+start the transfer immediately with
    # no interactive dialog. Passing dir+filename (when we know the real
    # filename, e.g. from Chrome's own Content-Disposition resolution) also
    # sidesteps KGet's own filename guess, which is derived purely from the
    # URL path and gets it wrong for opaque/signed URLs.
    dest_dir = default_download_dir()
    dest = os.path.join(dest_dir, filename) if filename else dest_dir
    cmd = [
        "dbus-send",
        "--print-reply",
        "--reply-timeout=10000",
        "--dest=org.kde.kget",
        "/KGet",
        "org.kde.kget.main.addTransfer",
        f"string:{url}",
        f"string:{dest}",
        "boolean:true",
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
    except FileNotFoundError:
        return False, "dbus-send not found on this system"
    except subprocess.TimeoutExpired:
        return False, "dbus-send call timed out (is KGet running?)"

    if result.returncode != 0:
        stderr = result.stderr.strip()
        return False, f"dbus-send failed: {stderr or 'unknown error'}"
    return True, None


def main():
    message = read_message()
    if not message or message.get("action") != "addTransfer" or "url" not in message:
        write_message({"ok": False, "error": "invalid request"})
        return

    ok, error = add_transfer(message["url"], message.get("filename"))
    write_message({"ok": True} if ok else {"ok": False, "error": error})


if __name__ == "__main__":
    main()
