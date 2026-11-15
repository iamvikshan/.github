#!/bin/sh
# ==============================================================================
# git identity, ssh signing, credential helper, delta pager & repository setup
# ==============================================================================

set -e

# --- configuration ---
GIT_AUTHOR_NAME="iamvikshan"
GIT_AUTHOR_EMAIL="vixshan@gmail.com"
GH_USERNAME="iamvikshan"
DEFAULT_GL_NAMESPACE="vikshan"
MAX_SSH_KEYS=100
REPO_RAW_ROOT="https://raw.githubusercontent.com/iamvikshan/.github/main"
# ---------------------

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { printf "${CYAN}[info]${NC} %s\n" "$1"; }
log_ok()   { printf "${GREEN}[ ok ]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[warn]${NC} %s\n" "$1"; }
log_fail() { printf "${RED}[fail]${NC} %s\n" "$1" >&2; exit 1; }

lowercase() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

mask_token() {
    tok="$1"
    if [ -z "$tok" ]; then
        printf "(empty)"
    elif [ "${#tok}" -le 8 ]; then
        printf "********"
    else
        first="$(printf '%s' "$tok" | cut -c1-4)"
        last="$(printf '%s' "$tok" | awk '{print substr($0, length($0)-3)}')"
        printf "%s********%s" "$first" "$last"
    fi
}

# 1. standalone fallback for interactive mode, host_id, and ~/.atlasrc
FORCE_DEFAULT=false
for arg in "$@"; do
    case "$arg" in
        --default|--non-interactive|-y) FORCE_DEFAULT=true ;;
    esac
done

if [ -z "${IS_INTERACTIVE:-}" ]; then
    if [ "$FORCE_DEFAULT" = "true" ] || [ ! -t 0 ] || ! (exec < /dev/tty) 2>/dev/null; then
        IS_INTERACTIVE=false
    else
        IS_INTERACTIVE=true
    fi
fi

if [ -z "${HOST_ID:-}" ]; then
    if [ -n "${CODESPACE_NAME:-}" ]; then
        HOST_ID="$CODESPACE_NAME"
    else
        HOST_ID="$(hostname -s 2>/dev/null || uname -n 2>/dev/null || printf 'local-machine')"
    fi
fi

ATLAS_SECRETS="${ATLAS_SECRETS:-$HOME/.atlasrc}"
if [ -f "$ATLAS_SECRETS" ] && [ -z "${GH_TOKEN:-}" ] && [ -z "${GL_TOKEN:-}" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$ATLAS_SECRETS"
    set +a
fi

GH_TOKEN="${GH_TOKEN:-}"
GL_TOKEN="${GL_TOKEN:-}"

# 2. trust workspace & extract repository context
if ! git config --global --get-all safe.directory 2>/dev/null | grep -qxF "$PWD"; then
    git config --global --add safe.directory "$PWD"
fi

GH_OWNER="${GH_OWNER:-$GH_USERNAME}"
GH_REPO="${GH_REPO:-$(basename "$PWD")}"
GL_NAMESPACE="${GL_NAMESPACE:-$DEFAULT_GL_NAMESPACE}"
GL_REPO="${GL_REPO:-$GH_REPO}"

REMOTE_URL="$(git config --get remote.origin.url 2>/dev/null || true)"
if [ -n "$REMOTE_URL" ]; then
    case "$REMOTE_URL" in
        *github.com*)
            gh_path="$(printf '%s' "$REMOTE_URL" | sed -E 's|^.*github\.com[:/]([^/]+/[^/.]+)(\.git)?$|\1|')"
            GH_OWNER="${gh_path%%/*}"
            GH_REPO="${gh_path#*/}"
            ;;
        *gitlab.com*)
            gl_path="$(printf '%s' "$REMOTE_URL" | sed -E 's|^.*gitlab\.com[:/]([^/]+/[^/.]+)(\.git)?$|\1|')"
            GL_NAMESPACE="${gl_path%%/*}"
            GL_REPO="${gl_path#*/}"
            ;;
    esac
fi

