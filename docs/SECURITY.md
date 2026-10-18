# Security

What this setup protects, what it doesn't, and what to do about the rest.

---

## The threat model

Your backend is exposed on the public internet by a Cloudflare quick tunnel with
a random hostname. Your PC is the only legitimate client. So the question is:
**what stops someone else from using it?**

Two independent secrets, both required:

1. **The random hostname.** A quick-tunnel URL is unguessable and not indexed.
2. **The API key.** 43 characters from `secrets.token_urlsafe`, compared in
   constant time, never logged.

An attacker needs both. Finding the hostname by guessing is infeasible; leaking
the key is the realistic failure mode.

## How the key travels

```
Colab box 2 prints it  →  you copy it  →  launcher stores it (0600)
                                           and puts it on the clipboard
                                        →  app sends it once, over HTTPS,
                                           to POST /api/auth/session
```

* It is sent over TLS (trycloudflare is HTTPS).
* It is **not** placed in the URL, so it stays out of logs and shell history.
* It is stored at `~/.config/VoiceStudio/remote-key.txt`, mode `0600`.
* It is also stored on Google Drive so it survives VM resets — treat that Drive
  file as a secret too.
* The app itself persists only the URL. The key stays in memory for the session.

## What the key unlocks

Admin-tier routes: settings, model installs, engine selection, diagnostics,
licence acceptance. Without it you get consumption only (generate, clone,
transcribe, dub, download) — which is a sane degraded mode, not a broken one.

## What it deliberately cannot unlock

Routes that act on the backend host's filesystem
(`require_native_access`, `require_desktop`) stay true-loopback-only, for **any**
remote client, key or not. On a headless VM they would target the wrong machine
anyway. Saving audio to your PC does not use them.

## Why the tunnel forwards your IP

`cloudflared` sends `X-Forwarded-For`, and uvicorn trusts it from loopback. That
is deliberate: it means the backend correctly sees your PC as a remote client and
enforces the gates. Without it every request would look local and the security
model would silently collapse.

## Residual risks, honestly

| Risk | Mitigation |
|---|---|
| **Clipboard leak** — the key sits on your clipboard, and other apps can read it | Clear the clipboard after pairing; it is a 9-hour credential only after the exchange |
| **Shared computer** — anyone using your PC can read `remote-key.txt` | `chmod 600`, and that user can use the backend while the key is valid |
| **Colab VM is Google's** — you are running code on someone else's machine | Your audio and models live there while it runs; Drive holds the rest |
| **Long-lived key on Drive** — Drive is synced to a Google account | Rotate by deleting `/content/drive/omnivoice/api_key.txt` and re-running box 2 |
| **No rate limiting on the tunnel** | Upstream does throttle failed key exchanges per client |

## Hardening, if you want it

* **Clear the clipboard** after pairing:
  ```sh
  printf '' | xclip -selection clipboard
  ```
* **Rotate the key** whenever you think it leaked:
  ```sh
  # on Colab
  !rm -f /content/drive/omnivoice/api_key.txt
  ```
  then re-run box 2 and re-pair. Your PC's saved key stops working immediately,
  which is the point.
* **Delete Drive contents** when finished: models, settings, cloned voices and
  the key are all under `/content/drive/omnivoice`.
* **Stop the tunnel** when done: killing the Colab tab or running
  `!pkill -x cloudflared` closes the public entry point.

## Responsible use

Voice cloning is powerful. Clone only voices you have the right to clone, and do
not clone anyone to deceive them. The default model is CC-BY-NC — see
[FAQ.md](FAQ.md#can-i-sell-this).