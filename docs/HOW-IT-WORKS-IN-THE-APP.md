# How it works inside VoiceStudio

Notes from reading the VoiceStudio source, so you can tell a designed
restriction from a bug. Line references are from the pinned commit
`f47221a1f0af89df27c34747471daa30391a9487`.

---

## The gates

Every privileged route depends on one of six functions, all in
`backend/api/dependencies.py`:

| Gate | Rule |
|---|---|
| `require_admin` | loopback, **or** (server mode + a valid admin credential) |
| `require_loopback` | loopback; in server mode falls back to the admin rule |
| `require_admin_action` | for legacy GETs that have side effects |
| `require_desktop` | **true loopback only**, never relaxed — file-picker boundary |
| `require_native_access` | **true loopback only**, never relaxed — host filesystem |
| `require_consumer` | consumption tier; open on a bare server with no credential |

The central function is `check_admin` (dependencies.py:221):

```python
if is_loopback(host): return
if _server_mode():
    if read_only and not _admin_credential_configured(request): return   # reads open
    if _request_presents_admin_credential(request): return               # key/session wins
_admin_gate_403()
```

Two consequences:

1. **Keyless server mode** (no key configured): reads are open, writes are 403.
   This is the state the very first version of this setup ran in, and why
   Settings saves and model installs failed with *loopback origin required*.
2. **With a key configured**: the read exception in line 1 no longer applies, so
   *everything* requires a credential — including reads. The PC app must hold the
   key. `/health` is exempt (`_STARTUP_EXEMPT`, main.py:1659) so liveness probing
   still works before pairing.

## Route map for a remote client

| Area | Gate | Keyless | With key |
|---|---|---|---|
| `/health`, `/startup/progress` | exempt | yes | yes |
| generation, `/tts-stream`, `/audio/*` | none | yes | yes |
| gallery, cloning, `/export/record` | `require_consumer` | yes | yes |
| `/api/settings/*` (analytics, performance-profile, hf-token, …) | `require_admin` | **403** | yes |
| `/models/licenses/accept` | `require_admin` | **403** | yes |
| `/engines/*/select` | `require_admin` | **403** | yes |
| `/system/*` (diagnostics, logs, gpu-report) | `require_admin` | **403** | yes |
| `POST /export`, `/export/reveal`, `/tools/probe` | `require_native_access` | **never** | **never** |
| `POST /engines/audiocpp/runtime/install` | `require_desktop` | **never** | **never** |

The last two rows are the interesting ones. They are unreachable from *any*
remote client, including one with a valid key, because they act on the backend
host's filesystem. On a headless Colab VM they would target the wrong machine
anyway. Saving audio to your PC does **not** use them: `saveExport` →
`saveBackendFile` downloads over HTTPS in the app's main process and only then
records history via `/export/record`.

## How the desktop app authenticates

`electron/src/main/remote-backend.ts` → `probeRemoteBackend`:

1. `GET /health` — no headers. Confirms something real is there.
2. If a master key was given: `POST /api/auth/session` with
   `Authorization: Bearer <key>` and `{"transport":"bearer"}`.
   Requires **201** and a token matching `ovs_admin_session_[A-Za-z0-9_-]{43}`.
3. `GET /system/info` with the session token.

Then `backend.ts` keeps only the session:

```ts
private activeSession() {
  if (this.remoteSession && this.remoteSession.expiresAt > Date.now()/1000) return this.remoteSession
  this.remoteSession = null; return null      // expired: no automatic re-exchange
}
```

So the app never re-authenticates on its own — one key paste per app restart.
Sessions live in `services/admin_sessions.py` (in-memory, per-process pepper),
so a backend restart invalidates them.

The backend persists **only** the URL on disk. That is deliberate, and it is why
this setup's launcher keeps the key separately and puts it on the clipboard.

## Models and quality tiers

`electron/src/renderer/src/features/settings/performance-model-packs.ts`:

| Tier | Repos |
|---|---|
| fast | OmniVoice, whisper-base, sherpa-tiny |
| balanced | OmniVoice, whisper-large-v3-turbo-ct2, sherpa-tiny, parakeet |
| quality / **max** | OmniVoice, **faster-whisper-large-v3**, sherpa-tiny, parakeet, **NLLB** |

Quality and Max download the same repos. The tier changes runtime policy
(`services/performance_profiles.py`):

| Family | Max policy |
|---|---|
| TTS | 64 sampling steps + postprocess |
| ASR | 8 beams |
| Dictation | beam search, 8 active paths |
| Translation | NLLB, 8 beams |
| Diarisation | pyannote |

Selecting a tier is `PUT /api/settings/performance-profile` — an admin write, so
it is blocked keyless. Box 3 performs that write over loopback instead.

Model installs are detected straight from the Hugging Face cache
(`api/routers/setup/models.py`, `is_cached`), which is why downloading with
`snapshot_download` on the VM is equivalent to clicking Install in the app.

## Licences

Each gated model needs an acceptance record bound to a fingerprint of its terms:

```
GET  /models/licenses/details/<repo>   → fingerprint "v2:<64 hex>"
POST /models/licenses/accept           {repo_id, fingerprint, accepted}
```

Anything whose licence category is not `commercial` fails closed. Note the
default TTS model: `k2-fsa/OmniVoice` is **CC-BY-NC**, commercial inference
restricted.

## Diarisation on a remote backend

`services/diarization_runtime.py` offers two engines:

* **pyannote** — pure Python, works on Colab, needs the three gated repos plus a
  Hugging Face token and `pyannote.audio`.
* **audiocpp Sortformer** — needs a native runtime that ships **only inside the
  desktop installer**. `engines/audiocpp/bootstrap.py` states outright:
  *"VoiceStudio never downloads executable code for this engine."*

So pyannote is the only option remotely — which is also what Max tier asks for.

## GPU Turbo

`services/engine_env.py`:

> `OMNIVOICE_FLASHINFER=1` patches the OmniVoice model with FlashInfer packed
> attention (~2× per upstream benchmarks); `graph` additionally captures CUDA
> graphs (best at batch=1).

Requires `flashinfer-python` + `flashinfer-jit-cache` installed into the same
interpreter that runs the backend. Off by default, and designed so it can never
be a point of failure: if the package is missing or a kernel fails at runtime,
the backend logs the reason and continues on the standard path.

That is exactly how the notebook uses it — detect, enable, verify, and silently
skip if unavailable.