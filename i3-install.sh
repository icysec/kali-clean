#!/usr/bin/env bash
# ============================================================================
#  i3-setup.sh — i3 window manager setup for Arch/BlackArch
#  Tokyo Night themed — matches WezTerm/Starship from arch-setup.sh
#
#  Run AFTER arch-setup.sh. Installs i3, polybar, picom, rofi, dunst,
#  and writes all config files.
#
#  Usage:  chmod +x i3-setup.sh && ./i3-setup.sh
# ============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[*]${NC} $*"; }
success() { echo -e "${GREEN}[+]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[-]${NC} $*"; }

if [[ "$EUID" -eq 0 ]]; then
    error "Run as your normal user, not root."
    exit 1
fi

# ----------------------------------------------------------
#  1. Install packages
# ----------------------------------------------------------
info "Installing i3 and related packages..."

sudo pacman -S --needed --noconfirm \
    i3-wm \
    i3lock \
    i3status \
    polybar \
    picom \
    rofi \
    dunst \
    feh \
    flameshot \
    arandr \
    lxappearance \
    arc-gtk-theme \
    papirus-icon-theme \
    xdg-utils \
    xorg-xrandr \
    xorg-xsetroot \
    xclip \
    playerctl \
    brightnessctl \
    network-manager-applet \
    pavucontrol \
    pulseaudio-utils \
    ttf-font-awesome \
    unclutter

success "Packages installed."

# ----------------------------------------------------------
#  2. i3 config
# ----------------------------------------------------------
info "Writing i3 config..."
mkdir -p "$HOME/.config/i3"

cat > "$HOME/.config/i3/config" << 'I3_EOF'
# ═══════════════════════════════════════
#  i3 config — Tokyo Night
# ═══════════════════════════════════════

# Mod key = Super (Windows key)
set $mod Mod4

# ── Fonts ──
font pango:FiraCode Nerd Font 10

# ── Terminal ──
bindsym $mod+Return exec wezterm

# ── Kill focused window ──
bindsym $mod+Shift+q kill

# ── App launcher (rofi) ──
bindsym $mod+d exec --no-startup-id rofi -show drun -show-icons
bindsym $mod+Tab exec --no-startup-id rofi -show window -show-icons

# ── Screenshot ──
bindsym Print exec --no-startup-id flameshot gui
bindsym $mod+Shift+s exec --no-startup-id flameshot gui

# ── Lock screen ──
bindsym $mod+l exec --no-startup-id i3lock -c 1a1b26

# ── Focus (arrow keys) ──
bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right

# ── Move windows (Shift + arrow keys) ──
bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right

# ── Focus (vim keys) ──
bindsym $mod+h focus left
bindsym $mod+j focus down
bindsym $mod+k focus up
# Note: $mod+l is lock screen; use arrows or $mod+semicolon for right
bindsym $mod+semicolon focus right

# ── Move (vim keys) ──
bindsym $mod+Shift+h move left
bindsym $mod+Shift+j move down
bindsym $mod+Shift+k move up
bindsym $mod+Shift+semicolon move right

# ── Split direction ──
bindsym $mod+b split h
bindsym $mod+v split v

# ── Fullscreen ──
bindsym $mod+f fullscreen toggle

# ── Layout ──
bindsym $mod+s layout stacking
bindsym $mod+w layout tabbed
bindsym $mod+e layout toggle split

# ── Floating ──
bindsym $mod+Shift+space floating toggle
bindsym $mod+space focus mode_toggle
floating_modifier $mod

# ── Scratchpad ──
bindsym $mod+Shift+minus move scratchpad
bindsym $mod+minus scratchpad show

# ── Workspaces ──
set $ws1  "1"
set $ws2  "2"
set $ws3  "3"
set $ws4  "4"
set $ws5  "5"
set $ws6  "6"
set $ws7  "7"
set $ws8  "8"
set $ws9  "9"
set $ws10 "10"

bindsym $mod+1 workspace $ws1
bindsym $mod+2 workspace $ws2
bindsym $mod+3 workspace $ws3
bindsym $mod+4 workspace $ws4
bindsym $mod+5 workspace $ws5
bindsym $mod+6 workspace $ws6
bindsym $mod+7 workspace $ws7
bindsym $mod+8 workspace $ws8
bindsym $mod+9 workspace $ws9
bindsym $mod+0 workspace $ws10

