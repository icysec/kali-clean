#!/usr/bin/env bash
# ============================================================================
#  kali-setup.sh — Fresh Kali Linux post-install provisioning script
#  Run as your normal user (script will sudo when needed).
#
#  Usage:
#    ./kali-setup.sh                 Full install (packages, tools, configs)
#    ./kali-setup.sh --reset-configs Rewrite all config files to defaults
#    ./kali-setup.sh --help          Show this help
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
#  Usage
# ----------------------------------------------------------
usage() {
    echo ""
    echo "Usage: $(basename "$0") [OPTION]"
    echo ""
    echo "  (no flag)         Full install — packages, tools, configs, fonts"
    echo "  --reset-configs   Rewrite shell/terminal configs to defaults"
    echo "                    Restores: .zshrc, .wezterm.lua, starship.toml,"
    echo "                    .tmux.conf, PATH, aliases, and tool symlinks"
    echo "  --help            Show this help"
    echo ""
    exit 0
}

# ----------------------------------------------------------
#  Pre-flight checks
# ----------------------------------------------------------
if [[ "$EUID" -eq 0 ]]; then
    error "Do NOT run this script as root. Run as your normal user; it will sudo when needed."
    exit 1
fi

TOOLS_DIR="$HOME/Tools"
mkdir -p "$TOOLS_DIR"/{AD,Shells,Windows,Pivoting,Web,Recon,Exploits,Wordlists}

# ----------------------------------------------------------
#  0. Migrate tools from old flat layout to categorized
# ----------------------------------------------------------
migrate_if_exists() {
    local src="$1"
    local dest="$2"
    if [[ -e "$src" ]] && [[ ! -e "$dest" ]]; then
        info "Migrating $(basename "$src") → $dest"
        mv "$src" "$dest"
        success "Moved $(basename "$src") to categorized directory."
    fi
}

