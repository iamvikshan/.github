#!/bin/bash
set -euo pipefail

# --- Configuration ---
GIT_AUTHOR_NAME="vikshan"
GIT_AUTHOR_EMAIL="vixshan@gmail.com"
GH_USERNAME="iamvikshan"
DEFAULT_GL_NAMESPACE="vikshan"
MAX_SSH_KEYS=100
# ---------------------

# Colors for UX
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# 1. Parse Execution Mode
IS_INTERACTIVE=true
if [[ "${1:-}" == "--default" ]]; then
  IS_INTERACTIVE=false
  echo -e "${YELLOW}Running in Headless (--default) Mode${NC}\n"
fi

# 2. Determine Context (Repository Name & Host)
REPO_NAME=$(basename "$PWD")
if [[ -n "${CODESPACE_NAME:-}" ]]; then
  HOST_ID="$CODESPACE_NAME"
else
  HOST_ID=$(hostname -s 2>/dev/null || echo "local-machine")
fi

echo -e "Detected Repository: ${GREEN}${REPO_NAME}${NC}"
echo -e "Detected Host: ${GREEN}${HOST_ID}${NC}"

# 3. Establish Identity
echo -e "\nConfiguring Git identity for ${GIT_AUTHOR_NAME}..."
git config --global user.name "$GIT_AUTHOR_NAME"
git config --global user.email "$GIT_AUTHOR_EMAIL"

# 4. Secret Waterfall (Quarantined & Cached)
ATLAS_SECRETS="$HOME/.atlasrc"
GH_TOKEN="${GH_TOKEN:-}"
GL_TOKEN="${GL_TOKEN:-}"

# Check Global Cache
if [ -f "$ATLAS_SECRETS" ]; then
  echo -e "Loading cached tokens from $ATLAS_SECRETS..."
  source "$ATLAS_SECRETS"
fi

# Check Local .env
if [ -f ".env" ]; then
  echo -e "Checking local .env for tokens..."
  if [[ -z "$GH_TOKEN" ]]; then
    GH_TOKEN=$(grep -E '^GH_TOKEN=' .env | head -1 | cut -d '=' -f2 | tr -d '"' | tr -d "'" || true)
  fi
  if [[ -z "$GL_TOKEN" ]]; then
    GL_TOKEN=$(grep -E '^GL_TOKEN=' .env | head -1 | cut -d '=' -f2 | tr -d '"' | tr -d "'" || true)
  fi
fi

# Interactive Prompt
TOKENS_ADDED=false
if [[ "$IS_INTERACTIVE" == "true" ]]; then
  if [[ -z "$GH_TOKEN" ]]; then
    read -sp "Enter GitHub PAT (GH_TOKEN) [Leave blank to skip]: " GH_TOKEN
    echo ""
    [[ -n "$GH_TOKEN" ]] && TOKENS_ADDED=true
  fi
  if [[ -z "$GL_TOKEN" ]]; then
    read -sp "Enter GitLab PAT (GL_TOKEN) [Leave blank to skip]: " GL_TOKEN
    echo ""
    [[ -n "$GL_TOKEN" ]] && TOKENS_ADDED=true
  fi
fi

GH_TOKEN=$(echo "$GH_TOKEN" | tr -d '[:space:]')
GL_TOKEN=$(echo "$GL_TOKEN" | tr -d '[:space:]')

# Offer to Cache
if [[ "$IS_INTERACTIVE" == "true" && "$TOKENS_ADDED" == "true" ]]; then
  read -p "Save these tokens to $ATLAS_SECRETS for future runs? [y/N]: " save_choice
  if [[ "$save_choice" =~ ^[Yy]$ ]]; then
    touch "$ATLAS_SECRETS"
    chmod 600 "$ATLAS_SECRETS"
    echo "GH_TOKEN=\"$GH_TOKEN\"" > "$ATLAS_SECRETS"
    echo "GL_TOKEN=\"$GL_TOKEN\"" >> "$ATLAS_SECRETS"
    echo -e "✓ Tokens securely cached."
  fi
fi

# 5. Determine GitLab Namespace (Streamlined)
GL_NAMESPACE="SKIP" # Default to skip unless proven otherwise
if [[ "$IS_INTERACTIVE" == "true" && -n "$GL_TOKEN" ]]; then
  echo ""
  read -p "GitLab namespace (Enter/y = '${DEFAULT_GL_NAMESPACE}', 'skip' = ignore, or type custom): " gl_input
  
  if [[ -z "$gl_input" || "$gl_input" =~ ^[Yy]$ ]]; then
    GL_NAMESPACE="$DEFAULT_GL_NAMESPACE"
  elif [[ "${gl_input,,}" == "skip" ]]; then
    GL_NAMESPACE="SKIP"
  else
    GL_NAMESPACE="$gl_input"
  fi
fi

# 6. Setup SSH Signing Key
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

