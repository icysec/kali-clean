#!/usr/bin/env bash
# ============================================================================
#  kali-setup.sh — Fresh Kali Linux post-install provisioning script
#  Run as your normal user (script will sudo when needed).
#  Usage:  chmod +x kali-setup.sh && ./kali-setup.sh
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# ----------------------------------------------------------
#  Color helpers
# ----------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[*]${NC} $*"; }
success() { echo -e "${GREEN}[+]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[-]${NC} $*"; }

# ----------------------------------------------------------
#  Pre-flight checks
# ----------------------------------------------------------
if [[ "$EUID" -eq 0 ]]; then
    error "Do NOT run this script as root. Run as your normal user; it will sudo when needed."
    exit 1
fi

info "Starting Kali post-install setup..."
TOOLS_DIR="$HOME/Tools"
mkdir -p "$TOOLS_DIR"

# ----------------------------------------------------------
#  1. System update & kali-linux-everything
# ----------------------------------------------------------
section_apt() {
    info "Updating package lists..."
    sudo apt update -y

    info "Upgrading existing packages..."
    sudo apt full-upgrade -y

    if dpkg -l kali-linux-everything 2>/dev/null | grep -q '^ii'; then
        warn "kali-linux-everything already installed — skipping."
    else
        info "Installing kali-linux-everything metapackage (this will take a LONG time)..."
        sudo DEBIAN_FRONTEND=noninteractive apt install -y kali-linux-everything
        success "kali-linux-everything installed."
    fi
}

# ----------------------------------------------------------
#  2. APT tools (rlwrap, feroxbuster, ffuf)
# ----------------------------------------------------------
section_apt_tools() {
    local to_install=()
    for pkg in rlwrap feroxbuster ffuf; do
        if dpkg -l "$pkg" 2>/dev/null | grep -q '^ii'; then
            warn "$pkg already installed — skipping."
        else
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        info "Installing apt tools: ${to_install[*]}..."
        sudo apt install -y "${to_install[@]}"
        success "${to_install[*]} installed."
    else
        success "All apt tools already installed."
    fi
}

# ----------------------------------------------------------
#  3. Git-based tools → ~/Tools
# ----------------------------------------------------------
clone_or_pull() {
    local repo_url="$1"
    local dest="$2"
    if [[ -d "$dest/.git" ]]; then
        warn "$dest already exists — pulling latest..."
        git -C "$dest" pull --ff-only || true
    else
        git clone "$repo_url" "$dest"
    fi
}

section_git_tools() {
    info "Cloning tools into $TOOLS_DIR..."

    # ntlm_theft
    clone_or_pull "https://github.com/Greenwolf/ntlm_theft.git" "$TOOLS_DIR/ntlm_theft"
    # Install ntlm_theft Python dependencies if requirements exist
    if [[ -f "$TOOLS_DIR/ntlm_theft/requirements.txt" ]]; then
        pip3 install --break-system-packages -r "$TOOLS_DIR/ntlm_theft/requirements.txt" || true
    fi

    # Penelope
    clone_or_pull "https://github.com/brightio/penelope.git" "$TOOLS_DIR/penelope"

    # Toolies
    clone_or_pull "https://github.com/expl0itabl3/Toolies.git" "$TOOLS_DIR/Toolies"

    success "Git tools cloned to $TOOLS_DIR."
}

# ----------------------------------------------------------
#  4. Kerbrute — latest release binary
# ----------------------------------------------------------
section_kerbrute() {
    if [[ -x "$TOOLS_DIR/kerbrute" ]]; then
        warn "Kerbrute already exists at $TOOLS_DIR/kerbrute — skipping."
        return 0
    fi

    info "Fetching latest Kerbrute release..."

    local api_url="https://api.github.com/repos/ropnop/kerbrute/releases/latest"
    local download_url

    download_url=$(curl -fsSL "$api_url" \
        | grep -oP '"browser_download_url":\s*"\K[^"]*linux_amd64[^"]*' \
        | head -1)

    if [[ -z "$download_url" ]]; then
        warn "Could not auto-detect Kerbrute download URL. Trying fallback..."
        # Fallback: grab the latest release tag and construct URL
        local tag
        tag=$(curl -fsSL "$api_url" | grep -oP '"tag_name":\s*"\K[^"]*' | head -1)
        download_url="https://github.com/ropnop/kerbrute/releases/download/${tag}/kerbrute_linux_amd64"
    fi

    info "Downloading from: $download_url"
    curl -fsSL -o "$TOOLS_DIR/kerbrute" "$download_url"
    chmod +x "$TOOLS_DIR/kerbrute"

    success "Kerbrute binary saved to $TOOLS_DIR/kerbrute"
}

