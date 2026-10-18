# Troubleshooting

Every message below is one that this setup actually produces. Find yours.

---

## In the app

### "Something went wrong" / a toast on a button

You are keyless. The app is talking to a backend whose key it does not hold, so
admin writes are refused.

**Fix:** Settings → Sharing → Remote backend → paste the key → Test → Save.
The launcher keeps it on the clipboard, so it is one Ctrl+V.

### "Could not reach the configured remote backend at …"

The URL is wrong, stale, or Colab is gone. Verify from a terminal:

```sh
curl -s -m 12 "$(python3 -c "import json;print(json.load(open('/home/mint/.config/VoiceStudio/remote-backend.json'))['url'])")/health"
```

Expect `{"status":"ok","device":"cuda (Tesla T4)",...}`. Empty output means the
tunnel is dead → run box 2 in Colab and paste the new URL.

### "API key required" when pasting the key

The URL and the key came from **different Colab runs**. Each run of box 2 prints
a new URL *and* its key together; copy both from the same output.

### Everything is 403 even after pasting the key

Check that the backend actually has a key configured:

```sh
U=$(python3 -c "import json;print(json.load(open('/home/mint/.config/VoiceStudio/remote-backend.json'))['url'].rstrip('/'))")
curl -s -X POST -H "Authorization: Bearer $(tr -d '[:space:]' < ~/.config/VoiceStudio/remote-key.txt)" \
     -H 'Content-Type: application/json' -d '{"transport":"bearer"}' "$U/api/auth/session"
```

`{"token":"ovs_admin_session_…"}` means the key is good. If you get
`{"detail":"API key required"}`, the PC's saved key no longer matches the running
backend — copy the key box 2 printed.

### Models show "Still needed" even though box 3 finished

The catalogue reads the Hugging Face cache. Re-run box 3 (it is safe and cached),
then click **Retry** in the app. Confirm on the VM:

```python
from huggingface_hub import scan_cache_dir
print({r.repo_id: round(r.size_on_disk/1e9, 2) for r in scan_cache_dir().repos})
```

### Dubbing fails with a licence or model error

Speaker separation is not installed. Run box 5 (needs your Hugging Face read
token and the two pyannote repos accepted).

---

## In Colab

### Box 2: `Backend did not come up`

```sh
!tail -40 /content/omnivoice_backend.log
```

Usually a truncated model download or a missing dependency — re-run box 1.

### Box 2: `The app is not installed in this VM yet. Run box 1 first.`

Exactly what it says. `/content` was wiped; run box 1, then box 2.

### Box 2: `cloudflared started but never handed out a link`

A transient Colab/network hiccup. Re-run box 2 in a minute.

### Box 2: `The public link did not answer: HTTP 503`

The tunnel is up but the backend is still booting. Re-run box 2.

### Box 2: `Could not download cloudflared (GitHub download blocked?)`

The binary download failed twice. Re-run, or open a fresh Colab tab — Colab's
egress to GitHub release assets is flaky.

### Health says `cannot reach it (Connection refused)`

The tunnel exists but nothing is listening on the VM. Re-run box 2.

### Models downloaded but load is very slow

Expected if they live on Google Drive: weights are copied there and FUSE is
slower than local disk. Set `PERSIST_TO_GOOGLE_DRIVE = False` in box 1 to keep
models local, accepting a re-download after a VM reset.

### Models report "still needed" although box 3 finished

The box downloaded into a different cache than the backend reads — almost always
after a kernel restart. Re-run box 3: it re-applies the Drive/`HF_HOME` config
itself before downloading. The same applies to box 5 (dubbing).

### Box 2: `Backend did not come up` on a re-run

A previous backend can keep port 3900. Box 2 reclaims the port without relying
on `lsof` (absent from many minimal images) by matching its own uvicorn process
in `/proc`, then falling back to `fuser`. If it still fails:
`!tail -40 /content/omnivoice_backend.log`.

### `GPU Turbo not available (...)`

Non-fatal. FlashInfer has no wheel for this CUDA build (common on the free T4's
sm75 architecture). Everything else still works, just without the ~2× kernel
speedup.

---

## Performance

### GPU shows 4 GB of 15 GB used

Normal, not a problem. The TTS model is ~2.4 GB; the rest is CUDA workbuffers.
Unallocated VRAM does not make anything faster — kernels do. Enable GPU Turbo for
the real win.

### Max tier is slow

Correct behaviour: 64 sampling steps plus postprocess is the slowest, best
quality setting. Drop to Balanced for speed if you prefer.

### First generation after a restart takes minutes

FlashInfer compiles kernels on first use. The prebuilt `flashinfer-jit-cache`
reduces this, but some compile time is expected. After that, generations are
roughly twice as fast.

---

## The launcher

### It never asks for my key

By design: it only asks when the backend actually rejects the saved one.

### It says the key was rejected

URL and key from different Colab runs. Copy both from the same box-2 output.

### The window is blank or the app crashes

Your machine needs software rendering. The launcher passes `--disable-gpu`; make
sure you start the app through the icon or the launcher, not the raw AppImage.

---

## Last resort

```sh
# Wipe the pairing and start clean
rm -f ~/.config/VoiceStudio/remote-backend.json ~/.config/VoiceStudio/remote-key.txt
```

Then re-run box 2 in Colab and pair again.