#!/bin/bash
set -euo pipefail

# --- Configuration ---
GIT_AUTHOR_NAME="iamvikshan"
GIT_AUTHOR_EMAIL="vixshan@gmail.com"
GH_USERNAME="iamvikshan"
DEFAULT_GL_NAMESPACE="vikshan"
MAX_SSH_KEYS=100
# ---------------------

# Colors for UX
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Global state for cleanup
TMP_DIR=""
JQ_INSTALLED_BY_US=false

# Auto-cleanup trap
cleanup() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
  if [[ "$JQ_INSTALLED_BY_US" == "true" ]]; then
    echo -e "\nCleaning up temporary dependencies..."
    SUDO=""
    if [ "$EUID" -ne 0 ] && command -v sudo &> /dev/null; then SUDO="sudo"; fi
    $SUDO apt-get remove -y jq -qq 2>/dev/null || true
    echo -e "✓ jq removed."
  fi
}
trap cleanup EXIT

echo -e "${GREEN}Starting Environment Bootstrap...${NC}\n"

# 1. Parse Execution Mode & TTY Check
IS_INTERACTIVE=true
if [[ "${1:-}" == "--default" ]] || [ ! -t 1 ]; then
  IS_INTERACTIVE=false
  echo -e "${YELLOW}Running in Headless (--default or non-TTY) Mode${NC}\n"
fi

if [[ -n "${CODESPACE_NAME:-}" ]]; then
  HOST_ID="$CODESPACE_NAME"
else
  HOST_ID=$(hostname -s 2>/dev/null || echo "local-machine")
fi

# 2. Secret & Context Waterfall
ATLAS_SECRETS="$HOME/.atlasrc"

# Migrate old token cache if needed
if [ ! -f "$ATLAS_SECRETS" ]; then
  if [ -f "$HOME/.atlas_secrets" ]; then
    echo -e "${CYAN}Migrating old token cache from ~/.atlas_secrets to ~/.atlasrc${NC}"
    cp -p "$HOME/.atlas_secrets" "$ATLAS_SECRETS"
  elif [ -f "$HOME/.atlas_secrets.json" ]; then
    echo -e "${CYAN}Migrating old token cache from ~/.atlas_secrets.json to ~/.atlasrc${NC}"
    cp -p "$HOME/.atlas_secrets.json" "$ATLAS_SECRETS"
  fi
fi

GH_TOKEN="${GH_TOKEN:-}"
GL_TOKEN="${GL_TOKEN:-}"

# Load from Cache if available
if [ -f "$ATLAS_SECRETS" ]; then
  echo -e "Loading cached configuration from $ATLAS_SECRETS..."
  source "$ATLAS_SECRETS"
fi

# Fallback to local .env if tokens are still missing
if [ -f ".env" ]; then
  if [[ -z "$GH_TOKEN" ]]; then GH_TOKEN=$(grep -E '^GH_TOKEN=' .env | head -1 | cut -d '=' -f2 | tr -d '"' | tr -d "'" || true); fi
  if [[ -z "$GL_TOKEN" ]]; then GL_TOKEN=$(grep -E '^GL_TOKEN=' .env | head -1 | cut -d '=' -f2 | tr -d '"' | tr -d "'" || true); fi
fi

# 3. Intelligent Context Extraction
GH_OWNER="${GH_OWNER:-$GH_USERNAME}"
GH_REPO="${GH_REPO:-$(basename "$PWD")}"
GL_NAMESPACE="${GL_NAMESPACE:-$DEFAULT_GL_NAMESPACE}"
GL_REPO="${GL_REPO:-$GH_REPO}"

# Tell Git to trust the current workspace before running any git commands
if ! git config --global --get-all safe.directory | grep -qxF "$PWD"; then
  git config --global --add safe.directory "$PWD"
fi

REMOTE_URL=$(git config --get remote.origin.url || true)
if [[ -n "$REMOTE_URL" ]]; then
  if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/([^.]+)(\.git)?$ ]]; then
    GH_OWNER="${BASH_REMATCH[1]}"
    GH_REPO="${BASH_REMATCH[2]}"
  elif [[ "$REMOTE_URL" =~ gitlab\.com[:/]([^/]+)/([^.]+)(\.git)?$ ]]; then
    GL_NAMESPACE="${BASH_REMATCH[1]}"
    GL_REPO="${BASH_REMATCH[2]}"
  fi
fi

