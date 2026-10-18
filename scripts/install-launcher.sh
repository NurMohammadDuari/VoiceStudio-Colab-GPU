#!/bin/sh
# Install the VoiceStudio remote launcher, its icon and desktop entry.
# Re-run any time to update the launcher after a git pull.
set -e

SRC_DIR=$(cd "$(dirname "$0")" && pwd)
BIN="$HOME/.local/bin/voicestudio-remote"
APPS="$HOME/.local/share/applications"
ICONS="$HOME/.local/share/icons"
DESKTOP_FILE="$APPS/voicestudio-remote.desktop"
SHORTCUT="$HOME/Desktop/VoiceStudio.desktop"

say() { printf '\n%s\n' "$*"; }

if [ ! -f "$SRC_DIR/voicestudio-remote.sh" ]; then
    echo "error: voicestudio-remote.sh not found next to this script." >&2
    exit 1
fi

say "1/4  Launcher"
mkdir -p "$HOME/.local/bin"
install -m 755 "$SRC_DIR/voicestudio-remote.sh" "$BIN"
echo "     installed $BIN"
sh -n "$BIN" && echo "     syntax OK"

say "2/4  Application"
APP="$HOME/.local/bin/VoiceStudio"
if [ -x "$APP" ]; then
    echo "     found $APP"
else
    echo "     VoiceStudio is not installed yet. Run the app installer first:"
    echo "       sh $(dirname "$0")/install-app.sh"
    echo "     (or from a clone: curl -fsSL https://raw.githubusercontent.com/NurMohammadDuari/VoiceStudio-Colab-GPU/main/install.sh | sh)"
    exit 1
fi

say "3/4  Icon"
mkdir -p "$ICONS"
if [ -f "$SRC_DIR/../assets/voicestudio.png" ]; then
    install -m 644 "$SRC_DIR/../assets/voicestudio.png" "$ICONS/voicestudio.png"
    echo "     installed $ICONS/voicestudio.png"
else
    echo "     assets/voicestudio.png not found - using the generic icon"
fi

say "4/4  Desktop entry"
mkdir -p "$APPS"
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=VoiceStudio (Remote GPU)
Comment=VoiceStudio UI - all compute on Colab, none on this PC
Exec=$BIN --disable-gpu
Icon=voicestudio
Terminal=false
Type=Application
Categories=AudioVideo;Video;Audio;Network;WebBrowser;
Keywords=VoiceStudio;voice;clone;TTS;AI;dubbing;
NoDisplay=false
StartupWMClass=VoiceStudio
EOF
chmod 644 "$DESKTOP_FILE"
if command -v desktop-file-validator >/dev/null 2>&1; then
    desktop-file-validator "$DESKTOP_FILE" && echo "     entry valid"
else
    echo "     (desktop-file-validator not installed; skipping validation)"
fi
if [ -d "$HOME/Desktop" ]; then
    cp "$DESKTOP_FILE" "$SHORTCUT"
    chmod +x "$SHORTCUT" 2>/dev/null || true
    echo "     shortcut: $SHORTCUT"
fi

say "Done."
cat <<'EOF'
Next:
  1. Colab: T4 GPU, open notebook/VoiceStudio-Colab-GPU.ipynb, Runtime > Run all
  2. Copy the URL and the API key it prints at the end
  3. Double-click the VoiceStudio icon and paste both
     (the key is on your clipboard - just Ctrl+V)

Verify the pairing any time:
  cat ~/.config/VoiceStudio/remote-backend.json
EOF