bindsym $mod+Shift+1 move container to workspace $ws1
bindsym $mod+Shift+2 move container to workspace $ws2
bindsym $mod+Shift+3 move container to workspace $ws3
bindsym $mod+Shift+4 move container to workspace $ws4
bindsym $mod+Shift+5 move container to workspace $ws5
bindsym $mod+Shift+6 move container to workspace $ws6
bindsym $mod+Shift+7 move container to workspace $ws7
bindsym $mod+Shift+8 move container to workspace $ws8
bindsym $mod+Shift+9 move container to workspace $ws9
bindsym $mod+Shift+0 move container to workspace $ws10

# ── Resize mode ──
mode "resize" {
    bindsym Left  resize shrink width 5 px or 5 ppt
    bindsym Down  resize grow height 5 px or 5 ppt
    bindsym Up    resize shrink height 5 px or 5 ppt
    bindsym Right resize grow width 5 px or 5 ppt
    bindsym h     resize shrink width 5 px or 5 ppt
    bindsym j     resize grow height 5 px or 5 ppt
    bindsym k     resize shrink height 5 px or 5 ppt
    bindsym semicolon resize grow width 5 px or 5 ppt

    bindsym Return mode "default"
    bindsym Escape mode "default"
    bindsym $mod+r mode "default"
}
bindsym $mod+r mode "resize"

# ── Reload / Restart / Exit ──
bindsym $mod+Shift+c reload
bindsym $mod+Shift+r restart
bindsym $mod+Shift+e exec "i3-nagbar -t warning -m 'Exit i3?' -B 'Yes' 'i3-msg exit'"

# ── Volume ──
bindsym XF86AudioRaiseVolume exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ +5%
bindsym XF86AudioLowerVolume exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ -5%
bindsym XF86AudioMute exec --no-startup-id pactl set-sink-mute @DEFAULT_SINK@ toggle
bindsym XF86AudioMicMute exec --no-startup-id pactl set-source-mute @DEFAULT_SOURCE@ toggle

# ── Brightness ──
bindsym XF86MonBrightnessUp exec --no-startup-id brightnessctl set +5%
bindsym XF86MonBrightnessDown exec --no-startup-id brightnessctl set 5%-

# ── Window appearance — Tokyo Night ──
# class                 border  bg      text    indicator child_border
client.focused          #769ff0 #24283b #c0caf5 #769ff0   #769ff0
client.focused_inactive #394260 #1a1b26 #565f89 #394260   #394260
client.unfocused        #1a1b26 #1a1b26 #565f89 #1a1b26   #1a1b26
client.urgent           #f7768e #f7768e #1a1b26 #f7768e   #f7768e
client.placeholder      #1a1b26 #1a1b26 #565f89 #1a1b26   #1a1b26
client.background       #1a1b26

# ── Window rules ──
default_border pixel 2
default_floating_border pixel 2
hide_edge_borders smart
gaps inner 8
gaps outer 2
smart_gaps on

# ── Float rules ──
for_window [class="Pavucontrol"] floating enable
for_window [class="Arandr"] floating enable
for_window [class="Lxappearance"] floating enable
for_window [class="flameshot"] floating enable
for_window [class="feh"] floating enable

# ── Autostart ──
exec_always --no-startup-id $HOME/.config/polybar/launch.sh
exec_always --no-startup-id picom --config $HOME/.config/picom/picom.conf -b
exec --no-startup-id feh --bg-fill $HOME/.wallpaper/wallpaper.jpg || xsetroot -solid '#1a1b26'
exec --no-startup-id dunst
exec --no-startup-id unclutter --timeout 3
exec --no-startup-id nm-applet
I3_EOF

success "~/.config/i3/config written."

# ----------------------------------------------------------
#  3. Polybar config
# ----------------------------------------------------------
info "Writing polybar config..."
mkdir -p "$HOME/.config/polybar"

cat > "$HOME/.config/polybar/config.ini" << 'POLYBAR_EOF'
; ═══════════════════════════════════════
;  Polybar — Tokyo Night
; ═══════════════════════════════════════

[colors]
background = #1a1b26
background-alt = #24283b
foreground = #a9b1d6
foreground-alt = #565f89
primary = #769ff0
secondary = #a3aed2
alert = #f7768e
success = #9ece6a
warning = #e0af68
cyan = #7dcfff

[bar/main]
monitor = ${env:MONITOR:}
width = 100%
height = 28pt
radius = 0
dpi = 0

background = ${colors.background}
foreground = ${colors.foreground}

line-size = 2pt

border-size = 0
border-color = #00000000

padding-left = 1
padding-right = 2

module-margin = 1

