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

extract_forge_coords() {
    raw_url="$1"
    clean_url="${raw_url%/}"
    clean_url="${clean_url%.git}"

    no_scheme="$clean_url"
    case "$no_scheme" in
        https://*) no_scheme="${no_scheme#https://}" ;;
        http://*)  no_scheme="${no_scheme#http://}" ;;
        ssh://*)   no_scheme="${no_scheme#ssh://}" ;;
    esac

    case "$no_scheme" in
        github.com[:/]*|*@github.com[:/]*)
            host_prefix="${no_scheme%%github.com[:/]*}"
            case "$host_prefix" in
                */*) return 1 ;;
            esac
            gh_path="${no_scheme#*github.com[:/]}"
            parsed_owner="${gh_path%%/*}"
            parsed_repo="${gh_path#*/}"
            if [ -n "$gh_path" ] && [ -n "$parsed_owner" ] && [ -n "$parsed_repo" ] && [ "$parsed_owner" != "$gh_path" ] && [ "$parsed_repo" = "${parsed_repo#*/}" ]; then
                GH_OWNER="$parsed_owner"
                GH_REPO="$parsed_repo"
                return 0
            fi
            return 1
            ;;
        gitlab.com[:/]*|*@gitlab.com[:/]*)
            host_prefix="${no_scheme%%gitlab.com[:/]*}"
            case "$host_prefix" in
                */*) return 1 ;;
            esac
            gl_path="${no_scheme#*gitlab.com[:/]}"
            parsed_gl_ns="${gl_path%/*}"
            parsed_gl_repo="${gl_path##*/}"
            if [ -n "$gl_path" ] && [ -n "$parsed_gl_ns" ] && [ -n "$parsed_gl_repo" ] && [ "$parsed_gl_ns" != "$gl_path" ]; then
                GL_NAMESPACE="$parsed_gl_ns"
                GL_REPO="$parsed_gl_repo"
                return 0
            fi
            return 1
            ;;
        *)
            return 1
            ;;
    esac
}

# 1. standalone execution mode and host identity
FORCE_DEFAULT=false
TRUST_ONLY=false
for arg in "$@"; do
    case "$arg" in
        --default|--non-interactive|-y) FORCE_DEFAULT=true ;;
        --trust-only) TRUST_ONLY=true ;;
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

# Trust only the discovered checkout, including when invoked from a subdirectory.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
    discovery_error="$(LC_ALL=C git rev-parse --show-toplevel 2>&1 || true)"
    case "$discovery_error" in
        *"detected dubious ownership in repository"*)
            REPO_ROOT="$(git -c safe.directory='*' rev-parse --show-toplevel 2>/dev/null || true)"
            ;;
    esac
fi
TARGET_DIR="${REPO_ROOT:-$PWD}"
if ! git config --global --get-all safe.directory 2>/dev/null | grep -qxF "$TARGET_DIR"; then
    git config --global --add safe.directory "$TARGET_DIR"
fi
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[ "$TRUST_ONLY" = "false" ] || exit 0

# 2. credentials come only from the calling environment; never cache secrets.
GH_TOKEN="${GH_TOKEN:-}"
GL_TOKEN="${GL_TOKEN:-}"
export GH_TOKEN GL_TOKEN

# 3. repository context

case "${GH_OWNER:-}${GH_REPO:-}" in
    *[:/]*)
        log_warn "malformed github coordinates; resetting to defaults."
        GH_OWNER=""
        GH_REPO=""
        ;;
esac
case "${GL_NAMESPACE:-}${GL_REPO:-}" in
    *:*)
        log_warn "malformed gitlab coordinates; resetting to defaults."
        GL_NAMESPACE=""
        GL_REPO=""
        ;;
esac

GH_OWNER="${GH_OWNER:-$GH_USERNAME}"
GH_REPO="${GH_REPO:-$(basename "$TARGET_DIR")}"
GL_NAMESPACE="${GL_NAMESPACE:-$DEFAULT_GL_NAMESPACE}"
GL_REPO="${GL_REPO:-$GH_REPO}"

