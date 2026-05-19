#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"

BTBN_BASE="https://github.com/BtbN/FFmpeg-Builds/releases/download/latest"
LINUX_ARCHIVE="ffmpeg-master-latest-linux64-lgpl.tar.xz"
WINDOWS_ARCHIVE="ffmpeg-master-latest-win64-lgpl.zip"
MACOS_URL="https://evermeet.cx/ffmpeg/getrelease/zip"

need() {
    if ! command -v "$1" &>/dev/null; then
        echo "error: '$1' is required but not found on PATH" >&2
        exit 1
    fi
}

download() {
    local url="$1" dest="$2"
    if command -v curl &>/dev/null; then
        curl -fL --progress-bar -o "$dest" "$url"
    elif command -v wget &>/dev/null; then
        wget -q --show-progress -O "$dest" "$url"
    else
        echo "error: neither curl nor wget found" >&2
        exit 1
    fi
}

install_linux() {
    echo "--- Linux (BtbN LGPL) ---"
    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN

    download "$BTBN_BASE/$LINUX_ARCHIVE" "$tmp/$LINUX_ARCHIVE"
    need tar
    tar -xf "$tmp/$LINUX_ARCHIVE" -C "$tmp" --wildcards "*/ffmpeg" --strip-components=2
    install -m 755 "$tmp/ffmpeg" "$BIN_DIR/linux/ffmpeg"
    echo "installed: bin/linux/ffmpeg"
}

install_windows() {
    echo "--- Windows (BtbN LGPL) ---"
    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN

    download "$BTBN_BASE/$WINDOWS_ARCHIVE" "$tmp/$WINDOWS_ARCHIVE"
    need unzip
    unzip -q "$tmp/$WINDOWS_ARCHIVE" -d "$tmp/win"
    local exe
    exe="$(find "$tmp/win" -name "ffmpeg.exe" | head -1)"
    if [[ -z "$exe" ]]; then
        echo "error: ffmpeg.exe not found in archive" >&2
        exit 1
    fi
    install -m 644 "$exe" "$BIN_DIR/windows/ffmpeg.exe"
    echo "installed: bin/windows/ffmpeg.exe"
}

install_macos() {
    echo "--- macOS (evermeet.cx) ---"
    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN

    download "$MACOS_URL" "$tmp/ffmpeg.zip"
    need unzip
    unzip -q "$tmp/ffmpeg.zip" -d "$tmp/mac"
    local bin
    bin="$(find "$tmp/mac" -name "ffmpeg" -not -name "*.txt" | head -1)"
    if [[ -z "$bin" ]]; then
        echo "error: ffmpeg binary not found in archive" >&2
        exit 1
    fi
    install -m 755 "$bin" "$BIN_DIR/macos/ffmpeg"
    echo "installed: bin/macos/ffmpeg"
}

mkdir -p "$BIN_DIR/linux" "$BIN_DIR/windows" "$BIN_DIR/macos"

TARGET="${1:-all}"

case "$TARGET" in
    linux)   install_linux ;;
    windows) install_windows ;;
    macos)   install_macos ;;
    all)
        install_linux
        install_windows
        install_macos
        ;;
    *)
        echo "usage: $0 [linux|windows|macos|all]" >&2
        exit 1
        ;;
esac

echo ""
echo "Done. Run the Godot project and trigger a video export to verify."