separator = |
separator-foreground = ${colors.foreground-alt}

font-0 = FiraCode Nerd Font:size=10;2
font-1 = Font Awesome 6 Free Solid:size=10;2
font-2 = FiraCode Nerd Font:size=14;3

modules-left = i3
modules-center = date
modules-right = filesystem pulseaudio memory cpu network tray

cursor-click = pointer
cursor-scroll = ns-resize

enable-ipc = true

wm-restack = i3

[module/i3]
type = internal/i3
pin-workspaces = true
show-urgent = true
strip-wsnumbers = true
index-sort = true

label-focused = %index%
label-focused-background = ${colors.background-alt}
label-focused-foreground = ${colors.primary}
label-focused-underline = ${colors.primary}
label-focused-padding = 2

label-unfocused = %index%
label-unfocused-foreground = ${colors.foreground-alt}
label-unfocused-padding = 2

label-visible = %index%
label-visible-foreground = ${colors.foreground-alt}
label-visible-padding = 2

label-urgent = %index%
label-urgent-background = ${colors.alert}
label-urgent-foreground = ${colors.background}
label-urgent-padding = 2

[module/filesystem]
type = internal/fs
interval = 30
mount-0 = /
label-mounted = %{F#769ff0}%{F-} %percentage_used%%
label-unmounted = %mountpoint% n/a

[module/pulseaudio]
type = internal/pulseaudio
label-volume = %{F#769ff0}%{F-} %percentage%%
label-muted = %{F#f7768e}%{F-} muted
label-muted-foreground = ${colors.foreground-alt}
click-right = pavucontrol

[module/memory]
type = internal/memory
interval = 3
label = %{F#769ff0}%{F-} %percentage_used%%
warn-percentage = 90

[module/cpu]
type = internal/cpu
interval = 3
label = %{F#769ff0}%{F-} %percentage%%
warn-percentage = 80

[module/network]
type = internal/network
interface-type = wired
interval = 5
label-connected = %{F#9ece6a}%{F-} %local_ip%
label-disconnected = %{F#f7768e}%{F-} disconnected

[module/network-vpn]
type = internal/network
interface = tun0
interval = 5
label-connected = %{F#e0af68}%{F-} %local_ip%
label-disconnected =

[module/date]
type = internal/date
interval = 1
date = %a %b %d
time = %H:%M:%S
label = %{F#769ff0}%{F-} %date%  %{F#769ff0}%{F-} %time%
label-foreground = ${colors.foreground}

[module/tray]
type = internal/tray
tray-spacing = 8px
tray-size = 65%

[settings]
screenchange-reload = true
pseudo-transparency = false

[global/wm]
margin-top = 0
margin-bottom = 0
POLYBAR_EOF

# Polybar launch script
cat > "$HOME/.config/polybar/launch.sh" << 'LAUNCH_EOF'
#!/usr/bin/env bash
# Terminate existing polybar instances
killall -q polybar
# Wait for processes to shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done
# Launch on all monitors
if type "xrandr" > /dev/null 2>&1; then
    for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
        MONITOR=$m polybar --reload main 2>&1 | tee -a /tmp/polybar.log &
    done
else
    polybar --reload main 2>&1 | tee -a /tmp/polybar.log &
fi
LAUNCH_EOF
chmod +x "$HOME/.config/polybar/launch.sh"

success "Polybar config written."

# ----------------------------------------------------------
#  4. Picom config
# ----------------------------------------------------------
info "Writing picom config..."
mkdir -p "$HOME/.config/picom"

cat > "$HOME/.config/picom/picom.conf" << 'PICOM_EOF'
# ═══════════════════════════════════════
#  Picom compositor — Tokyo Night
# ═══════════════════════════════════════

# Backend
backend = "glx";
vsync = true;
glx-no-stencil = true;
glx-no-rebind-pixmap = true;

# Opacity
active-opacity = 1.0;
inactive-opacity = 0.92;
frame-opacity = 1.0;
inactive-opacity-override = false;

# Opacity rules
opacity-rule = [
    "100:class_g = 'Rofi'",
    "100:class_g = 'Polybar'",
    "100:class_g = 'i3lock'",
    "100:class_g = 'flameshot'",
];

# Fading
fading = true;
fade-in-step = 0.04;
fade-out-step = 0.04;
fade-delta = 5;

# Rounded corners
corner-radius = 8;
rounded-corners-exclude = [
    "class_g = 'Polybar'",
    "class_g = 'i3bar'",
];

# Shadow
shadow = true;
shadow-radius = 12;
shadow-offset-x = -7;
shadow-offset-y = -7;
shadow-opacity = 0.5;
shadow-color = "#000000";
shadow-exclude = [
    "class_g = 'Polybar'",
    "class_g = 'i3-frame'",
    "_GTK_FRAME_EXTENTS@:c",
];

# Blur (background blur for transparent windows)
blur-method = "dual_kawase";
blur-strength = 5;
blur-background-exclude = [
    "class_g = 'Polybar'",
    "class_g = 'slop'",
    "class_g = 'flameshot'",
];

# Focus
focus-exclude = [
    "class_g = 'Rofi'",
];

# Misc
detect-rounded-corners = true;
detect-client-opacity = true;
detect-transient = true;
use-damage = true;
log-level = "warn";
PICOM_EOF

success "Picom config written."

# ----------------------------------------------------------
#  5. Rofi config
# ----------------------------------------------------------
info "Writing rofi config..."
mkdir -p "$HOME/.config/rofi"

cat > "$HOME/.config/rofi/config.rasi" << 'ROFI_EOF'
/* ═══════════════════════════════════════
 *  Rofi — Tokyo Night
 * ═══════════════════════════════════════ */

configuration {
    modi: "drun,run,window";
    show-icons: true;
    icon-theme: "Papirus-Dark";
    terminal: "wezterm";
    font: "FiraCode Nerd Font 11";
    display-drun: " Apps";
    display-run: " Run";
    display-window: " Windows";
}

* {
    bg:       #1a1b26;
    bg-alt:   #24283b;
    fg:       #a9b1d6;
    fg-alt:   #565f89;
    accent:   #769ff0;
    urgent:   #f7768e;
    border:   #394260;

    background-color: transparent;
    text-color: @fg;
}

window {
    width: 600px;
    background-color: @bg;
    border: 2px solid;
    border-color: @border;
    border-radius: 12px;
    padding: 0;
}

mainbox {
    padding: 12px;
}

inputbar {
    background-color: @bg-alt;
    border-radius: 8px;
    padding: 10px 16px;
    margin: 0 0 12px 0;
    children: [ prompt, entry ];
    spacing: 8px;
}

prompt {
    text-color: @accent;
}

entry {
    placeholder: "Search...";
    placeholder-color: @fg-alt;
}

listview {
    lines: 8;
    columns: 1;
    fixed-height: true;
    spacing: 4px;
    scrollbar: false;
}

element {
    padding: 8px 12px;
    border-radius: 6px;
}

element normal.normal {
    background-color: transparent;
}

element selected.normal {
    background-color: @bg-alt;
    text-color: @accent;
}

element alternate.normal {
    background-color: transparent;
}

element-icon {
    size: 22px;
    margin: 0 8px 0 0;
}

element-text {
    vertical-align: 0.5;
}
ROFI_EOF

success "Rofi config written."

# ----------------------------------------------------------
#  6. Dunst config (notifications)
# ----------------------------------------------------------
info "Writing dunst config..."
mkdir -p "$HOME/.config/dunst"

cat > "$HOME/.config/dunst/dunstrc" << 'DUNST_EOF'
# ═══════════════════════════════════════
#  Dunst — Tokyo Night notifications
# ═══════════════════════════════════════

[global]
    monitor = 0
    follow = mouse
    width = 350
    height = 120
    origin = top-right
    offset = 16x50
    notification_limit = 5
    progress_bar = true

    indicate_hidden = yes
    shrink = no
    separator_height = 2
    separator_color = "#394260"
    padding = 12
    horizontal_padding = 16
    text_icon_padding = 12

    frame_width = 2
    frame_color = "#394260"
    corner_radius = 8

    sort = yes
    idle_threshold = 120

    font = FiraCode Nerd Font 10
    line_height = 2
    markup = full
    format = "<b>%s</b>\n%b"
    alignment = left
    vertical_alignment = center
    show_age_threshold = 60
    word_wrap = yes
    ellipsize = middle

    icon_position = left
    min_icon_size = 32
    max_icon_size = 48
    icon_path = /usr/share/icons/Papirus-Dark/48x48/status/:/usr/share/icons/Papirus-Dark/48x48/devices/:/usr/share/icons/Papirus-Dark/48x48/apps/

    browser = /usr/bin/xdg-open
    mouse_left_click = close_current
    mouse_middle_click = do_action, close_current
    mouse_right_click = close_all

[urgency_low]
    background = "#1a1b26"
    foreground = "#a9b1d6"
    frame_color = "#394260"
    timeout = 5

[urgency_normal]
    background = "#1a1b26"
    foreground = "#a9b1d6"
    frame_color = "#769ff0"
    timeout = 10

[urgency_critical]
    background = "#1a1b26"
    foreground = "#f7768e"
    frame_color = "#f7768e"
    timeout = 0
DUNST_EOF

success "Dunst config written."

# ----------------------------------------------------------
#  7. Wallpaper directory
# ----------------------------------------------------------
info "Setting up wallpaper..."
mkdir -p "$HOME/.wallpaper"

if [[ ! -f "$HOME/.wallpaper/wallpaper.jpg" ]]; then
    # Generate a simple Tokyo Night gradient as placeholder
    if command -v convert &>/dev/null; then
        convert -size 1920x1080 \
            -define gradient:angle=135 \
            gradient:'#1a1b26-#24283b' \
            "$HOME/.wallpaper/wallpaper.jpg"
        success "Placeholder wallpaper generated."
    else
        warn "ImageMagick not found — no wallpaper set."
        warn "Place your wallpaper at ~/.wallpaper/wallpaper.jpg"
    fi
else
    warn "Wallpaper already exists — skipping."
fi

# fehbg for persistent wallpaper
cat > "$HOME/.fehbg" << 'FEHBG_EOF'
#!/bin/sh
feh --no-fehbg --bg-fill "$HOME/.wallpaper/wallpaper.jpg"
FEHBG_EOF
chmod +x "$HOME/.fehbg"

# ----------------------------------------------------------
#  8. GTK theme setup (for rofi, file managers, etc.)
# ----------------------------------------------------------
info "Setting GTK theme..."
mkdir -p "$HOME/.config/gtk-3.0"

cat > "$HOME/.config/gtk-3.0/settings.ini" << 'GTK_EOF'
[Settings]
gtk-theme-name=Arc-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Roboto 10
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=0
gtk-enable-input-feedback-sounds=0
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
gtk-application-prefer-dark-theme=1
GTK_EOF

# GTK2
cat > "$HOME/.gtkrc-2.0" << 'GTK2_EOF'
gtk-theme-name="Arc-Dark"
gtk-icon-theme-name="Papirus-Dark"
gtk-font-name="Roboto 10"
gtk-cursor-theme-name="Adwaita"
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=0
gtk-enable-input-feedback-sounds=0
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle="hintslight"
gtk-xft-rgba="rgb"
GTK2_EOF

success "GTK theme set to Arc-Dark + Papirus-Dark icons."

# ----------------------------------------------------------
#  Done
# ----------------------------------------------------------
echo ""
success "========================================="
success "  i3 setup complete!"
success "========================================="
echo ""
info "Configs written:"
info "  • ~/.config/i3/config          (i3 window manager)"
info "  • ~/.config/polybar/config.ini (status bar)"
info "  • ~/.config/polybar/launch.sh  (polybar launcher)"
info "  • ~/.config/picom/picom.conf   (compositor)"
info "  • ~/.config/rofi/config.rasi   (app launcher)"
info "  • ~/.config/dunst/dunstrc      (notifications)"
info "  • ~/.config/gtk-3.0/settings.ini (GTK theme)"
echo ""
info "Next steps:"
info "  1. Log out"
info "  2. Select 'i3' from the session menu on the login screen"
info "  3. Log in — i3 + polybar + picom will autostart"
info "  4. Drop your wallpaper at ~/.wallpaper/wallpaper.jpg"
echo ""
info "Key bindings (Super = Mod key):"
info "  Super+Return        → WezTerm"
info "  Super+d             → Rofi app launcher"
info "  Super+Tab           → Rofi window switcher"
info "  Super+Shift+q       → Kill window"
info "  Super+Arrow/hjk;    → Focus window"
info "  Super+Shift+Arrow   → Move window"
info "  Super+1-9           → Switch workspace"
info "  Super+Shift+1-9     → Move to workspace"
info "  Super+f             → Fullscreen"
info "  Super+v/b           → Split vertical/horizontal"
info "  Super+r             → Resize mode (arrows to resize, Esc to exit)"
info "  Super+Shift+Space   → Toggle floating"
info "  Super+l             → Lock screen"
info "  Print               → Screenshot (flameshot)"
info "  Super+Shift+r       → Restart i3"
info "  Super+Shift+c       → Reload config"
echo ""
warn "Run 'lxappearance' after first login to verify the GTK theme."
