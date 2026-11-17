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

# explicit pretty-printing; preserve standard cat/grep/find semantics
if (( $+commands[bat] )); then
    alias catp='bat --style=plain --paging=never'
fi

# ripgrep & fd
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
# Suffix and global aliases are Zsh-only, for interactive convenience.
if [[ -n ${ZSH_VERSION:-} ]]; then
    (( $+commands[jq] )) && alias -s json='jq .'
    if (( $+commands[bat] )); then
        alias -s md=bat yaml=bat yml=bat toml=bat
    fi
    alias -g NE='2>/dev/null' NO='>/dev/null 2>&1'
    (( $+commands[jq] )) && alias -g J='| jq'
fi