REMOTE_URL="$(git config --get remote.origin.url 2>/dev/null || true)"
REMOTE_VALID=true

if [ -n "$REMOTE_URL" ]; then
    if ! extract_forge_coords "$REMOTE_URL"; then
        REMOTE_VALID=false
        log_warn "unrecognized origin url; preserving existing remotes."
    fi
fi

# 4. interactive configuration review wizard
if [ "$IS_INTERACTIVE" = "true" ]; then
    printf "\n${CYAN}--- git & forge configuration review ---${NC}\n"
    while true; do
        printf "  github token:       %s\n" "${GH_TOKEN:+set}"
        printf "  1) github owner:     %s\n" "$GH_OWNER"
        printf "  2) github repo:      %s\n" "$GH_REPO"
        printf "  gitlab token:       %s\n" "${GL_TOKEN:+set}"
        printf "  3) gitlab namespace: %s\n" "$GL_NAMESPACE"
        printf "  4) gitlab repo:      %s\n\n" "$GL_REPO"

        printf "accept all [A] or edit coordinates (1-4): "
        read -r choice < /dev/tty
        choice="${choice:-A}"

        case "$(lowercase "$choice")" in
            a|accept) break ;;
            1) printf "enter github owner: "; read -r GH_OWNER < /dev/tty ;;
            2) printf "enter github repo: "; read -r GH_REPO < /dev/tty ;;
            3) printf "enter gitlab namespace (type SKIP to ignore): "; read -r GL_NAMESPACE < /dev/tty ;;
            4) printf "enter gitlab repo: "; read -r GL_REPO < /dev/tty ;;
            *) log_warn "invalid choice." ;;
        esac
    done
fi

# 5. global & local git identity reconciliation, delta pager
log_info "configuring git identity and delta pager..."
git config --global --replace-all user.name "$GIT_AUTHOR_NAME"
git config --global --replace-all user.email "$GIT_AUTHOR_EMAIL"
git config --global init.defaultBranch main
git config --global pull.rebase true

if [ -n "$REPO_ROOT" ]; then
    git config --local --replace-all user.name "$GIT_AUTHOR_NAME"
    git config --local --replace-all user.email "$GIT_AUTHOR_EMAIL"
    for role in author committer; do
        git config --local --replace-all "$role.name" "$GIT_AUTHOR_NAME"
        git config --local --replace-all "$role.email" "$GIT_AUTHOR_EMAIL"
    done
fi

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

# 6. install secure credential helper (keeps raw tokens out of .git/config on ntfs)
mkdir -p "$HOME/.local/bin"
CRED_HELPER="$HOME/.local/bin/git-credential-atlas"
cat > "$CRED_HELPER" << 'EOF'
#!/bin/sh
[ "$1" = "get" ] || exit 0

host=""
while IFS='=' read -r key val; do
    [ -z "$key" ] && break
    [ "$key" = "host" ] && host="$val"
done

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

# 7. setup ssh commit signing key
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
git config --global --replace-all gpg.format ssh
git config --global --replace-all user.signingkey "${KEY_PATH}.pub"
git config --global --replace-all gpg.ssh.program ssh-keygen
git config --global --replace-all commit.gpgsign true

if [ -n "$REPO_ROOT" ]; then
    git config --local --unset-all user.signingkey 2>/dev/null || true
    git config --local --unset-all gpg.ssh.program 2>/dev/null || true
    git config --local --replace-all gpg.format ssh
    git config --local --replace-all user.signingkey "${KEY_PATH}.pub"
    git config --local --replace-all gpg.ssh.program ssh-keygen
    git config --local --replace-all commit.gpgsign true
fi

# 8. register ssh signing key via forge apis & prune overflow
PUB_KEY="$(cat "${KEY_PATH}.pub")"

forge_curl() {
    forge="$1"
    shift
    case "$forge" in
        github) auth_header="Authorization: Bearer $GH_TOKEN" ;;
        gitlab) auth_header="PRIVATE-TOKEN: $GL_TOKEN" ;;
    esac
    case "$auth_header" in
        *[![:print:]]*|*'"'*|*'\'*) log_warn "invalid token characters" >&2; return 1 ;;
    esac
    printf 'header = "%s"\n' "$auth_header" | curl --config - "$@"
}

