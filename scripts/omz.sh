#!/usr/bin/env bash

# ==============================================================================
# Universal Zsh & Oh My Zsh Installer
# Tailored with custom git prompt, syntax highlighting, and autosuggestions
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
    # Run the OMZ install script in unattended mode so it doesn't block the script
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    echo -e "${GREEN}✓ Oh My Zsh installed.${NC}"
else
    echo -e "${BLUE}ℹ Oh My Zsh is already installed. Skipping.${NC}"
fi

# 3. Clone Custom Plugins
echo -e "${YELLOW}▶ Installing Zsh plugins...${NC}"
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

# zsh-autosuggestions
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" -q
fi

# zsh-syntax-highlighting
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" -q
fi
echo -e "${GREEN}✓ Plugins installed.${NC}"

# 4. Generate the custom .zshrc
echo -e "${YELLOW}▶ Configuring .zshrc...${NC}"

# Backup existing .zshrc if it wasn't created by us just now
if [ -f "$HOME/.zshrc" ]; then
    mv "$HOME/.zshrc" "$HOME/.zshrc.backup-$(date +%s)"
fi

# Write your stripped-down, universal config
cat << 'EOF' > "$HOME/.zshrc"
# ==============================================================================
# Custom Zsh Configuration
# ==============================================================================

# Ensure local bin is in PATH
if [[ "${PATH}" != *"$HOME/.local/bin"* ]]; then
  export PATH="$HOME/.local/bin:${PATH}"
fi

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set theme to empty string since we are building a custom prompt below
ZSH_THEME=""

# Plugins list
plugins=(git bun zsh-autosuggestions zsh-syntax-highlighting)

# Load Oh My Zsh
source $ZSH/oh-my-zsh.sh

# Allow variable substitution in prompt
setopt PROMPT_SUBST

# Custom Git Info Function
__git_info() {
    local branch
    branch=$(git --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git --no-optional-locks rev-parse --short HEAD 2>/dev/null)
    if [[ -n "${branch}" ]]; then
        local dirty_flag=""
        if git --no-optional-locks ls-files --error-unmatch -m --directory --no-empty-directory -o --exclude-standard ":/*" > /dev/null 2>&1; then
            dirty_flag=" %F{yellow}✗"
        fi
        echo "%F{cyan}(%F{red}${branch}${dirty_flag}%F{cyan}) "
    fi
}

# The Prompt String (Username replaced GITHUB_USER)
PROMPT='%(?.%F{green}.%F{red})➜%f %F{green}%n%f %F{blue}%4~%f $(__git_info)%f$ '

# Terminal Title Updates
if [[ "$TERM" == "xterm" || "$TERM" == "xterm-256color" || "$TERM_PROGRAM" == "vscode" ]]; then
    preexec() { print -Pn "\e]0;%n@%m: $1\a" }
    precmd() { print -Pn "\e]0;%n@%m: zsh\a" }
fi
EOF

echo -e "${GREEN}✓ .zshrc configured successfully.${NC}"

# 5. Change Default Shell
echo -e "${YELLOW}▶ Changing default shell to Zsh...${NC}"
ZSH_PATH=$(command -v zsh)
if [ "$SHELL" != "$ZSH_PATH" ]; then
    # We use sudo chsh to ensure it works without prompting for the user's password if they have sudo NOPASSWD
    sudo chsh -s "$ZSH_PATH" "$USER" || chsh -s "$ZSH_PATH"
    echo -e "${GREEN}✓ Default shell changed.${NC}"
else
    echo -e "${BLUE}ℹ Zsh is already the default shell.${NC}"
fi

echo -e "\n${GREEN}🎉 Zsh setup complete! Starting your new shell now...${NC}\n"

# 6. Hand over the session instantly to Zsh
exec zsh