# ----------------------------------------------------------
#  4b. Ligolo-ng — proxy + agent binaries              [NEW]
# ----------------------------------------------------------
section_ligolo() {
    if [[ -d "$TOOLS_DIR/ligolo-ng" ]] && ls "$TOOLS_DIR"/ligolo-ng/*proxy* &>/dev/null; then
        warn "Ligolo-ng already exists at $TOOLS_DIR/ligolo-ng — skipping."
        return 0
    fi

    info "Fetching latest Ligolo-ng release..."

    local api_url="https://api.github.com/repos/nicocha30/ligolo-ng/releases/latest"
    local release_json
    release_json=$(curl -fsSL "$api_url")

    # Proxy (runs on your attack box)
    local proxy_url
    proxy_url=$(echo "$release_json" \
        | grep -oP '"browser_download_url":\s*"\K[^"]*proxy[^"]*linux_amd64[^"]*\.tar\.gz' \
        | head -1)

    # Agent (transfer to targets)
    local agent_url
    agent_url=$(echo "$release_json" \
        | grep -oP '"browser_download_url":\s*"\K[^"]*agent[^"]*linux_amd64[^"]*\.tar\.gz' \
        | head -1)

    mkdir -p "$TOOLS_DIR/ligolo-ng"

    if [[ -n "$proxy_url" ]]; then
        info "Downloading Ligolo-ng proxy from: $proxy_url"
        curl -fsSL "$proxy_url" | tar xz -C "$TOOLS_DIR/ligolo-ng"
    else
        warn "Could not auto-detect Ligolo-ng proxy URL."
    fi

    if [[ -n "$agent_url" ]]; then
        info "Downloading Ligolo-ng agent from: $agent_url"
        curl -fsSL "$agent_url" | tar xz -C "$TOOLS_DIR/ligolo-ng"
    else
        warn "Could not auto-detect Ligolo-ng agent URL."
    fi

    chmod +x "$TOOLS_DIR"/ligolo-ng/* 2>/dev/null || true

    success "Ligolo-ng saved to $TOOLS_DIR/ligolo-ng"
}

# ----------------------------------------------------------
#  5. Wezterm — via official APT repo
# ----------------------------------------------------------
section_wezterm() {
    if command -v wezterm &>/dev/null; then
        warn "WezTerm already installed ($(wezterm --version 2>/dev/null || echo 'version unknown')) — skipping."
        return 0
    fi

    info "Installing WezTerm via APT repo..."

    curl -fsSL https://apt.fury.io/wez/gpg.key \
        | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg

    echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' \
        | sudo tee /etc/apt/sources.list.d/wezterm.list > /dev/null

    sudo chmod 644 /usr/share/keyrings/wezterm-fury.gpg
    sudo apt update -y
    sudo apt install -y wezterm

    success "WezTerm installed."
}

# ----------------------------------------------------------
#  6. Starship prompt
# ----------------------------------------------------------
section_starship() {
    if command -v starship &>/dev/null; then
        warn "Starship already installed ($(starship --version 2>/dev/null | head -1)) — skipping."
        return 0
    fi

    info "Installing Starship prompt..."
    curl -fsSL https://starship.rs/install.sh | sh -s -- --yes
    success "Starship installed."
}

# ----------------------------------------------------------
#  7. Fonts — FiraCode Nerd Font + Roboto
# ----------------------------------------------------------
section_fonts() {
    local font_dir="$HOME/.local/share/fonts"

    # Check if FiraCode Nerd Font is already installed
    if fc-list | grep -qi "FiraCode.*Nerd" 2>/dev/null; then
        warn "FiraCode Nerd Font already installed — skipping font download."
    else
        info "Installing FiraCode Nerd Font..."
        mkdir -p "$font_dir"

        # FiraCode Nerd Font from ryanoasis/nerd-fonts
        local nf_api="https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest"
        local nf_url
        nf_url=$(curl -fsSL "$nf_api" \
            | grep -oP '"browser_download_url":\s*"\K[^"]*FiraCode\.zip[^"]*' \
            | head -1)

        if [[ -n "$nf_url" ]]; then
            local tmpzip
            tmpzip=$(mktemp /tmp/firacode-nf-XXXXXX.zip)
            info "Downloading FiraCode Nerd Font from: $nf_url"
            curl -fsSL -o "$tmpzip" "$nf_url"
            unzip -o "$tmpzip" -d "$font_dir/FiraCodeNerdFont" -x "*.md" "*.txt" "LICENSE*" "license*" || true
            rm -f "$tmpzip"
        else
            warn "Could not auto-detect FiraCode Nerd Font URL — installing from apt fallback."
            sudo apt install -y fonts-firacode || true
        fi
    fi

    # Roboto font (used in Wezterm window frame)
    if dpkg -l fonts-roboto 2>/dev/null | grep -q '^ii'; then
        warn "Roboto font already installed — skipping."
    else
        info "Installing Roboto font..."
        sudo apt install -y fonts-roboto
    fi

    # Refresh font cache
    fc-cache -fv > /dev/null 2>&1

    success "Fonts ready."
}

# ----------------------------------------------------------
#  8. Config files
# ----------------------------------------------------------
section_configs() {
    info "Writing configuration files..."

    # Helper: backs up existing file before overwriting
    backup_if_exists() {
        local file="$1"
        if [[ -f "$file" ]]; then
            local backup="${file}.bak.$(date +%Y%m%d_%H%M%S)"
            warn "$file already exists — backing up to $backup"
            cp "$file" "$backup"
        fi
    }

    # ---- 8a. ~/.zshrc ----
    backup_if_exists "$HOME/.zshrc"
    info "Writing ~/.zshrc..."
    cat > "$HOME/.zshrc" << 'ZSHRC_EOF'
# ~/.zshrc file for zsh interactive shells.
# see /usr/share/doc/zsh/examples/zshrc for examples

setopt autocd              # change directory just by typing its name
#setopt correct            # auto correct mistakes
setopt interactivecomments # allow comments in interactive mode
setopt magicequalsubst     # enable filename expansion for arguments of the form 'anything=expression'
setopt nonomatch           # hide error message if there is no match for the pattern
setopt notify              # report the status of background jobs immediately
setopt numericglobsort     # sort filenames numerically when it makes sense
setopt promptsubst         # enable command substitution in prompt

WORDCHARS='_-' # Don't consider certain characters part of the word

# hide EOL sign ('%')
PROMPT_EOL_MARK=""

# configure key keybindings
bindkey -e                                        # emacs key bindings
bindkey ' ' magic-space                           # do history expansion on space
bindkey '^U' backward-kill-line                   # ctrl + U
bindkey '^[[3;5~' kill-word                       # ctrl + Supr
bindkey '^[[3~' delete-char                       # delete
bindkey '^[[1;5C' forward-word                    # ctrl + ->
bindkey '^[[1;5D' backward-word                   # ctrl + <-
bindkey '^[[5~' beginning-of-buffer-or-history    # page up
bindkey '^[[6~' end-of-buffer-or-history          # page down
bindkey '^[[H' beginning-of-line                  # home
bindkey '^[[F' end-of-line                        # end
bindkey '^[[Z' undo                               # shift + tab undo last action

# enable completion features
autoload -Uz compinit
compinit -d ~/.cache/zcompdump
zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' rehash true
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

# History configurations
HISTFILE=~/.zsh_history
HISTSIZE=1000
SAVEHIST=2000
setopt hist_expire_dups_first # delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt hist_ignore_dups       # ignore duplicated commands history list
setopt hist_ignore_space      # ignore commands that start with space
setopt hist_verify            # show command with history expansion to user before running it
#setopt share_history         # share command history data

# force zsh to show the complete history
alias history="history 0"

# configure `time` format
TIMEFMT=$'\nreal\t%E\nuser\t%U\nsys\t%S\ncpu\t%P'

# make less more friendly for non-text input files, see lesspipe(1)
#[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        # We have color support; assume it's compliant with Ecma-48
        # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
        # a case would tend to support setf rather than setaf.)
        color_prompt=yes
    else
        color_prompt=
    fi
fi

configure_prompt() {
    prompt_symbol=㉿
    # Skull emoji for root terminal
    #[ "$EUID" -eq 0 ] && prompt_symbol=💀
    case "$PROMPT_ALTERNATIVE" in
        twoline)
            PROMPT=$'%F{%(#.blue.green)}┌──${debian_chroot:+($debian_chroot)─}${VIRTUAL_ENV:+($(basename $VIRTUAL_ENV))─}(%B%F{%(#.red.blue)}%n'$prompt_symbol$'%m%b%F{%(#.blue.green)})-[%B%F{reset}%(6~.%-1~/…/%4~.%5~)%b%F{%(#.blue.green)}]\n└─%B%(#.%F{red}#.%F{blue}$)%b%F{reset} '
            # Right-side prompt with exit codes and background processes
            #RPROMPT=$'%(?.. %? %F{red}%B⨯%b%F{reset})%(1j. %j %F{yellow}%B⚙%b%F{reset}.)'
            ;;
        oneline)
            PROMPT=$'${debian_chroot:+($debian_chroot)}${VIRTUAL_ENV:+($(basename $VIRTUAL_ENV))}%B%F{%(#.red.blue)}%n@%m%b%F{reset}:%B%F{%(#.blue.green)}%~%b%F{reset}%(#.#.$) '
            RPROMPT=
            ;;
        backtrack)
            PROMPT=$'${debian_chroot:+($debian_chroot)}${VIRTUAL_ENV:+($(basename $VIRTUAL_ENV))}%B%F{red}%n@%m%b%F{reset}:%B%F{blue}%~%b%F{reset}%(#.#.$) '
            RPROMPT=
            ;;
    esac
    unset prompt_symbol
}

# The following block is surrounded by two delimiters.
# These delimiters must not be modified. Thanks.
# START KALI CONFIG VARIABLES
PROMPT_ALTERNATIVE='backtrack'
NEWLINE_BEFORE_PROMPT='yes'
# STOP KALI CONFIG VARIABLES

if [ "$color_prompt" = yes ]; then
    # override default virtualenv indicator in prompt
    VIRTUAL_ENV_DISABLE_PROMPT=1

    configure_prompt

    # enable syntax-highlighting
    if [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
        . /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
        ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)
        ZSH_HIGHLIGHT_STYLES[default]=none
        ZSH_HIGHLIGHT_STYLES[unknown-token]=underline
        ZSH_HIGHLIGHT_STYLES[reserved-word]=fg=cyan,bold
        ZSH_HIGHLIGHT_STYLES[suffix-alias]=fg=green,underline
        ZSH_HIGHLIGHT_STYLES[global-alias]=fg=green,bold
        ZSH_HIGHLIGHT_STYLES[precommand]=fg=green,underline
        ZSH_HIGHLIGHT_STYLES[commandseparator]=fg=blue,bold
        ZSH_HIGHLIGHT_STYLES[autodirectory]=fg=green,underline
        ZSH_HIGHLIGHT_STYLES[path]=bold
        ZSH_HIGHLIGHT_STYLES[path_pathseparator]=
        ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]=
        ZSH_HIGHLIGHT_STYLES[globbing]=fg=blue,bold
        ZSH_HIGHLIGHT_STYLES[history-expansion]=fg=blue,bold
        ZSH_HIGHLIGHT_STYLES[command-substitution]=none
        ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]=fg=magenta,bold
        ZSH_HIGHLIGHT_STYLES[process-substitution]=none
        ZSH_HIGHLIGHT_STYLES[process-substitution-delimiter]=fg=magenta,bold
        ZSH_HIGHLIGHT_STYLES[single-hyphen-option]=fg=green
        ZSH_HIGHLIGHT_STYLES[double-hyphen-option]=fg=green
        ZSH_HIGHLIGHT_STYLES[back-quoted-argument]=none
        ZSH_HIGHLIGHT_STYLES[back-quoted-argument-delimiter]=fg=blue,bold
        ZSH_HIGHLIGHT_STYLES[single-quoted-argument]=fg=yellow
        ZSH_HIGHLIGHT_STYLES[double-quoted-argument]=fg=yellow
        ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]=fg=yellow
        ZSH_HIGHLIGHT_STYLES[rc-quote]=fg=magenta
        ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]=fg=magenta,bold
        ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]=fg=magenta,bold
        ZSH_HIGHLIGHT_STYLES[back-dollar-quoted-argument]=fg=magenta,bold
        ZSH_HIGHLIGHT_STYLES[assign]=none
        ZSH_HIGHLIGHT_STYLES[redirection]=fg=blue,bold
        ZSH_HIGHLIGHT_STYLES[comment]=fg=black,bold
        ZSH_HIGHLIGHT_STYLES[named-fd]=none
        ZSH_HIGHLIGHT_STYLES[numeric-fd]=none
        ZSH_HIGHLIGHT_STYLES[arg0]=fg=cyan
        ZSH_HIGHLIGHT_STYLES[bracket-error]=fg=red,bold
        ZSH_HIGHLIGHT_STYLES[bracket-level-1]=fg=blue,bold
        ZSH_HIGHLIGHT_STYLES[bracket-level-2]=fg=green,bold
        ZSH_HIGHLIGHT_STYLES[bracket-level-3]=fg=magenta,bold
        ZSH_HIGHLIGHT_STYLES[bracket-level-4]=fg=yellow,bold
        ZSH_HIGHLIGHT_STYLES[bracket-level-5]=fg=cyan,bold
        ZSH_HIGHLIGHT_STYLES[cursor-matchingbracket]=standout
    fi
else
    PROMPT='${debian_chroot:+($debian_chroot)}%n@%m:%~%(#.#.$) '
fi
unset color_prompt force_color_prompt

toggle_oneline_prompt(){
    if [ "$PROMPT_ALTERNATIVE" = oneline ]; then
        PROMPT_ALTERNATIVE=twoline
    else
        PROMPT_ALTERNATIVE=oneline
    fi
    configure_prompt
    zle reset-prompt
}
zle -N toggle_oneline_prompt
bindkey ^P toggle_oneline_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*|Eterm|aterm|kterm|gnome*|alacritty)
    TERM_TITLE=$'\e]0;${debian_chroot:+($debian_chroot)}${VIRTUAL_ENV:+($(basename $VIRTUAL_ENV))}%n@%m: %~\a'
    ;;
*)
    ;;
esac

precmd() {
    # Print the previously configured title
    print -Pnr -- "$TERM_TITLE"

    # Print a new line before the prompt, but only if it is not the first line
    if [ "$NEWLINE_BEFORE_PROMPT" = yes ]; then
        if [ -z "$_NEW_LINE_BEFORE_PROMPT" ]; then
            _NEW_LINE_BEFORE_PROMPT=1
        else
            print ""
        fi
    fi
}

# enable color support of ls, less and man, and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    export LS_COLORS="$LS_COLORS:ow=30;44:" # fix ls color for folders with 777 permissions

    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
    alias diff='diff --color=auto'
    alias ip='ip --color=auto'

    export LESS_TERMCAP_mb=$'\E[1;31m'     # begin blink
    export LESS_TERMCAP_md=$'\E[1;36m'     # begin bold
    export LESS_TERMCAP_me=$'\E[0m'        # reset bold/blink
    export LESS_TERMCAP_so=$'\E[01;33m'    # begin reverse video
    export LESS_TERMCAP_se=$'\E[0m'        # reset reverse video
    export LESS_TERMCAP_us=$'\E[1;32m'     # begin underline
    export LESS_TERMCAP_ue=$'\E[0m'        # reset underline

    # Take advantage of $LS_COLORS for completion as well
    zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
    zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
fi

# some more ls aliases
alias ll='ls -l'
alias la='ls -A'
alias l='ls -CF'

# enable auto-suggestions based on the history
if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    . /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    # change suggestion color
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=244'
fi

# enable command-not-found if installed
if [ -f /etc/zsh_command_not_found ]; then
    . /etc/zsh_command_not_found
fi
eval "$(starship init zsh)"
ZSHRC_EOF
    success "~/.zshrc written."

    # ---- 8b. ~/.wezterm.lua ----
    backup_if_exists "$HOME/.wezterm.lua"
    info "Writing ~/.wezterm.lua..."
    cat > "$HOME/.wezterm.lua" << 'WEZTERM_EOF'
-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()

--- Insert Customization Below ---

-- Color Scheme
config.color_scheme = 'Tokyo Night'
config.window_background_opacity = 1

-- Fonts
config.font_size = 10
config.font = wezterm.font 'FiraCode Nerd Font'

-- Window
config.initial_cols = 120
config.initial_rows = 28
config.window_frame = {
        font = wezterm.font 'Roboto',
        font_size = 12,
        active_titlebar_bg = '#1a1b26',
        inactive_titlebar_bg = '#1a1b26'
}
config.colors = {
  tab_bar = {
    -- The color of the inactive tab bar edge/divider
    inactive_tab_edge = '#1a1b26',
        active_tab = {
                bg_color = '#1d2230',
                fg_color = '#c0c0c0',
        },
        inactive_tab = {
                bg_color = '#1a1b26',
                fg_color = '#808080',
        },
        inactive_tab_hover = {
                bg_color = '#24283b',
                fg_color = '#909090',

        },
        new_tab = {
                bg_color = '#1a1b26',
                fg_color = '#808080',
        },
        new_tab_hover = {
                bg_color = '#1d2230',
                fg_color = '#909090'
        },
  },
}

--- Insert Customization Above ---

-- Building Config -- Keep at Bottom
return config
WEZTERM_EOF
    success "~/.wezterm.lua written."


    # ---- 8c. ~/.config/starship.toml ----
    backup_if_exists "$HOME/.config/starship.toml"
    info "Writing ~/.config/starship.toml..."
    mkdir -p "$HOME/.config"

    # Write config with placeholders (PUA Unicode chars can't survive heredocs)
    cat > "$HOME/.config/starship.toml" << 'STARSHIP_EOF'
"$schema" = 'https://starship.rs/config-schema.json'

format = """
[__GRAD1____GRAD2____GRAD3__](#a3aed2)\
[ icysec](bg:#a3aed2 fg:#090c0c)\
[__RSEP__](bg:#769ff0 fg:#a3aed2)\
$directory\
[__RSEP__](fg:#769ff0 bg:#394260)\
$git_branch\
$git_status\
[__RSEP__](fg:#394260 bg:#212736)\
$python\
$nodejs\
$rust\
$golang\
$php\
[__RSEP__](fg:#212736 bg:#1d2230)\
$cmd_duration\
${custom.timeicon}\
$time\
[__RSEP__](fg:#1d2230)\
\n   $username$hostname$character"""

[directory]
style = "fg:#090c0c bg:#769ff0"
format = "[ $path ]($style)"
truncation_length = 3
truncation_symbol = "__DOTS__/"

[directory.substitutions]
"Engagements" = "__TARGET__ Engagements"
"Tools" = "__WRENCH__ Tools"
"wordlists" = "__BOOK__ wordlists"
"Documents" = "__DOC__ Documents"
"Downloads" = "__INBOX__ Downloads"

[git_branch]
symbol = "__GITICON__"
style = "bg:#394260"
format = '[[ $symbol $branch ](fg:#769ff0 bg:#394260)]($style)'

[git_status]
style = "bg:#394260"
format = '[[$all_status$ahead_behind ](fg:#769ff0 bg:#394260)]($style)'

[python]
symbol = "__PYICON__"
style = "bg:#212736"
format = '[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)'

[nodejs]
symbol = "__NODEICON__"
style = "bg:#212736"
format = '[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)'

[rust]
symbol = "__RUSTICON__"
style = "bg:#212736"
format = '[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)'

[golang]
symbol = "__GOICON__"
style = "bg:#212736"
format = '[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)'

[php]
symbol = "__PHPICON__"
style = "bg:#212736"
format = '[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)'

[cmd_duration]
min_time = 2_000
style = "bg:#1d2230"
format = '[[ __STOPWATCH__ $duration ](fg:#f7768e bg:#1d2230)]($style)'

[custom.timeicon]
command = 'h=$(date +%-H); if [ "$h" -ge 6 ] && [ "$h" -lt 12 ]; then printf "\xe2\x98\x80\xef\xb8\x8f"; elif [ "$h" -ge 12 ] && [ "$h" -lt 18 ]; then printf "\xf0\x9f\x8c\xa4\xef\xb8\x8f"; elif [ "$h" -ge 18 ] && [ "$h" -lt 21 ]; then printf "\xf0\x9f\x8c\x86"; else printf "\xf0\x9f\x8c\x99"; fi'
when = true
shell = ["bash", "--noprofile", "--norc"]
style = "bg:#1d2230"
format = '[[ $output](fg:#a0a9cb bg:#1d2230)]($style)'

[time]
disabled = false
time_format = "%H:%M"
style = "bg:#1d2230"
format = '[[ __CLOCK__ $time ](fg:#a0a9cb bg:#1d2230)]($style)'

[username]
show_always = false
style_user = "fg:#769ff0"
style_root = "fg:#ff0000 bold"
format = '[$user]($style)'

[hostname]
ssh_only = true
style = "fg:#769ff0"
format = '[@$hostname ]($style)'

[character]
success_symbol = '[__PROMPT__](#769ff0)'
error_symbol = '[__PROMPT__](#f7768e)'
STARSHIP_EOF

    # Replace placeholders with actual Unicode glyphs (PUA chars don't survive heredocs)
    python3 -c "
import sys
replacements = {
    '__RSEP__':      '\ue0b4',   # Rounded right powerline separator
    '__GRAD1__':     '\u2591',   # Light shade
    '__GRAD2__':     '\u2592',   # Medium shade
    '__GRAD3__':     '\u2593',   # Dark shade
    '__DOTS__':      '\u2026',   # Ellipsis
    '__GITICON__':   '\ue0a0',   # Git branch (powerline)
    '__PYICON__':    '\ue73c',   # Python (nerd font)
    '__NODEICON__':  '\ue718',   # Node.js (nerd font)
    '__RUSTICON__':  '\ue7a8',   # Rust (nerd font)
    '__GOICON__':    '\ue627',   # Go (nerd font)
    '__PHPICON__':   '\ue73d',   # PHP (nerd font)
    '__CLOCK__':     '\uf43a',   # Clock icon (nerd font)
    '__STOPWATCH__': '\u23f1',   # Stopwatch emoji
    '__PROMPT__':    '\u276f',   # Heavy right-pointing angle bracket
    '__TARGET__':    '\U0001f3af', # Target emoji
    '__WRENCH__':    '\U0001f527', # Wrench emoji
    '__BOOK__':      '\U0001f4d6', # Open book emoji
    '__DOC__':       '\U0001f4c4', # Document emoji
    '__INBOX__':     '\U0001f4e5', # Inbox tray emoji
}
path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()
for placeholder, char in replacements.items():
    content = content.replace(placeholder, char)
with open(path, 'w') as f:
    f.write(content)
" "$HOME/.config/starship.toml"

    success "~/.config/starship.toml written."

    # ---- 8d. ~/.tmux.conf ----                          [NEW]
    backup_if_exists "$HOME/.tmux.conf"
    info "Writing ~/.tmux.conf..."
    cat > "$HOME/.tmux.conf" << 'TMUX_EOF'
# ---------------------------------------------------
#  tmux config — pentesting-friendly defaults
# ---------------------------------------------------

# Remap prefix from C-b to C-a (easier one-hand reach)
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# Enable mouse (scroll, resize panes, click to select)
set -g mouse on

# 256-color + true color support
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"

# Start window/pane numbering at 1 (matches keyboard layout)
set -g base-index 1
setw -g pane-base-index 1

# Renumber windows when one is closed
set -g renumber-windows on

# Increase scrollback buffer (useful for long scan output)
set -g history-limit 50000

# Faster escape time (no lag in vim/zsh)
set -sg escape-time 10

# Split panes with | and - (more intuitive)
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %

# New windows open in current directory
bind c new-window -c "#{pane_current_path}"

# Reload config with prefix + r
bind r source-file ~/.tmux.conf \; display "Config reloaded"

# Status bar styling (Tokyo Night-ish to match Wezterm)
set -g status-style "bg=#1a1b26,fg=#a9b1d6"
set -g status-left "#[fg=#090c0c,bg=#a3aed2,bold] #S #[fg=#a3aed2,bg=#1a1b26] "
set -g status-right "#[fg=#394260]#[fg=#769ff0,bg=#394260] %H:%M #[fg=#a3aed2,bg=#394260]#[fg=#090c0c,bg=#a3aed2,bold] #H "
set -g status-left-length 30
setw -g window-status-format "#[fg=#808080] #I:#W "
setw -g window-status-current-format "#[fg=#769ff0,bold] #I:#W "
TMUX_EOF
    success "~/.tmux.conf written."
}

# ----------------------------------------------------------
#  9. Add ~/Tools to PATH (idempotent)
# ----------------------------------------------------------
section_path() {
    info "Ensuring ~/Tools is on PATH..."
    local path_line='export PATH="$HOME/Tools:$PATH"'
    if ! grep -qF 'export PATH="$HOME/Tools:$PATH"' "$HOME/.zshrc"; then
        echo "" >> "$HOME/.zshrc"
        echo "# Add ~/Tools to PATH" >> "$HOME/.zshrc"
        echo "$path_line" >> "$HOME/.zshrc"
        success "~/Tools added to PATH in .zshrc."
    else
        warn "~/Tools PATH entry already present — skipping."
    fi
}

# ----------------------------------------------------------
#  9b. Wordlist symlinks                                [NEW]
# ----------------------------------------------------------
section_wordlist_symlinks() {
    info "Creating wordlist symlinks..."

    local wl_dir="$HOME/wordlists"
    mkdir -p "$wl_dir"

    # Symlink seclists if present
    if [[ -d /usr/share/seclists ]]; then
        ln -sfn /usr/share/seclists "$wl_dir/seclists"
        success "Symlinked /usr/share/seclists → ~/wordlists/seclists"
    else
        warn "/usr/share/seclists not found — will be available after kali-linux-everything finishes."
    fi

    # Symlink default wordlists
    if [[ -d /usr/share/wordlists ]]; then
        ln -sfn /usr/share/wordlists "$wl_dir/default"
        success "Symlinked /usr/share/wordlists → ~/wordlists/default"
    else
        warn "/usr/share/wordlists not found."
    fi
}

# ----------------------------------------------------------
#  9c. Engagement scaffolding function in .zshrc        [NEW]
# ----------------------------------------------------------
section_engagement_alias() {
    info "Adding newengagement function to .zshrc..."

    if ! grep -qF 'newengagement()' "$HOME/.zshrc"; then
        cat >> "$HOME/.zshrc" << 'ENGAGE_EOF'

# Engagement scaffolding — creates a standard directory structure
newengagement() {
    if [[ -z "${1:-}" ]]; then
        echo "Usage: newengagement <client-name>"
        return 1
    fi
    local base="$HOME/Engagements/$1"
    if [[ -d "$base" ]]; then
        echo "[!] $base already exists."
        return 1
    fi
    mkdir -p "$base"/{nmap,bloodhound,loot,notes,screenshots,web,ad,creds,reports}
    echo "# $1 — Engagement Notes" > "$base/notes/README.md"
    echo "[+] Created engagement workspace at $base"
    cd "$base" || return
}
ENGAGE_EOF
        success "newengagement() function added to .zshrc."
    else
        warn "newengagement() already present — skipping."
    fi
}

# ----------------------------------------------------------
#  9d. Tool symlinks & shortcuts                        [NEW]
# ----------------------------------------------------------
section_tool_symlinks() {
    info "Creating tool symlinks..."

    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"

    # Penelope — symlink penelope.py → ~/.local/bin/penelope
    if [[ -f "$TOOLS_DIR/penelope/penelope.py" ]]; then
        chmod +x "$TOOLS_DIR/penelope/penelope.py"
        ln -sfn "$TOOLS_DIR/penelope/penelope.py" "$bin_dir/penelope"
        success "penelope → ~/.local/bin/penelope"
    else
        warn "penelope.py not found — skipping symlink."
    fi

    # ntlm_theft — symlink ntlm_theft.py → ~/.local/bin/ntlm_theft
    if [[ -f "$TOOLS_DIR/ntlm_theft/ntlm_theft.py" ]]; then
        chmod +x "$TOOLS_DIR/ntlm_theft/ntlm_theft.py"
        ln -sfn "$TOOLS_DIR/ntlm_theft/ntlm_theft.py" "$bin_dir/ntlm_theft"
        success "ntlm_theft → ~/.local/bin/ntlm_theft"
    else
        warn "ntlm_theft.py not found — skipping symlink."
    fi

    # Ligolo-ng — symlink versioned binaries to clean names
    if [[ -d "$TOOLS_DIR/ligolo-ng" ]]; then
        local proxy_bin agent_bin
        proxy_bin=$(find "$TOOLS_DIR/ligolo-ng" -maxdepth 1 -name '*proxy*' -type f 2>/dev/null | head -1)
        agent_bin=$(find "$TOOLS_DIR/ligolo-ng" -maxdepth 1 -name '*agent*' -type f 2>/dev/null | head -1)

        if [[ -n "$proxy_bin" ]]; then
            ln -sfn "$proxy_bin" "$bin_dir/ligolo-proxy"
            success "$(basename "$proxy_bin") → ~/.local/bin/ligolo-proxy"
        fi
        if [[ -n "$agent_bin" ]]; then
            ln -sfn "$agent_bin" "$bin_dir/ligolo-agent"
            success "$(basename "$agent_bin") → ~/.local/bin/ligolo-agent"
        fi
    else
        warn "Ligolo-ng directory not found — skipping symlinks."
    fi

    # Ensure ~/.local/bin is on PATH (idempotent)
    if ! grep -qF 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.zshrc"; then
        echo "" >> "$HOME/.zshrc"
        echo "# Add ~/.local/bin to PATH (tool symlinks)" >> "$HOME/.zshrc"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
        success "~/.local/bin added to PATH in .zshrc."
    fi

    # Toolies — quick-access alias (it's a collection, not a single tool)
    if ! grep -qF 'alias toolies=' "$HOME/.zshrc"; then
        echo "" >> "$HOME/.zshrc"
        echo "# Quick-access alias for Toolies collection" >> "$HOME/.zshrc"
        echo "alias toolies='ls -la \$HOME/Tools/Toolies/'" >> "$HOME/.zshrc"
        success "alias 'toolies' added to .zshrc (lists ~/Tools/Toolies contents)."
    else
        warn "toolies alias already present — skipping."
    fi

    success "Tool symlinks configured."
}

# ----------------------------------------------------------
#  10. Cleanup
# ----------------------------------------------------------
section_cleanup() {
    info "Cleaning up apt cache..."
    sudo apt autoremove -y
    sudo apt autoclean -y
    success "Cleanup done."
}

# ============================================================================
#  Main — run all sections in order
# ============================================================================
main() {
    section_apt
    section_apt_tools
    section_git_tools
    section_kerbrute
    section_ligolo
    section_wezterm
    section_starship
    section_fonts
    section_configs
    section_path
    section_wordlist_symlinks
    section_engagement_alias
    section_tool_symlinks
    section_cleanup

    echo ""
    success "========================================="
    success "  Kali setup complete!"
    success "========================================="
    echo ""
    info "Summary:"
    info "  • kali-linux-everything installed"
    info "  • Tools cloned to ~/Tools (ntlm_theft, penelope, Toolies)"
    info "  • Kerbrute binary in ~/Tools/kerbrute"
    info "  • Ligolo-ng proxy + agent in ~/Tools/ligolo-ng"
    info "  • rlwrap, feroxbuster, ffuf installed via apt"
    info "  • WezTerm installed (config at ~/.wezterm.lua)"
    info "  • Starship installed (config at ~/.config/starship.toml)"
    info "  • FiraCode Nerd Font + Roboto installed"
    info "  • ~/.zshrc configured with Starship init"
    info "  • ~/.tmux.conf written (C-a prefix, mouse, Tokyo Night status bar)"
    info "  • ~/Tools added to PATH"
    info "  • ~/wordlists symlinks created (seclists, default)"
    info "  • newengagement <name> function available in zsh"
    echo ""
    info "Tool shortcuts (via ~/.local/bin):"
    info "  • penelope       → ~/Tools/penelope/penelope.py"
    info "  • ntlm_theft     → ~/Tools/ntlm_theft/ntlm_theft.py"
    info "  • ligolo-proxy   → ~/Tools/ligolo-ng/proxy binary"
    info "  • ligolo-agent   → ~/Tools/ligolo-ng/agent binary"
    info "  • kerbrute       → ~/Tools/kerbrute (via PATH)"
    info "  • toolies        → alias, lists ~/Tools/Toolies/"
    echo ""
    warn "Restart your terminal (or run 'source ~/.zshrc') to apply changes."
}

main "$@"
