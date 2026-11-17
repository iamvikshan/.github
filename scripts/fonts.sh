#!/bin/sh
# Install the four common Monaspice Argon Nerd Font Mono faces on this host.
set -eu

FONT_VERSION=3.5.1
FONT_SHA256=7cdb44b7cd3855a231641b3cc4cf38f434d615d12e1c475eb86232868c667dc0
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v${FONT_VERSION}/Monaspace.tar.xz"
FONT_PATTERN='MonaspiceAr Nerd Font Mono|MonaspiceAr NFM|Monaspace Argon NF'

# Existing equivalent families may live outside the directory this script manages.
if command -v fc-list >/dev/null 2>&1 && fc-list --format '%{family}\n' | grep -Ei "$FONT_PATTERN" >/dev/null; then
    printf '[info] Argon Nerd Font is already registered.\n'
    exit 0
fi
if [ "$(uname -s)" = Darwin ] && command -v system_profiler >/dev/null 2>&1 &&
   system_profiler SPFontsDataType 2>/dev/null | grep -Ei "$FONT_PATTERN" >/dev/null; then
    printf '[info] Argon Nerd Font is already registered.\n'
    exit 0
fi

case "$(uname -s)" in
    Darwin) system_dir='/Library/Fonts'; user_dir="$HOME/Library/Fonts" ;;
    Linux) system_dir='/usr/local/share/fonts/atlas-monaspice'; user_dir="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/atlas-monaspice" ;;
    *) printf '[error] Font installation supports Linux and macOS.\n' >&2; exit 1 ;;
esac

font_sudo=''
if [ -n "${ATLAS_FONT_DIR:-}" ]; then
    font_dir=$ATLAS_FONT_DIR
elif [ "$(id -u)" -eq 0 ] || [ -w "$system_dir" ]; then
    font_dir=$system_dir
elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    font_dir=$system_dir
    font_sudo=sudo
else
    font_dir=$user_dir
fi

# Avoid downloading again even when the font cache is unavailable.
all_present=true
for face in Regular Italic Bold BoldItalic; do
    [ -f "$font_dir/MonaspiceArNerdFontMono-$face.otf" ] || all_present=false
done
if [ "$all_present" = true ]; then
    printf '[info] Argon Nerd Font files are already installed in %s.\n' "$font_dir"
    exit 0
fi

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/atlas-fonts.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM
curl -fL --retry 2 --connect-timeout 15 --max-time 120 "$FONT_URL" -o "$tmp_dir/Monaspace.tar.xz"
if command -v sha256sum >/dev/null 2>&1; then
    actual_hash=$(sha256sum "$tmp_dir/Monaspace.tar.xz" | awk '{print $1}')
elif command -v shasum >/dev/null 2>&1; then
    actual_hash=$(shasum -a 256 "$tmp_dir/Monaspace.tar.xz" | awk '{print $1}')
else
    printf '[error] sha256sum or shasum is required to verify fonts.\n' >&2
    exit 1
fi
[ "$actual_hash" = "$FONT_SHA256" ] || { printf '[error] Font archive checksum mismatch.\n' >&2; exit 1; }

tar -xJf "$tmp_dir/Monaspace.tar.xz" -C "$tmp_dir" \
    MonaspiceArNerdFontMono-Regular.otf MonaspiceArNerdFontMono-Italic.otf \
    MonaspiceArNerdFontMono-Bold.otf MonaspiceArNerdFontMono-BoldItalic.otf
$font_sudo mkdir -p "$font_dir"
for face in Regular Italic Bold BoldItalic; do
    $font_sudo install -m 644 "$tmp_dir/MonaspiceArNerdFontMono-$face.otf" "$font_dir/"
done
if command -v fc-cache >/dev/null 2>&1; then
    $font_sudo fc-cache -f "$font_dir"
fi
printf '[ok] Installed MonaspiceAr Nerd Font Mono in %s; select it in your terminal/editor.\n' "$font_dir"
