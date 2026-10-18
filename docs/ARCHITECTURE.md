# Architecture

Four pieces. Two of them are yours, one is Google, one is Cloudflare.

```
  YOUR PC                          COLAB (T4 VM)                  PUBLIC
┌───────────────┐   HTTPS    ┌──────────────────────┐
│ Electron app  │────────────▶│ VoiceStudio backend   │
│ (UI only)     │◀────────────│ FastAPI on :3900      │
│               │             │  ├─ OmniVoice  (TTS)  │
│ ~/.local/bin/ │             │  ├─ faster-whisper    │
│  voicestudio- │             │  ├─ NLLB (translate)  │
│  remote       │             │  └─ pyannote (dub)*   │
└───────────────┘             └──────────┬───────────┘
      ▲                                    │ 127.0.0.1
      │  URL + key on the clipboard        ▼
      └──────────────── cloudflared quick tunnel ────────────▶ you
                             (random *.trycloudflare.com)
```

\* only after the optional dubbing box.

---

## Component 1 — the desktop app

The official [VoiceStudio](https://github.com/debpalash/VoiceStudio) Electron
build, installed as an AppImage. It renders the UI and does **no** compute. It is
pointed at the Colab backend instead of a local one.

Two files on the PC:

| File | Purpose |
|---|---|
| `~/.local/bin/voicestudio-remote` | the launcher: asks for URL/key, verifies, launches |
| `~/.config/VoiceStudio/remote-backend.json` | the saved URL, written by the app itself |
| `~/.config/VoiceStudio/remote-key.txt` | the saved API key, written by the launcher (0600) |

The app persists only the URL — that is the upstream design
(`electron/src/main/remote-backend.ts`). The key is used once, to exchange a
session, and then held in memory only.

## Component 2 — the backend on Colab

Started by box 2:

```sh
python -m uvicorn main:app --app-dir backend --host 127.0.0.1 --port 3900
```

Bound to loopback only. Nothing is exposed directly; the tunnel is the only way
in.

### Environment variables

| Variable | Value | Why |
|---|---|---|
| `OMNIVOICE_SERVER_MODE` | `1` | headless mode; relaxes the loopback admin gate (in Docker the bridge makes everything look non-loopback) |
| `OMNIVOICE_API_KEY` | 43-char random | the admin credential; see below |
| `OMNIVOICE_DATA_DIR` | Drive or `/content` | settings, licences, cloned voices |
| `HF_HOME` | Drive or `/content` | model cache |
| `OMNIVOICE_ALLOWED_HOSTS` | `.trycloudflare.com` | host-name allow-list for the tunnel |
| `OMNIVOICE_FLASHINFER` | `graph` | FlashInfer packed attention + CUDA graphs |
| `PYTHONUNBUFFERED` | `1` | live logs |

### The credential model

The app has a two-tier design:

* **consumption** — generate, clone, transcribe, dub, download
* **admin** — settings, model installs, engine selection, diagnostics

On a normal desktop both tiers come free, because "the user" is identified as
loopback. Over a tunnel that is not true, so admin needs a credential. That
credential is `OMNIVOICE_API_KEY`.

Setting the key has one consequence worth knowing: **keyless requests stop
working, including reads**. So once the key is configured, the PC app must hold
it. That is why the launcher verifies the key and keeps it on the clipboard.

## Component 3 — the tunnel

A `cloudflared` quick tunnel gives a random public hostname pointing at
`127.0.0.1:3900`. The hostname is random and changes whenever the tunnel
restarts, which makes it part of your security story: an attacker needs both the
hostname and the key.

The tunnel forwards the client's IP in `X-Forwarded-For`, which uvicorn trusts
from loopback. That is what makes the backend correctly see your PC as a
*remote* client — otherwise every security gate would silently pass.

## Component 4 — Google Drive (optional but recommended)

Colab wipes `/content` when the VM is recycled. Box 1 mounts Drive and stores:

```
/content/drive/omnivoice/
├── config.json      paths to the model cache and the data dir
├── hf/              model weights (stored in copy mode - see below)
├── data/            settings, licences, accepted models, cloned voices
└── api_key.txt      the API key - survives VM resets
```

Because the key survives, the one already saved on your PC keeps working after a
recycle. Only the URL changes.

**Symlinks:** by default the Hugging Face cache stores weights as symlinks into
`blobs/`, and Drive's FUSE mount refuses symlinks. Box 1 therefore sets
`HF_HUB_DISABLE_SYMLINKS=1`, which makes `huggingface_hub` **copy** each file
while keeping the same `snapshots/` layout — so the cache stays readable by the
app's `is_cached()` detector and still lives on Drive. The flag is read once at
import time, which is why boxes 1, 2, 3 and 5 each set it before importing
`huggingface_hub`.

---

## The key handshake

Exactly what the desktop app does, and what box 2 verifies before printing:

```
POST /api/auth/session
Authorization: Bearer <OMNIVOICE_API_KEY>
Content-Type: application/json

{"transport": "bearer"}
```

```json
201 Created
{"token": "ovs_admin_session_<43 chars>", "expires_at": 0, "expires_in": 32400}
```

That session token is then sent as `Authorization: Bearer <session token>` on
every request. It lasts nine hours.

Sessions are **process-local** (in-memory, with a per-process pepper), so
restarting the backend invalidates them. The app then asks for the key once
more — which is why the launcher keeps that key ready to paste.

`/health` is exempt from all gates (`_STARTUP_EXEMPT`), which is how the app
probes liveness before it has a session at all.

---

## What is deliberately not possible

A handful of routes can never work from a remote client, by design: they act on
the **backend host's own filesystem** — copying a file to a Colab path, opening
a file manager on a headless box, ffprobing a Colab path, installing a native
runtime. Their detail message is literally "native filesystem access requires
loopback origin".

This costs you nothing in practice: **saving audio or video to your PC is an
HTTP download**, handled by the app's main process, not those routes.

See [HOW-IT-WORKS-IN-THE-APP.md](HOW-IT-WORKS-IN-THE-APP.md) for the full route
map.