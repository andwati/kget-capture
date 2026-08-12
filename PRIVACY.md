# Privacy Policy

KGet Capture does not collect, store, transmit, or sell any user data.

## What the extension does

When you right-click a link and choose "Download with KGet", or when
auto-capture is on and Chrome starts a download, the extension sends that
download's URL and filename to a native messaging host, a small helper
program installed locally on your own computer (see
[Install](README.md#install)). That helper hands the URL to KGet, the KDE
download manager, over D-Bus, also entirely on your own machine.

The only other data the extension stores is your auto-capture on/off
preference, saved locally via the `chrome.storage.local` API. It never
leaves your browser.

## What never happens

- No data is sent to any server operated by the developer or anyone else.
- No analytics, tracking, or telemetry of any kind.
- No data is sold, shared, or transferred to third parties.
- No account, sign-in, or personal information is collected.

## Source code

KGet Capture is open source. You can review exactly what it does at
[github.com/andwati/kget-capture](https://github.com/andwati/kget-capture).

## Contact

Questions about this policy can be raised via
[GitHub Issues](https://github.com/andwati/kget-capture/issues).
