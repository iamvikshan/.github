# ==============================================================================
# universal zsh configuration (debian, alpine, macos, devcontainers)
# ==============================================================================

# path hierarchy
typeset -U path PATH
path=("$HOME/.local/bin" "$HOME/.bun/bin" $path)
export BUN_INSTALL="$HOME/.bun"

# devcontainer / codespaces first-run notice suppression
if [[ -t 1 && ("${TERM_PROGRAM}" == 'vscode' || "${TERM_PROGRAM}" == 'codespaces') && ! -f "$HOME/.config/vscode-dev-containers/first-run-notice-already-displayed" ]]; then
    if [[ -f '/usr/local/etc/vscode-dev-containers/first-run-notice.txt' ]]; then
        cat '/usr/local/etc/vscode-dev-containers/first-run-notice.txt'
    elif [[ -f '/workspaces/.codespaces/shared/first-run-notice.txt' ]]; then
        cat '/workspaces/.codespaces/shared/first-run-notice.txt'
    fi
    mkdir -p "$HOME/.config/vscode-dev-containers"
    (sleep 10s; touch "$HOME/.config/vscode-dev-containers/first-run-notice-already-displayed") &!
fi

# set vs code as git editor only when no editor is already configured
if [[ -z "${GIT_EDITOR}" && "${TERM_PROGRAM}" == 'vscode' ]] &&
   ! git config --get core.editor >/dev/null 2>&1; then
    if (( $+commands[code-insiders] )) && (( ! $+commands[code] )); then
        export GIT_EDITOR='code-insiders --wait'
    elif (( $+commands[code] )); then
        export GIT_EDITOR='code --wait'
    fi
fi

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

# load standalone zsh plugins
ZSH_PLUGIN_DIR="$HOME/.local/share/zsh/plugins"
[[ -f "$ZSH_PLUGIN_DIR/fzf-tab/fzf-tab.plugin.zsh" ]] && source "$ZSH_PLUGIN_DIR/fzf-tab/fzf-tab.plugin.zsh"
[[ -f "$ZSH_PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "$ZSH_PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh"
[[ -f "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && source "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# blood-obsidian autosuggestion tint
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#634F52'

# fzf + fd + bat integration with blood-obsidian palette
if (( $+commands[fzf] )); then
    export FZF_DEFAULT_OPTS=" \
        --height=50% --layout=reverse --border=rounded --margin=1 --padding=1 \
        --color=bg+:#291F21,bg:#141011,spinner:#D92638,hl:#FF4D5E \
        --color=fg:#DEC9CB,header:#8C787B,info:#B81D24,pointer:#D92638 \
        --color=marker:#6ECB86,fg+:#FFF5F6,prompt:#D92638,hl+:#FF4D5E \
        --color=border:#48393B"

    if (( $+commands[fd] )); then
        export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        export FZF_ALT_C_COMMAND='fd --type d --strip-cwd-prefix --hidden --follow --exclude .git'
    fi

    if (( $+commands[bat] )); then
        export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
        export BAT_THEME="ansi"
    fi

    if (( $+commands[eza] )); then
        export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --icons --color=always {}'"
        zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --icons --color=always $realpath'
    fi

    if fzf --zsh >/dev/null 2>&1; then
        source <(fzf --zsh)
    else
        for fzf_dir in /usr/share/doc/fzf/examples /usr/share/fzf; do
            [[ -f "$fzf_dir/completion.zsh" ]] && source "$fzf_dir/completion.zsh"
            [[ -f "$fzf_dir/key-bindings.zsh" ]] && source "$fzf_dir/key-bindings.zsh"
        done
    fi
fi

# zoxide smart cd initialization
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"

# starship async rust prompt
(( $+commands[starship] )) && eval "$(starship init zsh)"

# terminal window title updates
if [[ "$TERM" == "xterm" || "$TERM" == "xterm-256color" || "$TERM_PROGRAM" == "vscode" ]]; then
    preexec() { print -Pn "\e]0;%n@%m: $1\a" }
    precmd()  { print -Pn "\e]0;%n@%m: zsh\a" }
fi

# environment-aware clipboard (macos, wayland/cosmic, x11, and ssh/containers via osc 52)
if [[ "$(uname)" != "Darwin" ]]; then
    pbcopy() {
        if [[ -n "${WAYLAND_DISPLAY}" ]] && (( $+commands[wl-copy] )); then
            wl-copy
        elif [[ -n "${DISPLAY}" ]] && (( $+commands[xclip] )); then
            xclip -selection clipboard
        elif [[ -n "${DISPLAY}" ]] && (( $+commands[xsel] )); then
            xsel --clipboard --input
        else
            printf '\033]52;c;%s\a' "$(base64 | tr -d '\n')"
        fi
    }
fi

# source centralized aliases
[[ -f "$HOME/.config/zsh/aliases.sh" ]] && source "$HOME/.config/zsh/aliases.sh"

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