# 4. Stateful Interactive Wizard
mask_token() {
  local token=$1
  if [[ -z "$token" ]]; then echo "(empty)"; else echo "${token:0:4}********${token: -4}"; fi
}

lowercase() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

if [[ "$IS_INTERACTIVE" == "true" ]]; then
  echo -e "\n${CYAN}--- Configuration Review ---${NC}"
  while true; do
    echo -e "  1) GitHub Token:      $(mask_token "$GH_TOKEN")"
    echo -e "  2) GitHub Owner:      ${GH_OWNER}"
    echo -e "  3) GitHub Repo:       ${GH_REPO}"
    echo -e "  4) GitLab Token:      $(mask_token "$GL_TOKEN")"
    echo -e "  5) GitLab Namespace:  ${GL_NAMESPACE}"
    echo -e "  6) GitLab Repo:       ${GL_REPO}"
    echo ""
    
    # </dev/tty is CRITICAL for 'curl | bash' compatibility
    read -p "Accept all [A] or enter a number to edit (1-6): " choice < /dev/tty
    choice=${choice:-A}
    
    case "$(lowercase "$choice")" in
      a|accept) break ;;
      1) read -sp "Enter GitHub Token: " GH_TOKEN < /dev/tty; echo ;;
      2) read -p "Enter GitHub Owner: " GH_OWNER < /dev/tty ;;
      3) read -p "Enter GitHub Repo: " GH_REPO < /dev/tty ;;
      4) read -sp "Enter GitLab Token: " GL_TOKEN < /dev/tty; echo ;;
      5) read -p "Enter GitLab Namespace (type SKIP to ignore): " GL_NAMESPACE < /dev/tty ;;
      6) read -p "Enter GitLab Repo: " GL_REPO < /dev/tty ;;
      *) echo -e "${RED}Invalid choice.${NC}" ;;
    esac
  done

  # Save to Global Config
  echo ""
  read -p "Save this configuration to $ATLAS_SECRETS? [Y/n]: " save_choice < /dev/tty
  save_choice=${save_choice:-Y}
  if [[ "$save_choice" =~ ^[Yy]$ ]]; then
    touch "$ATLAS_SECRETS"
    chmod 600 "$ATLAS_SECRETS"
    cat > "$ATLAS_SECRETS" <<EOF
GH_TOKEN="$GH_TOKEN"
GH_OWNER="$GH_OWNER"
GH_REPO="$GH_REPO"
GL_TOKEN="$GL_TOKEN"
GL_NAMESPACE="$GL_NAMESPACE"
GL_OWNER="$GL_NAMESPACE"
GL_REPO="$GL_REPO"
EOF
    echo -e "✓ Configuration securely cached in ~/.atlasrc."
  fi
fi

echo -e "\nConfiguring Git identity for ${GIT_AUTHOR_NAME}..."
git config --global user.name "$GIT_AUTHOR_NAME"
git config --global user.email "$GIT_AUTHOR_EMAIL"

# 5. Setup SSH Signing Key
KEY_NAME="${HOST_ID}-git-signing"
KEY_PATH="$HOME/.ssh/$KEY_NAME"

echo -e "\nSetting up SSH signing key (${KEY_NAME})..."
mkdir -p "$HOME/.ssh"

if [ ! -f "$KEY_PATH" ]; then
  ssh-keygen -t ed25519 -C "$GIT_AUTHOR_EMAIL" -f "$KEY_PATH" -N "" -q
  echo -e "✓ Generated new SSH signing key."
else
  echo -e "✓ SSH signing key already exists."
fi

# Purge injected configurations and wrappers across all levels
git config --system --unset-all user.signingkey 2>/dev/null || true
git config --global --unset-all user.signingkey 2>/dev/null || true
git config --system --unset-all gpg.ssh.program 2>/dev/null || true
git config --global --unset-all gpg.ssh.program 2>/dev/null || true

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git config --local --unset-all user.signingkey 2>/dev/null || true
  git config --local --unset-all gpg.ssh.program 2>/dev/null || true
fi

# Set global configuration with --replace-all for absolute certainty
git config --global --replace-all gpg.format ssh
git config --global --replace-all user.signingkey "${KEY_PATH}.pub"
git config --global --replace-all commit.gpgsign true

if [ ! -f "${KEY_PATH}.pub" ]; then
  echo -e "${RED}ERROR: Public key file ${KEY_PATH}.pub does not exist.${NC}" >&2
  exit 1
fi

