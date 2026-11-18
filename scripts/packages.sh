#!/bin/sh
# ==============================================================================
# installs modern rust/c++ cli suite across debian, alpine, and macos
# ==============================================================================

set -e

mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
elif command -v sudo > /dev/null 2>&1; then
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

    command -v starship > /dev/null 2>&1 || [ -x "$HOME/.local/bin/starship" ] || {
        printf "[error] starship install failed and none is present.\n" >&2
        exit 1
    }

    printf "[warn] starship update failed; keeping existing install.\n" >&2
}

# ==============================================================================
# package installation
# ==============================================================================

if command -v apt-get > /dev/null 2>&1; then
    $SUDO apt-get update -qq

    # required baseline utilities across debian/ubuntu releases
    $SUDO apt-get install -y -qq \
        bat \
        ripgrep \
        fd-find \
        fzf \
        btop \
        zoxide \
        eza

    # Desktop clipboard providers depend on the host; OSC 52 remains the fallback.
    # git-delta is unavailable in Ubuntu 22.04 (Jammy) default repos.
    for opt_pkg in git-delta wl-clipboard xclip; do
        if apt-cache show "$opt_pkg" > /dev/null 2>&1; then
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

elif command -v apk > /dev/null 2>&1; then
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

elif command -v brew > /dev/null 2>&1; then
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

# The shell assumes these tools exist. Refuse a partial installation.
for tool in bat rg fd fzf btop zoxide eza starship; do
    command -v "$tool" > /dev/null 2>&1 || {
        printf '[error] required tool missing: %s\n' "$tool" >&2
        exit 1
    }
done
command -v delta > /dev/null 2>&1 || printf '[warn] git-delta not installed; diff paging unavailable\n' >&2

# Validate fzf against the exact options used by the shell configuration.
# Keep this string in sync with FZF_DEFAULT_OPTS in universal.zshrc.
FZF_CHECK_OPTS="--height=50% --layout=reverse --border=rounded --margin=1 --padding=1 \
    --color=bg+:#291F21,bg:#141011,spinner:#D92638,hl:#FF4D5E \
    --color=fg:#DEC9CB,header:#8C787B,info:#B81D24,pointer:#D92638 \
    --color=marker:#6ECB86,fg+:#FFF5F6,prompt:#D92638,hl+:#FF4D5E \
    --color=border:#48393B"
# shellcheck disable=SC2086
printf 'check\n' | FZF_DEFAULT_OPTS= FZF_DEFAULT_OPTS_FILE=/dev/null fzf --filter=check $FZF_CHECK_OPTS > /dev/null || {
    printf '[error] fzf is too old for this configuration; install a newer version\n' >&2
    exit 1
}
fd --help | grep -q -- '--strip-cwd-prefix' || {
    printf '[error] fd must support --strip-cwd-prefix; install a newer version\n' >&2
    exit 1
}