# 3. interactive configuration review wizard
if [ "$IS_INTERACTIVE" = "true" ]; then
    printf "\n${CYAN}--- git & forge configuration review ---${NC}\n"
    while true; do
        printf "  1) github token:     %s\n" "$(mask_token "$GH_TOKEN")"
        printf "  2) github owner:     %s\n" "$GH_OWNER"
        printf "  3) github repo:      %s\n" "$GH_REPO"
        printf "  4) gitlab token:     %s\n" "$(mask_token "$GL_TOKEN")"
        printf "  5) gitlab namespace: %s\n" "$GL_NAMESPACE"
        printf "  6) gitlab repo:      %s\n\n" "$GL_REPO"

        printf "accept all [A] or enter a number to edit (1-6): "
        read -r choice < /dev/tty
        choice="${choice:-A}"

        case "$(lowercase "$choice")" in
            a|accept) break ;;
            1)
                printf "enter github token: "
                stty -echo < /dev/tty 2>/dev/null || true
                read -r GH_TOKEN < /dev/tty
                stty echo < /dev/tty 2>/dev/null || true
                printf "\n"
                ;;
            2) printf "enter github owner: "; read -r GH_OWNER < /dev/tty ;;
            3) printf "enter github repo: "; read -r GH_REPO < /dev/tty ;;
            4)
                printf "enter gitlab token: "
                stty -echo < /dev/tty 2>/dev/null || true
                read -r GL_TOKEN < /dev/tty
                stty echo < /dev/tty 2>/dev/null || true
                printf "\n"
                ;;
            5) printf "enter gitlab namespace (type SKIP to ignore): "; read -r GL_NAMESPACE < /dev/tty ;;
            6) printf "enter gitlab repo: "; read -r GL_REPO < /dev/tty ;;
            *) log_warn "invalid choice." ;;
        esac
    done

    printf "\nsave configuration to %s? [Y/n]: " "$ATLAS_SECRETS"
    read -r save_choice < /dev/tty
    save_choice="${save_choice:-Y}"
    case "$(lowercase "$save_choice")" in
        y|yes)
            umask 077
            cat > "$ATLAS_SECRETS" <<EOF
GH_TOKEN="$GH_TOKEN"
GH_OWNER="$GH_OWNER"
GH_REPO="$GH_REPO"
GL_TOKEN="$GL_TOKEN"
GL_NAMESPACE="$GL_NAMESPACE"
GL_OWNER="$GL_NAMESPACE"
GL_REPO="$GL_REPO"
EOF
            chmod 600 "$ATLAS_SECRETS"
            log_ok "secrets cached in $ATLAS_SECRETS (mode 0600)."
            ;;
    esac
fi

# 4. global git defaults, ntfs filemode guard & blood-obsidian delta pager
log_info "configuring global git identity, ntfs compatibility, and delta pager..."
git config --global user.name "$GIT_AUTHOR_NAME"
git config --global user.email "$GIT_AUTHOR_EMAIL"
git config --global init.defaultBranch main
git config --global pull.rebase true
git config --global core.fileMode false

if command -v delta >/dev/null 2>&1; then
    git config --global core.pager delta
    git config --global interactive.diffFilter "delta --color-only"
    git config --global delta.navigate true
    git config --global delta.side-by-side true
    git config --global delta.line-numbers true
    git config --global delta.dark true
    git config --global delta.syntax-theme "base16"
    git config --global delta.minus-style 'syntax "#3B1217"'
    git config --global delta.minus-emph-style 'syntax "#6B1A24"'
    git config --global delta.plus-style 'syntax "#122E1C"'
    git config --global delta.plus-emph-style 'syntax "#1D4D2E"'
    git config --global delta.line-numbers-minus-style "#D92638"
    git config --global delta.line-numbers-plus-style "#6ECB86"
    git config --global delta.line-numbers-zero-style "#634F52"
    git config --global merge.conflictstyle zdiff3
    log_ok "git-delta blood-obsidian pager configured."
fi

# 5. install secure credential helper (keeps raw tokens out of .git/config on ntfs)
mkdir -p "$HOME/.local/bin"
CRED_HELPER="$HOME/.local/bin/git-credential-atlas"
cat > "$CRED_HELPER" << 'EOF'
#!/bin/sh
[ "$1" = "get" ] || exit 0
[ -f "$HOME/.atlasrc" ] || exit 0

host=""
while IFS='=' read -r key val; do
    [ -z "$key" ] && break
    [ "$key" = "host" ] && host="$val"
done

set -a
# shellcheck disable=SC1091
. "$HOME/.atlasrc"
set +a

