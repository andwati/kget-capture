# KGet Capture

A Chromium browser extension that sends downloads to
[KGet](https://apps.kde.org/kget/), KDE's download manager, instead of the
browser's built-in downloader.

- Right-click a link/image/video/audio and choose **"Download with KGet"**.
- Or toggle **auto-capture** from the toolbar so every download is handed off
  automatically, with the correct filename.
- A desktop notification fires when a capture finishes downloading.

## Requirements

- Linux with KGet installed and running (or set to autostart)
- A Chromium-based browser: Chrome, Chromium, Brave, Vivaldi, or Edge
- `python3`, `dbus-send`
- `curl` or `wget`, for the one-line remote installer below (skip if you'd
  rather download and run `install.sh` yourself)
- `notify-send`, optional, for the completion notification
- `kwriteconfig6` (KDE Frameworks), optional, silences KGet's own duplicate
  notification

Install everything on your distro:

**Fedora**
```bash
sudo dnf install kget python3 dbus-tools libnotify kf6-kconfig
```

**Arch / Manjaro**
```bash
sudo pacman -S kget python dbus libnotify kconfig
```

**Debian / Ubuntu / KDE neon**
```bash
sudo apt install kget python3 dbus-bin libnotify-bin kf6-kconfig-bin
```

**openSUSE**
```bash
sudo zypper install kget python3 dbus-1 libnotify-tools kconfig-tools
```

(`notify-send` and `kwriteconfig6` package names shift around between distro
versions. If a command above fails, drop that one package and search your
package manager for the binary name instead. Everything else still works
without them.)

## Install

1. Install the extension from the Chrome Web Store: **`<CHROME_WEB_STORE_URL>`**
   *(placeholder, fill in once the listing is live)*.
2. Click the extension's toolbar icon. The popup detects that the native
   messaging host isn't set up yet and shows a one-line command; run it in a
   terminal, then click "I ran it, check again" in the popup:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/andwati/kget-capture/main/install-remote.sh | bash
   ```
   (or with `wget`: `wget -qO- https://raw.githubusercontent.com/andwati/kget-capture/main/install-remote.sh | bash`)

   This downloads the latest release and runs its `install.sh`, which
   registers the native host for every supported browser it finds installed
   and prints any remaining setup warnings. No git clone required. If you'd
   rather run it yourself: download and extract `kget-capture-vX.Y.Z.zip`
   (the source archive, not `kget-capture-extension-vX.Y.Z.zip`) from the
   [Releases page](https://github.com/andwati/kget-capture/releases), then
   from inside that folder run `./install.sh` directly.
3. Open your browser's download settings (`chrome://settings/downloads`,
   `brave://settings/downloads`, etc.) and turn **off** "Ask where to save
   each file before downloading". Chrome shows this dialog itself, before the
   extension gets a chance to intercept the download, so this one-time change
   is required (no extension API can do it for you).

### Building from source

Contributing, or want to run an unreleased version? Load the extension
unpacked instead of step 1 above:

```bash
git clone https://github.com/andwati/kget-capture.git
cd kget-capture
./install.sh
```

(Or, for an already-tagged version without cloning: download and extract
`kget-capture-extension-vX.Y.Z.zip` from the
[Releases page](https://github.com/andwati/kget-capture/releases) instead.
It's already just `extension/`'s contents, unpacked at the zip root the way
Chrome expects. You'll still need `kget-capture-vX.Y.Z.zip` for `install.sh`,
per step 2 above.)

Then in `chrome://extensions`: enable **Developer mode**, click **Load
unpacked**, and select the `extension/` directory (from your clone, or the
extracted extension zip). Chrome assigns this unpacked copy its own ID,
different from the published extension's, so add it to `allowed_origins` in
`~/.config/<browser>/NativeMessagingHosts/com.kget_capture.host.json` (see
[keys/README.md](keys/README.md)) for the native host to accept it.

## Usage

- **On-demand:** right-click a link/image/video/audio → "Download with KGet".
- **Automatic:** click the toolbar icon and flip "Auto-capture all downloads"
  on or off. The badge shows "ON" (green) or "OFF" (grey).

## Uninstall

```bash
./uninstall.sh
```

Removes the native messaging host registrations and installed host script.
Remove the extension itself via `chrome://extensions` (or the Chrome Web
Store listing); that step can't be scripted.

## Releases

Prebuilt releases are published on the
[Releases page](https://github.com/andwati/kget-capture/releases); each
`vX.Y.Z` tag push builds and publishes one automatically, as two zips:

- `kget-capture-vX.Y.Z.zip`: full source, for `install.sh`/`install-remote.sh`.
- `kget-capture-extension-vX.Y.Z.zip`: just the extension, manifest at the
  zip root, ready for either a manual "Load unpacked" install or a Chrome
  Web Store upload.

The published extension's canonical ID
(`mkiffclapimhbjjlgkndlillglopbcic`) is hardcoded into
`native-host/com.kget_capture.host.json`'s `allowed_origins`; see
[keys/README.md](keys/README.md) for why, and what to do for local unpacked
testing (which gets a different, machine-specific ID).

## Known limitations

- **`blob:`/`data:`/`file:`/`filesystem:` URLs can't be captured.** There's
  no real network URL to hand to KGet, so these proceed normally through
  Chrome.
- **Auto-capture has a brief head start.** Manifest V3 removed blocking
  `webRequest`, so Chrome begins the download before the extension can cancel
  it. A small/partial temp file may transiently appear before it's erased.
- **No editable dialog.** Captures start immediately with no chance to
  rename the file or pick a folder beforehand: KGet only skips its
  interactive dialog when given a destination path up front, so instant
  capture and an editable prompt are mutually exclusive.
- **Chrome may still show its own "Save As" dialog** if you skipped step 3 of
  Install above.
- **KGet must already be running.** If it's not, captures fail silently;
  check the service worker console for the actual error (see
  Troubleshooting).

## Troubleshooting

- **`install-remote.sh` fails to look up the latest release?** It queries
  GitHub's API, which rate-limits unauthenticated requests (60/hour per IP);
  wait a bit, or fall back to the manual `install.sh` steps in Install above.
- **Check native host registration:** confirm
  `~/.config/<browser>/NativeMessagingHosts/com.kget_capture.host.json` exists
  and its `path` points at an executable file
  (`~/.local/share/kget-capture/kget_capture_host.py`).
- **Inspect the extension's logs:** on `chrome://extensions`, find "KGet
  Capture", click "service worker" under "Inspect views" to open its console.
- **Test D-Bus directly:**
  ```bash
  dbus-send --print-reply --dest=org.kde.kget /KGet \
    org.kde.kget.main.addTransfer string:"https://example.com/file.zip" string:"$HOME/Downloads/file.zip" boolean:true
  ```
  If this fails with `ServiceUnknown`, KGet isn't running.
- **Download-complete notification not showing?** Confirm `notify-send` is
  installed (`command -v notify-send`); without it, `kget_capture_host.py`
  skips the notification entirely rather than erroring. Otherwise, check that
  the transfer actually reached 100%: `kget_capture_host.py` polls
  `org.kde.kget.transfer.percent` on the new transfer's D-Bus object path
  (e.g. `/KGet/Transfers/9`, printed by the `addTransfer` call above) until it
  hits 100, so a stuck/erroring transfer never fires one. This notification
  is separate from KGet's own built-in "Download Finished" event.
  `install.sh` disables that one because KGet only fires it for transfers it
  observed in a non-finished state at least once, so it silently skips
  small/fast downloads that complete before that first observation.

## Privacy

KGet Capture doesn't collect, transmit, or store any user data. See
[PRIVACY.md](PRIVACY.md) for details.

## License

MIT, see [LICENSE](LICENSE).