git config --global gpg.format ssh
git config --global user.signingkey "${KEY_PATH}.pub"
git config --global commit.gpgsign true

# Pin the repo to the generated signing key so stale host configs cannot win
if [ ! -f "${KEY_PATH}.pub" ]; then
  echo -e "${RED}ERROR: Public key file ${KEY_PATH}.pub does not exist.${NC}" >&2
  echo -e "${RED}Cannot set local signing key. Exiting.${NC}" >&2
  exit 1
fi
git config --local user.signingkey "${KEY_PATH}.pub"

# --- Helper Functions for API Keys ---
ensure_jq() {
  if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}jq is required for API parsing but not installed. Attempting temporary installation...${NC}"
    if command -v apt-get &> /dev/null; then
      SUDO=""
      if [ "$EUID" -ne 0 ] && command -v sudo &> /dev/null; then SUDO="sudo"; fi
      $SUDO apt-get update -qq 2>/dev/null || true
      if $SUDO apt-get install -y jq -qq 2>/dev/null; then
        JQ_INSTALLED_BY_US=true
        echo -e "✓ jq temporarily installed."
      else
        echo -e "${RED}⚠️ Failed to install jq. SSH key pruning skipped.${NC}"
        return 1
      fi
    else
      echo -e "${RED}⚠️ Package manager not found. SSH key pruning skipped.${NC}"
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

  if [[ "$key_count" -gt "$MAX_SSH_KEYS" ]]; then
    local delete_count=$((key_count - MAX_SSH_KEYS))
    echo -e "⚠️ Found $key_count GitHub keys. Pruning the oldest $delete_count..."
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
  else
    echo -e "  ✓ GitHub key count ($key_count) is within limits."
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

  if [[ "$key_count" -gt "$MAX_SSH_KEYS" ]]; then
    local delete_count=$((key_count - MAX_SSH_KEYS))
    echo -e "⚠️ Found $key_count GitLab signing keys. Pruning the oldest $delete_count..."
    local old_keys
    old_keys=$(echo "$keys_json" | jq -r "[.[] | select(.usage_type == \"signing\")] | sort_by(.created_at) | .[0:${delete_count}] | .[].id")

    for key_id in $old_keys; do
      curl -s -o /dev/null -X DELETE \
           --header "PRIVATE-TOKEN: $GL_TOKEN" \
           "https://gitlab.com/api/v4/user/keys/${key_id}"
      echo -e "  ✓ Deleted GitLab key ID: $key_id"
    done
  else
    echo -e "  ✓ GitLab key count ($key_count) is within limits."
  fi
}

enable_gitlab_force_push() {
  if [[ -z "$GL_TOKEN" ]]; then return 0; fi

  echo -e "Attempting to enable force pushes on GitLab main branch..."
  ensure_jq || return 0

  local project_id
  project_id=$(curl -s --header "PRIVATE-TOKEN: $GL_TOKEN" \
    "https://gitlab.com/api/v4/projects/${GL_NAMESPACE}%2F${REPO_NAME}" 2>/dev/null | jq -r '.id // empty' 2>/dev/null)

  if [[ -z "$project_id" ]]; then
    echo -e "${YELLOW}⚠️ Could not fetch GitLab project ID. Force push configuration skipped.${NC}"
    echo -e "${YELLOW}   (This is expected for newly created projects; manually enable via GitLab UI if needed).${NC}"
    return 1
  fi

  local http_status
  http_status=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH \
    --header "PRIVATE-TOKEN: $GL_TOKEN" \
    "https://gitlab.com/api/v4/projects/${project_id}/protected_branches/main?allow_force_push=true")

  if [[ "$http_status" == "200" ]]; then
    echo -e "✓ Force push enabled on GitLab main branch."
  elif [[ "$http_status" == "404" ]]; then
    echo -e "${YELLOW}⚠️ Protected branch 'main' not found on GitLab. This is expected for new projects.${NC}"
  else
    echo -e "${YELLOW}⚠️ Could not enable force push (HTTP $http_status). You may need to do this manually.${NC}"
  fi
}

# 7. Upload SSH Key to APIs & Prune
PUB_KEY=$(cat "${KEY_PATH}.pub")

echo -e "\n--- API Integrations ---"

if [[ -n "$GH_TOKEN" ]]; then
  echo -e "Uploading SSH public key to GitHub..."
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GH_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://api.github.com/user/ssh_signing_keys \
    -d "{\"title\":\"${KEY_NAME}\",\"key\":\"${PUB_KEY}\"}")

  if [[ "$HTTP_STATUS" == "201" || "$HTTP_STATUS" == "304" || "$HTTP_STATUS" == "422" ]]; then
    echo -e "✓ Key successfully registered with GitHub."
    prune_github_keys
  else
    echo -e "${RED}⚠️ Failed to upload key to GitHub (HTTP $HTTP_STATUS).${NC}"
  fi
