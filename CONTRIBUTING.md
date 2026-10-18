# Contributing

## What this repo is

Notebook + launcher + documentation that let the AGPL-3.0 VoiceStudio app use a
remote GPU (Google Colab T4) while the PC only renders the UI. The application
itself lives in [debpalash/VoiceStudio](https://github.com/debpalash/VoiceStudio)
and is **not** vendored here.

## Ground rules

1. **Never commit a URL or a key.** Tunnel hostnames and API keys are
   credentials. `.gitignore` covers the usual filenames; if you ever paste one
   into a doc, remove it.
2. **Pin the commit.** The notebook targets one app commit
   (`PINNED_COMMIT`). If the upstream API changes, update the pin *and* the
   affected boxes together.
3. **Every code cell must compile.** Before committing:
   ```sh
   python3 - <<'PY'
   import json
   d = json.load(open("notebook/VoiceStudio-Colab-GPU.ipynb"))
   for i, c in enumerate(d["cells"]):
       if c["cell_type"] == "code":
           compile("".join(c["source"]), f"cell{i}", "exec")
   print("ok:", len(d["cells"]), "cells")
   PY
   ```
4. **The launcher must stay POSIX `sh`** and pass `sh -n`.
5. **Never make setup harder.** If a change adds a step to the user's first run,
   it needs a very good reason.

## Testing the launcher

There is a mock-backend pattern worth reusing: a `http.server` that answers
`/health` and `/api/auth/session` the way the backend does. Test the launcher
against it in a throwaway `HOME`, covering at least: fresh pairing, valid saved
key, rotated key, no argument, dead link.

## Style

- Comments explain *why*, not *what*.
- No jargon in user-facing strings; the audience is non-technical.