# Fetch every page before deleting anything, so failed/partial lists cannot prune.
list_keys() {
    forge="$1"; endpoint="$2"; page=1; all_keys='[]'
    while :; do
        batch="$(forge_curl "$forge" -fsS "$endpoint?per_page=100&page=$page")" || return 1
        printf '%s' "$batch" | jq -e 'type == "array"' >/dev/null || return 1
        all_keys="$(printf '%s\n%s' "$all_keys" "$batch" | jq -sc '.[0] + .[1]')" || return 1
        [ "$(printf '%s' "$batch" | jq length)" -eq 100 ] || break
        page=$((page + 1))
    done
    printf '%s' "$all_keys"
}

prune_github_keys() {
    command -v jq >/dev/null 2>&1 || return 0
    if ! keys_json="$(list_keys github https://api.github.com/user/ssh_signing_keys)"; then
        log_warn "failed to list github signing keys; skipping pruning."
        return 0
    fi

    key_count="$(printf '%s' "$keys_json" | jq 'if type == "array" then length else 0 end' 2>/dev/null || printf '0')"
    if [ "$key_count" -gt "$MAX_SSH_KEYS" ]; then
        delete_count=$((key_count - MAX_SSH_KEYS))
        log_warn "pruning oldest $delete_count github signing keys..."
        old_keys="$(printf '%s' "$keys_json" | jq -r "sort_by(.created_at) | .[0:${delete_count}] | .[].id")"
        for key_id in $old_keys; do
            forge_curl github -fsS -o /dev/null -X DELETE \
                -H "Accept: application/vnd.github+json" \
                -H "X-GitHub-Api-Version: 2022-11-28" \
                "https://api.github.com/user/ssh_signing_keys/${key_id}" || log_warn "failed to delete github signing key."
        done
    fi
}

prune_gitlab_keys() {
    command -v jq >/dev/null 2>&1 || return 0
    if ! keys_json="$(list_keys gitlab https://gitlab.com/api/v4/user/keys)"; then
        log_warn "failed to list gitlab signing keys; skipping pruning."
        return 0
    fi

    key_count="$(printf '%s' "$keys_json" | jq 'if type == "array" then [.[] | select(.usage_type == "signing")] | length else 0 end' 2>/dev/null || printf '0')"
    if [ "$key_count" -gt "$MAX_SSH_KEYS" ]; then
        delete_count=$((key_count - MAX_SSH_KEYS))
        log_warn "pruning oldest $delete_count gitlab signing keys..."
        old_keys="$(printf '%s' "$keys_json" | jq -r "[.[] | select(.usage_type == \"signing\")] | sort_by(.created_at) | .[0:${delete_count}] | .[].id")"
        for key_id in $old_keys; do
            forge_curl gitlab -s -o /dev/null -X DELETE \
                "https://gitlab.com/api/v4/user/keys/${key_id}" || log_warn "failed to delete gitlab signing key."
        done
    fi
}

enable_gitlab_force_push() {
    [ -n "$GL_TOKEN" ] && command -v jq >/dev/null 2>&1 || return 0
    encoded_project="$(printf '%s/%s' "$GL_NAMESPACE" "$GL_REPO" | sed 's|/|%2F|g')"
    project_id="$(forge_curl gitlab -s \
        "https://gitlab.com/api/v4/projects/${encoded_project}" 2>/dev/null | jq -r '.id // empty' 2>/dev/null || true)"

    if [ -z "$project_id" ]; then
        log_warn "gitlab project ${GL_NAMESPACE}/${GL_REPO} not found via api; skipping branch protection patch."
        return 0
    fi

    forge_curl gitlab -s -o /dev/null -X PATCH \
        "https://gitlab.com/api/v4/projects/${project_id}/protected_branches/main?allow_force_push=true" || true
}

if [ -n "$GH_TOKEN" ]; then
    if HTTP_STATUS="$(forge_curl github -s -o /dev/null -w "%{http_code}" \
        -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        https://api.github.com/user/ssh_signing_keys \
        -d "{\"title\":\"${KEY_NAME}\",\"key\":\"${PUB_KEY}\"}")"; then

        case "$HTTP_STATUS" in
            201|304|422)
                log_ok "signing key registered on github."
                prune_github_keys
                ;;
            *)
                log_warn "github signing key registration returned http $HTTP_STATUS."
                ;;
        esac
    else
        log_warn "github signing key registration failed (transport error)."
    fi
