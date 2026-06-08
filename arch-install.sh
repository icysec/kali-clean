#!/usr/bin/env bash
# ============================================================================
#  arch-setup.sh — Arch Linux + BlackArch post-install provisioning script
#  Companion to kali-setup.sh — same configs, same workflow, Arch packages.
#
#  Assumes a working Arch install with base, base-devel, and an internet
#  connection. Run as your normal user (script will sudo when needed).
#
#  Usage:
#    ./arch-setup.sh                 Full install (BlackArch, tools, configs)
#    ./arch-setup.sh --reset-configs Rewrite all config files to defaults
#    ./arch-setup.sh --help          Show this help
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
    echo "  (no flag)         Full install — BlackArch repo, tools, configs"
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

if ! command -v pacman &>/dev/null; then
    error "This script is for Arch Linux. pacman not found."
    exit 1
fi

TOOLS_DIR="$HOME/Tools"
mkdir -p "$TOOLS_DIR"

# ----------------------------------------------------------
#  1. System update + BlackArch repo
# ----------------------------------------------------------
section_system() {
    info "Updating system..."
    sudo pacman -Syu --noconfirm

    # Ensure base-devel is present (needed for yay/AUR)
    sudo pacman -S --needed --noconfirm base-devel git curl wget unzip

    # Add BlackArch repo if not already present
    if grep -q "blackarch" /etc/pacman.conf 2>/dev/null; then
        warn "BlackArch repo already configured — skipping."
    else
        info "Adding BlackArch repository via strap.sh..."
        local tmpdir
        tmpdir=$(mktemp -d)
        curl -fsSL -o "$tmpdir/strap.sh" https://blackarch.org/strap.sh

        # Verify SHA1
        local expected_sha1="00688950aaf5e5804d2abebb8d3d3ea1d28525ed"
        local actual_sha1
        actual_sha1=$(sha1sum "$tmpdir/strap.sh" | awk '{print $1}')

        if [[ "$actual_sha1" != "$expected_sha1" ]]; then
            warn "SHA1 mismatch! Expected: $expected_sha1"
            warn "                    Got: $actual_sha1"
            warn "The BlackArch team may have updated strap.sh."
            warn "Verify manually at https://blackarch.org/downloads.html"
            read -rp "$(echo -e "${YELLOW}[!]${NC} Continue anyway? [y/N] ")" confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                error "Aborted."
                rm -rf "$tmpdir"
                exit 1
            fi
        else
            success "SHA1 verified: $actual_sha1"
        fi

        chmod +x "$tmpdir/strap.sh"
        sudo "$tmpdir/strap.sh"
        rm -rf "$tmpdir"

        # Sync after adding repo
        sudo pacman -Syy
        success "BlackArch repository added."
    fi
}

# ----------------------------------------------------------
#  2. Install yay (AUR helper)
# ----------------------------------------------------------
section_yay() {
    if command -v yay &>/dev/null; then
        warn "yay already installed — skipping."
        return 0
    fi

    info "Installing yay (AUR helper)..."
    local tmpdir
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    cd "$tmpdir/yay"
    makepkg -si --noconfirm
    cd "$HOME"
    rm -rf "$tmpdir"
    success "yay installed."
}

