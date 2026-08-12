# KGet Capture

A Chrome (and other Chromium-browser) extension that sends downloads to
[KGet](https://apps.kde.org/kget/), KDE's download manager, instead of (or in
addition to) the browser's built-in downloader.

- Right-click any link, image, video, or audio element and choose
  **"Download with KGet"** to open KGet's "New Download" dialog, prefilled
  with the URL — edit the filename or destination folder if you want, then
  confirm to start the transfer.
- A toolbar toggle enables **auto-capture**: while on, every download Chrome
  starts is cancelled and redirected to the same KGet dialog automatically.
  Defaults to ON.

## Requirements

- Linux with KGet installed (and running, or set to autostart)
- One of: Google Chrome, Chromium, Brave, Vivaldi, Microsoft Edge
- `python3` and `dbus-send` on `PATH` (standard on virtually all Linux/KDE
  systems already)

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
- **A KGet dialog opens for every capture.** The extension uses KGet's
  `showNewTransferDialog` D-Bus method, which opens the interactive "New
  Download" dialog rather than starting the transfer immediately. This is
  intentional — it lets you rename the file or change the destination folder
  before it starts. If you'd rather it start immediately without a prompt,
  see [Troubleshooting](#troubleshooting) for the alternate `addTransfer`
  call — note that route only returns once the dialog is dismissed, so it's
  not what the extension uses by default.
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
    org.kde.kget.main.showNewTransferDialog array:string:"https://example.com/file.zip"
  ```
  If this fails with `ServiceUnknown`, KGet isn't running. To skip the dialog
  and start a transfer straight away instead, use `addTransfer` with a real
  destination folder:
  ```bash
  dbus-send --print-reply --dest=org.kde.kget /KGet \
    org.kde.kget.main.addTransfer string:"https://example.com/file.zip" string:"$HOME/Downloads" boolean:true
  ```

## License

MIT — see [LICENSE](LICENSE).
