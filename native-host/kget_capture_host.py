#!/usr/bin/env python3
"""Native messaging host bridging Chrome to KGet's D-Bus service."""

import json
import struct
import subprocess
import sys


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


def add_transfer(url):
    # showNewTransferDialog opens KGet's "New Download" dialog (editable name
    # and destination) and returns immediately without waiting for the user
    # to interact with it. addTransfer, by contrast, only returns once the
    # dialog is dismissed when destDir is empty -- it blocks the D-Bus call
    # on human input, which is why we don't use it here.
    cmd = [
        "dbus-send",
        "--print-reply",
        "--reply-timeout=10000",
        "--dest=org.kde.kget",
        "/KGet",
        "org.kde.kget.main.showNewTransferDialog",
        f"array:string:{url}",
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

    ok, error = add_transfer(message["url"])
    write_message({"ok": True} if ok else {"ok": False, "error": error})


if __name__ == "__main__":
    main()
