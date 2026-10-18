# Changelog

## 1.0.0

First public release of the Colab remote-GPU setup.

### Setup
- 6-cell Colab notebook: install, start, one-time setup, reprint pair, optional
  dubbing pack
- Pinned app commit so the notebook cannot drift from the code it targets
- Google Drive persistence for models, settings, cloned voices and the API key,
  with a symlink probe that falls back to a local model cache on mounts that
  cannot host one

### Pairing
- Stable API key per run, persisted so a Colab recycle does not invalidate the
  key already saved on the PC
- Launcher asks for the key only when the backend actually rejects the saved one
- Launcher verifies the pairing with a real `/api/auth/session` exchange and
  puts the key on the clipboard
- Full feature unlock: settings, model installs, engine selection, diagnostics

### Performance
- GPU Turbo (FlashInfer packed attention + CUDA graphs), ~2x faster generations,
  installed with a torch-pinned constraint, import-tested, and auto-removed if
  broken so it can never slow a run
- Max quality profile activated from the VM: 64-step TTS, 8-beam ASR, NLLB
  translation

### Reliability
- Verified end to end through the public tunnel before the pair is ever printed
- Self-healing: stale-backend detection mints a fresh key and restarts
- Diagnosable failures: the health probe reports *why* a link is dead
- Retries on git clone, dependency install and the tunnel binary download
- No local python/torch is ever started on the PC

### Documentation
- README, INSTALL, ARCHITECTURE, HOW-IT-WORKS-IN-THE-APP, TROUBLESHOOTING,
  SECURITY, FAQ, CONTRIBUTING
- CI validating notebook compilation, shell syntax and absence of credentials
