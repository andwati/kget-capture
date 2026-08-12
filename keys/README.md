# Extension signing key

This directory holds the RSA key pair used to pin the extension's Chrome ID so
it's identical across every install (needed so the native messaging host's
`allowed_origins` can be hardcoded instead of asking each user to paste their
extension ID).

- `kget-capture-private.pem` — **not committed** (see `.gitignore`). Keep it
  somewhere safe if you want to be able to reproduce the same key deterministically
  later; losing it just means a future re-key would get a new extension ID, it's
  not a security incident.
- `kget-capture-public.der` / `kget-capture-public.b64` — derived from the
  private key. The base64 contents of `kget-capture-public.b64` is pasted
  verbatim into `extension/manifest.json`'s `"key"` field. These are already
  effectively public once checked into `manifest.json`, so committing them is
  fine (and `extension-id.txt` too).
- `extension-id.txt` — the 32-character Chrome extension ID derived from the
  public key (also hardcoded into `native-host/com.kget_capture.host.json`).

## Regenerating (only if rotating the key)

```bash
openssl genrsa -out keys/kget-capture-private.pem 2048
openssl rsa -in keys/kget-capture-private.pem -pubout -outform DER -out keys/kget-capture-public.der
openssl base64 -A -in keys/kget-capture-public.der -out keys/kget-capture-public.b64
openssl dgst -sha256 -binary keys/kget-capture-public.der | head -c 16 | od -An -tx1 \
  | tr -d ' \n' | tr '0123456789abcdef' 'abcdefghijklmnop' > keys/extension-id.txt
```

Rotating the key changes the extension ID, which means `extension/manifest.json`'s
`"key"` and `native-host/com.kget_capture.host.json`'s `allowed_origins` both
need updating to match.