# Enforce strictly at the local level to override any phantom environment variables
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git config --local --replace-all gpg.format ssh
  git config --local --replace-all user.signingkey "${KEY_PATH}.pub"
  git config --local --replace-all commit.gpgsign true
fi

# --- Helper Functions for API Keys ---
ensure_jq() {
  if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}jq is required but not installed. Attempting installation...${NC}"
    if command -v apt-get &> /dev/null; then
      SUDO=""
      if [ "$EUID" -ne 0 ] && command -v sudo &> /dev/null; then SUDO="sudo"; fi
      $SUDO apt-get update -qq 2>/dev/null || true
      if $SUDO apt-get install -y jq -qq 2>/dev/null; then
        JQ_INSTALLED_BY_US=true
        echo -e "✓ jq temporarily installed."
      else
        return 1
      fi
    else
      return 1
    fi
  fi
  return 0
}

prune_github_keys() {
  echo -e "Checking GitHub SSH keys limit (Max: $MAX_SSH_KEYS)..."
  ensure_jq || return 0

  local keys_json
  keys_json=$(curl -s -H "Accept: application/vnd.github+json" \
                     -H "Authorization: Bearer $GH_TOKEN" \
                     -H "X-GitHub-Api-Version: 2022-11-28" \
                     https://api.github.com/user/ssh_signing_keys)

  local key_count
  key_count=$(echo "$keys_json" | jq '. | length' 2>/dev/null || echo "0")
  echo -e "  Found $key_count configured keys on GitHub."

  if [[ "$key_count" -gt "$MAX_SSH_KEYS" ]]; then
    local delete_count=$((key_count - MAX_SSH_KEYS))
    echo -e "⚠️ Pruning the oldest $delete_count GitHub keys..."
    local old_keys
    old_keys=$(echo "$keys_json" | jq -r "sort_by(.created_at) | .[0:${delete_count}] | .[].id")

    for key_id in $old_keys; do
      curl -s -o /dev/null -X DELETE \
           -H "Accept: application/vnd.github+json" \
           -H "Authorization: Bearer $GH_TOKEN" \
           -H "X-GitHub-Api-Version: 2022-11-28" \
           "https://api.github.com/user/ssh_signing_keys/${key_id}"
      echo -e "  ✓ Deleted GitHub key ID: $key_id"
    done
  fi
}

prune_gitlab_keys() {
  echo -e "Checking GitLab SSH keys limit (Max: $MAX_SSH_KEYS)..."
  ensure_jq || return 0

  local keys_json
  keys_json=$(curl -s --header "PRIVATE-TOKEN: $GL_TOKEN" \
                     "https://gitlab.com/api/v4/user/keys")

  local key_count
  key_count=$(echo "$keys_json" | jq '[.[] | select(.usage_type == "signing")] | length' 2>/dev/null || echo "0")
  echo -e "  Found $key_count configured keys on GitLab."

  if [[ "$key_count" -gt "$MAX_SSH_KEYS" ]]; then
    local delete_count=$((key_count - MAX_SSH_KEYS))
    echo -e "⚠️ Pruning the oldest $delete_count GitLab signing keys..."
    local old_keys
    old_keys=$(echo "$keys_json" | jq -r "[.[] | select(.usage_type == \"signing\")] | sort_by(.created_at) | .[0:${delete_count}] | .[].id")

    for key_id in $old_keys; do
      curl -s -o /dev/null -X DELETE \
           --header "PRIVATE-TOKEN: $GL_TOKEN" \
           "https://gitlab.com/api/v4/user/keys/${key_id}"
      echo -e "  ✓ Deleted GitLab key ID: $key_id"
    done
  fi
}

enable_gitlab_force_push() {
  if [[ -z "$GL_TOKEN" ]]; then return 0; fi

  ensure_jq || return 0
  local project_id
  project_id=$(curl -s --header "PRIVATE-TOKEN: $GL_TOKEN" \
    "https://gitlab.com/api/v4/projects/${GL_NAMESPACE}%2F${GL_REPO}" 2>/dev/null | jq -r '.id // empty' 2>/dev/null)

  if [[ -z "$project_id" ]]; then return 1; fi

  curl -s -o /dev/null -X PATCH \
    --header "PRIVATE-TOKEN: $GL_TOKEN" \
    "https://gitlab.com/api/v4/projects/${project_id}/protected_branches/main?allow_force_push=true" || true
}

# 6. Upload SSH Key to APIs & Prune
PUB_KEY=$(cat "${KEY_PATH}.pub")

echo -e "\n--- API Integrations ---"

if [[ -n "$GH_TOKEN" ]]; then
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GH_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://api.github.com/user/ssh_signing_keys \
    -d "{\"title\":\"${KEY_NAME}\",\"key\":\"${PUB_KEY}\"}")

  if [[ "$HTTP_STATUS" == "201" || "$HTTP_STATUS" == "304" || "$HTTP_STATUS" == "422" ]]; then
    echo -e "✓ Key registered with GitHub."
    prune_github_keys
  else
    echo -e "${RED}⚠️ Failed to upload key to GitHub (HTTP $HTTP_STATUS).${NC}"
  fi
