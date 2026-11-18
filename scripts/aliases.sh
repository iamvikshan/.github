# ==============================================================================
# centralized shell aliases
# ==============================================================================

# eza (replaces ls)
alias ls='eza --icons --group-directories-first'
alias ll='eza --icons --group-directories-first -lh'
alias la='eza --icons --group-directories-first -lah'
alias llg='eza --icons --group-directories-first --git -lah'
alias lt='eza --icons --tree --level=2'
alias lta='eza --icons --tree --level=3 -a'

# explicit pretty-printing; preserve standard cat/grep/find semantics
alias catp='bat --style=plain --paging=never'

# ripgrep & fd
alias top='btop'

# zoxide navigation
alias cd='z'
alias cdi='zi'

# bun shortcuts
if (( $+commands[bun] )); then
    alias b='bun'
    alias bi='bun install'
    alias br='bun run'
    alias bx='bunx'
fi

# git & delta shortcuts
alias gs='git status -sb'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph --decorate -n 20'
alias gp='git pull --rebase'
alias gca='git commit --amend --no-edit'
alias gcas='git commit --amend --no-edit --no-verify'
alias ga='git add .'
alias gacas='git add . && git commit --amend --no-edit --no-verify'
alias gaca='git add . && git commit --amend --no-edit'
alias gacapf='git add . && git commit --amend --no-edit && git push -f'
alias gacaspf='git add . && git commit --amend --no-edit --no-verify && git push -f'

# safety & navigation
alias ..='cd ..'
alias ...='cd ../..'
alias reload='exec zsh -l'
# Suffix and global aliases are Zsh-only, for interactive convenience.
alias -s json='jq .'
alias -s md=bat yaml=bat yml=bat toml=bat

# debian/ubuntu
alias apgd='sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt clean'

# extras
alias bts='sh -c "$(curl -fsSL https://raw.githubusercontent.com/iamvikshan/.github/main/scripts/bootstrap.sh)"'