else
  echo -e "${YELLOW}⚠️ No GH_TOKEN found. Skipping GitHub API setup.${NC}"
fi

echo ""

if [[ -n "$GL_TOKEN" && "$GL_NAMESPACE" != "SKIP" ]]; then
  echo -e "Uploading SSH public key to GitLab..."
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    --header "PRIVATE-TOKEN: $GL_TOKEN" \
    --header "Content-Type: application/json" \
    -d "{\"title\":\"${KEY_NAME}\",\"key\":\"${PUB_KEY}\",\"usage_type\":\"signing\"}" \
    "https://gitlab.com/api/v4/user/keys")

  if [[ "$HTTP_STATUS" == "201" || "$HTTP_STATUS" == "304" || "$HTTP_STATUS" == "400" ]]; then
    echo -e "✓ Key successfully registered with GitLab."
    prune_gitlab_keys
  else
    echo -e "${RED}⚠️ Failed to upload key to GitLab (HTTP $HTTP_STATUS). Ensure token has 'api' scope and is a Personal Access Token.${NC}"
  fi
else
  echo -e "${YELLOW}⚠️ GitLab configuration skipped.${NC}"
fi

# 8. Configure Multiple Push URLs
echo -e "\n--- Git Remotes ---"

GH_URL="github.com/${GH_USERNAME}/${REPO_NAME}.git"
if [[ -n "$GH_TOKEN" ]]; then
  GH_REMOTE="https://${GH_TOKEN}@${GH_URL}"
else
  GH_REMOTE="https://${GH_URL}"
fi

git remote set-url origin "$GH_REMOTE" 2>/dev/null || git remote add origin "$GH_REMOTE"
git config --unset-all remote.origin.pushurl || true
git remote set-url --add --push origin "$GH_REMOTE"
echo -e "✓ GitHub push remote configured."

if [[ "$GL_NAMESPACE" != "SKIP" ]]; then
  GL_URL="gitlab.com/${GL_NAMESPACE}/${REPO_NAME}.git"
  if [[ -n "$GL_TOKEN" ]]; then
    GL_REMOTE="https://oauth2:${GL_TOKEN}@${GL_URL}"
  else
    GL_REMOTE="https://${GL_URL}"
  fi
  
  git remote set-url --add --push origin "$GL_REMOTE"
  echo -e "✓ GitLab push remote configured (${GL_NAMESPACE}/${REPO_NAME})."

  if [[ -n "$GL_TOKEN" ]]; then
    enable_gitlab_force_push
  fi
fi

# 9. Fetch and Apply Git Hooks
echo -e "\n--- Git Hooks ---"
TMP_DIR=$(mktemp -d)

git clone --depth 1 --filter=blob:none --sparse https://github.com/iamvikshan/atlas.git "$TMP_DIR" -q
git -C "$TMP_DIR" sparse-checkout set scripts/hooks > /dev/null 2>&1

mkdir -p scripts/hooks
if [ -d "$TMP_DIR/scripts/hooks" ]; then
  cp -R "$TMP_DIR/scripts/hooks/"* scripts/hooks/ 2>/dev/null || true
  cp -R "$TMP_DIR/scripts/hooks/".* scripts/hooks/ 2>/dev/null || true
  echo -e "✓ Hooks successfully installed from Atlas."
else
  echo -e "${YELLOW}⚠️ Hooks directory not found in Atlas repo.${NC}"
fi

# 10. Local Identity Guard Setup
# (Leaving this uncommented so it's ready when you push identity-guard.sh to main)
echo -e "\n--- Local Identity Guard ---"
git config --local atlas.expected-name "$GIT_AUTHOR_NAME"
git config --local atlas.expected-email "$GIT_AUTHOR_EMAIL"
echo -e "✓ Identity cached to local git config."

mkdir -p .husky
curl -sL https://raw.githubusercontent.com/iamvikshan/.github/main/scripts/husky/identity-guard.sh > .husky/_/identity-guard.sh 2>/dev/null || true
chmod +x .husky/_/identity-guard.sh 2>/dev/null || true
echo -e "✓ Identity guard payload installed to .husky/_/identity-guard.sh."

# 11. Final Summary
echo -e "\n${GREEN}==========================================${NC}"
echo -e "${GREEN}✓ Environ Setup Complete!${NC}"
echo -e "${GREEN}==========================================${NC}"
echo -e "Identity: $(git config user.name) <$(git config user.email)>"
echo -e "Signing Key: ${KEY_NAME}"
if [[ "$IS_INTERACTIVE" == "false" && -z "$GH_TOKEN" && -z "$GL_TOKEN" ]]; then
  echo -e "\n${YELLOW}Note: Ran in headless mode without tokens.${NC}"
  echo -e "To authenticate remotes and upload SSH keys, run:"
  echo -e "  ${GREEN}bash scripts/bootstrap.sh${NC}"
fi
echo ""
