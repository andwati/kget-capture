#!/usr/bin/env python3
"""Native messaging host bridging Chrome to KGet's D-Bus service."""

import json
import os
import re
import shutil
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
    # A bare directory path with no trailing slash (e.g. "/home/ian/Downloads")
    # gets misparsed by KGet's addTransfer as dir="/home/ian" + filename=
    # "Downloads" -- the same split it applies to a real dir/filename path --
    # landing the transfer in the parent directory instead. A trailing slash
    # keeps it unambiguous when we don't have a real filename to append.
    dest = os.path.join(dest_dir, filename) if filename else dest_dir.rstrip("/") + "/"
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
        return False, "dbus-send not found on this system", None, dest
    except subprocess.TimeoutExpired:
        return False, "dbus-send call timed out (is KGet running?)", None, dest

    if result.returncode != 0:
        stderr = result.stderr.strip()
        return False, f"dbus-send failed: {stderr or 'unknown error'}", None, dest

    # addTransfer replies with an array of the new transfer's D-Bus object
    # path(s), e.g. `array [ string "/KGet/Transfers/9" ]` -- grab the first
    # one so we can poll it for completion (see spawn_notifier).
    match = re.search(r'string "(/KGet/Transfers/\d+)"', result.stdout)
    transfer_path = match.group(1) if match else None
    return True, None, transfer_path, dest


# KGet only fires its own "Download Finished" desktop notification if the
# transfer was still in a non-Finished state the first time KGet's UI
# observed it (see GenericObserver::transfersChangedEvent in KGet's
# core/kget.cpp: `status() == Finished && startStatus() != Finished`).
# Small/fast downloads routinely finish before that first observation, so
# KGet silently skips the notification for them -- confirmed by tracing
# actual D-Bus traffic against a running KGet instance. We replace it with
# our own, driven by polling the transfer's real progress, so captures
# always get a completion notification regardless of how fast they finish.
_NOTIFIER_SCRIPT = """
import subprocess, sys, time

path, dest = sys.argv[1], sys.argv[2]

def get_percent():
    try:
        result = subprocess.run(
            ["dbus-send", "--session", "--print-reply", "--dest=org.kde.kget",
             path, "org.kde.kget.transfer.percent"],
            capture_output=True, text=True, timeout=10,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return None
    if result.returncode != 0:
        return None
    for line in result.stdout.splitlines():
        line = line.strip()
        if line.startswith("int32"):
            return int(line.split()[-1])
    return None

deadline = time.time() + 6 * 3600
finished = False
while time.time() < deadline:
    percent = get_percent()
    if percent is None:
        break  # transfer object is gone: finished+cleared, cancelled, or KGet restarted
    if percent >= 100:
        finished = True
        break
    time.sleep(2)

if finished:
    subprocess.run(
        ["notify-send", "--app-name=KGet Capture", "--icon=kget",
         "Download complete", dest.rsplit("/", 1)[-1]],
        timeout=10,
    )
"""


def spawn_notifier(transfer_path, dest):
    if not transfer_path or not shutil.which("notify-send"):
        return
    # Detached (new session, no inherited pipes) so it keeps running after
    # Chrome closes the native-messaging connection and kills this process --
    # sendNativeMessage() tears down its native host as soon as it gets a
    # reply, which is long before a real download finishes.
    subprocess.Popen(
        [sys.executable, "-c", _NOTIFIER_SCRIPT, transfer_path, dest],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )


def main():
    message = read_message()
    if not message or message.get("action") != "addTransfer" or "url" not in message:
        write_message({"ok": False, "error": "invalid request"})
        return

    ok, error, transfer_path, dest = add_transfer(message["url"], message.get("filename"))
    if ok:
        spawn_notifier(transfer_path, dest)
    write_message({"ok": True} if ok else {"ok": False, "error": error})


if __name__ == "__main__":
    main()
