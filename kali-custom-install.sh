#!/bin/bash

#============================================
# Kali Linux Custom Setup Script
# Modified version of KaliGhost with WezTerm + Starship
#============================================

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ASCII Banner
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
    ╔═══════════════════════════════════════════════════════════╗
    ║                                                           ║
    ║     ██╗  ██╗ █████╗ ██╗     ██╗                         ║
    ║     ██║ ██╔╝██╔══██╗██║     ██║                         ║
    ║     █████╔╝ ███████║██║     ██║                         ║
    ║     ██╔═██╗ ██╔══██║██║     ██║                         ║
    ║     ██║  ██╗██║  ██║███████╗██║                         ║
    ║     ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝                         ║
    ║                                                           ║
    ║         Custom Setup - WezTerm + Starship Edition         ║
    ║                                                           ║
    ╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Logging function
log() {
    echo -e "${GREEN}[+]${NC} $1"
}

error() {
    echo -e "${RED}[!]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[*]${NC} $1"
}

info() {
    echo -e "${BLUE}[i]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check internet connectivity
check_internet() {
    log "Checking internet connectivity..."
    if ! ping -c 1 google.com &> /dev/null; then
        error "No internet connection. Please connect and try again."
        exit 1
    fi
    log "Internet connection verified"
}

# Update system
update_system() {
    log "Updating system packages..."
    apt update -y && apt upgrade -y
    if [ $? -eq 0 ]; then
        log "System updated successfully"
    else
        error "Failed to update system"
        exit 1
    fi
}

# Install base dependencies
install_dependencies() {
    log "Installing base dependencies..."
    
    local packages=(
        "build-essential"
        "git"
        "curl"
        "wget"
        "vim"
        "neovim"
        "tmux"
        "zsh"
        "htop"
        "unzip"
        "tar"
        "python3"
        "python3-pip"
        "fonts-powerline"
        "fonts-nerd-font-hack"
        "fonts-font-awesome"
        "feh"
        "rofi"
        "polybar"
        "picom"
        "dunst"
        "xclip"
        "xsel"
        "scrot"
        "maim"
        "nitrogen"
        "lxappearance"
        "thunar"
        "neofetch"
        "figlet"
        "lolcat"
    )
    
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package"; then
            info "Installing $package..."
            apt install -y "$package" || warn "Failed to install $package"
        else
            info "$package already installed"
        fi
    done
    
    log "Base dependencies installed"
}

# Install i3 window manager
install_i3() {
    log "Installing i3 window manager..."
    
    apt install -y i3 i3status i3lock i3blocks
    
    if [ $? -eq 0 ]; then
        log "i3 window manager installed successfully"
    else
        error "Failed to install i3"
        exit 1
    fi
}

# Install WezTerm
install_wezterm() {
    log "Installing WezTerm terminal emulator..."
    
    # Add WezTerm repository
    info "Adding WezTerm repository..."
    curl -fsSL https://apt.fury.io/wez/gpg.key | gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
    echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | tee /etc/apt/sources.list.d/wezterm.list
    chmod 644 /usr/share/keyrings/wezterm-fury.gpg
    
    # Update and install
    apt update
    apt install -y wezterm
    
    if command -v wezterm &> /dev/null; then
        log "WezTerm installed successfully"
        wezterm --version
    else
        error "WezTerm installation failed"
        exit 1
    fi
}

# Install Starship prompt
install_starship() {
    log "Installing Starship prompt..."
    
    # Install via official script
    curl -sS https://starship.rs/install.sh | sh -s -- -y
    
    if command -v starship &> /dev/null; then
        log "Starship installed successfully"
        starship --version
    else
        error "Starship installation failed"
        exit 1
    fi
}

# Install Oh-My-Zsh
install_oh_my_zsh() {
    log "Installing Oh-My-Zsh..."
    
    # Get the actual user (not root)
    ACTUAL_USER="${SUDO_USER:-$USER}"
    ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)
    
    if [ -d "$ACTUAL_HOME/.oh-my-zsh" ]; then
        warn "Oh-My-Zsh already installed, skipping..."
        return
    fi
    
    # Install for actual user
    su - $ACTUAL_USER -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
    
    log "Oh-My-Zsh installed successfully"
}

