#!/bin/sh
# Install the VoiceStudio desktop app (Electron AppImage) for the remote-GPU setup.
#
# This is a thin, pinned mirror of the official installer. It exists so the whole
# setup can originate from this repository instead of voicestudio.sh, while still
# fetching the application binary itself from the official GitHub release, and
# verifying it against that release's SHA256SUMS.txt.
#
# Usage:
#   install-app.sh                 # latest official release (Linux / macOS)
#   install-app.sh --version X.Y.Z # a specific release
#   install-app.sh --uninstall     # remove the app, keep all user data
#
# The application is AGPL-3.0 software by debpalash/VoiceStudio and is NOT
# vendored here - only its official release artifact is downloaded.
set -eu

REPO="debpalash/VoiceStudio"
VERSION=""
UNINSTALL=0
CHECK=0

die() { printf 'install-app: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
log() { printf '\033[2m>\033[0m %s\n' "$*"; }
usage() {
    cat <<'HELP'
install-app - VoiceStudio desktop app (for the remote-GPU setup)

  install-app.sh                 install the latest official release
  install-app.sh --version X.Y.Z install a specific release (v prefix ok)
  install-app.sh --check         resolve and verify without downloading
  install-app.sh --uninstall     remove the app, keeping all user data

Installs the official AGPL-3.0 AppImage from debpalash/VoiceStudio after
verifying it against that release's SHA256SUMS.txt. The app binary is not
vendored in this repository - only this installer is.
HELP
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --version) [ "$#" -ge 2 ] || die '--version needs a value'
                   VERSION=${2#v}; shift ;;
        --uninstall) UNINSTALL=1 ;;
        --check) CHECK=1 ;;
        --help|-h) usage; exit 0 ;;
        *) die "unknown option: $1" ;;
    esac
    shift
done

if [ "$UNINSTALL" = 1 ] && [ -n "$VERSION" ]; then
    die '--uninstall cannot be combined with --version'
fi

case "$(uname -s)" in
    Linux) OS=linux ;;
    Darwin) OS=mac ;;
    *) die 'this installer covers Linux and macOS; on Windows use the .exe from GitHub Releases' ;;
esac
have curl || die 'curl is required'
have tar || die 'tar is required'

INSTALL_DIR="${VOICESTUDIO_INSTALL_DIR:-$HOME/.local/bin}"
case "$INSTALL_DIR" in /*) ;; *) die 'VOICESTUDIO_INSTALL_DIR must be an absolute path' ;; esac
TARGET="$INSTALL_DIR/VoiceStudio"

# Never touch files while the app is running.
if have pgrep; then
    if pgrep -x VoiceStudio >/dev/null 2>&1 || pgrep -f 'voicestudio-electron' >/dev/null 2>&1; then
        die 'VoiceStudio is running. Quit it (the remote launcher too) and run this again.'
    fi
fi

if [ "$UNINSTALL" = 1 ]; then
    if [ -e "$TARGET" ]; then
        recovered="$(dirname "$TARGET")/.VoiceStudio.removed.$$"
        mkdir -p "$recovered"
        mv "$TARGET" "$recovered/VoiceStudio"
        printf 'Moved to %s (restore by moving it back, or delete it to reclaim space).\n' "$recovered"
    else
        printf 'Nothing to remove at %s\n' "$TARGET"
    fi
    printf 'Settings, projects and model downloads were left untouched.\n'
    exit 0
fi

sha_tool=""
if have sha256sum; then sha_tool="sha256sum"
elif have shasum;    then sha_tool="shasum -a 256"
else die 'need sha256sum or shasum to verify the download'
fi

# Resolve the version to install.
if [ -z "$VERSION" ]; then
    log "resolving the latest $REPO release"
    VERSION=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
        | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v\{0,1\}\([^"]*\)".*/\1/p' | head -1)
    [ -n "$VERSION" ] || die 'could not resolve the latest release (network?)'
fi
printf '%s\n' "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9]+([.-][A-Za-z0-9]+)*)?$' \
    || die "invalid version: $VERSION"
BASE="https://github.com/$REPO/releases/download/v$VERSION"

if [ "$OS" = linux ]; then
    ASSET="VoiceStudio-Electron-$VERSION-linux-x64.AppImage"
else
    ASSET="VoiceStudio-Electron-$VERSION-mac-arm64.dmg"
    have uname && [ "$(uname -m)" = x86_64 ] && ASSET="VoiceStudio-Electron-$VERSION-mac-x64.dmg"
fi
log "installing VoiceStudio $VERSION ($OS)"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM

log "fetching checksums"
curl -fsSL "$BASE/SHA256SUMS.txt" -o "$TMP/SHA256SUMS.txt" \
    || die "no SHA256SUMS.txt for v$VERSION (release has no installable package?)"
WANT=$(awk -v f="$ASSET" '$2 == f || $2 == "*"f {print $1}' "$TMP/SHA256SUMS.txt" | head -1)
[ -n "$WANT" ] || die "$ASSET is not listed in SHA256SUMS.txt for v$VERSION"

if [ "$CHECK" = 1 ]; then
    printf 'OK  version   %s\n' "$VERSION"
    printf 'OK  os        %s\n' "$OS"
    printf 'OK  asset     %s\n' "$ASSET"
    printf 'OK  sha256    %s\n' "$WANT"
    printf 'OK  url       %s/%s\n' "$BASE" "$ASSET"
    exit 0
fi

log "downloading $ASSET (~260 MB)"
curl -fL --progress-bar "$BASE/$ASSET" -o "$TMP/$ASSET" || die 'download failed'

GOT=$($sha_tool "$TMP/$ASSET" | awk '{print $1}')
if [ "$GOT" != "$WANT" ]; then
    die "checksum mismatch - refusing to install.
  expected $WANT
  got      $GOT"
fi
log "checksum verified"

if [ "$OS" = linux ]; then
    mkdir -p "$INSTALL_DIR"
    chmod +x "$TMP/$ASSET"
    mv "$TMP/$ASSET" "$TARGET"
    printf '\nInstalled %s\n' "$TARGET"
    case ":$PATH:" in
        *":$INSTALL_DIR:"*) ;;
        *) printf '\nAdd it to your PATH:\n  export PATH="$HOME/.local/bin:$PATH"\n' ;;
    esac
else
    APP_DIR="/Applications"
    [ -w "$APP_DIR" ] || APP_DIR="$HOME/Applications"
    mkdir -p "$APP_DIR"
    hdiutil attach "$TMP/$ASSET" -nobrowse -quiet
    cp -R "/Volumes/VoiceStudio/VoiceStudio.app" "$APP_DIR/"
    hdiutil detach "/Volumes/VoiceStudio" -quiet
    printf '\nInstalled %s/VoiceStudio.app\n' "$APP_DIR"
fi

printf '\nNext: run scripts/install-launcher.sh to add the remote-GPU icon.\n'