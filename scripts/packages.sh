#!/bin/sh
# ==============================================================================
# installs modern rust/c++ cli suite across debian, alpine, and macos
# ==============================================================================

set -e

mkdir -p "$HOME/.local/bin"

if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
elif command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
else
    SUDO=""
fi

if command -v apt-get >/dev/null 2>&1; then
    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq \
        bat \
        ripgrep \
        fd-find \
        zoxide \
        fzf \
        git-delta \
        btop \
        eza \
        starship 2>/dev/null || true

    # fallback for older debian/ubuntu containers lacking starship or eza in apt
    if ! command -v starship >/dev/null 2>&1; then
        curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
    fi

    # install wayland/x11 clipboard utilities on linux desktop/gui environments
    $SUDO apt-get install -y -qq wl-clipboard xclip 2>/dev/null || true

    # normalize debian binary names to match macos and alpine
    [ -x /usr/bin/batcat ] && ln -sf /usr/bin/batcat "$HOME/.local/bin/bat"
    [ -x /usr/bin/fdfind ] && ln -sf /usr/bin/fdfind "$HOME/.local/bin/fd"

elif command -v apk >/dev/null 2>&1; then
    # alpine packages git-delta as 'delta' and uses native 'bat' and 'fd' names
    $SUDO apk add --no-cache \
        starship \
        eza \
        bat \
        ripgrep \
        fd \
        zoxide \
        fzf \
        delta \
        btop

elif command -v brew >/dev/null 2>&1; then
    brew install \
        starship \
        eza \
        bat \
        ripgrep \
        fd \
        zoxide \
        fzf \
        git-delta \
        btop
fi