fi

if [[ -n "$GL_TOKEN" && "$(lowercase "$GL_NAMESPACE")" != "skip" ]]; then
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    --header "PRIVATE-TOKEN: $GL_TOKEN" \
    --header "Content-Type: application/json" \
    -d "{\"title\":\"${KEY_NAME}\",\"key\":\"${PUB_KEY}\",\"usage_type\":\"signing\"}" \
    "https://gitlab.com/api/v4/user/keys")

  if [[ "$HTTP_STATUS" == "201" || "$HTTP_STATUS" == "304" || "$HTTP_STATUS" == "400" ]]; then
    echo -e "✓ Key registered with GitLab."
    prune_gitlab_keys
  fi
fi

# 7. Configure Multiple Push URLs
echo -e "\n--- Git Remotes ---"

GH_URL="github.com/${GH_OWNER}/${GH_REPO}.git"
if [[ -n "$GH_TOKEN" ]]; then GH_REMOTE="https://${GH_TOKEN}@${GH_URL}"
else GH_REMOTE="https://${GH_URL}"; fi

git remote set-url origin "$GH_REMOTE" 2>/dev/null || git remote add origin "$GH_REMOTE"
git config --unset-all remote.origin.pushurl || true
git remote set-url --add --push origin "$GH_REMOTE"
echo -e "✓ GitHub push remote configured (${GH_OWNER}/${GH_REPO})."

# ONLY configure GitLab if GL_TOKEN exists AND wasn't skipped
if [[ -n "$GL_TOKEN" && "$(lowercase "$GL_NAMESPACE")" != "skip" ]]; then
  GL_URL="gitlab.com/${GL_NAMESPACE}/${GL_REPO}.git"
  GL_REMOTE="https://oauth2:${GL_TOKEN}@${GL_URL}"
  
  git remote set-url --add --push origin "$GL_REMOTE"
  echo -e "✓ GitLab push remote configured (${GL_NAMESPACE}/${GL_REPO})."
  
  enable_gitlab_force_push
else
  echo -e "✓ Skipping GitLab remote configuration (No token provided or skipped)."
fi

# 8. Fetch and Apply Git Hooks
echo -e "\n--- Git Hooks ---"
TMP_DIR=$(mktemp -d)

git clone --depth 1 --filter=blob:none --sparse https://github.com/iamvikshan/atlas.git "$TMP_DIR" -q &>/dev/null
git -C "$TMP_DIR" sparse-checkout set scripts/hooks &>/dev/null

mkdir -p scripts/hooks
if [ -d "$TMP_DIR/scripts/hooks" ]; then
  cp -R "$TMP_DIR/scripts/hooks/"* scripts/hooks/ 2>/dev/null || true
  cp -R "$TMP_DIR/scripts/hooks/".* scripts/hooks/ 2>/dev/null || true
  echo -e "✓ Hooks successfully installed."
fi

# 9. Local Identity Guard Setup
echo -e "\n--- Local Identity Guard ---"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git config --local atlas.expected-name "$GIT_AUTHOR_NAME"
  git config --local atlas.expected-email "$GIT_AUTHOR_EMAIL"
fi

mkdir -p .husky/_
curl -sL https://raw.githubusercontent.com/iamvikshan/.github/main/scripts/husky/identity-guard.sh > .husky/_/identity-guard.sh 2>/dev/null || true
chmod +x .husky/_/identity-guard.sh 2>/dev/null || true
echo -e "✓ Identity guard payload installed."

# 10. Final Summary
echo -e "\n${GREEN}==========================================${NC}"
echo -e "${GREEN}✓ Environ Setup Complete!${NC}"
echo -e "${GREEN}==========================================${NC}"
echo -e "Identity: $(git config user.name) <$(git config user.email)>"
echo -e "Signing Key: ${KEY_NAME}"
echo ""
