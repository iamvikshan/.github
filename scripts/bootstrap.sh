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

# 3. secret & context waterfall (~/.atlasrc + local .env)
ATLAS_SECRETS="$HOME/.atlasrc"
if [ ! -f "$ATLAS_SECRETS" ]; then
    if [ -f "$HOME/.atlas_secrets" ]; then
        log_info "migrating token cache from ~/.atlas_secrets to ~/.atlasrc"
        cp -p "$HOME/.atlas_secrets" "$ATLAS_SECRETS"
    elif [ -f "$HOME/.atlas_secrets.json" ]; then
        log_info "migrating token cache from ~/.atlas_secrets.json to ~/.atlasrc"
        cp -p "$HOME/.atlas_secrets.json" "$ATLAS_SECRETS"
    fi
fi

GH_TOKEN="${GH_TOKEN:-}"
GL_TOKEN="${GL_TOKEN:-}"

if [ -f "$ATLAS_SECRETS" ]; then
    log_info "loading cached secrets from $ATLAS_SECRETS"
    set -a
    # shellcheck disable=SC1090
    . "$ATLAS_SECRETS"
    set +a
fi

if [ -f "$CALLER_DIR/.env" ]; then
    if [ -z "$GH_TOKEN" ]; then
        GH_TOKEN="$(grep -E '^GH_TOKEN=' "$CALLER_DIR/.env" | head -n 1 | cut -d '=' -f2- | tr -d "\"'" || true)"
    fi
    if [ -z "$GL_TOKEN" ]; then
        GL_TOKEN="$(grep -E '^GL_TOKEN=' "$CALLER_DIR/.env" | head -n 1 | cut -d '=' -f2- | tr -d "\"'" || true)"
    fi
fi
export GH_TOKEN GL_TOKEN ATLAS_SECRETS

# 4. install base prerequisites (zsh, git, curl, jq, ca-certificates)
log_exec "verifying base prerequisites..."
if command -v apt-get >/dev/null 2>&1; then
    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq zsh git curl jq ca-certificates
elif command -v apk >/dev/null 2>&1; then
    $SUDO apk add --no-cache zsh git curl jq ca-certificates openssh-client
elif command -v brew >/dev/null 2>&1; then
    brew install zsh git curl jq >/dev/null 2>&1 || true
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
    curl -fsSL "$REPO_RAW_BASE/packages.sh" | sh
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
        curl -fsSL "$REPO_RAW_BASE/$filename" -o "$dest" || log_fail "failed to fetch $filename"
    fi
}

if [ -f "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
    mv "$HOME/.zshrc" "$HOME/.zshrc.backup-$(date +%s)"
fi

install_config "universal.zshrc" "$HOME/.zshrc"
install_config "aliases.sh" "$ZSH_CONFIG_DIR/aliases.sh"
install_config "starship.toml" "$HOME/.config/starship.toml"
log_ok "configurations deployed."

# 8. configure login shell handoff (.profile for alpine/sh, .bashrc for debian/bash)
HANDOFF_SNIPPET='
# auto-handover interactive shells to zsh
if [ -t 1 ] && [ -z "$ZSH_VERSION" ] && command -v zsh >/dev/null 2>&1; then
    export SHELL="$(command -v zsh)"
    exec zsh -l
fi
'

for rc_file in "$HOME/.profile" "$HOME/.bashrc"; do
    if ! grep -Eq 'exec zsh' "$rc_file" 2>/dev/null; then
        printf "%s\n" "$HANDOFF_SNIPPET" >> "$rc_file"
    fi
done

ZSH_PATH="$(command -v zsh)"
CURRENT_USER="${USER:-$(id -un)}"
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
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log_info "git repository detected in $CALLER_DIR; running git.sh..."
    GIT_ARGS=""
    [ "$IS_INTERACTIVE" = "false" ] && GIT_ARGS="--default"
    if [ -f "$SCRIPT_DIR/git.sh" ]; then
        chmod +x "$SCRIPT_DIR/git.sh"
        sh "$SCRIPT_DIR/git.sh" $GIT_ARGS
    else
        curl -fsSL "$REPO_RAW_BASE/git.sh" | sh -s -- $GIT_ARGS
    fi
else
    log_info "not inside a git repository; skipping git.sh."
fi

log_ok "bootstrap complete."
if [ "$IS_INTERACTIVE" = "true" ] && [ -z "${ZSH_VERSION:-}" ]; then
    exec "$ZSH_PATH" -l
fi