#!/bin/sh
# ==============================================================================
# cross-platform environment bootstrapper (debian, alpine, macos, devcontainers)
# supports interactive tty mode and headless (--default / non-tty) execution
# ==============================================================================

set -e

CALLER_DIR="$PWD"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_RAW_BASE="https://raw.githubusercontent.com/iamvikshan/.github/refs/heads/main/scripts"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { printf "${BLUE}[info]${NC} %s\n" "$1"; }
log_exec() { printf "${YELLOW}[exec]${NC} %s\n" "$1"; }
log_ok()   { printf "${GREEN}[ ok ]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[warn]${NC} %s\n" "$1"; }
log_fail() { printf "${RED}[fail]${NC} %s\n" "$1" >&2; exit 1; }

TMP_FILES=""
cleanup_tmp() {
    for f in $TMP_FILES; do
        [ -n "$f" ] && rm -f "$f"
    done
}
trap cleanup_tmp EXIT

run_remote_script() {
    script_name="$1"
    shift
    tmp_script="$(mktemp "${TMPDIR:-/tmp}/${script_name}.XXXXXX")"
    TMP_FILES="$TMP_FILES $tmp_script"
    if ! curl -fsSL "$REPO_RAW_BASE/$script_name" -o "$tmp_script" || [ ! -s "$tmp_script" ]; then
        rm -f "$tmp_script"
        log_fail "failed to download $script_name."
    fi
    sh "$tmp_script" "$@"
    rm -f "$tmp_script"
}

# 1. parse execution mode & verify controlling tty
FORCE_DEFAULT=false
for arg in "$@"; do
    case "$arg" in
        --default|--non-interactive|-y) FORCE_DEFAULT=true ;;
    esac
done

IS_INTERACTIVE=true
if [ "$FORCE_DEFAULT" = "true" ] || [ ! -t 0 ] || ! (exec < /dev/tty) 2>/dev/null; then
    IS_INTERACTIVE=false
    log_warn "running in headless (--default or non-tty) mode."
fi
export IS_INTERACTIVE

# 2. privilege & host identity resolution
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
elif command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
else
    log_fail "neither root nor sudo available to install system packages."
fi
export SUDO

if [ -n "${CODESPACE_NAME:-}" ]; then
    HOST_ID="$CODESPACE_NAME"
else
    HOST_ID="$(hostname -s 2>/dev/null || uname -n 2>/dev/null || printf 'local-machine')"
fi
export HOST_ID

# 3. install base prerequisites (zsh, git, curl, jq, ca-certificates)
log_exec "verifying base prerequisites..."
if command -v apt-get >/dev/null 2>&1; then
    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq zsh git curl jq ca-certificates
elif command -v apk >/dev/null 2>&1; then
    $SUDO apk add --no-cache zsh git curl jq ca-certificates openssh-client
elif command -v brew >/dev/null 2>&1; then
    brew install zsh git curl jq
elif command -v dnf >/dev/null 2>&1; then
    $SUDO dnf install -y -q zsh git curl jq ca-certificates
elif command -v pacman >/dev/null 2>&1; then
    $SUDO pacman -Sy --noconfirm --needed zsh git curl jq ca-certificates
else
    log_fail "unsupported package manager."
fi
log_ok "base prerequisites ready."

# 5. install modern rust/c++ cli toolchain
if [ -f "$SCRIPT_DIR/packages.sh" ]; then
    chmod +x "$SCRIPT_DIR/packages.sh"
    sh "$SCRIPT_DIR/packages.sh"
else
    run_remote_script "packages.sh"
fi

# 6. install standalone zsh plugins (zero oh-my-zsh overhead)
log_exec "syncing standalone zsh plugins..."
PLUGIN_DIR="$HOME/.local/share/zsh/plugins"
mkdir -p "$PLUGIN_DIR"

clone_or_pull() {
    repo_url="$1"
    target_dir="$PLUGIN_DIR/$2"
    if [ ! -d "$target_dir/.git" ]; then
        git clone --depth=1 -q "$repo_url" "$target_dir"
    else
        git -C "$target_dir" pull --ff-only -q || true
    fi
}

clone_or_pull "https://github.com/zsh-users/zsh-autosuggestions.git" "zsh-autosuggestions"
clone_or_pull "https://github.com/zsh-users/zsh-syntax-highlighting.git" "zsh-syntax-highlighting"
clone_or_pull "https://github.com/Aloxaf/fzf-tab.git" "fzf-tab"
log_ok "zsh plugins synced."

