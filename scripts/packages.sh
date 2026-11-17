
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

# ==============================================================================
# starship installer
# ==============================================================================

install_starship() {
    tmp="$(mktemp "${TMPDIR:-/tmp}/starship-install.XXXXXX")" || return 1

    if curl -fsSL --max-time 60 https://starship.rs/install.sh -o "$tmp" &&
       [ -s "$tmp" ] && sh -n "$tmp" &&
       sh "$tmp" -y -b "$HOME/.local/bin"; then
        rm -f "$tmp"
        return 0
    fi

    rm -f "$tmp"
    return 1
}

ensure_starship() {
    install_starship && return 0

    command -v starship >/dev/null 2>&1 || [ -x "$HOME/.local/bin/starship" ] || {
        printf "[error] starship install failed and none is present.\n" >&2
        exit 1
    }

    printf "[warn] starship update failed; keeping existing install.\n" >&2
}

# ==============================================================================
# package installation
# ==============================================================================

if command -v apt-get >/dev/null 2>&1; then
    $SUDO apt-get update -qq

    # required baseline utilities across debian/ubuntu releases
    $SUDO apt-get install -y -qq \
        bat \
        ripgrep \
        fd-find \
        fzf \
        btop

    # optional packages
    for opt_pkg in zoxide git-delta eza wl-clipboard xclip; do
        if apt-cache show "$opt_pkg" >/dev/null 2>&1; then
            $SUDO apt-get install -y -qq "$opt_pkg" || printf "[warn] failed to install optional package: %s\n" "$opt_pkg" >&2
        else
            printf "[warn] optional package unavailable in apt repository: %s\n" "$opt_pkg" >&2
        fi
    done

    # normalize debian binary names
    [ -x /usr/bin/batcat ] && ln -sf /usr/bin/batcat "$HOME/.local/bin/bat"
    [ -x /usr/bin/fdfind ] && ln -sf /usr/bin/fdfind "$HOME/.local/bin/fd"

    # install or update starship
    ensure_starship

elif command -v apk >/dev/null 2>&1; then
    $SUDO apk add --no-cache \
        eza \
        bat \
        ripgrep \
        fd \
        zoxide \
        fzf \
        delta \
        btop

    # install or update starship via official installer (keeps version consistent across distros)
    ensure_starship

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
