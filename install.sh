#!/bin/sh
# One-command setup for the VoiceStudio remote-GPU workflow.
#
#   curl -fsSL https://raw.githubusercontent.com/NurMohammadDuari/VoiceStudio-Colab-GPU/main/install.sh | sh
#
# Does two things, in order:
#   1. installs the VoiceStudio desktop app (official release, checksum-verified)
#   2. installs the remote launcher, icon and desktop entry
#
# Neither step starts a GPU or touches your models - all compute happens on
# Colab. Options are forwarded to each step; see scripts/install-app.sh.
set -eu

REPO_RAW="https://raw.githubusercontent.com/NurMohammadDuari/VoiceStudio-Colab-GPU/main"
SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
FETCHED=0
TMP=""

# Fetch our own scripts from the repo when piped through curl; use local copies
# when run from a clone.
grab() {
    name="$1"
    if [ -f "$SELF_DIR/$name" ]; then
        printf '%s' "$SELF_DIR/$name"
    else
        if [ -z "$TMP" ]; then
            TMP=$(mktemp -d)
            trap 'rm -rf "$TMP"' EXIT INT TERM
        fi
        curl -fsSL "$REPO_RAW/$name" -o "$TMP/$name"
        FETCHED=1
        printf '%s' "$TMP/$name"
    fi
}

printf '\n\033[1mVoiceStudio on Colab - PC setup\033[0m\n'
printf '1/2  Installing the VoiceStudio desktop app (official release)\n'
sh "$(grab scripts/install-app.sh)" "$@"

printf '\n2/2  Installing the remote launcher, icon and desktop entry\n'
sh "$(grab scripts/install-launcher.sh)"

cat <<'DONE'

────────────────────────────────────────────────────────────
 PC side is done.

 1. Open notebook/VoiceStudio-Colab-GPU.ipynb in Google Colab
 2. Runtime -> Change runtime type -> T4 GPU
 3. Runtime -> Run all, and wait for it to finish
 4. Scroll to the end: it prints a URL and an API key
 5. Double-click the VoiceStudio icon, paste the URL,
    then paste the key (it is already on your clipboard)

 Docs: https://nurmohammadduari.github.io/VoiceStudio-Colab-GPU/
────────────────────────────────────────────────────────────
DONE