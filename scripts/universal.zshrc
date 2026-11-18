# ==============================================================================
# universal zsh configuration (debian, alpine, macos, devcontainers)
# ==============================================================================

# path hierarchy
typeset -U path PATH
path=("$HOME/.local/bin" "$HOME/.bun/bin" $path)
export BUN_INSTALL="$HOME/.bun"

# history persistence
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_FIND_NO_DUPS HIST_REDUCE_BLANKS HIST_VERIFY SHARE_HISTORY EXTENDED_HISTORY INTERACTIVE_COMMENTS

# completion initialization (cached daily for instant startup)
autoload -Uz compinit
if [[ -n ${HOME}/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' menu no

ZSH_PLUGIN_DIR="$HOME/.local/share/zsh/plugins"

# blood-obsidian autosuggestion tint
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#634F52'

# fzf + fd + bat integration with blood-obsidian palette
export FZF_DEFAULT_OPTS=" \
    --height=50% --layout=reverse --border=rounded --margin=1 --padding=1 \
    --color=bg+:#291F21,bg:#141011,spinner:#D92638,hl:#FF4D5E \
    --color=fg:#DEC9CB,header:#8C787B,info:#B81D24,pointer:#D92638 \
    --color=marker:#6ECB86,fg+:#FFF5F6,prompt:#D92638,hl+:#FF4D5E \
    --color=border:#48393B"

export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --strip-cwd-prefix --hidden --follow --exclude .git'

export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
export BAT_THEME="ansi"

export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --icons --color=always {}'"
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --icons --color=always $realpath'

# bootstrap:fzf

# fzf must bind Tab before fzf-tab; widget wrappers load after both.
source "$ZSH_PLUGIN_DIR/fzf-tab/fzf-tab.plugin.zsh"
source "$ZSH_PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh"

# zoxide smart cd initialization
eval "$(zoxide init zsh)"

# Starship owns the active two-line prompt; collapse only accepted, complete input.
eval "$(starship init zsh)"
typeset -g _full_prompt=$PROMPT _full_rprompt=$RPROMPT
_restore_prompt() {
    PROMPT=$_full_prompt
    RPROMPT=$_full_rprompt
    zle .reset-prompt
}
_accept_line() {
    if [[ $CONTEXT == start && -n ${BUFFER//[[:space:]]/} ]] &&
       printf '%s\n' "$BUFFER" | command zsh -fn 2>/dev/null; then
        # Render only the character module: no leading blank line in scrollback.
        # Status belongs to the previous command, just like the active prompt.
        PROMPT="$(starship module character --status="${STARSHIP_CMD_STATUS:-0}" --keymap="${KEYMAP:-main}")"
        RPROMPT=''
        zle .reset-prompt
    fi
    zle _original_accept_line
}
autoload -Uz add-zle-hook-widget
add-zle-hook-widget line-init _restore_prompt
# Preserve any existing accept-line wrapper; initialization is safe on reload.
if (( ! ${+_custom_transient_installed} )); then
    zle -A accept-line _original_accept_line
    zle -N accept-line _accept_line
    typeset -g _custom_transient_installed=1
fi

# terminal window title updates
if [[ "$TERM" == "xterm" || "$TERM" == "xterm-256color" || "$TERM_PROGRAM" == "vscode" ]]; then
    preexec() { print -Pn "\e]0;%n@%m: $1\a" }
    precmd() {
        local _status=$?
        print -Pn "\e]0;%n@%m: zsh\a"
        return $_status
    }
fi

# bootstrap:platform

# Interactive editing helpers. Saving in the editor returns for inspection.
autoload -Uz edit-command-line zmv
zle -N edit-command-line
bindkey '^X^E' edit-command-line
bindkey ' ' magic-space
bindkey '^_' undo
bindkey '^L' clear-screen
_copybuffer() { print -rn -- "$BUFFER" | pbcopy }
zle -N _copybuffer
bindkey '^X^C' _copybuffer

# Syntax highlighting must see all custom widgets.
source "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# source centralized aliases
source "$HOME/.config/zsh/aliases.sh"

# compile zsh configs and plugins to bytecode (.zwc) in background when newer than cache
{
  typeset _zfile
  for _zfile in \
    "$HOME/.zshrc" \
    "$ZSH_PLUGIN_DIR/fzf-tab/fzf-tab.plugin.zsh" \
    "$HOME/.config/zsh/aliases.sh" \
    "$HOME/.local/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" \
    "$HOME/.local/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"; do
    if [[ -f "$_zfile" && ( ! -f "${_zfile}.zwc" || "$_zfile" -nt "${_zfile}.zwc" ) ]]; then
      zcompile "$_zfile" 2>/dev/null
    fi
  done
} &!
