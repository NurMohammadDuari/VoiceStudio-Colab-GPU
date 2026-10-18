# Installation

Everything below assumes you have a Google account (for Colab) and a PC with
the VoiceStudio desktop app installed. No Python, no GPU, no CUDA on the PC.

---

## Part 1 — the PC (once)

### 1. Install the desktop app

```sh
curl -fsSL https://raw.githubusercontent.com/NurMohammadDuari/VoiceStudio-Colab-GPU/main/install.sh | sh
```

That single command runs `scripts/install-app.sh` (installs the official AppImage
to `~/.local/bin/VoiceStudio`, verifying its SHA-256) followed by
`scripts/install-launcher.sh` (launcher, icon, desktop entry).

To install only the app, or to pin a version:

```sh
sh scripts/install-app.sh                  # latest release
sh scripts/install-app.sh --version 0.5.6  # a specific release
sh scripts/install-app.sh --check          # resolve + verify, download nothing
sh scripts/install-app.sh --uninstall      # remove the app, keep your data
```

This repository hosts the installer; the application binary itself is still the
official release from `debpalash/VoiceStudio` and is verified against that
release's `SHA256SUMS.txt` before it is installed.

On some machines (older Intel/AMD GPUs on X11) the UI needs software rendering.
If the window is blank or crashes, always launch it through the launcher in
Part 2 — it passes `--disable-gpu` for you.

### 2. Install the launcher

```sh
./scripts/install-launcher.sh
```

This copies the launcher to `~/.local/bin/voicestudio-remote`, creates the icon
and the `.desktop` entry, and installs the app icon. Re-run it any time you
update the launcher.

Check it worked:

```sh
. ~/.local/share/applications/voicestudio-remote.desktop   # no, just verify:
ls -l ~/.local/bin/voicestudio-remote ~/Desktop/VoiceStudio.desktop
```

---

## Part 2 — Colab (first run)

1. Open [VoiceStudio-Colab-GPU.ipynb](../notebook/VoiceStudio-Colab-GPU.ipynb)
   in Google Colab.
2. **Runtime → Change runtime type → T4 GPU.** Confirm it says GPU.
3. **Runtime → Run all** (or run boxes 1, 2, 3 in order).
4. Wait. First run downloads the app, ffmpeg, the engine stack and roughly 5 GB
   of models. Ten to twenty minutes is normal.

### The boxes

| Box | What it does | When to run |
|---|---|---|
| 1 | Installs the app on the VM, mounts Google Drive, optionally installs GPU Turbo | once per VM |
| 2 | Starts the backend, opens the public tunnel, prints **URL + API key** | every time Colab restarts |
| 3 | Downloads models, sets privacy, activates Max quality | once per VM |
| 4 | Reprints the URL and key | any time you lose them |
| 5 | Optional: dubbing pack (speaker separation) | once, if you want dubbing |

### ### Licence acceptance is deliberately not automatic

Box 3 ships with `ACCEPT_MODEL_LICENCES = False`. Acceptance is a legal
acknowledgement of each model's terms, so the notebook refuses to record it for
you. Read them in the app under **Model Catalogue**, then set that flag to
`True` and re-run box 3.

### Watch for these lines

Box 2 ends with:

```
Backend ready: {'status': 'ok', 'device': 'cuda (Tesla T4)', ...}
Public link verified end to end.
==================================================================
URL:
https://three-random-words-here.trycloudflare.com

API KEY:
<43 characters>
```

That `Public link verified end to end.` line means the box proved the key works
through the public tunnel, using the same handshake your PC app uses. If it
prints, the pairing will work.

---

## Part 3 — pair the PC

1. Double-click the **VoiceStudio** icon on your desktop.
2. Paste the **URL**.
3. Paste the **API key** — the launcher put it on your clipboard (Ctrl+V).
4. In the app: **Settings → Sharing → Remote backend**, paste the key,
   **Test**, then **Save & reload**.

The app stores only the URL on disk; the key lives in the app's memory for this
session and is exchanged for a short-lived session token. That is by design —
so after each app restart you repeat step 3-4 once (the key is on your clipboard,
so it is one Ctrl+V).

### When the launcher asks for the key

It only asks when your saved key is **rejected by the backend**. It verifies
with a real key exchange first. If it asks, the usual cause is a URL and a key
copied from two different Colab runs — copy both from the same output.

---

## Part 4 — optional: dubbing

Dubbing needs speaker separation. On a remote backend the only viable engine is
pyannote (the Sortformer alternative needs a native runtime that ships only with
the desktop installer). That needs a Hugging Face account, once:

1. Log in at [huggingface.co](https://huggingface.co).
2. Open [pyannote/speaker-diarization-3.1](https://huggingface.co/pyannote/speaker-diarization-3.1)
   and click **Agree and access repository**.
3. Do the same on [pyannote/segmentation-3.0](https://huggingface.co/pyannote/segmentation-3.0).
4. Create a **read** token at [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens).
5. Paste it into box 5 and run it.

---

## Daily use

Keep the Colab tab open. Box 2 prints a keep-alive heartbeat every two minutes;
that reduces disconnects but cannot beat Colab's hard limits.

When it dies: run box 2, paste the new URL, done. The key does not change.

## Performance

Box 1 installs **GPU Turbo** (FlashInfer CUDA graphs) by default. The first
generation after a restart compiles kernels and can take minutes; after that,
generations are roughly twice as fast. Set `INSTALL_GPU_TURBO = False` at the
top of box 1 to skip it.

VRAM sitting at 4 GB of 15 GB is normal and not a problem — the model is ~2.4 GB
and unallocated VRAM does not make anything faster. See
[FAQ.md](FAQ.md#why-is-gpu-usage-so-low).