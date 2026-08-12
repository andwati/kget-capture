# KGet Capture

A Chrome (and other Chromium-browser) extension that sends downloads to
[KGet](https://apps.kde.org/kget/), KDE's download manager, instead of (or in
addition to) the browser's built-in downloader.

- Right-click any link, image, video, or audio element and choose
  **"Download with KGet"** to send it straight to KGet — it starts
  downloading immediately into your Downloads folder, no dialog.
- A toolbar toggle enables **auto-capture**: while on, every download Chrome
  starts is cancelled and handed off to KGet the same way, automatically,
  with the correct filename (resolved by Chrome itself, so it's right even
  for URLs whose path is just an opaque ID). Defaults to ON.
- A "Download complete" desktop notification appears once a capture actually
  finishes downloading. This is driven by the extension itself (not KGet's
  own per-transfer notification, which KGet silently skips for downloads
  that finish very quickly — see Troubleshooting), so it fires reliably
  regardless of file size or speed.

## Requirements

- Linux with KGet installed (and running, or set to autostart)
- One of: Google Chrome, Chromium, Brave, Vivaldi, Microsoft Edge
- `python3` and `dbus-send` on `PATH` (standard on virtually all Linux/KDE
  systems already)
- `notify-send` (ships with most Linux desktops via libnotify) — optional,
  only used for the download-complete notification; captures still work
  without it, just silently
- `kwriteconfig6` (ships with KDE Plasma) — optional, only used to disable
  KGet's own unreliable per-transfer notification so it doesn't double up
  with the extension's; install still works without it

## Install

```bash
git clone <this-repo-url> kget-capture
cd kget-capture
./install.sh
```

`install.sh` registers a native messaging host for every supported browser it
finds installed, then prints the extension's fixed ID and next steps:

1. Open `chrome://extensions` (or your browser's equivalent).
2. Enable **Developer mode** (top-right toggle).
3. Click **Load unpacked** and select this repo's `extension/` directory.
4. Confirm the loaded extension's ID matches the one `install.sh` printed.
5. Open `chrome://settings/downloads` (or your browser's equivalent, e.g.
   `brave://settings/downloads`, `edge://settings/downloads`) and turn **off**
   "Ask where to save each file before downloading". Chrome shows this dialog
   itself, before the extension ever gets a chance to intercept the download —
   no extension API can read or suppress it, so this one-time setting change
   is required for captures to work without an extra prompt.

## Usage

- **On-demand:** right-click a link/image/video/audio → "Download with KGet".
- **Automatic:** click the toolbar icon and flip "Auto-capture all downloads"
  on or off. The badge shows "ON" (green) or "OFF" (grey).

## Uninstall

```bash
./uninstall.sh
```

This removes the native messaging host registrations and the installed host
script. You'll still need to remove the unpacked extension yourself via
`chrome://extensions` — that step can't be scripted.

## Releases

Pushing a tag matching `v*.*.*` (e.g. `v1.0.0`) triggers a GitHub Actions
workflow ([.github/workflows/release.yml](.github/workflows/release.yml))
that zips `extension/` and publishes it as a GitHub Release with
auto-generated release notes. Bump `"version"` in `extension/manifest.json`
before tagging so the packaged extension's version matches.

```bash
git tag v1.0.0
git push origin v1.0.0
```

## Known limitations

- **`blob:`/`data:` URLs can't be captured.** There's no real network URL to
  hand to KGet, so these downloads proceed normally through Chrome (a console
  warning is logged in the extension's service worker).
- **Auto-capture has a brief head start.** Manifest V3 removed blocking
  `webRequest`, so Chrome begins the download before the extension can cancel
  it. A small/partial temp file may transiently appear before it's erased.
- **No editable dialog.** Captures start immediately with no chance to
  rename the file or pick a different folder beforehand — rename/move it
  afterward in KGet or your file manager if needed. This is intentional: KGet
  only skips its interactive "New Download" dialog when given a real
  destination path up front, so instant capture and an editable prompt are
  mutually exclusive given KGet's D-Bus API.
- **The context-menu capture can't always get the correct filename.**
  Auto-capture gets the real filename for free from Chrome's own
  `Content-Disposition` resolution. Right-click captures don't have that —
  the extension only has the raw URL — so KGet falls back to guessing from
  the URL path, which is wrong for opaque/signed URLs (e.g. cloud storage
  links). Fixing this would require broad host permissions and an extra HTTP
  request per right-click, which isn't worth it for now.
- **Chrome may still show its own "Save As" dialog** if you skipped step 5 of
  Install above — see there for why and how to fix it.
- **KGet must already be running.** If it's not, captures fail silently from
  the user's perspective — check the service worker console for the actual
  error (see Troubleshooting).

## Troubleshooting

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
  installed (`command -v notify-send`) — without it, `kget_capture_host.py`
  skips the notification entirely rather than erroring. Otherwise, check that
  the transfer actually reached 100%: `kget_capture_host.py` polls
  `org.kde.kget.transfer.percent` on the new transfer's D-Bus object path
  (e.g. `/KGet/Transfers/9`, printed by the `addTransfer` call above) until it
  hits 100, so a stuck/erroring transfer never fires one. Note this
  notification is separate from KGet's own built-in "Download Finished"
  event — `install.sh` disables that one (`kwriteconfig6 --file knotifyrc
  --group "Event/kget/finished" --key Action None`) because KGet only fires
  it for transfers it observed in a non-finished state at least once, so it
  silently skips small/fast downloads that complete before that first
  observation.

## License

MIT — see [LICENSE](LICENSE).
