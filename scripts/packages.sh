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

    # required baseline utilities across debian/ubuntu releases
    $SUDO apt-get install -y -qq \
        bat \
        ripgrep \
        fd-find \
        fzf \
        btop

    # optional packages that may be absent on older debian/ubuntu container images
    for opt_pkg in zoxide git-delta eza starship wl-clipboard xclip; do
        if apt-cache show "$opt_pkg" >/dev/null 2>&1; then
            $SUDO apt-get install -y -qq "$opt_pkg" || printf "[warn] failed to install optional package: %s\n" "$opt_pkg" >&2
        else
            printf "[warn] optional package unavailable in apt repository: %s\n" "$opt_pkg" >&2
        fi
    done

    # fallback for starship when unavailable in apt
    if ! command -v starship >/dev/null 2>&1; then
        tmp_starship="$(mktemp "${TMPDIR:-/tmp}/starship-install.XXXXXX")"
        if curl -fsSL https://starship.rs/install.sh -o "$tmp_starship" && [ -s "$tmp_starship" ]; then
            sh "$tmp_starship" -y -b "$HOME/.local/bin" || printf "[warn] starship fallback installer failed.\n" >&2
        else
            printf "[warn] failed to download starship installer.\n" >&2
        fi
        rm -f "$tmp_starship"
    fi

    # normalize debian binary names to match macos and alpine
    [ -x /usr/bin/batcat ] && ln -sf /usr/bin/batcat "$HOME/.local/bin/bat"
    [ -x /usr/bin/fdfind ] && ln -sf /usr/bin/fdfind "$HOME/.local/bin/fd"

elif command -v apk >/dev/null 2>&1; then
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
else
    printf "[error] unsupported package manager for modern CLI tools (supported: apt-get, apk, brew).\n" >&2
    exit 1
fi