# Migrate from old ~/Tools/<tool> to ~/Tools/<category>/<tool>
migrate_if_exists "$TOOLS_DIR/ntlm_theft"   "$TOOLS_DIR/AD/ntlm_theft"
migrate_if_exists "$TOOLS_DIR/kerbrute"     "$TOOLS_DIR/AD/kerbrute"
migrate_if_exists "$TOOLS_DIR/penelope"     "$TOOLS_DIR/Shells/penelope"
migrate_if_exists "$TOOLS_DIR/Toolies"      "$TOOLS_DIR/Windows/Toolies"
migrate_if_exists "$TOOLS_DIR/ligolo-ng"    "$TOOLS_DIR/Pivoting/ligolo-ng"

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
#  2. APT tools
# ----------------------------------------------------------
section_apt_tools() {
    local all_pkgs=(rlwrap feroxbuster ffuf fzf zoxide bat eza ripgrep xclip mousepad arc-theme broot)
    local to_install=()
    local already=()

    for pkg in "${all_pkgs[@]}"; do
        if dpkg -l "$pkg" 2>/dev/null | grep -q '^ii'; then
            already+=("$pkg")
        else
            to_install+=("$pkg")
        fi
    done

    if [[ ${#already[@]} -gt 0 ]]; then
        info "${#already[@]}/${#all_pkgs[@]} packages already installed — skipping."
    fi

    if [[ ${#to_install[@]} -gt 0 ]]; then
        info "Installing ${#to_install[@]} packages: ${to_install[*]}..."
        sudo apt install -y "${to_install[@]}"
        success "Packages installed."
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
    info "Cloning tools into $TOOLS_DIR (categorized)..."

    # ntlm_theft → AD
    clone_or_pull "https://github.com/Greenwolf/ntlm_theft.git" "$TOOLS_DIR/AD/ntlm_theft"
    # Install ntlm_theft Python dependencies if requirements exist
    if [[ -f "$TOOLS_DIR/AD/ntlm_theft/requirements.txt" ]]; then
        pip3 install --break-system-packages -r "$TOOLS_DIR/AD/ntlm_theft/requirements.txt" || true
    fi

    # Penelope → Shells
    clone_or_pull "https://github.com/brightio/penelope.git" "$TOOLS_DIR/Shells/penelope"

    # Toolies → Windows
    clone_or_pull "https://github.com/expl0itabl3/Toolies.git" "$TOOLS_DIR/Windows/Toolies"

    success "Git tools cloned to $TOOLS_DIR."
}

# ----------------------------------------------------------
#  4. Kerbrute — latest release binary
# ----------------------------------------------------------
section_kerbrute() {
    if [[ -x "$TOOLS_DIR/AD/kerbrute" ]]; then
        warn "Kerbrute already exists at $TOOLS_DIR/AD/kerbrute — skipping."
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
    curl -fsSL -o "$TOOLS_DIR/AD/kerbrute" "$download_url"
    chmod +x "$TOOLS_DIR/AD/kerbrute"

    success "Kerbrute binary saved to $TOOLS_DIR/AD/kerbrute"
}

# ----------------------------------------------------------
#  4b. Ligolo-ng — proxy + agent binaries              [NEW]
# ----------------------------------------------------------
section_ligolo() {
    if [[ -d "$TOOLS_DIR/Pivoting/ligolo-ng" ]] && ls "$TOOLS_DIR"/Pivoting/ligolo-ng/*proxy* &>/dev/null; then
        warn "Ligolo-ng already exists at $TOOLS_DIR/Pivoting/ligolo-ng — skipping."
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

    mkdir -p "$TOOLS_DIR/Pivoting/ligolo-ng"

    if [[ -n "$proxy_url" ]]; then
        info "Downloading Ligolo-ng proxy from: $proxy_url"
        curl -fsSL "$proxy_url" | tar xz -C "$TOOLS_DIR/Pivoting/ligolo-ng"
    else
        warn "Could not auto-detect Ligolo-ng proxy URL."
    fi

    if [[ -n "$agent_url" ]]; then
        info "Downloading Ligolo-ng agent from: $agent_url"
        curl -fsSL "$agent_url" | tar xz -C "$TOOLS_DIR/Pivoting/ligolo-ng"
    else
        warn "Could not auto-detect Ligolo-ng agent URL."
    fi

    chmod +x "$TOOLS_DIR"/Pivoting/ligolo-ng/* 2>/dev/null || true

    success "Ligolo-ng saved to $TOOLS_DIR/Pivoting/ligolo-ng"
}

# ----------------------------------------------------------
#  4c. Recon tools (Go binaries) → ~/Tools/Recon
# ----------------------------------------------------------
# Helper: download latest Go binary from GitHub releases
install_go_release() {
    local name="$1"
    local repo="$2"
    local match="$3"
    local dest="$4"

    if [[ -x "$dest/$name" ]]; then
        warn "$name already exists — skipping."
        return 0
    fi

    info "Fetching latest $name release..."
    local api_url="https://api.github.com/repos/$repo/releases/latest"
    local download_url
    download_url=$(curl -fsSL "$api_url" \
        | grep -oP '"browser_download_url":\s*"\K[^"]*'"$match"'[^"]*' \
        | head -1)

    if [[ -z "$download_url" ]]; then
        warn "Could not find $name release binary — skipping."
        return 1
    fi

    info "Downloading $name from: $download_url"
    local tmpfile
    tmpfile=$(mktemp /tmp/${name}-XXXXXX)

    if [[ "$download_url" == *.zip ]]; then
        curl -fsSL -o "${tmpfile}.zip" "$download_url"
        unzip -o "${tmpfile}.zip" -d "$dest" "$name" 2>/dev/null || \
        unzip -o "${tmpfile}.zip" -d "$dest" 2>/dev/null
        rm -f "${tmpfile}.zip"
    elif [[ "$download_url" == *.tar.gz || "$download_url" == *.tgz ]]; then
        curl -fsSL "$download_url" | tar xz -C "$dest"
    else
        curl -fsSL -o "$dest/$name" "$download_url"
    fi

    chmod +x "$dest/$name" 2>/dev/null || true
    success "$name installed to $dest"
}

section_recon_tools() {
    info "Installing recon tools to $TOOLS_DIR/Recon..."
    local dest="$TOOLS_DIR/Recon"

    # katana — web crawler/spider (ProjectDiscovery)
    install_go_release "katana" \
        "projectdiscovery/katana" \
        "linux_amd64" \
        "$dest"

    # gau — Get All URLs from Wayback/Common Crawl/OTX
    install_go_release "gau" \
        "lc/gau" \
        "linux_amd64" \
        "$dest"

    # waybackurls — fetch historical URLs from Wayback Machine
    install_go_release "waybackurls" \
        "tomnomnom/waybackurls" \
        "linux-amd64" \
        "$dest"

    # qsreplace — replace query string values in URL lists
    install_go_release "qsreplace" \
        "tomnomnom/qsreplace" \
        "linux-amd64" \
        "$dest"

    success "Recon tools installed."
}

# ----------------------------------------------------------
#  4d. Web tools (Python/Go) → ~/Tools/Web
# ----------------------------------------------------------
section_web_tools() {
    info "Installing web testing tools to $TOOLS_DIR/Web..."
    local dest="$TOOLS_DIR/Web"

    # ParamSpider — mine parameters from web archives
    clone_or_pull "https://github.com/devanshbatham/ParamSpider.git" "$dest/ParamSpider"
    if [[ -f "$dest/ParamSpider/requirements.txt" ]]; then
        pip3 install --break-system-packages -r "$dest/ParamSpider/requirements.txt" 2>/dev/null || true
    fi

    # Arjun — HTTP parameter discovery
    clone_or_pull "https://github.com/s0md3v/Arjun.git" "$dest/Arjun"
    if [[ -f "$dest/Arjun/setup.py" ]]; then
        pip3 install --break-system-packages -e "$dest/Arjun" 2>/dev/null || true
    fi

    # SecretFinder — find secrets/API keys in JavaScript
    clone_or_pull "https://github.com/m4ll0k/SecretFinder.git" "$dest/SecretFinder"
    if [[ -f "$dest/SecretFinder/requirements.txt" ]]; then
        pip3 install --break-system-packages -r "$dest/SecretFinder/requirements.txt" 2>/dev/null || true
    fi

    # LinkFinder — extract endpoints from JS files
    clone_or_pull "https://github.com/GerbenJavado/LinkFinder.git" "$dest/LinkFinder"
    if [[ -f "$dest/LinkFinder/requirements.txt" ]]; then
        pip3 install --break-system-packages -r "$dest/LinkFinder/requirements.txt" 2>/dev/null || true
    fi

    # dalfox — XSS scanner (Go binary)
    install_go_release "dalfox" \
        "hahwul/dalfox" \
        "linux_amd64" \
        "$dest"

    # trufflehog — credential/secret scanner (Go binary)
    install_go_release "trufflehog" \
        "trufflesecurity/trufflehog" \
        "linux_amd64" \
        "$dest"

    success "Web tools installed."
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
        # Tokyo Night syntax highlighting
        ZSH_HIGHLIGHT_STYLES[default]='fg=#a9b1d6'
        ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#f7768e'
        ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=#bb9af7,bold'
        ZSH_HIGHLIGHT_STYLES[suffix-alias]='fg=#7dcfff,underline'
        ZSH_HIGHLIGHT_STYLES[global-alias]='fg=#7dcfff,bold'
        ZSH_HIGHLIGHT_STYLES[precommand]='fg=#7dcfff,underline'
        ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=#bb9af7,bold'
        ZSH_HIGHLIGHT_STYLES[autodirectory]='fg=#9ece6a,underline'
        ZSH_HIGHLIGHT_STYLES[path]='fg=#9ece6a,underline'
        ZSH_HIGHLIGHT_STYLES[path_pathseparator]=
        ZSH_HIGHLIGHT_STYLES[path_prefix]='fg=#9ece6a'
        ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]=
        ZSH_HIGHLIGHT_STYLES[globbing]='fg=#ff9e64'
        ZSH_HIGHLIGHT_STYLES[history-expansion]='fg=#bb9af7,bold'
        ZSH_HIGHLIGHT_STYLES[command-substitution]=none
        ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]='fg=#bb9af7,bold'
        ZSH_HIGHLIGHT_STYLES[process-substitution]=none
        ZSH_HIGHLIGHT_STYLES[process-substitution-delimiter]='fg=#bb9af7,bold'
        ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#7dcfff'
        ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=#7dcfff'
        ZSH_HIGHLIGHT_STYLES[back-quoted-argument]=none
        ZSH_HIGHLIGHT_STYLES[back-quoted-argument-delimiter]='fg=#bb9af7,bold'
        ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#e0af68'
        ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#e0af68'
        ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=#e0af68'
        ZSH_HIGHLIGHT_STYLES[rc-quote]='fg=#bb9af7'
        ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]='fg=#bb9af7,bold'
        ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]='fg=#bb9af7,bold'
        ZSH_HIGHLIGHT_STYLES[back-dollar-quoted-argument]='fg=#bb9af7,bold'
        ZSH_HIGHLIGHT_STYLES[assign]=none
        ZSH_HIGHLIGHT_STYLES[redirection]='fg=#89ddff,bold'
        ZSH_HIGHLIGHT_STYLES[comment]='fg=#565f89,italic'
        ZSH_HIGHLIGHT_STYLES[named-fd]=none
        ZSH_HIGHLIGHT_STYLES[numeric-fd]=none
        ZSH_HIGHLIGHT_STYLES[arg0]='fg=#7aa2f7'
        ZSH_HIGHLIGHT_STYLES[bracket-error]='fg=#f7768e,bold'
        ZSH_HIGHLIGHT_STYLES[bracket-level-1]='fg=#7aa2f7,bold'
        ZSH_HIGHLIGHT_STYLES[bracket-level-2]='fg=#9ece6a,bold'
        ZSH_HIGHLIGHT_STYLES[bracket-level-3]='fg=#bb9af7,bold'
        ZSH_HIGHLIGHT_STYLES[bracket-level-4]='fg=#e0af68,bold'
        ZSH_HIGHLIGHT_STYLES[bracket-level-5]='fg=#7dcfff,bold'
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

# ── eza — modern ls replacement ──
# Tokyo Night eza colors
export EZA_COLORS="\
di=1;34:ln=36:so=35:pi=33:ex=1;32:bd=34;46:cd=34;43:\
su=30;41:sg=30;46:tw=30;42:ow=34;42:fi=0:\
*.py=33:*.sh=32:*.rb=31:*.rs=33:*.go=36:*.js=33:*.ts=34:*.lua=34:\
*.conf=35:*.toml=35:*.yml=35:*.yaml=35:*.json=35:*.xml=35:\
*.md=37:*.txt=37:*.log=90:*.bak=90:*.swp=90:\
*.zip=31:*.tar=31:*.gz=31:*.7z=31:\
*.pdf=35:*.png=36:*.jpg=36:*.svg=36"

if command -v eza &>/dev/null; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -lh --icons --group-directories-first --git'
    alias la='eza -lah --icons --group-directories-first --git'
    alias l='eza --icons --group-directories-first'
    alias tree='eza --tree --icons --level=3'
else
    alias ll='ls -l'
    alias la='ls -A'
    alias l='ls -CF'
fi

# ── bat — better cat ──
# Debian/Kali names the binary 'batcat' to avoid conflicts
if command -v batcat &>/dev/null; then
    alias bat='batcat'
    alias cat='batcat --paging=never'
    export BAT_THEME="tokyonight_night"
elif command -v bat &>/dev/null; then
    alias cat='bat --paging=never'
    export BAT_THEME="tokyonight_night"
fi

# ── ripgrep alias ──
# rg is already the binary name, just set useful defaults
alias rg='rg --smart-case --hidden --glob "!.git"'

# ═══════════════════════════════════════
#  Pentest workflow shortcuts
# ═══════════════════════════════════════

# serve <port> — HTTP file server in current directory
#   Usage: serve 8080
#   Default port: 80 (auto-sudo for ports < 1024)
serve() {
    local port="${1:-80}"
    local ip
    ip=$(ip -4 addr show tun0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || \
         ip -4 addr show eth0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || \
         echo "0.0.0.0")
    echo -e "\033[0;36m[*]\033[0m Serving $(pwd) on http://${ip}:${port}"
    if [[ "$port" -lt 1024 ]]; then
        sudo python3 -m http.server "$port" --bind 0.0.0.0
    else
        python3 -m http.server "$port" --bind 0.0.0.0
    fi
}

# listen <port> — Penelope reverse shell listener
#   Usage: listen 4444
#   Default port: 4444 (auto-sudo for ports < 1024)
listen() {
    local port="${1:-4444}"
    # Ensure penelope's log directory exists
    mkdir -p "$HOME/.penelope" 2>/dev/null
    if command -v penelope &>/dev/null; then
        echo -e "\033[0;36m[*]\033[0m Starting Penelope listener on port ${port}..."
        if [[ "$port" -lt 1024 ]]; then
            sudo $(which penelope) "$port"
        else
            penelope "$port"
        fi
    else
        echo -e "\033[1;33m[!]\033[0m Penelope not found, falling back to netcat..."
        if [[ "$port" -lt 1024 ]]; then
            sudo nc -lvnp "$port"
        else
            nc -lvnp "$port"
        fi
    fi
}

# myip — show attack box IPs at a glance
myip() {
    echo -e "\033[0;36m[*]\033[0m Network interfaces:"
    local iface ip
    for iface in tun0 tun1 eth0 wlan0; do
        ip=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
        if [[ -n "$ip" ]]; then
            printf "    \033[0;32m%-8s\033[0m %s\n" "$iface" "$ip"
        fi
    done
    # External IP
    local extip
    extip=$(curl -s --max-time 3 ifconfig.me 2>/dev/null)
    if [[ -n "$extip" ]]; then
        printf "    \033[1;33m%-8s\033[0m %s\n" "public" "$extip"
    fi
}

# cleanengagement — post-engagement hygiene
#   Wipes temp files and clears sensitive history entries
cleanengagement() {
    echo -e "\033[1;33m[!]\033[0m Post-engagement cleanup..."

    # Clear common temp/loot locations
    rm -rf /tmp/bloodhound* /tmp/sharphound* /tmp/*.exe /tmp/*.ps1 2>/dev/null
    rm -rf /tmp/kerbrute* /tmp/chisel* /tmp/ligolo* 2>/dev/null
    rm -rf /dev/shm/*.tmp 2>/dev/null

    # Clear credential artifacts
    rm -f /tmp/ntlm_theft_* 2>/dev/null
    rm -f /tmp/responder_* 2>/dev/null

    # Flush arp cache
    sudo ip neigh flush all 2>/dev/null

    # Clear zsh history of sensitive patterns (passwords, hashes, creds)
    if [[ -f ~/.zsh_history ]]; then
        local before
        before=$(wc -l < ~/.zsh_history)
        sed -i '/:.*password\|:.*NTLM\|:.*secret\|:.*cred\|:.*hash.*:/Id' ~/.zsh_history 2>/dev/null
        local after
        after=$(wc -l < ~/.zsh_history)
        echo -e "    \033[0;32m[+]\033[0m Scrubbed $((before - after)) sensitive history entries"
    fi

    echo -e "    \033[0;32m[+]\033[0m Temp files cleared"
    echo -e "    \033[0;32m[+]\033[0m ARP cache flushed"
    echo -e "\033[0;32m[+]\033[0m Cleanup complete."
}

# ═══════════════════════════════════════
#  Clipboard helpers
# ═══════════════════════════════════════
# Usage: echo "stuff" | copy     →  copies to clipboard
#        paste                   →  pastes from clipboard
#        cat file.txt | copy     →  copy file contents
if command -v xclip &>/dev/null; then
    alias copy='xclip -selection clipboard'
    alias paste='xclip -selection clipboard -o'
fi

# ═══════════════════════════════════════
#  Universal extract
# ═══════════════════════════════════════
# Usage: extract archive.tar.gz
extract() {
    if [[ -z "$1" ]]; then
        echo "Usage: extract <archive>"
        return 1
    fi
    if [[ ! -f "$1" ]]; then
        echo -e "\033[0;31m[-]\033[0m '$1' not found"
        return 1
    fi
    case "$1" in
        *.tar.bz2) tar xjf "$1"    ;;
        *.tar.gz)  tar xzf "$1"    ;;
        *.tar.xz)  tar xJf "$1"    ;;
        *.tar.zst) tar --zstd -xf "$1" ;;
        *.bz2)     bunzip2 "$1"    ;;
        *.rar)     unrar x "$1"    ;;
        *.gz)      gunzip "$1"     ;;
        *.tar)     tar xf "$1"     ;;
        *.tbz2)    tar xjf "$1"    ;;
        *.tgz)     tar xzf "$1"    ;;
        *.zip)     unzip "$1"      ;;
        *.Z)       uncompress "$1" ;;
        *.7z)      7z x "$1"       ;;
        *)         echo -e "\033[1;33m[!]\033[0m Unknown format: '$1'" ;;
    esac
}

# ═══════════════════════════════════════
#  Encoding helpers
# ═══════════════════════════════════════
# Base64
#   echo "payload" | b64e        →  encode
#   echo "cGF5bG9hZA==" | b64d  →  decode
#   b64e "string"                →  encode argument
alias b64d='base64 -d'
b64e() {
    if [[ -n "$1" ]]; then
        echo -n "$1" | base64
    else
        base64
    fi
}

# URL encode/decode
#   echo "hello world" | urlencode   →  hello%20world
#   echo "hello%20world" | urldecode →  hello world
#   urlencode "hello world"          →  hello%20world
urlencode() {
    if [[ -n "$1" ]]; then
        python3 -c "import urllib.parse; print(urllib.parse.quote('$1', safe=''))"
    else
        python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip(), safe=''))"
    fi
}
urldecode() {
    if [[ -n "$1" ]]; then
        python3 -c "import urllib.parse; print(urllib.parse.unquote('$1'))"
    else
        python3 -c "import sys, urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))"
    fi
}

# ═══════════════════════════════════════
#  Nmap quick profiles
# ═══════════════════════════════════════
# All output to current directory with timestamped filenames
#   nquick 10.0.0.0/24           →  fast TCP top 1000
#   nfull 10.0.0.1               →  all TCP ports, scripts
#   nudp 10.0.0.1                →  top 100 UDP
#   nvuln 10.0.0.1               →  vuln scripts
nquick() {
    local target="$1"
    [[ -z "$target" ]] && { echo "Usage: nquick <target>"; return 1; }
    local out="nmap-quick-$(date +%Y%m%d-%H%M)"
    echo -e "\033[0;36m[*]\033[0m Quick scan → $target (output: ${out}.*)"
    sudo nmap -sC -sV -T4 --open -oA "$out" "$target"
}

nfull() {
    local target="$1"
    [[ -z "$target" ]] && { echo "Usage: nfull <target>"; return 1; }
    local out="nmap-full-$(date +%Y%m%d-%H%M)"
    echo -e "\033[0;36m[*]\033[0m Full TCP scan → $target (output: ${out}.*)"
    sudo nmap -sC -sV -p- -T4 --open -oA "$out" "$target"
}

nudp() {
    local target="$1"
    [[ -z "$target" ]] && { echo "Usage: nudp <target>"; return 1; }
    local out="nmap-udp-$(date +%Y%m%d-%H%M)"
    echo -e "\033[0;36m[*]\033[0m UDP scan (top 100) → $target (output: ${out}.*)"
    sudo nmap -sU --top-ports 100 -T4 --open -oA "$out" "$target"
}

nvuln() {
    local target="$1"
    [[ -z "$target" ]] && { echo "Usage: nvuln <target>"; return 1; }
    local out="nmap-vuln-$(date +%Y%m%d-%H%M)"
    echo -e "\033[0;36m[*]\033[0m Vuln scan → $target (output: ${out}.*)"
    sudo nmap -sV --script vuln -T4 -oA "$out" "$target"
}

# ═══════════════════════════════════════
#  Python venv helpers
# ═══════════════════════════════════════
# mkvenv [name]  →  create venv (default: .venv)
# activate       →  activate venv in current or parent dir
mkvenv() {
    local name="${1:-.venv}"
    python3 -m venv "$name"
    source "$name/bin/activate"
    pip install --upgrade pip > /dev/null 2>&1
    echo -e "\033[0;32m[+]\033[0m Created and activated venv: $name"
}

activate() {
    # Search current dir, then parent dirs for a venv
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        for venv in .venv venv env; do
            if [[ -f "$dir/$venv/bin/activate" ]]; then
                source "$dir/$venv/bin/activate"
                echo -e "\033[0;32m[+]\033[0m Activated: $dir/$venv"
                return 0
            fi
        done
        dir="$(dirname "$dir")"
    done
    echo -e "\033[0;31m[-]\033[0m No venv found in current or parent directories"
    return 1
}

# enable auto-suggestions based on the history
if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    . /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    # change suggestion color
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#565f89'
fi

# enable command-not-found if installed
if [ -f /etc/zsh_command_not_found ]; then
    . /etc/zsh_command_not_found
fi

# ── fzf — fuzzy finder ──
# Ctrl+R  = fuzzy history search
# Ctrl+T  = fuzzy file search (insert path)
# Alt+C   = fuzzy cd into directory
if [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]; then
    . /usr/share/doc/fzf/examples/key-bindings.zsh
fi
if [ -f /usr/share/doc/fzf/examples/completion.zsh ]; then
    . /usr/share/doc/fzf/examples/completion.zsh
fi
# Tokyo Night colors for fzf popup
export FZF_DEFAULT_OPTS="
  --color=bg+:#24283b,bg:#1a1b26,fg:#c0caf5,fg+:#c0caf5
  --color=hl:#769ff0,hl+:#769ff0,info:#f7768e,marker:#9ece6a
  --color=prompt:#769ff0,spinner:#9ece6a,pointer:#f7768e,header:#769ff0
  --color=border:#394260,gutter:#1a1b26
  --height=40% --layout=reverse --border=rounded
"
# Use fd if available, fall back to find
if command -v fd &>/dev/null; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
fi

# ── zoxide — smart cd ──
# Usage: z <partial-dir-name>  (e.g. "z acme" → ~/Engagements/acme)
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init zsh)"
fi

# ── broot — interactive tree browser ──
# Run 'broot' once to generate the launcher, then 'br' to use
if [[ -f "$HOME/.config/broot/launcher/bash/br" ]]; then
    source "$HOME/.config/broot/launcher/bash/br"
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

-- ═══════════════════════════════════════
--  Color Scheme & Background
-- ═══════════════════════════════════════
config.color_scheme = 'Tokyo Night'
config.window_background_opacity = 1

-- ═══════════════════════════════════════
--  Fonts & Ligatures
-- ═══════════════════════════════════════
config.font_size = 10
config.font = wezterm.font('FiraCode Nerd Font', { weight = 'Regular' })
config.font_rules = {
    {
        italic = true,
        font = wezterm.font('FiraCode Nerd Font', { weight = 'Regular', italic = true }),
    },
    {
        intensity = 'Bold',
        font = wezterm.font('FiraCode Nerd Font', { weight = 'Bold' }),
    },
}
config.harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1' }

-- ═══════════════════════════════════════
--  Cursor
-- ═══════════════════════════════════════
config.default_cursor_style = 'SteadyBar'
config.cursor_blink_rate = 600
config.cursor_blink_ease_in = 'EaseIn'
config.cursor_blink_ease_out = 'EaseOut'
config.force_reverse_video_cursor = false

-- ═══════════════════════════════════════
--  Window & Padding
-- ═══════════════════════════════════════
config.initial_cols = 120
config.initial_rows = 28
config.window_padding = {
    left = 12,
    right = 12,
    top = 10,
    bottom = 10,
}
config.enable_scroll_bar = false
config.scrollback_lines = 10000

-- ═══════════════════════════════════════
--  Pane Dimming
-- ═══════════════════════════════════════
config.inactive_pane_hsb = {
    saturation = 0.85,
    brightness = 0.65,
}

-- ═══════════════════════════════════════
--  Tab Bar (non-fancy for Nerd Font compat)
-- ═══════════════════════════════════════
config.use_fancy_tab_bar = true
config.tab_bar_at_bottom = false
config.hide_tab_bar_if_only_one_tab = false
config.tab_max_width = 32
config.show_new_tab_button_in_tab_bar = true

config.window_frame = {
    font = wezterm.font 'Roboto',
    font_size = 12,
    active_titlebar_bg = '#1a1b26',
    inactive_titlebar_bg = '#1a1b26',
}

config.colors = {
    cursor_bg = '#769ff0',
    cursor_border = '#769ff0',
    cursor_fg = '#1a1b26',

    tab_bar = {
        background = '#1a1b26',
        inactive_tab_edge = '#1a1b26',
        active_tab = {
            bg_color = '#24283b',
            fg_color = '#a9b1d6',
            intensity = 'Bold',
        },
        inactive_tab = {
            bg_color = '#1a1b26',
            fg_color = '#565f89',
        },
        inactive_tab_hover = {
            bg_color = '#1d2230',
            fg_color = '#a9b1d6',
        },
        new_tab = {
            bg_color = '#1a1b26',
            fg_color = '#565f89',
        },
        new_tab_hover = {
            bg_color = '#1d2230',
            fg_color = '#a9b1d6',
        },
    },
}

-- ═══════════════════════════════════════
--  Key Bindings — using WezTerm defaults
--  Ctrl+Shift+T = new tab
--  Ctrl+Shift+W = close tab
--  Ctrl+Shift+Arrow = switch pane (if split)
--  Ctrl+Shift+| = split horizontal (default)
--  Ctrl+Shift+Space = quick select
--  Ctrl+Shift+P = command palette
--  See: https://wezfurlong.org/wezterm/config/default-keys.html
-- ═══════════════════════════════════════

-- ═══════════════════════════════════════
--  Quick Select Patterns (pentest-friendly)
-- ═══════════════════════════════════════
config.quick_select_patterns = {
    -- IPv4 addresses
    '\\b\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\b',
    -- IPv4 with CIDR
    '\\b\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}/\\d{1,2}\\b',
    -- MAC addresses
    '[0-9a-fA-F]{2}(?::[0-9a-fA-F]{2}){5}',
    -- MD5 hashes
    '\\b[a-fA-F0-9]{32}\\b',
    -- SHA1 hashes
    '\\b[a-fA-F0-9]{40}\\b',
    -- SHA256 hashes
    '\\b[a-fA-F0-9]{64}\\b',
    -- NTLMv2 / NetNTLM hashes (user::domain format)
    '[\\w.]+::\\w+:[a-fA-F0-9]+:[a-fA-F0-9]+:[a-fA-F0-9]+',
    -- Port numbers in nmap-style output (e.g. 80/tcp, 443/tcp)
    '\\b\\d{1,5}/(?:tcp|udp)\\b',
    -- File paths (Unix)
    '(?:/[\\w.-]+)+',
}

-- ═══════════════════════════════════════
--  Hyperlinks
-- ═══════════════════════════════════════
config.hyperlink_rules = wezterm.default_hyperlink_rules()

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
"Engagements" = "Engagements __TARGET__"
"Tools" = "Tools __WRENCH__"
"wordlists" = "wordlists __BOOK__"
"Documents" = "Documents __DOC__"
"Downloads" = "Downloads __INBOX__"

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

    # ---- 8e. ~/.ssh/config ----                          [NEW]
    info "Writing ~/.ssh/config defaults..."
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    if [[ ! -f "$HOME/.ssh/config" ]]; then
        cat > "$HOME/.ssh/config" << 'SSH_EOF'
# ── Global SSH defaults ──

Host *
    # Keep connections alive (prevents tunnel/session drops)
    ServerAliveInterval 60
    ServerAliveCountMax 3

    # Reuse connections (faster reconnects)
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 600

    # Don't hash known_hosts (readable during engagements)
    HashKnownHosts no

    # Default to not forwarding agent (OPSEC — opt in per host)
    ForwardAgent no
SSH_EOF
        mkdir -p "$HOME/.ssh/sockets"
        chmod 600 "$HOME/.ssh/config"
        success "~/.ssh/config written."
    else
        warn "~/.ssh/config already exists — skipping (won't overwrite SSH config)."
    fi
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

    local wl_dir="$TOOLS_DIR/Wordlists"
    # Directory already created at startup

    # Symlink seclists if present
    if [[ -d /usr/share/seclists ]]; then
        ln -sfn /usr/share/seclists "$wl_dir/seclists"
        success "Symlinked /usr/share/seclists → ~/Tools/Wordlists/seclists"
    else
        warn "/usr/share/seclists not found — will be available after kali-linux-everything finishes."
    fi

    # Symlink default wordlists
    if [[ -d /usr/share/wordlists ]]; then
        ln -sfn /usr/share/wordlists "$wl_dir/default"
        success "Symlinked /usr/share/wordlists → ~/Tools/Wordlists/default"
    else
        warn "/usr/share/wordlists not found."
    fi

    # Convenience symlink: ~/wordlists → ~/Tools/Wordlists
    ln -sfn "$wl_dir" "$HOME/wordlists"
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
    mkdir -p "$HOME/.penelope"

    # Penelope → Shells
    if [[ -f "$TOOLS_DIR/Shells/penelope/penelope.py" ]]; then
        chmod +x "$TOOLS_DIR/Shells/penelope/penelope.py"
        ln -sfn "$TOOLS_DIR/Shells/penelope/penelope.py" "$bin_dir/penelope"
        success "penelope → ~/.local/bin/penelope"
    else
        warn "penelope.py not found — skipping symlink."
    fi

    # ntlm_theft → AD
    if [[ -f "$TOOLS_DIR/AD/ntlm_theft/ntlm_theft.py" ]]; then
        chmod +x "$TOOLS_DIR/AD/ntlm_theft/ntlm_theft.py"
        ln -sfn "$TOOLS_DIR/AD/ntlm_theft/ntlm_theft.py" "$bin_dir/ntlm_theft"
        success "ntlm_theft → ~/.local/bin/ntlm_theft"
    else
        warn "ntlm_theft.py not found — skipping symlink."
    fi

    # Kerbrute → AD
    if [[ -x "$TOOLS_DIR/AD/kerbrute" ]]; then
        ln -sfn "$TOOLS_DIR/AD/kerbrute" "$bin_dir/kerbrute"
        success "kerbrute → ~/.local/bin/kerbrute"
    fi

    # Ligolo-ng → Pivoting
    if [[ -d "$TOOLS_DIR/Pivoting/ligolo-ng" ]]; then
        local proxy_bin agent_bin
        proxy_bin=$(find "$TOOLS_DIR/Pivoting/ligolo-ng" -maxdepth 1 -name '*proxy*' -type f 2>/dev/null | head -1)
        agent_bin=$(find "$TOOLS_DIR/Pivoting/ligolo-ng" -maxdepth 1 -name '*agent*' -type f 2>/dev/null | head -1)

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

    # Recon tools → symlink binaries
    for tool in katana gau waybackurls qsreplace; do
        if [[ -x "$TOOLS_DIR/Recon/$tool" ]]; then
            ln -sfn "$TOOLS_DIR/Recon/$tool" "$bin_dir/$tool"
            success "$tool → ~/.local/bin/$tool"
        fi
    done

    # Web tools → symlink binaries
    for tool in dalfox trufflehog; do
        if [[ -x "$TOOLS_DIR/Web/$tool" ]]; then
            ln -sfn "$TOOLS_DIR/Web/$tool" "$bin_dir/$tool"
            success "$tool → ~/.local/bin/$tool"
        fi
    done

    # ParamSpider → symlink
    if [[ -f "$TOOLS_DIR/Web/ParamSpider/paramspider/main.py" ]]; then
        ln -sfn "$TOOLS_DIR/Web/ParamSpider/paramspider/main.py" "$bin_dir/paramspider"
        chmod +x "$bin_dir/paramspider" 2>/dev/null
        success "paramspider → ~/.local/bin/paramspider"
    fi

    # SecretFinder → symlink
    if [[ -f "$TOOLS_DIR/Web/SecretFinder/SecretFinder.py" ]]; then
        chmod +x "$TOOLS_DIR/Web/SecretFinder/SecretFinder.py"
        ln -sfn "$TOOLS_DIR/Web/SecretFinder/SecretFinder.py" "$bin_dir/secretfinder"
        success "secretfinder → ~/.local/bin/secretfinder"
    fi

    # LinkFinder → symlink
    if [[ -f "$TOOLS_DIR/Web/LinkFinder/linkfinder.py" ]]; then
        chmod +x "$TOOLS_DIR/Web/LinkFinder/linkfinder.py"
        ln -sfn "$TOOLS_DIR/Web/LinkFinder/linkfinder.py" "$bin_dir/linkfinder"
        success "linkfinder → ~/.local/bin/linkfinder"
    fi

    # Ensure ~/.local/bin is on PATH (idempotent)
    if ! grep -qF 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.zshrc"; then
        echo "" >> "$HOME/.zshrc"
        echo "# Add ~/.local/bin to PATH (tool symlinks)" >> "$HOME/.zshrc"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
        success "~/.local/bin added to PATH in .zshrc."
    fi

    # Toolies — quick-access alias
    if ! grep -qF 'alias toolies=' "$HOME/.zshrc"; then
        echo "" >> "$HOME/.zshrc"
        echo "# Quick-access alias for Toolies collection" >> "$HOME/.zshrc"
        echo "alias toolies='ls -la \$HOME/Tools/Windows/Toolies/'" >> "$HOME/.zshrc"
        success "alias 'toolies' added to .zshrc (lists ~/Tools/Windows/Toolies)."
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
#  Reset configs — restores all dotfiles/configs to script defaults
# ============================================================================
reset_configs() {
    info "Resetting configs to defaults..."
    echo ""
    warn "This will overwrite the following files (backups will be created):"
    warn "  ~/.zshrc"
    warn "  ~/.wezterm.lua"
    warn "  ~/.config/starship.toml"
    warn "  ~/.tmux.conf"
    echo ""
    read -rp "$(echo -e "${YELLOW}[!]${NC} Continue? [y/N] ")" confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        info "Aborted."
        exit 0
    fi
    echo ""

    section_configs
    section_path
    section_engagement_alias
    section_tool_symlinks

    echo ""
    success "========================================="
    success "  Configs reset to defaults!"
    success "========================================="
    echo ""
    info "Restored:"
    info "  • ~/.zshrc (with Starship init, PATH, aliases)"
    info "  • ~/.wezterm.lua (Tokyo Night, FiraCode Nerd Font)"
    info "  • ~/.config/starship.toml (rounded bar, time, emojis)"
    info "  • ~/.tmux.conf (C-a prefix, mouse, Tokyo Night status)"
    info "  • Tool symlinks in ~/.local/bin"
    echo ""
    info "Backups of your previous configs saved as <filename>.bak.<timestamp>"
    echo ""
    warn "Run 'source ~/.zshrc' or restart your terminal to apply."
}

# ============================================================================
#  Main — full install
# ============================================================================
main() {
    info "Starting full Kali post-install setup..."
    echo ""

    section_apt
    section_apt_tools
    section_git_tools
    section_kerbrute
    section_ligolo
    section_recon_tools
    section_web_tools
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
    info "  • rlwrap, feroxbuster, ffuf, fzf, zoxide, bat, eza, ripgrep, xclip, mousepad installed via apt"
    info "  • WezTerm installed (config at ~/.wezterm.lua)"
    info "  • Starship installed (config at ~/.config/starship.toml)"
    info "  • FiraCode Nerd Font + Roboto installed"
    info "  • ~/.zshrc configured (Tokyo Night colors, Starship, aliases)"
    info "  • ~/.tmux.conf written (C-a prefix, mouse, Tokyo Night status bar)"
    info "  • ~/.ssh/config written (keepalive, multiplexing, unhashed known_hosts)"
    info "  • newengagement <name> function available in zsh"
    echo ""
    info "~/Tools directory structure:"
    info "  • AD/              ntlm_theft, kerbrute"
    info "  • Shells/          penelope"
    info "  • Windows/         Toolies (PowerView, SharpHound, etc.)"
    info "  • Pivoting/        ligolo-ng (proxy + agent)"
    info "  • Recon/           katana, gau, waybackurls, qsreplace"
    info "  • Web/             ParamSpider, Arjun, dalfox, SecretFinder, LinkFinder, trufflehog"
    info "  • Exploits/        (ready for compiled exploits, POCs)"
    info "  • Wordlists/       seclists + default symlinks"
    echo ""
    info "Tool shortcuts (via ~/.local/bin):"
    info "  • penelope       → ~/Tools/Shells/penelope/penelope.py"
    info "  • ntlm_theft     → ~/Tools/AD/ntlm_theft/ntlm_theft.py"
    info "  • kerbrute       → ~/Tools/AD/kerbrute"
    info "  • ligolo-proxy   → ~/Tools/Pivoting/ligolo-ng/proxy"
    info "  • ligolo-agent   → ~/Tools/Pivoting/ligolo-ng/agent"
    info "  • toolies        → alias, lists ~/Tools/Windows/Toolies/"
    echo ""
    info "Shell functions & aliases:"
    info "  • serve <port>     — HTTP server (auto-sudo for <1024)"
    info "  • listen <port>    — Penelope listener (auto-sudo for <1024)"
    info "  • myip             — show all interface IPs"
    info "  • nquick/nfull/nudp/nvuln <target> — nmap profiles"
    info "  • extract <file>   — universal archive extraction"
    info "  • b64e/b64d        — base64 encode/decode"
    info "  • urlencode/urldecode — URL encode/decode"
    info "  • copy/paste       — clipboard pipe (xclip)"
    info "  • mkvenv/activate  — Python venv helpers"
    info "  • cleanengagement  — post-engagement hygiene"
    echo ""
    warn "Restart your terminal (or run 'source ~/.zshrc') to apply changes."
}

# ============================================================================
#  Entry point — parse flags
# ============================================================================
case "${1:-}" in
    --reset-configs) reset_configs ;;
    --help|-h)       usage ;;
    "")              main ;;
    *)               error "Unknown flag: $1"; usage ;;
esac