# Install Zsh plugins
install_zsh_plugins() {
    log "Installing Zsh plugins..."
    
    ACTUAL_USER="${SUDO_USER:-$USER}"
    ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)
    ZSH_CUSTOM="$ACTUAL_HOME/.oh-my-zsh/custom"
    
    # zsh-autosuggestions
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
        info "Installing zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    fi
    
    # zsh-syntax-highlighting
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
        info "Installing zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    fi
    
    # zsh-completions
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-completions" ]; then
        info "Installing zsh-completions..."
        git clone https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions"
    fi
    
    # Change ownership
    chown -R $ACTUAL_USER:$ACTUAL_USER "$ZSH_CUSTOM"
    
    log "Zsh plugins installed"
}

# Install Neovim plugins manager (vim-plug)
install_neovim_plugins() {
    log "Installing Neovim plugin manager..."
    
    ACTUAL_USER="${SUDO_USER:-$USER}"
    ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)
    
    # Install vim-plug for Neovim
    su - $ACTUAL_USER -c "curl -fLo $ACTUAL_HOME/.local/share/nvim/site/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
    
    log "Neovim plugin manager installed"
}

# Install GTK theme (Catppuccin)
install_gtk_theme() {
    log "Installing Catppuccin GTK theme..."
    
    # Create themes directory
    mkdir -p /usr/share/themes
    
    # Clone Catppuccin GTK theme
    cd /tmp
    if [ -d "catppuccin-gtk-theme" ]; then
        rm -rf catppuccin-gtk-theme
    fi
    
    git clone https://github.com/Fausto-Korpsvart/Catppuccin-GTK-Theme.git catppuccin-gtk-theme
    
    if [ -d "catppuccin-gtk-theme" ]; then
        cp -r catppuccin-gtk-theme/themes/* /usr/share/themes/ 2>/dev/null || warn "Some themes may not have copied"
        log "Catppuccin GTK theme installed"
    else
        warn "Failed to clone Catppuccin theme"
    fi
}

# Install icon theme
install_icon_theme() {
    log "Installing icon theme..."
    
    mkdir -p /usr/share/icons
    
    # Install Papirus icon theme
    apt install -y papirus-icon-theme
    
    log "Icon theme installed"
}

# Install additional tools
install_additional_tools() {
    log "Installing additional pentesting tools..."
    
    local tools=(
        "terminator"
        "ranger"
        "bat"
        "exa"
        "ripgrep"
        "fd-find"
        "fzf"
        "tldr"
    )
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            info "Installing $tool..."
            apt install -y "$tool" 2>/dev/null || warn "Failed to install $tool"
        fi
    done
    
    log "Additional tools installed"
}

# Install FiraCode Nerd Font
install_firacode_font() {
    log "Installing FiraCode Nerd Font..."
    
    ACTUAL_USER="${SUDO_USER:-$USER}"
    ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)
    FONT_DIR="$ACTUAL_HOME/.local/share/fonts"
    
    # Create font directory
    su - $ACTUAL_USER -c "mkdir -p $FONT_DIR"
    
    # Download FiraCode Nerd Font
    cd /tmp
    wget -q https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/FiraCode.zip -O FiraCode.zip
    
    if [ -f "FiraCode.zip" ]; then
        unzip -q -o FiraCode.zip -d "$FONT_DIR/FiraCode"
        rm FiraCode.zip
        
        # Update font cache
        fc-cache -f "$FONT_DIR"
        
        log "FiraCode Nerd Font installed successfully"
    else
        warn "Failed to download FiraCode Nerd Font"
    fi
}

# Setup config directories
setup_config_dirs() {
    log "Setting up configuration directories..."
    
    ACTUAL_USER="${SUDO_USER:-$USER}"
    ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)
    
    # Create necessary directories
    su - $ACTUAL_USER -c "mkdir -p $ACTUAL_HOME/.config/{i3,polybar,rofi,picom,dunst,neofetch,nvim}"
    su - $ACTUAL_USER -c "mkdir -p $ACTUAL_HOME/.local/share/fonts"
    su - $ACTUAL_USER -c "mkdir -p $ACTUAL_HOME/Pictures/wallpapers"
    
    log "Configuration directories created"
}

# Create WezTerm config
create_wezterm_config() {
    log "Creating WezTerm configuration..."
    
    ACTUAL_USER="${SUDO_USER:-$USER}"
    ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)
    WEZTERM_CONFIG="$ACTUAL_HOME/.wezterm.lua"
    
    cat > "$WEZTERM_CONFIG" << 'EOF'
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
EOF
    
    chown $ACTUAL_USER:$ACTUAL_USER "$WEZTERM_CONFIG"
    log "WezTerm configuration created"
}

# Create Starship config
create_starship_config() {
    log "Creating Starship configuration..."
    
    ACTUAL_USER="${SUDO_USER:-$USER}"
    ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)
    STARSHIP_CONFIG="$ACTUAL_HOME/.config/starship.toml"
    
    cat > "$STARSHIP_CONFIG" << 'EOF'
"$schema" = 'https://starship.rs/config-schema.json'
format = """
[░▒▓](#a3aed2)\
[ icysec](bg:#a3aed2 fg:#090c0c)\
[](bg:#769ff0 fg:#a3aed2)\
$directory\
[](fg:#769ff0 bg:#394260)\
$git_branch\
$git_status\
[](fg:#394260 bg:#212736)\
$nodejs\
$rust\
$golang\
$php\
[](fg:#212736 bg:#1d2230)\
[ ](fg:#1d2230)\
\n   $character"""
[directory]
style = "fg:#090c0c bg:#769ff0"
format = "[ $path ]($style)"
truncation_length = 3
truncation_symbol = "…/"
[directory.substitutions]
#"Documents" = "󰈙 "
#"Downloads" = " "
#"Music" = " "
#"Pictures" = " "
[git_branch]
symbol = ""
style = "bg:#394260"
format = '[[ $symbol $branch ](fg:#769ff0 bg:#394260)]($style)'
[git_status]
style = "bg:#394260"
format = '[[($all_status$ahead_behind )](fg:#769ff0 bg:#394260)]($style)'
[nodejs]
symbol = ""
style = "bg:#212736"
format = '[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)'
[rust]
symbol = ""
style = "bg:#212736"
format = '[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)'
[golang]
symbol = ""
style = "bg:#212736"
format = '[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)'
[php]
symbol = ""
style = "bg:#212736"
format = '[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)'
[time]
disabled = false
time_format = "%R" # Hour:Minute Format
style = "bg:#1d2230"
format = '[[  $time ](fg:#a0a9cb bg:#1d2230)]($style)'
[character]
success_symbol = '[❯](#769ff0)'
EOF
    
    chown $ACTUAL_USER:$ACTUAL_USER "$STARSHIP_CONFIG"
    log "Starship configuration created"
}

# Create Zsh config
create_zsh_config() {
    log "Creating Zsh configuration..."
    
    ACTUAL_USER="${SUDO_USER:-$USER}"
    ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)
    ZSHRC="$ACTUAL_HOME/.zshrc"
    
    cat > "$ZSHRC" << 'EOF'
# Path to oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Theme (disabled because we use Starship)
ZSH_THEME=""

# Plugins
plugins=(
    git
    sudo
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
    docker
    python
    golang
)

source $ZSH/oh-my-zsh.sh

# User configuration
export EDITOR='nvim'
export VISUAL='nvim'

# Aliases
alias v='nvim'
alias vim='nvim'
alias ls='exa --icons --group-directories-first'
alias ll='exa -l --icons --group-directories-first'
alias la='exa -la --icons --group-directories-first'
alias lt='exa --tree --level=2 --icons'
alias cat='bat --style=plain --paging=never'
alias grep='rg'
alias find='fd'
alias cls='clear'
alias update='sudo apt update && sudo apt upgrade -y'
alias ports='netstat -tulanp'

# Custom functions
mkcd() {
    mkdir -p "$1" && cd "$1"
}

extract() {
    if [ -f $1 ] ; then
        case $1 in
            *.tar.bz2)   tar xjf $1     ;;
            *.tar.gz)    tar xzf $1     ;;
            *.bz2)       bunzip2 $1     ;;
            *.rar)       unrar e $1     ;;
            *.gz)        gunzip $1      ;;
            *.tar)       tar xf $1      ;;
            *.tbz2)      tar xjf $1     ;;
            *.tgz)       tar xzf $1     ;;
            *.zip)       unzip $1       ;;
            *.Z)         uncompress $1  ;;
            *.7z)        7z x $1        ;;
            *)     echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Initialize Starship prompt
eval "$(starship init zsh)"

# Neofetch on terminal start
if [ -f /usr/bin/neofetch ]; then
    neofetch
fi
EOF
    
    chown $ACTUAL_USER:$ACTUAL_USER "$ZSHRC"
    log "Zsh configuration created"
}

# Create basic i3 config
create_i3_config() {
    log "Creating i3 window manager configuration..."
    
    ACTUAL_USER="${SUDO_USER:-$USER}"
    ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)
    I3_CONFIG="$ACTUAL_HOME/.config/i3/config"
    
    cat > "$I3_CONFIG" << 'EOF'
# i3 config file

set $mod Mod4

# Font
font pango:JetBrainsMono Nerd Font 10

# Use Mouse+$mod to drag floating windows
floating_modifier $mod

# Start terminal
bindsym $mod+Return exec wezterm

# Kill focused window
bindsym $mod+Shift+q kill

# Start rofi
bindsym $mod+d exec --no-startup-id rofi -show drun

# Change focus
bindsym $mod+h focus left
bindsym $mod+j focus down
bindsym $mod+k focus up
bindsym $mod+l focus right

# Move focused window
bindsym $mod+Shift+h move left
bindsym $mod+Shift+j move down
bindsym $mod+Shift+k move up
bindsym $mod+Shift+l move right

# Split orientation
bindsym $mod+v split h
bindsym $mod+s split v

# Fullscreen
bindsym $mod+f fullscreen toggle

# Toggle tiling / floating
bindsym $mod+Shift+space floating toggle

# Change focus between tiling / floating
bindsym $mod+space focus mode_toggle

# Workspaces
set $ws1 "1"
set $ws2 "2"
set $ws3 "3"
set $ws4 "4"
set $ws5 "5"
set $ws6 "6"
set $ws7 "7"
set $ws8 "8"
set $ws9 "9"
set $ws10 "10"

# Switch to workspace
bindsym $mod+1 workspace number $ws1
bindsym $mod+2 workspace number $ws2
bindsym $mod+3 workspace number $ws3
bindsym $mod+4 workspace number $ws4
bindsym $mod+5 workspace number $ws5
bindsym $mod+6 workspace number $ws6
bindsym $mod+7 workspace number $ws7
bindsym $mod+8 workspace number $ws8
bindsym $mod+9 workspace number $ws9
bindsym $mod+0 workspace number $ws10

# Move container to workspace
bindsym $mod+Shift+1 move container to workspace number $ws1
bindsym $mod+Shift+2 move container to workspace number $ws2
bindsym $mod+Shift+3 move container to workspace number $ws3
bindsym $mod+Shift+4 move container to workspace number $ws4
bindsym $mod+Shift+5 move container to workspace number $ws5
bindsym $mod+Shift+6 move container to workspace number $ws6
bindsym $mod+Shift+7 move container to workspace number $ws7
bindsym $mod+Shift+8 move container to workspace number $ws8
bindsym $mod+Shift+9 move container to workspace number $ws9
bindsym $mod+Shift+0 move container to workspace number $ws10

# Reload config
bindsym $mod+Shift+c reload

# Restart i3
bindsym $mod+Shift+r restart

# Exit i3
bindsym $mod+Shift+e exec "i3-msg exit"

# Resize mode
mode "resize" {
    bindsym h resize shrink width 10 px or 10 ppt
    bindsym j resize grow height 10 px or 10 ppt
    bindsym k resize shrink height 10 px or 10 ppt
    bindsym l resize grow width 10 px or 10 ppt
    
    bindsym Return mode "default"
    bindsym Escape mode "default"
}

bindsym $mod+r mode "resize"

# Colors (Catppuccin Mocha)
set $rosewater #f5e0dc
set $flamingo  #f2cdcd
set $pink      #f5c2e7
set $mauve     #cba6f7
set $red       #f38ba8
set $maroon    #eba0ac
set $peach     #fab387
set $yellow    #f9e2af
set $green     #a6e3a1
set $teal      #94e2d5
set $sky       #89dceb
set $sapphire  #74c7ec
set $blue      #89b4fa
set $lavender  #b4befe
set $text      #cdd6f4
set $subtext1  #bac2de
set $subtext0  #a6adc8
set $overlay2  #9399b2
set $overlay1  #7f849c
set $overlay0  #6c7086
set $surface2  #585b70
set $surface1  #45475a
set $surface0  #313244
set $base      #1e1e2e
set $mantle    #181825
set $crust     #11111b

# Window colors
client.focused           $mauve    $base $text  $mauve   $mauve
client.focused_inactive  $surface0 $base $text  $surface0 $surface0
client.unfocused         $surface0 $base $text  $surface0 $surface0
client.urgent            $red      $base $red   $red     $red
client.placeholder       $surface0 $base $text  $surface0 $surface0
client.background        $base

# Window settings
for_window [class=".*"] border pixel 2
gaps inner 10
gaps outer 5

# Startup applications
exec_always --no-startup-id $HOME/.config/polybar/launch.sh
exec --no-startup-id picom --config $HOME/.config/picom/picom.conf
exec --no-startup-id dunst
exec --no-startup-id nitrogen --restore
EOF
    
    chown $ACTUAL_USER:$ACTUAL_USER "$I3_CONFIG"
    log "i3 configuration created"
}

# Create Polybar config
create_polybar_config() {
    log "Creating Polybar configuration..."
    
    ACTUAL_USER="${SUDO_USER:-$USER}"
    ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)
    POLYBAR_DIR="$ACTUAL_HOME/.config/polybar"
    
    mkdir -p "$POLYBAR_DIR"
    
    # Create polybar config
    cat > "$POLYBAR_DIR/config.ini" << 'EOF'
[colors]
background = #1e1e2e
background-alt = #313244
foreground = #cdd6f4
primary = #cba6f7
secondary = #89b4fa
alert = #f38ba8
disabled = #6c7086

[bar/main]
width = 100%
height = 24pt
radius = 0

background = ${colors.background}
foreground = ${colors.foreground}

line-size = 3pt

border-size = 0
border-color = #00000000

padding-left = 1
padding-right = 1

module-margin = 1

separator = |
separator-foreground = ${colors.disabled}

font-0 = JetBrainsMono Nerd Font:size=10;2

modules-left = xworkspaces xwindow
modules-right = filesystem pulseaudio memory cpu wlan eth date

cursor-click = pointer
cursor-scroll = ns-resize

enable-ipc = true

[module/xworkspaces]
type = internal/xworkspaces

label-active = %name%
label-active-background = ${colors.background-alt}
label-active-underline= ${colors.primary}
label-active-padding = 1

label-occupied = %name%
label-occupied-padding = 1

label-urgent = %name%
label-urgent-background = ${colors.alert}
label-urgent-padding = 1

label-empty = %name%
label-empty-foreground = ${colors.disabled}
label-empty-padding = 1

[module/xwindow]
type = internal/xwindow
label = %title:0:60:...%

[module/filesystem]
type = internal/fs
interval = 25

mount-0 = /

label-mounted = %{F#89b4fa}%mountpoint%%{F-} %percentage_used%%

label-unmounted = %mountpoint% not mounted
label-unmounted-foreground = ${colors.disabled}

[module/pulseaudio]
type = internal/pulseaudio

format-volume-prefix = "VOL "
format-volume-prefix-foreground = ${colors.primary}
format-volume = <label-volume>

label-volume = %percentage%%

label-muted = muted
label-muted-foreground = ${colors.disabled}

[module/memory]
type = internal/memory
interval = 2
format-prefix = "RAM "
format-prefix-foreground = ${colors.primary}
label = %percentage_used:2%%

[module/cpu]
type = internal/cpu
interval = 2
format-prefix = "CPU "
format-prefix-foreground = ${colors.primary}
label = %percentage:2%%

[network-base]
type = internal/network
interval = 5
format-connected = <label-connected>
format-disconnected = <label-disconnected>
label-disconnected = %{F#f38ba8}%ifname%%{F#6c7086} disconnected

[module/wlan]
inherit = network-base
interface-type = wireless
label-connected = %{F#89b4fa}%ifname%%{F-} %essid% %local_ip%

[module/eth]
inherit = network-base
interface-type = wired
label-connected = %{F#89b4fa}%ifname%%{F-} %local_ip%

[module/date]
type = internal/date
interval = 1

date = %H:%M
date-alt = %Y-%m-%d %H:%M:%S

label = %date%
label-foreground = ${colors.primary}

[settings]
screenchange-reload = true
pseudo-transparency = true
EOF
    
    # Create launch script
    cat > "$POLYBAR_DIR/launch.sh" << 'EOF'
#!/bin/bash

# Terminate already running bar instances
killall -q polybar

# Wait until the processes have been shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

# Launch bar
polybar main 2>&1 | tee -a /tmp/polybar.log & disown

echo "Polybar launched..."
EOF
    
    chmod +x "$POLYBAR_DIR/launch.sh"
    chown -R $ACTUAL_USER:$ACTUAL_USER "$POLYBAR_DIR"
    
    log "Polybar configuration created"
}

# Create Picom config
create_picom_config() {
    log "Creating Picom configuration..."
    
    ACTUAL_USER="${SUDO_USER:-$USER}"
    ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)
    PICOM_CONFIG="$ACTUAL_HOME/.config/picom/picom.conf"
    
    mkdir -p "$(dirname "$PICOM_CONFIG")"
    
    cat > "$PICOM_CONFIG" << 'EOF'
# Picom configuration

# Backend
backend = "glx";
glx-no-stencil = true;
glx-copy-from-front = false;

# Opacity
inactive-opacity = 0.95;
active-opacity = 1.0;
frame-opacity = 1.0;
inactive-opacity-override = false;

# Fading
fading = true;
fade-delta = 4;
fade-in-step = 0.03;
fade-out-step = 0.03;

# Shadows
shadow = true;
shadow-radius = 12;
shadow-offset-x = -7;
shadow-offset-y = -7;
shadow-opacity = 0.5;

# Blur
blur-background = false;

# Corner radius
corner-radius = 8;

# Other
mark-wmwin-focused = true;
mark-ovredir-focused = true;
detect-rounded-corners = true;
detect-client-opacity = true;
vsync = true;
dbe = false;
focus-exclude = [ ];

wintypes:
{
    tooltip = { fade = true; shadow = true; opacity = 0.95; focus = true; };
    dock = { shadow = false; }
    dnd = { shadow = false; }
};
EOF
    
    chown $ACTUAL_USER:$ACTUAL_USER "$PICOM_CONFIG"
    log "Picom configuration created"
}

# Create Rofi config
create_rofi_config() {
    log "Creating Rofi configuration..."
    
    ACTUAL_USER="${SUDO_USER:-$USER}"
    ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)
    ROFI_CONFIG="$ACTUAL_HOME/.config/rofi/config.rasi"
    
    mkdir -p "$(dirname "$ROFI_CONFIG")"
    
    cat > "$ROFI_CONFIG" << 'EOF'
configuration {
    modi: "drun,run,window";
    show-icons: true;
    terminal: "wezterm";
    drun-display-format: "{name}";
    location: 0;
    disable-history: false;
    hide-scrollbar: true;
    display-drun: " Apps";
    display-run: " Run";
    display-window: " Window";
    sidebar-mode: true;
}

@theme "~/.config/rofi/catppuccin-mocha.rasi"
EOF
    
    # Create Catppuccin theme
    cat > "$ACTUAL_HOME/.config/rofi/catppuccin-mocha.rasi" << 'EOF'
* {
    bg-col:  #1e1e2e;
    bg-col-light: #313244;
    border-col: #cba6f7;
    selected-col: #45475a;
    blue: #89b4fa;
    fg-col: #cdd6f4;
    fg-col2: #f38ba8;
    grey: #6c7086;

    width: 600;
    font: "JetBrainsMono Nerd Font 12";
}

element-text, element-icon , mode-switcher {
    background-color: inherit;
    text-color:       inherit;
}

window {
    height: 360px;
    border: 3px;
    border-color: @border-col;
    background-color: @bg-col;
}

mainbox {
    background-color: @bg-col;
}

inputbar {
    children: [prompt,entry];
    background-color: @bg-col;
    border-radius: 5px;
    padding: 2px;
}

prompt {
    background-color: @blue;
    padding: 6px;
    text-color: @bg-col;
    border-radius: 3px;
    margin: 20px 0px 0px 20px;
}

textbox-prompt-colon {
    expand: false;
    str: ":";
}

entry {
    padding: 6px;
    margin: 20px 0px 0px 10px;
    text-color: @fg-col;
    background-color: @bg-col;
}

listview {
    border: 0px 0px 0px;
    padding: 6px 0px 0px;
    margin: 10px 0px 0px 20px;
    columns: 1;
    lines: 5;
    background-color: @bg-col;
}

element {
    padding: 5px;
    background-color: @bg-col;
    text-color: @fg-col  ;
}

element-icon {
    size: 25px;
}

element selected {
    background-color:  @selected-col ;
    text-color: @fg-col2  ;
}

mode-switcher {
    spacing: 0;
  }

button {
    padding: 10px;
    background-color: @bg-col-light;
    text-color: @grey;
    vertical-align: 0.5; 
    horizontal-align: 0.5;
}

button selected {
  background-color: @bg-col;
  text-color: @blue;
}

message {
    background-color: @bg-col-light;
    margin: 2px;
    padding: 2px;
    border-radius: 5px;
}

textbox {
    padding: 6px;
    margin: 20px 0px 0px 20px;
    text-color: @blue;
    background-color: @bg-col-light;
}
EOF
    
    chown -R $ACTUAL_USER:$ACTUAL_USER "$ACTUAL_HOME/.config/rofi"
    log "Rofi configuration created"
}

# Change default shell to Zsh
change_default_shell() {
    log "Changing default shell to Zsh..."
    
    ACTUAL_USER="${SUDO_USER:-$USER}"
    
    chsh -s $(which zsh) $ACTUAL_USER
    
    log "Default shell changed to Zsh"
}

# Final message
show_completion() {
    clear
    echo -e "${GREEN}"
    cat << "EOF"
    ╔═══════════════════════════════════════════════════════════╗
    ║                                                           ║
    ║              Installation Complete! ✓                     ║
    ║                                                           ║
    ║     Your Kali Linux setup is ready with:                 ║
    ║     • i3 Window Manager                                   ║
    ║     • WezTerm Terminal                                    ║
    ║     • Starship Prompt                                     ║
    ║     • Zsh with Oh-My-Zsh                                  ║
    ║     • Polybar Status Bar                                  ║
    ║     • Rofi Launcher                                       ║
    ║     • Catppuccin Theme                                    ║
    ║                                                           ║
    ║     Please REBOOT your system and select i3 at login     ║
    ║                                                           ║
    ╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    info "Keybindings:"
    echo "  Mod+Enter       - Open WezTerm terminal"
    echo "  Mod+d           - Open Rofi launcher"
    echo "  Mod+Shift+q     - Close window"
    echo "  Mod+Shift+e     - Exit i3"
    echo "  Mod+Shift+r     - Restart i3"
    echo ""
    warn "Remember to reboot: sudo reboot"
}

# Main installation flow
main() {
    show_banner
    
    log "Starting Kali Linux custom setup..."
    
    check_root
    check_internet
    update_system
    install_dependencies
    install_i3
    install_wezterm
    install_starship
    install_oh_my_zsh
    install_zsh_plugins
    install_neovim_plugins
    install_gtk_theme
    install_icon_theme
    install_additional_tools
    install_firacode_font
    setup_config_dirs
    create_wezterm_config
    create_starship_config
    create_zsh_config
    create_i3_config
    create_polybar_config
    create_picom_config
    create_rofi_config
    change_default_shell
    
    show_completion
}

# Run main function
main "$@"