case "$host" in
    github.com)
        if [ -n "${GH_TOKEN:-}" ]; then
            printf "protocol=https\nhost=github.com\nusername=%s\npassword=%s\n\n" "${GH_OWNER:-iamvikshan}" "$GH_TOKEN"
        fi
        ;;
    gitlab.com)
        if [ -n "${GL_TOKEN:-}" ]; then
            printf "protocol=https\nhost=gitlab.com\nusername=oauth2\npassword=%s\n\n" "$GL_TOKEN"
        fi
        ;;
esac
EOF
chmod 700 "$CRED_HELPER"

git config --global --replace-all credential.https://github.com.helper "$CRED_HELPER"
git config --global --replace-all credential.https://gitlab.com.helper "$CRED_HELPER"
log_ok "credential helper bound (zero plaintext tokens in .git/config)."

# 6. setup ssh commit signing key
KEY_NAME="${HOST_ID}-git-signing"
KEY_PATH="$HOME/.ssh/$KEY_NAME"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

if [ ! -f "$KEY_PATH" ]; then
    ssh-keygen -t ed25519 -C "$GIT_AUTHOR_EMAIL" -f "$KEY_PATH" -N "" -q
    log_ok "generated new ed25519 signing key: $KEY_NAME"
else
    log_ok "using existing ssh signing key: $KEY_NAME"
fi

[ -f "${KEY_PATH}.pub" ] || log_fail "public key ${KEY_PATH}.pub missing."

git config --global --unset-all user.signingkey 2>/dev/null || true
git config --global --unset-all gpg.ssh.program 2>/dev/null || true
git config --local --unset-all user.signingkey 2>/dev/null || true
git config --local --unset-all gpg.ssh.program 2>/dev/null || true

git config --global --replace-all gpg.format ssh
git config --global --replace-all user.signingkey "${KEY_PATH}.pub"
git config --global --replace-all gpg.ssh.program ssh-keygen
git config --global --replace-all commit.gpgsign true

git config --local --replace-all gpg.format ssh
git config --local --replace-all user.signingkey "${KEY_PATH}.pub"
git config --local --replace-all gpg.ssh.program ssh-keygen
git config --local --replace-all commit.gpgsign true

# 7. register ssh signing key via forge apis & prune overflow
PUB_KEY="$(cat "${KEY_PATH}.pub")"

prune_github_keys() {
    command -v jq >/dev/null 2>&1 || return 0
    keys_json="$(curl -s -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GH_TOKEN" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        https://api.github.com/user/ssh_signing_keys)"

    key_count="$(printf '%s' "$keys_json" | jq 'if type == "array" then length else 0 end' 2>/dev/null || printf '0')"
    if [ "$key_count" -gt "$MAX_SSH_KEYS" ]; then
        delete_count=$((key_count - MAX_SSH_KEYS))
        log_warn "pruning oldest $delete_count github signing keys..."
        old_keys="$(printf '%s' "$keys_json" | jq -r "sort_by(.created_at) | .[0:${delete_count}] | .[].id")"
        for key_id in $old_keys; do
            curl -s -o /dev/null -X DELETE \
                -H "Accept: application/vnd.github+json" \
                -H "Authorization: Bearer $GH_TOKEN" \
                -H "X-GitHub-Api-Version: 2022-11-28" \
                "https://api.github.com/user/ssh_signing_keys/${key_id}"
        done
    fi
}