fi

if [ -n "$GL_TOKEN" ] && [ "$(lowercase "$GL_NAMESPACE")" != "skip" ]; then
    if HTTP_STATUS="$(forge_curl gitlab -s -o /dev/null -w "%{http_code}" \
        -X POST \
        --header "Content-Type: application/json" \
        -d "{\"title\":\"${KEY_NAME}\",\"key\":\"${PUB_KEY}\",\"usage_type\":\"signing\"}" \
        "https://gitlab.com/api/v4/user/keys")"; then

        case "$HTTP_STATUS" in
            201|304|400)
                log_ok "signing key registered on gitlab."
                prune_gitlab_keys
                ;;
            *)
                log_warn "gitlab signing key registration returned http $HTTP_STATUS."
                ;;
        esac
    else
        log_warn "gitlab signing key registration failed (transport error)."
    fi
fi

# 9. configure clean dual-push remotes (only when origin url is valid or unset)
if [ "$REMOTE_VALID" = "true" ] && [ -n "$GH_OWNER" ] && [ -n "$GH_REPO" ]; then
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
else
    log_warn "skipping remote updates due to unmatched or incomplete repository coordinates."
fi

# 10. husky: identity guard (always refreshed) + one guard call in pre-commit
GUARD_CALL='sh "$(git rev-parse --show-toplevel)/.husky/identity-guard.sh" || exit $?'

# returns 1 on any failure and never exits, so the caller decides
fetch_executable() {
    url="$1"; dest="$2"; label="$3"
    tmp="$(mktemp "${dest}.tmp.XXXXXX")" || return 1
    if curl -fsSL --max-time 30 "$url" -o "$tmp" &&
       [ -s "$tmp" ] &&
       head -n 1 "$tmp" | grep -q '^#!' &&
       sh -n "$tmp" &&
       chmod +x "$tmp" &&
       mv -f "$tmp" "$dest"; then
        return 0
    fi
    rm -f "$tmp"
    log_warn "could not fetch $label from $url"
    return 1
}

# true when the shebang line names a posix-ish shell we can safely insert into
shell_shebang_ok() {
    interp="${1#\#!}"
    set -- $interp
    base="${1##*/}"
    [ "$base" = env ] && base="${2:-}"
    case "$base" in sh|bash|dash|ash|zsh) return 0 ;; *) return 1 ;; esac
}