# ----------------------------------------------------------
#  3. Pacman tools (core utilities)
# ----------------------------------------------------------
section_pacman_tools() {
    info "Installing core tools via pacman..."

    local packages=(
        # Shell & terminal
        zsh
        zsh-autosuggestions
        zsh-syntax-highlighting
        tmux
        wezterm
        starship
        ttf-roboto

        # CLI upgrades
        fzf
        zoxide
        bat
        eza
        ripgrep
        xclip
        rlwrap

        # Pentest essentials (from BlackArch / community)
        nmap
        feroxbuster
        ffuf
        metasploit
        impacket
        responder
        john
        hashcat
        sqlmap
        gobuster
        seclists
        wordlists
        burpsuite
        wireshark-qt
        bloodhound
        crackmapexec
        enum4linux-ng
        certipy
        evil-winrm
        chisel
        sshuttle
        proxychains-ng
        hydra
        nikto
        whatweb
        wpscan
        netcat
        socat
        tcpdump
    )

    local to_install=()
    for pkg in "${packages[@]}"; do
        if pacman -Qi "$pkg" &>/dev/null; then
            continue
        else
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        info "Installing ${#to_install[@]} packages..."
        # Use --needed to skip already installed, allow failures for
        # packages that may not exist in repos (name differences)
        sudo pacman -S --needed --noconfirm "${to_install[@]}" || {
            warn "Some packages may not be available. Installing one by one..."
            for pkg in "${to_install[@]}"; do
                sudo pacman -S --needed --noconfirm "$pkg" 2>/dev/null || \
                    warn "Package not found: $pkg — try: yay -S $pkg"
            done
        }
    else
        success "All core packages already installed."
    fi
}

# ----------------------------------------------------------
#  4. Git-based tools → ~/Tools
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
    if [[ -f "$TOOLS_DIR/ntlm_theft/requirements.txt" ]]; then
        pip install --break-system-packages -r "$TOOLS_DIR/ntlm_theft/requirements.txt" 2>/dev/null || \
        pip install -r "$TOOLS_DIR/ntlm_theft/requirements.txt" 2>/dev/null || true
    fi

    # Penelope
    clone_or_pull "https://github.com/brightio/penelope.git" "$TOOLS_DIR/penelope"

    # Toolies
    clone_or_pull "https://github.com/expl0itabl3/Toolies.git" "$TOOLS_DIR/Toolies"

    success "Git tools cloned to $TOOLS_DIR."
}

