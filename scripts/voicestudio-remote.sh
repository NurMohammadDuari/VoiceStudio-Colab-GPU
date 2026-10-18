#!/bin/sh
# VoiceStudio - remote-only launcher (no local CPU/GPU work)
# All inference runs on Colab. This PC only shows the UI.
#
# Usage:
#   voicestudio-remote                                    # popup asks for the Colab URL
#   voicestudio-remote "https://<random-words>.trycloudflare.com"   # URL as an argument
#   voicestudio-remote --disable-gpu                      # flags go to Electron
#
# Colab box 2 prints ONE fresh URL and ONE matching API key per run, and the
# key is stable until Colab restarts, so this launcher only asks for the key
# when the backend actually rejects the saved one. The key is copied to the
# clipboard: the app keeps sessions in memory only, so it needs one Ctrl+V in
# Settings -> Sharing -> Remote backend after each app restart.

CONFIG_DIR="$HOME/.config/VoiceStudio"
REMOTE_FILE="$CONFIG_DIR/remote-backend.json"
KEY_FILE="$CONFIG_DIR/remote-key.txt"

REMOTE_URL=""
FLAGS=""
CANCELLED=0
for a in "$@"; do
  case "$a" in
    http://*|https://*) REMOTE_URL="$a" ;;
    *) FLAGS="$FLAGS \"$a\"" ;;
  esac
done

# Strip trailing slashes exactly like the app's normalizeRemoteUrl().
REMOTE_URL=$(printf '%s' "$REMOTE_URL" | sed 's:/*$::')

saved_url() {
  python3 -c 'import json; print((json.load(open("'"$REMOTE_FILE"'")).get("url") or ""))' 2>/dev/null
}
saved_key() {
  [ -f "$KEY_FILE" ] && tr -d '[:space:]' < "$KEY_FILE"
}
has_gui() { [ -n "$DISPLAY" ] && command -v zenity >/dev/null 2>&1; }

# 201 = the backend accepted this key and issued an admin session.
key_ok() {
  command -v curl >/dev/null 2>&1 || return 1
  [ -n "$1" ] || return 1
  [ "$(curl -s -o /dev/null -w '%{http_code}' -m 20 -X POST \
        -H "Authorization: Bearer $1" -H 'Content-Type: application/json' \
        -d '{"transport":"bearer"}' "$2/api/auth/session")" = "201" ]
}

ask_url() {
  if has_gui; then
    zenity --entry --title="VoiceStudio - Colab link" \
      --text="Paste the URL from Colab box 2 (https://....trycloudflare.com)." \
      --entry-text="$(saved_url)" 2>/dev/null || CANCELLED=1
  else
    printf '%s' "$(saved_url)"
  fi
}

ask_key() {
  if has_gui; then
    _out=$(zenity --entry --title="VoiceStudio - API key" \
      --text="Paste the API KEY printed by the same Colab box 2 run as the URL." 2>/dev/null) \
      || CANCELLED=1
    printf '%s' "$_out" | tr -d '[:space:]'
  fi
}

to_clipboard() {
  command -v xclip >/dev/null 2>&1 && printf '%s' "$1" | xclip -selection clipboard 2>/dev/null && return 0
  command -v xsel  >/dev/null 2>&1 && printf '%s' "$1" | xsel --clipboard --input 2>/dev/null && return 0
  return 1
}

# 1. URL
[ -n "$REMOTE_URL" ] || REMOTE_URL=$(ask_url | tr -d '[:space:]')
REMOTE_URL=$(printf '%s' "$REMOTE_URL" | sed 's:/*$::')
[ "$CANCELLED" = 1 ] && exit 0        # user closed the dialog: do nothing, quietly
if [ -z "$REMOTE_URL" ]; then
  has_gui && zenity --error --title="VoiceStudio" \
    --text="No Colab URL given. Run Colab box 2, then paste the URL it prints." 2>/dev/null
  echo "No Colab URL. Run Colab box 2 first." >&2
  exit 1
fi

# 2. Persist the URL (same shape the app itself writes)
mkdir -p "$CONFIG_DIR"
printf '{"url": "%s"}\n' "$REMOTE_URL" > "$REMOTE_FILE"
chmod 600 "$REMOTE_FILE"

# 3. Liveness, so a stale link is reported before the app opens
if command -v curl >/dev/null 2>&1; then
  HK=$(curl -s -m 12 "$REMOTE_URL/health" 2>/dev/null | tr -d ' \n')
  case "$HK" in
    *'"status":"ok"'*) echo "Backend: $HK" ;;
    *) echo "WARNING: $REMOTE_URL/health did not report ok (${HK:-no answer})."
       echo "         Colab may be closed or the link stale - re-run Colab box 2." ;;
  esac
fi

# 4. Key: keep the saved one whenever the backend still accepts it
KEY=$(saved_key)
NEEDED_KEY=0
if key_ok "$KEY" "$REMOTE_URL"; then
  echo "Saved API key still valid for this backend."
else
  NEEDED_KEY=1
  KEY=$(ask_key)
  [ "$CANCELLED" = 1 ] && exit 0
  if [ -n "$KEY" ]; then
    if key_ok "$KEY" "$REMOTE_URL"; then
      printf '%s\n' "$KEY" > "$KEY_FILE"
      chmod 600 "$KEY_FILE"
      echo "API key saved and verified."
    else
      has_gui && zenity --error --title="VoiceStudio" --text="That API key was rejected by $REMOTE_URL.

Most likely cause: the URL and the key came from DIFFERENT Colab box 2 runs.
Copy BOTH lines from one single run." 2>/dev/null
      echo "ERROR: the backend rejected that key (URL/key from different runs?)." >&2
      exit 1
    fi
  else
    echo "No key entered."
  fi
fi

# 5. The app keeps sessions in memory only: hand the user a paste-ready key.
if [ -n "$KEY" ]; then
  if to_clipboard "$KEY"; then
    echo "API key copied to clipboard."
    if [ "$NEEDED_KEY" = 1 ] && has_gui; then
      has_gui && zenity --info --title="VoiceStudio - ready" --no-wrap --text="URL + key saved. Key is on your clipboard.

In the app, once per restart:
  Settings -> Sharing -> Remote backend
  URL: saved   |   API key: Ctrl+V
  Test -> Save & reload
Admin buttons (model installs, Settings) work once the key is in." 2>/dev/null
    fi
  else
    echo "API key stored in $KEY_FILE"
  fi
fi

# 6. Launch - never spawn local python/torch
export VOICESTUDIO_SKIP_BACKEND=1
# shellcheck disable=SC2086
eval exec "$HOME/.local/bin/VoiceStudio" $FLAGS