if [ -n "$REPO_ROOT" ]; then
    HUSKY_DIR="$REPO_ROOT/.husky"
    HOOK="$HUSKY_DIR/pre-commit"
    GUARD="$HUSKY_DIR/identity-guard.sh"
    mkdir -p "$HUSKY_DIR"
    [ ! -d "$HOOK" ] || log_fail ".husky/pre-commit is a directory; move it aside and rerun setup."

    git config --local atlas.expected-name "$GIT_AUTHOR_NAME"
    git config --local atlas.expected-email "$GIT_AUTHOR_EMAIL"

    # guard: always refresh; keep an existing copy only if the fetch fails
    if fetch_executable "${REPO_RAW_ROOT}/.husky/identity-guard.sh" "$GUARD" ".husky/identity-guard.sh"; then
        log_ok "refreshed .husky/identity-guard.sh."
    elif [ -f "$GUARD" ]; then
        chmod +x "$GUARD" || log_fail "failed to mark existing identity-guard.sh executable."
        log_warn "using existing identity-guard.sh, which may be stale."
    else
        log_fail "identity-guard.sh unavailable and no local copy exists."
    fi

    # pre-commit: never overwrite; make sure it calls the guard
    if [ ! -e "$HOOK" ] && [ ! -L "$HOOK" ]; then
        printf '#!/usr/bin/env sh\nset -e\n%s\n' "$GUARD_CALL" > "$HOOK"
        chmod +x "$HOOK"
        log_ok "created .husky/pre-commit with identity guard."
    elif awk '
        /^[[:space:]]*set -e[[:space:]]*$/ { errexit = 1; next }
        /^[[:space:]]*set \+e[[:space:]]*$/ { errexit = 0; next }
        {
            line = $0
            exits = sub(/[[:space:]]+\|\| exit \$\?[[:space:]]*$/, "", line)
            if (line ~ /^[[:space:]]*sh[[:space:]]+([^[:space:]]*identity-guard\.sh|".*identity-guard\.sh")[[:space:]]*$/ && (errexit || exits)) protected = 1
        }
        END { exit !protected }
    ' "$HOOK"; then
        log_ok "pre-commit already calls the identity guard."
    else
        [ ! -L "$HOOK" ] ||
            log_fail ".husky/pre-commit is a symlink; editing it would change a shared file. add this line by hand: $GUARD_CALL"
        first="$(head -n 1 "$HOOK")"
        has_shebang=false
        case "$first" in
            "#!"*)
                shell_shebang_ok "$first" ||
                    log_fail "pre-commit is not a shell hook ($first). add this line by hand: $GUARD_CALL"
                has_shebang=true
                ;;
        esac
        tmp="$(mktemp "$HOOK.tmp.XXXXXX")"
        {
            if [ "$has_shebang" = "true" ]; then
                printf '%s\n%s\n' "$first" "$GUARD_CALL"
                tail -n +2 "$HOOK"
            else
                printf '%s\n' "$GUARD_CALL"
                cat "$HOOK"
            fi
        } > "$tmp" || { rm -f "$tmp"; log_fail "failed to build updated pre-commit."; }
        chmod +x "$tmp"
        mv -f "$tmp" "$HOOK"
        log_ok "added identity guard call to existing pre-commit."
    fi
    [ -L "$HOOK" ] || [ -x "$HOOK" ] || chmod +x "$HOOK" || log_fail "failed to mark .husky/pre-commit executable."

    # Ensure the configured hooks directory reaches the identity guard.
    hooks_path="$(git config --path --get core.hooksPath 2>/dev/null || true)"
    hooks_reach_guard() {
        hook_candidate="$hooks_path/pre-commit"
        case "$hook_candidate" in
            /*) ;;
            *) hook_candidate="$REPO_ROOT/$hook_candidate" ;;
        esac
        [ -f "$hook_candidate" ] && [ -x "$hook_candidate" ] || return 1
        [ "$hook_candidate" -ef "$HOOK" ] && return 0
        [ "$hook_candidate" -ef "$HUSKY_DIR/_/pre-commit" ] &&
            [ -x "$HUSKY_DIR/_/h" ] &&
            grep -qF '. "$(dirname "$0")/h"' "$hook_candidate" &&
            grep -qF 's=$(dirname "$(dirname "$0")")/$s' "$HUSKY_DIR/_/h" &&
            grep -qF 'sh -e "$s" "$@"' "$HUSKY_DIR/_/h"
    }
    if [ -z "$hooks_path" ] || ! hooks_reach_guard; then
        case "$hooks_path" in
            ""|.husky|.husky/_|"$HUSKY_DIR"|"$HUSKY_DIR/_")
                git config --local core.hooksPath .husky
                hooks_path=.husky
                ;;
            *) log_fail "configured core.hooksPath does not reach the identity hook." ;;
        esac
    fi
    hooks_reach_guard || log_fail "failed to activate local identity hook."
    log_ok "local identity guard and git hooks active."
fi

printf "\n${GREEN}==========================================${NC}\n"
printf "${GREEN}git & environment setup complete${NC}\n"
printf "identity:    %s <%s>\n" "$(git config user.name)" "$(git config user.email)"
printf "signing key: %s\n" "$KEY_NAME"
printf "${GREEN}==========================================${NC}\n\n"
