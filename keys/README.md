# Extension ID

`extension-id.txt` holds the extension's one canonical ID,
`mkiffclapimhbjjlgkndlillglopbcic`, assigned by the Chrome Web Store on
first publish. It's hardcoded into
`native-host/com.kget_capture.host.json`'s `allowed_origins`, which is what
lets the native host trust connections from the extension without asking
each user to paste their own ID.

`extension/manifest.json` intentionally has no `"key"` field: the Chrome Web
Store dashboard rejects any manifest that includes one ("key field is not
allowed in manifest"), since it assigns its own permanent ID on first
publish instead.

`kget-capture-private.pem` / `kget-capture-public.der` / `kget-capture-public.b64`
are leftover from an earlier approach that pinned a separate ID for unpacked
installs via a local key pair. They're no longer referenced anywhere (the
`.pem` was never committed; see `.gitignore`) and can be ignored or removed.

## Implication for local "Load unpacked" development

Since there's no pinned key, Chrome derives an unpacked install's ID from a
hash of its local path, which won't match
`mkiffclapimhbjjlgkndlillglopbcic` and differs per machine/checkout. To test
an unpacked build against the native host locally, add your own unpacked
ID to `allowed_origins` in `~/.config/<browser>/NativeMessagingHosts/com.kget_capture.host.json`
after running `install.sh` (Chrome shows the unpacked ID on
`chrome://extensions` once loaded).