prune_gitlab_keys() {
    command -v jq >/dev/null 2>&1 || return 0
    keys_json="$(curl -s --header "PRIVATE-TOKEN: $GL_TOKEN" "https://gitlab.com/api/v4/user/keys")"

    key_count="$(printf '%s' "$keys_json" | jq 'if type == "array" then [.[] | select(.usage_type == "signing")] | length else 0 end' 2>/dev/null || printf '0')"
    if [ "$key_count" -gt "$MAX_SSH_KEYS" ]; then
        delete_count=$((key_count - MAX_SSH_KEYS))
        log_warn "pruning oldest $delete_count gitlab signing keys..."
        old_keys="$(printf '%s' "$keys_json" | jq -r "[.[] | select(.usage_type == \"signing\")] | sort_by(.created_at) | .[0:${delete_count}] | .[].id")"
        for key_id in $old_keys; do
            curl -s -o /dev/null -X DELETE \
                --header "PRIVATE-TOKEN: $GL_TOKEN" \
                "https://gitlab.com/api/v4/user/keys/${key_id}"
        done
    fi
}

enable_gitlab_force_push() {
    [ -n "$GL_TOKEN" ] && command -v jq >/dev/null 2>&1 || return 0
    project_id="$(curl -s --header "PRIVATE-TOKEN: $GL_TOKEN" \
        "https://gitlab.com/api/v4/projects/${GL_NAMESPACE}%2F${GL_REPO}" 2>/dev/null | jq -r '.id // empty' 2>/dev/null || true)"

    if [ -z "$project_id" ]; then
        log_warn "gitlab project ${GL_NAMESPACE}/${GL_REPO} not found via api; skipping branch protection patch."
        return 0
    fi

    curl -s -o /dev/null -X PATCH \
        --header "PRIVATE-TOKEN: $GL_TOKEN" \
        "https://gitlab.com/api/v4/projects/${project_id}/protected_branches/main?allow_force_push=true" || true
}

if [ -n "$GH_TOKEN" ]; then
    HTTP_STATUS="$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GH_TOKEN" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        https://api.github.com/user/ssh_signing_keys \
        -d "{\"title\":\"${KEY_NAME}\",\"key\":\"${PUB_KEY}\"}")"

    case "$HTTP_STATUS" in
        201|304|422)
            log_ok "signing key registered on github."
            prune_github_keys
            ;;
        *)
            log_warn "github signing key registration returned http $HTTP_STATUS."
            ;;
    esac
fi

if [ -n "$GL_TOKEN" ] && [ "$(lowercase "$GL_NAMESPACE")" != "skip" ]; then
    HTTP_STATUS="$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        --header "PRIVATE-TOKEN: $GL_TOKEN" \
        --header "Content-Type: application/json" \
        -d "{\"title\":\"${KEY_NAME}\",\"key\":\"${PUB_KEY}\",\"usage_type\":\"signing\"}" \
        "https://gitlab.com/api/v4/user/keys")"

    case "$HTTP_STATUS" in
        201|304|400)
            log_ok "signing key registered on gitlab."
            prune_gitlab_keys
            ;;
        *)
            log_warn "gitlab signing key registration returned http $HTTP_STATUS."
            ;;
    esac
fi

# 8. configure clean dual-push remotes
GH_CLEAN_URL="https://github.com/${GH_OWNER}/${GH_REPO}.git"
git remote set-url origin "$GH_CLEAN_URL" 2>/dev/null || git remote add origin "$GH_CLEAN_URL"
git config --unset-all remote.origin.pushurl 2>/dev/null || true
git remote set-url --add --push origin "$GH_CLEAN_URL"
log_ok "github remote configured: ${GH_OWNER}/${GH_REPO}"

if [ -n "$GL_TOKEN" ] && [ "$(lowercase "$GL_NAMESPACE")" != "skip" ]; then
    GL_CLEAN_URL="https://gitlab.com/${GL_NAMESPACE}/${GL_REPO}.git"
    git remote set-url --add --push origin "$GL_CLEAN_URL"
    log_ok "gitlab mirror push remote configured: ${GL_NAMESPACE}/${GL_REPO}"
    enable_gitlab_force_push
else
    log_info "skipping gitlab mirror remote."
fi

# 9. husky hooks & local identity guard
mkdir -p .husky
if [ ! -f ".husky/pre-commit" ]; then
    curl -fsSL "${REPO_RAW_ROOT}/.husky/pre-commit" -o .husky/pre-commit 2>/dev/null || true
    chmod +x .husky/pre-commit 2>/dev/null || true
    log_ok "installed .husky/pre-commit."
fi

git config --local atlas.expected-name "$GIT_AUTHOR_NAME"
git config --local atlas.expected-email "$GIT_AUTHOR_EMAIL"

if [ ! -f ".husky/identity-guard.sh" ]; then
    curl -fsSL "${REPO_RAW_ROOT}/.husky/identity-guard.sh" -o .husky/identity-guard.sh 2>/dev/null || true
fi
chmod +x .husky/identity-guard.sh 2>/dev/null || true
log_ok "local identity guard active."

printf "\n${GREEN}==========================================${NC}\n"
printf "${GREEN}git & environment setup complete${NC}\n"
printf "identity:    %s <%s>\n" "$(git config user.name)" "$(git config user.email)"
printf "signing key: %s\n" "$KEY_NAME"
printf "${GREEN}==========================================${NC}\n\n"