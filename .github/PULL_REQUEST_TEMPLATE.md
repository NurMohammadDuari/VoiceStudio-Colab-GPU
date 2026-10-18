## What does this change?

<!-- One or two sentences. -->

## Type

- [ ] Notebook
- [ ] Launcher / scripts
- [ ] Documentation
- [ ] CI

## Checklist

- [ ] Every notebook code cell compiles:
      `python3 -c "import json;d=json.load(open('notebook/VoiceStudio-Colab-GPU.ipynb'));[compile(''.join(c['source']),str(i),'exec') for i,c in enumerate(d['cells']) if c['cell_type']=='code']"`
- [ ] `sh -n scripts/*.sh` passes
- [ ] **No API key, tunnel URL, or other credential is included**
- [ ] No new step was added to a first-time user's setup (without a very good reason)
- [ ] Docs updated where behaviour changed

## Testing

<!-- How did you verify this? Which platform, which box? -->
