# FAQ

### Does this cost anything?

No. Free Colab T4, free Cloudflare quick tunnel, and the app is AGPL-3.0 free.
The paid VoiceStudio "Pro" plan sells a packaged version of what this repo sets
up.

### Is my audio private?

While a run is active, your audio is on the Colab VM and passes over the tunnel
from Google to your PC — both HTTPS. Your PC never stores it locally.
Models, settings and cloned voices sit in your Google Drive. Nothing is sent to
the vendor.

### Does it phone home?

The app has opt-in analytics that is **off by default** (box 3 explicitly records
"no"). If you ever accept it, it sends engine usage, timings and error types —
never audio or text.

### Why is GPU usage so low?

Normal, and not a waste. See below.

### Why is GPU usage so low?

The TTS model is ~2.4 GB, so ~4 GB of the 15 GB T4 is expected. **VRAM usage is
not a speed dial** — unused VRAM does not make anything faster. Speed comes from
kernels, which is what GPU Turbo (FlashInfer) improves: roughly 2× faster
generations, enabled by default in box 1.

A T4 also idles between pipeline stages, because chunking, WAV post-processing
and I/O are CPU work. Low utilisation between bursts is expected.

### Why is Max slower than Balanced?

That is what Max is: 64 sampling steps plus postprocess, 8-beam ASR, 8-path
dictation, NLLB translation with 8 beams. It is the slowest, highest-quality
preset. Use GPU Turbo to make it bearable, or drop to Balanced for speed.

### How long do I get?

Whatever Colab gives you — commonly up to ~12 GPU-hours per day, with idle tabs
disconnected sooner. Box 2's heartbeat (every 2 minutes) reduces disconnects but
cannot beat the hard cap. For 24/7, rent a GPU box; nothing about the setup
changes except the URL.

### Will my key keep working after Colab restarts?

Yes, if you enabled Drive persistence (default). The key is stored at
`/content/drive/omnivoice/api_key.txt` and reloaded by box 2, so the one already
on your PC stays valid. Only the URL changes.

### Can I use this from more than one computer?

Yes. That is VoiceStudio Pro's "multiple devices" feature, and it costs nothing
here. Install the app on the other machine, run the launcher, paste the same URL
and key. (Pro's paid limit of 3 devices does not apply to the free app.)

### Can I sell this?

**Not with the default models.** `k2-fsa/OmniVoice` is **CC-BY-NC** with
commercial inference restricted, and the tokenizer has its own terms. Selling a
dubbing or TTS service on that stack is not permitted.

To sell, you would need commercially licensed models, and note that if you modify
the app and host it, AGPL-3.0 requires offering your modified source to users.
VoiceStudio's own [Pro](https://voicestudio.sh/pro) and
[Cloud](https://voicestudio.sh/cloud) products exist for that; Cloud is still a
waitlist.

### Which models get downloaded?

`k2-fsa/OmniVoice` (TTS), `eustlb/higgs-audio-v2-tokenizer`,
`Systran/faster-whisper-large-v3` (ASR), two sherpa-onnx models (dictation),
`facebook/nllb-200-distilled-600M` (translation) — about 5 GB. Optionally three
pyannote repos for dubbing. Box 4 prints what is actually on disk.

### Why must I accept a licence before generating?

Models whose licence is not `commercial` fail closed until you acknowledge the
terms. That acknowledgement is yours to make: box 3 ships with `ACCEPT_MODEL_LICENCES = False` and will not record it on your behalf. It is a local honesty gate, not a security boundary — but it is
enforced on use, so generation is blocked until it is recorded.

### Do I need a Hugging Face account?

Only for dubbing (pyannote repos are gated). Everything else works without one.

### Why do some buttons stay greyed out?

A small set of capabilities act on the backend host's filesystem and can never
run for a remote client, by design. Saving audio to your PC is unaffected — that
is an HTTP download. See
[HOW-IT-WORKS-IN-THE-APP.md](HOW-IT-WORKS-IN-THE-APP.md).

### Can I use a paid GPU instead of Colab?

Yes — anything that runs Linux with a GPU: a VPS, RunPod, Vast.ai, a spare
machine. Run box 1 and 2 there (skip the Drive part if you do not need it), open
a tunnel, paste the URL and key. The app does not care where the backend lives.

### Is this the same as VoiceStudio Cloud?

No. Cloud is the vendor's hosted product and is still a waitlist. This is the
open-source app with your own compute behind it.