# ----------------------------------------------------------
#  5. Kerbrute — latest release binary
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
#  6. Ligolo-ng — proxy + agent binaries
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

    local proxy_url
    proxy_url=$(echo "$release_json" \
        | grep -oP '"browser_download_url":\s*"\K[^"]*proxy[^"]*linux_amd64[^"]*\.tar\.gz' \
        | head -1)

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
#  7. Fonts — FiraCode Nerd Font
# ----------------------------------------------------------
section_fonts() {
    local font_dir="$HOME/.local/share/fonts"

    if fc-list | grep -qi "FiraCode.*Nerd" 2>/dev/null; then
        warn "FiraCode Nerd Font already installed — skipping."
    else
        info "Installing FiraCode Nerd Font..."
        mkdir -p "$font_dir"

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
            warn "Could not auto-detect FiraCode Nerd Font URL."
        fi
    fi

    # Roboto (installed via pacman in section_pacman_tools as ttf-roboto)

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
# ~/.zshrc — Arch Linux + BlackArch

setopt autocd
setopt interactivecomments
setopt magicequalsubst
setopt nonomatch
setopt notify
setopt numericglobsort
setopt promptsubst

WORDCHARS='_-'
PROMPT_EOL_MARK=""

# Key bindings (emacs mode)
bindkey -e
bindkey ' ' magic-space
bindkey '^U' backward-kill-line
bindkey '^[[3;5~' kill-word
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^[[5~' beginning-of-buffer-or-history
bindkey '^[[6~' end-of-buffer-or-history
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[Z' undo

# Completion
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

# History
HISTFILE=~/.zsh_history
HISTSIZE=5000
SAVEHIST=5000
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_ignore_space
setopt hist_verify

alias history="history 0"

TIMEFMT=$'\nreal\t%E\nuser\t%U\nsys\t%S\ncpu\t%P'

# Prompt fallback (overridden by starship at the bottom)
PROMPT='%B%F{blue}%n@%m%b%F{reset}:%B%F{green}%~%b%F{reset}$ '

# Color support
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    export LS_COLORS="$LS_COLORS:ow=30;44:"

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
    alias diff='diff --color=auto'
    alias ip='ip --color=auto'

    export LESS_TERMCAP_mb=$'\E[1;31m'
    export LESS_TERMCAP_md=$'\E[1;36m'
    export LESS_TERMCAP_me=$'\E[0m'
    export LESS_TERMCAP_so=$'\E[01;33m'
    export LESS_TERMCAP_se=$'\E[0m'
    export LESS_TERMCAP_us=$'\E[1;32m'
    export LESS_TERMCAP_ue=$'\E[0m'

    zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
    zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
fi

# ── eza — modern ls replacement ──
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
# On Arch, the binary is 'bat' (not 'batcat' like Debian)
if command -v bat &>/dev/null; then
    alias cat='bat --paging=never'
fi

# ── ripgrep ──
alias rg='rg --smart-case --hidden --glob "!.git"'

# ═══════════════════════════════════════
#  Pentest workflow shortcuts
# ═══════════════════════════════════════

# serve <port>
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

# listen <port>
listen() {
    local port="${1:-4444}"
    local prefix=""
    if [[ "$port" -lt 1024 ]]; then
        prefix="sudo"
    fi
    if command -v penelope &>/dev/null; then
        echo -e "\033[0;36m[*]\033[0m Starting Penelope listener on port ${port}..."
        $prefix penelope "$port"
    else
        echo -e "\033[1;33m[!]\033[0m Penelope not found, falling back to netcat..."
        $prefix nc -lvnp "$port"
    fi
}

# myip
myip() {
    echo -e "\033[0;36m[*]\033[0m Network interfaces:"
    local iface ip
    for iface in tun0 tun1 eth0 wlan0; do
        ip=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
        if [[ -n "$ip" ]]; then
            printf "    \033[0;32m%-8s\033[0m %s\n" "$iface" "$ip"
        fi
    done
    local extip
    extip=$(curl -s --max-time 3 ifconfig.me 2>/dev/null)
    if [[ -n "$extip" ]]; then
        printf "    \033[1;33m%-8s\033[0m %s\n" "public" "$extip"
    fi
}

# cleanengagement
cleanengagement() {
    echo -e "\033[1;33m[!]\033[0m Post-engagement cleanup..."
    rm -rf /tmp/bloodhound* /tmp/sharphound* /tmp/*.exe /tmp/*.ps1 2>/dev/null
    rm -rf /tmp/kerbrute* /tmp/chisel* /tmp/ligolo* 2>/dev/null
    rm -rf /dev/shm/*.tmp 2>/dev/null
    rm -f /tmp/ntlm_theft_* /tmp/responder_* 2>/dev/null
    sudo ip neigh flush all 2>/dev/null
    if [[ -f ~/.zsh_history ]]; then
        local before after
        before=$(wc -l < ~/.zsh_history)
        sed -i '/:.*password\|:.*NTLM\|:.*secret\|:.*cred\|:.*hash.*:/Id' ~/.zsh_history 2>/dev/null
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
if command -v xclip &>/dev/null; then
    alias copy='xclip -selection clipboard'
    alias paste='xclip -selection clipboard -o'
fi

# ═══════════════════════════════════════
#  Universal extract
# ═══════════════════════════════════════
extract() {
    if [[ -z "$1" ]]; then echo "Usage: extract <archive>"; return 1; fi
    if [[ ! -f "$1" ]]; then echo -e "\033[0;31m[-]\033[0m '$1' not found"; return 1; fi
    case "$1" in
        *.tar.bz2) tar xjf "$1"        ;;
        *.tar.gz)  tar xzf "$1"        ;;
        *.tar.xz)  tar xJf "$1"        ;;
        *.tar.zst) tar --zstd -xf "$1" ;;
        *.bz2)     bunzip2 "$1"        ;;
        *.rar)     unrar x "$1"        ;;
        *.gz)      gunzip "$1"         ;;
        *.tar)     tar xf "$1"         ;;
        *.tbz2)    tar xjf "$1"        ;;
        *.tgz)     tar xzf "$1"        ;;
        *.zip)     unzip "$1"          ;;
        *.Z)       uncompress "$1"     ;;
        *.7z)      7z x "$1"           ;;
        *)         echo -e "\033[1;33m[!]\033[0m Unknown format: '$1'" ;;
    esac
}

# ═══════════════════════════════════════
#  Encoding helpers
# ═══════════════════════════════════════
alias b64d='base64 -d'
b64e() {
    if [[ -n "$1" ]]; then echo -n "$1" | base64; else base64; fi
}

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
mkvenv() {
    local name="${1:-.venv}"
    python3 -m venv "$name"
    source "$name/bin/activate"
    pip install --upgrade pip > /dev/null 2>&1
    echo -e "\033[0;32m[+]\033[0m Created and activated venv: $name"
}
activate() {
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

# ═══════════════════════════════════════
#  Zsh plugins (Arch paths)
# ═══════════════════════════════════════

# Syntax highlighting
if [ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    . /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Auto-suggestions
if [ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    . /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=244'
fi

# ── fzf — fuzzy finder ──
if [ -f /usr/share/fzf/key-bindings.zsh ]; then
    . /usr/share/fzf/key-bindings.zsh
fi
if [ -f /usr/share/fzf/completion.zsh ]; then
    . /usr/share/fzf/completion.zsh
fi
export FZF_DEFAULT_OPTS="
  --color=bg+:#24283b,bg:#1a1b26,fg:#c0caf5,fg+:#c0caf5
  --color=hl:#769ff0,hl+:#769ff0,info:#f7768e,marker:#9ece6a
  --color=prompt:#769ff0,spinner:#9ece6a,pointer:#f7768e,header:#769ff0
  --color=border:#394260,gutter:#1a1b26
  --height=40% --layout=reverse --border=rounded
"
if command -v fd &>/dev/null; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
fi

# ── zoxide — smart cd ──
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init zsh)"
fi

eval "$(starship init zsh)"
ZSHRC_EOF
    success "~/.zshrc written."

    # ---- 8b. ~/.wezterm.lua ----
    # (identical to Kali version — Wezterm config is platform-agnostic)
    backup_if_exists "$HOME/.wezterm.lua"
    info "Writing ~/.wezterm.lua..."
    cat > "$HOME/.wezterm.lua" << 'WEZTERM_EOF'
local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

config.color_scheme = 'Tokyo Night'
config.window_background_opacity = 1

config.font_size = 10
config.font = wezterm.font('FiraCode Nerd Font', { weight = 'Regular' })
config.font_rules = {
    { italic = true, font = wezterm.font('FiraCode Nerd Font', { weight = 'Regular', italic = true }) },
    { intensity = 'Bold', font = wezterm.font('FiraCode Nerd Font', { weight = 'Bold' }) },
}
config.harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1' }

config.default_cursor_style = 'SteadyBar'
config.cursor_blink_rate = 600
config.cursor_blink_ease_in = 'EaseIn'
config.cursor_blink_ease_out = 'EaseOut'
config.force_reverse_video_cursor = false

config.initial_cols = 120
config.initial_rows = 28
config.window_padding = { left = 12, right = 12, top = 10, bottom = 10 }
config.window_decorations = 'RESIZE'
config.enable_scroll_bar = false
config.scrollback_lines = 10000

config.inactive_pane_hsb = { saturation = 0.85, brightness = 0.65 }

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
        active_tab = { bg_color = '#24283b', fg_color = '#a9b1d6', intensity = 'Bold' },
        inactive_tab = { bg_color = '#1a1b26', fg_color = '#565f89' },
        inactive_tab_hover = { bg_color = '#1d2230', fg_color = '#a9b1d6' },
        new_tab = { bg_color = '#1a1b26', fg_color = '#565f89' },
        new_tab_hover = { bg_color = '#1d2230', fg_color = '#a9b1d6' },
    },
}

config.keys = {
    { key = '|', mods = 'CTRL|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
    { key = '_', mods = 'CTRL|SHIFT', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
    { key = 'LeftArrow',  mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Left' },
    { key = 'RightArrow', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Right' },
    { key = 'UpArrow',    mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Up' },
    { key = 'DownArrow',  mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Down' },
    { key = 'z', mods = 'CTRL|SHIFT', action = act.TogglePaneZoomState },
    { key = 's', mods = 'CTRL|SHIFT', action = act.PaneSelect },
    { key = 'x', mods = 'CTRL|SHIFT', action = act.PaneSelect { mode = 'SwapWithActive' } },
    { key = 'w', mods = 'CTRL|SHIFT', action = act.CloseCurrentPane { confirm = true } },
    { key = 'PageUp',   mods = 'CTRL|SHIFT', action = act.MoveTabRelative(-1) },
    { key = 'PageDown', mods = 'CTRL|SHIFT', action = act.MoveTabRelative(1) },
    { key = 'PageUp',   mods = 'CTRL', action = act.ActivateTabRelative(-1) },
    { key = 'PageDown', mods = 'CTRL', action = act.ActivateTabRelative(1) },
    { key = '=', mods = 'CTRL', action = act.IncreaseFontSize },
    { key = '-', mods = 'CTRL', action = act.DecreaseFontSize },
    { key = '0', mods = 'CTRL', action = act.ResetFontSize },
    { key = 'Space', mods = 'CTRL|SHIFT', action = act.QuickSelect },
    { key = 't', mods = 'CTRL|SHIFT', action = act.ShowTabNavigator },
    { key = 'r', mods = 'CTRL|SHIFT', action = act.PromptInputLine {
        description = 'Enter new tab name:',
        action = wezterm.action_callback(function(window, _, line)
            if line then window:active_tab():set_title(line) end
        end),
    }},
    { key = 'p', mods = 'CTRL|SHIFT', action = act.ActivateCommandPalette },
}

for i = 1, 8 do
    table.insert(config.keys, { key = tostring(i), mods = 'CTRL', action = act.ActivateTab(i - 1) })
end

config.quick_select_patterns = {
    '\\b\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\b',
    '\\b\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}/\\d{1,2}\\b',
    '[0-9a-fA-F]{2}(?::[0-9a-fA-F]{2}){5}',
    '\\b[a-fA-F0-9]{32}\\b',
    '\\b[a-fA-F0-9]{40}\\b',
    '\\b[a-fA-F0-9]{64}\\b',
    '[\\w.]+::\\w+:[a-fA-F0-9]+:[a-fA-F0-9]+:[a-fA-F0-9]+',
    '\\b\\d{1,5}/(?:tcp|udp)\\b',
    '(?:/[\\w.-]+)+',
}

config.hyperlink_rules = wezterm.default_hyperlink_rules()

return config
WEZTERM_EOF
    success "~/.wezterm.lua written."

    # ---- 8c. ~/.config/starship.toml ----
    backup_if_exists "$HOME/.config/starship.toml"
    info "Writing ~/.config/starship.toml..."
    mkdir -p "$HOME/.config"

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

    # Replace placeholders with Unicode glyphs
    python3 -c "
import sys
replacements = {
    '__RSEP__':      '\ue0b4',
    '__GRAD1__':     '\u2591',
    '__GRAD2__':     '\u2592',
    '__GRAD3__':     '\u2593',
    '__DOTS__':      '\u2026',
    '__GITICON__':   '\ue0a0',
    '__PYICON__':    '\ue73c',
    '__NODEICON__':  '\ue718',
    '__RUSTICON__':  '\ue7a8',
    '__GOICON__':    '\ue627',
    '__PHPICON__':   '\ue73d',
    '__CLOCK__':     '\uf43a',
    '__STOPWATCH__': '\u23f1',
    '__PROMPT__':    '\u276f',
    '__TARGET__':    '\U0001f3af',
    '__WRENCH__':    '\U0001f527',
    '__BOOK__':      '\U0001f4d6',
    '__DOC__':       '\U0001f4c4',
    '__INBOX__':     '\U0001f4e5',
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

    # ---- 8d. ~/.tmux.conf ----
    backup_if_exists "$HOME/.tmux.conf"
    info "Writing ~/.tmux.conf..."
    cat > "$HOME/.tmux.conf" << 'TMUX_EOF'
unbind C-b
set -g prefix C-a
bind C-a send-prefix

set -g mouse on
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -g history-limit 50000
set -sg escape-time 10

bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %
bind c new-window -c "#{pane_current_path}"
bind r source-file ~/.tmux.conf \; display "Config reloaded"

set -g status-style "bg=#1a1b26,fg=#a9b1d6"
set -g status-left "#[fg=#090c0c,bg=#a3aed2,bold] #S #[fg=#a3aed2,bg=#1a1b26] "
set -g status-right "#[fg=#394260]#[fg=#769ff0,bg=#394260] %H:%M #[fg=#a3aed2,bg=#394260]#[fg=#090c0c,bg=#a3aed2,bold] #H "
set -g status-left-length 30
setw -g window-status-format "#[fg=#808080] #I:#W "
setw -g window-status-current-format "#[fg=#769ff0,bold] #I:#W "
TMUX_EOF
    success "~/.tmux.conf written."

    # ---- 8e. ~/.ssh/config ----
    info "Writing ~/.ssh/config defaults..."
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    if [[ ! -f "$HOME/.ssh/config" ]]; then
        cat > "$HOME/.ssh/config" << 'SSH_EOF'
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 600
    HashKnownHosts no
    ForwardAgent no
SSH_EOF
        mkdir -p "$HOME/.ssh/sockets"
        chmod 600 "$HOME/.ssh/config"
        success "~/.ssh/config written."
    else
        warn "~/.ssh/config already exists — skipping."
    fi
}

# ----------------------------------------------------------
#  9. PATH, symlinks, aliases
# ----------------------------------------------------------
section_path() {
    info "Ensuring ~/Tools is on PATH..."
    if ! grep -qF 'export PATH="$HOME/Tools:$PATH"' "$HOME/.zshrc"; then
        echo "" >> "$HOME/.zshrc"
        echo "# Add ~/Tools to PATH" >> "$HOME/.zshrc"
        echo 'export PATH="$HOME/Tools:$PATH"' >> "$HOME/.zshrc"
        success "~/Tools added to PATH in .zshrc."
    else
        warn "~/Tools PATH entry already present — skipping."
    fi
}

section_wordlist_symlinks() {
    info "Creating wordlist symlinks..."
    local wl_dir="$HOME/wordlists"
    mkdir -p "$wl_dir"

    # BlackArch / Arch seclists path
    for src in /usr/share/seclists /usr/share/SecLists; do
        if [[ -d "$src" ]]; then
            ln -sfn "$src" "$wl_dir/seclists"
            success "Symlinked $src → ~/wordlists/seclists"
            break
        fi
    done

    if [[ -d /usr/share/wordlists ]]; then
        ln -sfn /usr/share/wordlists "$wl_dir/default"
        success "Symlinked /usr/share/wordlists → ~/wordlists/default"
    fi
}

section_engagement_alias() {
    info "Adding newengagement function to .zshrc..."
    if ! grep -qF 'newengagement()' "$HOME/.zshrc"; then
        cat >> "$HOME/.zshrc" << 'ENGAGE_EOF'

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

section_tool_symlinks() {
    info "Creating tool symlinks..."
    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"

    if [[ -f "$TOOLS_DIR/penelope/penelope.py" ]]; then
        chmod +x "$TOOLS_DIR/penelope/penelope.py"
        ln -sfn "$TOOLS_DIR/penelope/penelope.py" "$bin_dir/penelope"
        success "penelope → ~/.local/bin/penelope"
    fi

    if [[ -f "$TOOLS_DIR/ntlm_theft/ntlm_theft.py" ]]; then
        chmod +x "$TOOLS_DIR/ntlm_theft/ntlm_theft.py"
        ln -sfn "$TOOLS_DIR/ntlm_theft/ntlm_theft.py" "$bin_dir/ntlm_theft"
        success "ntlm_theft → ~/.local/bin/ntlm_theft"
    fi

    if [[ -d "$TOOLS_DIR/ligolo-ng" ]]; then
        local proxy_bin agent_bin
        proxy_bin=$(find "$TOOLS_DIR/ligolo-ng" -maxdepth 1 -name '*proxy*' -type f 2>/dev/null | head -1)
        agent_bin=$(find "$TOOLS_DIR/ligolo-ng" -maxdepth 1 -name '*agent*' -type f 2>/dev/null | head -1)
        [[ -n "$proxy_bin" ]] && ln -sfn "$proxy_bin" "$bin_dir/ligolo-proxy" && success "ligolo-proxy symlinked"
        [[ -n "$agent_bin" ]] && ln -sfn "$agent_bin" "$bin_dir/ligolo-agent" && success "ligolo-agent symlinked"
    fi

    if ! grep -qF 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.zshrc"; then
        echo "" >> "$HOME/.zshrc"
        echo '# Add ~/.local/bin to PATH (tool symlinks)' >> "$HOME/.zshrc"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
    fi

    if ! grep -qF 'alias toolies=' "$HOME/.zshrc"; then
        echo "" >> "$HOME/.zshrc"
        echo "alias toolies='ls -la \$HOME/Tools/Toolies/'" >> "$HOME/.zshrc"
    fi

    success "Tool symlinks configured."
}

# ----------------------------------------------------------
#  10. Set default shell to zsh
# ----------------------------------------------------------
section_shell() {
    if [[ "$SHELL" == *"zsh"* ]]; then
        warn "Default shell is already zsh — skipping."
    else
        info "Setting default shell to zsh..."
        chsh -s "$(which zsh)"
        success "Default shell set to zsh. Log out and back in to apply."
    fi
}

# ----------------------------------------------------------
#  11. Cleanup
# ----------------------------------------------------------
section_cleanup() {
    info "Cleaning up pacman cache..."
    sudo pacman -Sc --noconfirm 2>/dev/null || true
    success "Cleanup done."
}

# ============================================================================
#  Reset configs
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
    info "Backups of your previous configs saved as <filename>.bak.<timestamp>"
    warn "Run 'source ~/.zshrc' or restart your terminal to apply."
}

# ============================================================================
#  Main — full install
# ============================================================================
main() {
    info "Starting Arch + BlackArch setup..."
    echo ""

    section_system
    section_yay
    section_pacman_tools
    section_git_tools
    section_kerbrute
    section_ligolo
    section_fonts
    section_configs
    section_path
    section_wordlist_symlinks
    section_engagement_alias
    section_tool_symlinks
    section_shell
    section_cleanup

    echo ""
    success "========================================="
    success "  Arch + BlackArch setup complete!"
    success "========================================="
    echo ""
    info "Summary:"
    info "  • BlackArch repository added"
    info "  • yay (AUR helper) installed"
    info "  • Pentest tools installed via pacman"
    info "  • Tools cloned to ~/Tools (ntlm_theft, penelope, Toolies)"
    info "  • Kerbrute + Ligolo-ng binaries in ~/Tools"
    info "  • WezTerm, Starship, tmux, zsh configured"
    info "  • FiraCode Nerd Font + Roboto installed"
    info "  • fzf, zoxide, bat, eza, ripgrep ready"
    info "  • SSH config written"
    echo ""
    info "Shell functions available after restart:"
    info "  • serve, listen, myip, nquick/nfull/nudp/nvuln"
    info "  • extract, b64e/b64d, urlencode/urldecode"
    info "  • copy/paste, mkvenv/activate"
    info "  • newengagement, cleanengagement"
    echo ""
    info "Install more BlackArch tools by category:"
    info "  • sudo pacman -S blackarch-scanner"
    info "  • sudo pacman -S blackarch-exploitation"
    info "  • sudo pacman -S blackarch-cracker"
    info "  • sudo pacman -S blackarch-webapp"
    info "  • sudo pacman -S blackarch-recon"
    info "  • Or individually: sudo pacman -S <toolname>"
    echo ""
    warn "Log out and back in (or run 'source ~/.zshrc') to apply."
}

# ============================================================================
#  Entry point
# ============================================================================
case "${1:-}" in
    --reset-configs) reset_configs ;;
    --help|-h)       usage ;;
    "")              main ;;
    *)               error "Unknown flag: $1"; usage ;;
esac