# 7. deploy universal.zshrc, aliases.sh, and starship.toml
log_exec "deploying zsh and starship configurations..."
ZSH_CONFIG_DIR="$HOME/.config/zsh"
mkdir -p "$ZSH_CONFIG_DIR" "$HOME/.config"

install_config() {
    filename="$1"
    dest="$2"
    if [ -f "$SCRIPT_DIR/$filename" ]; then
        cp "$SCRIPT_DIR/$filename" "$dest"
    else
        tmp_cfg="$(mktemp "${dest}.tmp.XXXXXX")"
        TMP_FILES="$TMP_FILES $tmp_cfg"
        if ! curl -fsSL "$REPO_RAW_BASE/$filename" -o "$tmp_cfg" || [ ! -s "$tmp_cfg" ]; then
            rm -f "$tmp_cfg"
            log_fail "failed to fetch $filename"
        fi
        mv "$tmp_cfg" "$dest"
    fi
}

if [ -f "$HOME/.zshrc" ] || [ -L "$HOME/.zshrc" ]; then
    mv "$HOME/.zshrc" "$HOME/.zshrc.backup-$(date +%s)"
fi

install_config "universal.zshrc" "$HOME/.zshrc"
install_config "aliases.sh" "$ZSH_CONFIG_DIR/aliases.sh"
install_config "starship.toml" "$HOME/.config/starship.toml"
log_ok "configurations deployed."

# 8. configure interactive and login shell handoff
HANDOFF_SNIPPET='
# auto-handover interactive shells to zsh
case "$-" in
    *i*)
        if [ -t 1 ] && [ -z "$ZSH_VERSION" ] && command -v zsh >/dev/null 2>&1; then
            export SHELL="$(command -v zsh)"
            exec zsh -l
        fi
        ;;
esac
'

for rc_file in "$HOME/.profile" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.bash_login"; do
    # Creating a higher-priority Bash login file would hide existing startup files.
    case "$rc_file" in
        "$HOME/.bash_profile"|"$HOME/.bash_login") [ -f "$rc_file" ] || continue ;;
    esac
    if ! grep -Eq 'exec zsh' "$rc_file" 2>/dev/null; then
        printf "%s\n" "$HANDOFF_SNIPPET" >> "$rc_file"
    fi
done

ZSH_PATH="$(command -v zsh)"
CURRENT_USER="${USER:-$(id -un)}"

# ensure zsh path is whitelisted in /etc/shells before chsh (prevents macos/pam login lockout)
if [ -f /etc/shells ] && ! grep -qxF "$ZSH_PATH" /etc/shells 2>/dev/null; then
    if [ -w /etc/shells ] || [ -n "$SUDO" ]; then
        printf '\n%s\n' "$ZSH_PATH" | $SUDO tee -a /etc/shells >/dev/null || \
            log_warn "could not register $ZSH_PATH in /etc/shells."
    fi
fi

if [ "$SHELL" != "$ZSH_PATH" ]; then
    if command -v chsh >/dev/null 2>&1; then
        $SUDO chsh -s "$ZSH_PATH" "$CURRENT_USER" 2>/dev/null || chsh -s "$ZSH_PATH" 2>/dev/null || true
    elif [ -w /etc/passwd ] || [ -n "$SUDO" ]; then
        $SUDO sed -i "s|^\(${CURRENT_USER}:.*:\)[^:]*$|\1${ZSH_PATH}|" /etc/passwd
    fi
fi
log_ok "default shell locked to $ZSH_PATH."

# 9. smart git setup (executes only if caller directory is inside a git worktree)
cd "$CALLER_DIR"
run_git_setup() {
    if [ -f "$SCRIPT_DIR/git.sh" ]; then
        sh "$SCRIPT_DIR/git.sh" "$@"
    else
        run_remote_script "git.sh" "$@"
    fi
}
repo_discovery="$(LC_ALL=C git rev-parse --is-inside-work-tree 2>&1 || true)"
case "$repo_discovery" in
    *"detected dubious ownership in repository"*)
        run_git_setup --trust-only
        repo_discovery="$(git rev-parse --is-inside-work-tree 2>/dev/null || true)"
        ;;
esac
if [ "$repo_discovery" = "true" ]; then
    log_info "git repository detected in $CALLER_DIR; running git.sh..."
    if [ "$IS_INTERACTIVE" = "false" ]; then
        run_git_setup --default
    else
        run_git_setup
    fi
else
    log_info "not inside a git repository; skipping git.sh."
fi

log_ok "bootstrap complete."
if [ "$IS_INTERACTIVE" = "true" ] && [ -z "${ZSH_VERSION:-}" ]; then
    exec "$ZSH_PATH" -l
fi