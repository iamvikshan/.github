#!/bin/sh
# Select host configuration once, before bootstrap deploys ~/.zshrc.
set -eu

candidate=${1:?usage: platforms.sh zshrc-candidate}
platform=$(mktemp "${candidate}.platform.XXXXXX")
rendered=$(mktemp "${candidate}.rendered.XXXXXX")
fzf_init=$(mktemp "${candidate}.fzf.XXXXXX")
trap 'rm -f "$platform" "$rendered" "$fzf_init"' EXIT

# Freeze only the choice of integration, not fzf's session-dependent initialization.
if fzf --zsh >/dev/null 2>&1; then
    printf '%s\n' 'source <(fzf --zsh)' > "$fzf_init"
else
    found=false
    for fzf_dir in /usr/share/doc/fzf/examples /usr/share/fzf; do
        if [ -s "$fzf_dir/completion.zsh" ] && [ -s "$fzf_dir/key-bindings.zsh" ]; then
            printf 'source "%s/completion.zsh"\nsource "%s/key-bindings.zsh"\n' "$fzf_dir" "$fzf_dir" > "$fzf_init"
            found=true
            break
        fi
    done
    [ "$found" = true ] || { printf '[error] fzf Zsh integration unavailable\n' >&2; exit 1; }
fi

case "$(uname -s)" in
    Darwin) : ;; # Use the native pbcopy command.
    Linux)
        cat > "$platform" <<'ZSH'
# Clipboard backend follows the current display/session, including SSH and WSL.
pbcopy() {
    if (( $+commands[clip.exe] )); then
        clip.exe
    elif [[ -n ${WAYLAND_DISPLAY:-} ]] && (( $+commands[wl-copy] )); then
        wl-copy
    elif [[ -n ${DISPLAY:-} ]] && (( $+commands[xclip] )); then
        xclip -selection clipboard
    elif [[ -n ${DISPLAY:-} ]] && (( $+commands[xsel] )); then
        xsel --clipboard --input
    else
        printf '\033]52;c;%s\a' "$(base64 | tr -d '\n')"
    fi
}
ZSH
        ;;
    *) printf '[error] unsupported operating system\n' >&2; exit 1 ;;
esac

# col is not available on every distribution. Preserve a user's pager choice.
if command -v col >/dev/null 2>&1; then
    cat >> "$platform" <<'ZSH'
if [[ ! -v MANPAGER ]]; then
    export MANPAGER="sh -c 'col -bx | bat --language=man --style=plain'"
fi
ZSH
fi

awk -v fragment="$platform" -v fzf="$fzf_init" '
    $0 == "# bootstrap:fzf" {
        while ((getline line < fzf) > 0) print line
        close(fzf)
        next
    }
    $0 == "# bootstrap:platform" {
        while ((getline line < fragment) > 0) print line
        close(fragment)
        next
    }
    { print }
' "$candidate" > "$rendered"
zsh -n "$rendered"
zsh -n "$fzf_init"
mv "$rendered" "$candidate"
