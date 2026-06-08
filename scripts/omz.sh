#!/usr/bin/env bash

# ==============================================================================
# Universal Zsh & Oh My Zsh Installer
# Fetches configuration from the centralized universal.zshrc
# ==============================================================================

set -e

# --- Colors for output ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}ℹ Starting Zsh environment setup...${NC}"

# 1. Detect OS and Install Prerequisites (zsh, git, curl)
echo -e "${YELLOW}▶ Checking prerequisites...${NC}"
if ! command -v zsh >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
    echo -e "${BLUE}ℹ Missing prerequisites. Attempting to install...${NC}"
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -qq && sudo apt-get install -y -qq zsh git curl
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y zsh git curl
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y zsh git curl
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm zsh git curl
    else
        echo "❌ Package manager not found. Please install zsh, git, and curl manually."
        exit 1
    fi
fi
echo -e "${GREEN}✓ Prerequisites installed.${NC}"

# 2. Install Oh My Zsh (Unattended)
echo -e "${YELLOW}▶ Installing Oh My Zsh...${NC}"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    echo -e "${GREEN}✓ Oh My Zsh installed.${NC}"
else
    echo -e "${BLUE}ℹ Oh My Zsh is already installed. Skipping.${NC}"
fi

# 3. Clone Custom Plugins
echo -e "${YELLOW}▶ Installing Zsh plugins...${NC}"
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" -q
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" -q
fi
echo -e "${GREEN}✓ Plugins installed.${NC}"

# 4. Fetch Universal .zshrc Configuration
echo -e "${YELLOW}▶ Fetching universal .zshrc...${NC}"


# Download to a temporary file first
TEMP_ZSHRC="$HOME/.zshrc.tmp"
if ! curl -fsSL https://raw.githubusercontent.com/iamvikshan/.github/refs/heads/main/scripts/universal.zshrc -o "$TEMP_ZSHRC"; then
    echo "❌ Failed to download universal.zshrc. Keeping existing configuration."
    rm -f "$TEMP_ZSHRC"
    exit 1
fi

# Verify the download succeeded and file exists
if [ ! -f "$TEMP_ZSHRC" ]; then
    echo "❌ Download failed - temporary file not found. Keeping existing configuration."
    exit 1
fi

# Backup existing .zshrc only after successful download and verification
if [ -f "$HOME/.zshrc" ]; then
    mv "$HOME/.zshrc" "$HOME/.zshrc.backup-$(date +%s)"
fi

# Atomically move temp file to final location
mv "$TEMP_ZSHRC" "$HOME/.zshrc"

echo -e "${GREEN}✓ .zshrc configured successfully.${NC}"

# 5. Add Zsh fallback to .bashrc
echo -e "${YELLOW}▶ Adding Zsh fallback to .bashrc...${NC}"
BASH_FALLBACK_SNIPPET='
# Automatically switch to Zsh
if [[ $- == *i* ]] && [ -x "$(command -v zsh)" ]; then
    export SHELL="$(command -v zsh)"
    if shopt -q login_shell; then
        exec zsh -l
    else
        exec zsh
    fi
fi
'

if ! grep -Eq '^[[:space:]]*exec[[:space:]]+zsh' "$HOME/.bashrc" 2>/dev/null; then
    echo "$BASH_FALLBACK_SNIPPET" >> "$HOME/.bashrc"
    echo -e "${GREEN}✓ Fallback added to .bashrc.${NC}"
else
    echo -e "${BLUE}ℹ Zsh fallback already present in .bashrc.${NC}"
fi

# 6. Change Default Shell
echo -e "${YELLOW}▶ Changing default shell to Zsh...${NC}"
ZSH_PATH=$(command -v zsh)
if [ "$SHELL" != "$ZSH_PATH" ]; then
    sudo chsh -s "$ZSH_PATH" "$USER" || chsh -s "$ZSH_PATH"
    echo -e "${GREEN}✓ Default shell changed.${NC}"
else
    echo -e "${BLUE}ℹ Zsh is already the default shell.${NC}"
fi

echo -e "\n${GREEN}🎉 Zsh setup complete! Starting your new shell now...${NC}\n"

# 7. Hand over the session instantly to Zsh
exec zsh