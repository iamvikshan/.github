# ==============================================================================
# centralized shell aliases
# ==============================================================================

# eza (replaces ls)
if (( $+commands[eza] )); then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza --icons --group-directories-first -lh'
    alias la='eza --icons --group-directories-first -lah'
    alias llg='eza --icons --group-directories-first --git -lah'
    alias lt='eza --icons --tree --level=2'
    alias lta='eza --icons --tree --level=3 -a'
fi

# bat (replaces cat)
if (( $+commands[bat] )); then
    alias cat='bat --paging=never'
    alias catp='bat --style=plain --paging=never'
fi

# ripgrep & fd
(( $+commands[rg] ))   && alias grep='rg'
(( $+commands[fd] ))   && alias find='fd'
(( $+commands[btop] )) && alias top='btop'

# zoxide navigation
if (( $+commands[zoxide] )); then
    alias cd='z'
    alias cdi='zi'
fi

# bun shortcuts
if (( $+commands[bun] )); then
    alias b='bun'
    alias bi='bun install'
    alias br='bun run'
    alias bx='bunx'
    alias bs='chmod +x scripts/*.sh && scripts/bootstrap.sh'
fi

# git & delta shortcuts
alias gs='git status -sb'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph --decorate -n 20'
alias gp='git pull --rebase'
alias gca='git commit --amend --no-edit'

# safety & navigation
alias ..='cd ..'
alias ...='cd ../..'
alias reload='exec zsh -l'