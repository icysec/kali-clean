# Kali Linux Custom Setup Script
## WezTerm + Starship Edition

A comprehensive automated setup script for Kali Linux with custom branding and toolkits.

---

## 🎯 Features

### Core Components
- **Window Manager**: i3 with gaps
- **Terminal**: WezTerm (GPU-accelerated) with **Tokyo Night theme**
- **Prompt**: Starship with **custom "icysec" design**
- **Shell**: Zsh with Oh-My-Zsh
- **Status Bar**: Polybar
- **Compositor**: Picom (transparency & effects)
- **Launcher**: Rofi
- **Theme**: Catppuccin Mocha for i3/Rofi
- **Editor**: Neovim

### Custom Configuration Highlights

**WezTerm**:
- Tokyo Night color scheme
- FiraCode Nerd Font (auto-installed)
- Custom tab bar with matching colors
- 120x28 window size
- No transparency (solid background)

**Starship**:
- Custom gradient prompt with "icysec" branding
- Git integration with status indicators
- Language version displays (Node, Rust, Go, PHP)
- Time display
- Color scheme matching Tokyo Night

### Included Tools
- **File Managers**: Ranger, Thunar
- **System Monitors**: htop, neofetch
- **Modern CLI Tools**: 
  - `bat` (better cat)
  - `exa` (better ls)
  - `ripgrep` (better grep)
  - `fd` (better find)
  - `fzf` (fuzzy finder)

### Zsh Plugins
- zsh-autosuggestions
- zsh-syntax-highlighting
- zsh-completions

---

## 📋 Prerequisites

- Fresh Kali Linux installation (recommended)
- Root/sudo access
- Active internet connection
- Minimum 4GB RAM
- 10GB free disk space

---

## 🚀 Installation

### Quick Install (One Command)

```bash
curl -o kali-custom-install.sh https://raw.githubusercontent.com/<your-repo>/kali-custom-install.sh
chmod +x kali-custom-install.sh
sudo ./kali-custom-install.sh
```

### Manual Install

1. **Clone or download the script**:
```bash
git clone <your-repo-url>
cd <repo-name>
```

2. **Make it executable**:
```bash
chmod +x kali-custom-install.sh
```

3. **Run the script**:
```bash
sudo ./kali-custom-install.sh
```

4. **Reboot your system**:
```bash
sudo reboot
```

5. **At login, select i3 from the session dropdown**

---

## ⌨️ Key Bindings

### i3 Window Manager

| Action | Keybinding |
|--------|-----------|
| Open terminal (WezTerm) | `Mod + Enter` |
| Open Rofi launcher | `Mod + d` |
| Close focused window | `Mod + Shift + q` |
| Toggle fullscreen | `Mod + f` |
| Toggle floating | `Mod + Shift + Space` |
| Exit i3 | `Mod + Shift + e` |
| Restart i3 | `Mod + Shift + r` |
| Reload i3 config | `Mod + Shift + c` |
| Enter resize mode | `Mod + r` |

### Navigation

| Action | Keybinding |
|--------|-----------|
| Focus left | `Mod + h` |
| Focus down | `Mod + j` |
| Focus up | `Mod + k` |
| Focus right | `Mod + l` |
| Move window left | `Mod + Shift + h` |
| Move window down | `Mod + Shift + j` |
| Move window up | `Mod + Shift + k` |
| Move window right | `Mod + Shift + l` |

### Workspaces

| Action | Keybinding |
|--------|-----------|
| Switch to workspace 1-10 | `Mod + 1-0` |
| Move to workspace 1-10 | `Mod + Shift + 1-0` |

### Splits

| Action | Keybinding |
|--------|-----------|
| Split horizontal | `Mod + v` |
| Split vertical | `Mod + s` |

**Note**: `Mod` key is typically the Windows/Super key

---

## 🎨 Customization

### WezTerm Configuration

Edit: `~/.wezterm.lua` (in home directory root)

The script installs with **Tokyo Night theme** and these settings:
- Font: FiraCode Nerd Font (size 10)
- Color scheme: Tokyo Night
- Window size: 120x28
- Opacity: 1.0 (no transparency)
- Custom tab bar with matching Tokyo Night colors

```lua
-- Change font size
config.font_size = 11

-- Change to a different font
config.font = wezterm.font 'JetBrainsMono Nerd Font'

-- Add transparency
config.window_background_opacity = 0.95

-- Change color scheme
config.color_scheme = 'Dracula'
```

Available color schemes: https://wezfurlong.org/wezterm/colorschemes/index.html

### Starship Prompt

Edit: `~/.config/starship.toml`

The script uses a **custom "icysec" themed prompt**:
- Gradient blocks: `░▒▓`
- Custom branding: `icysec`
- Git status with branch indicator
- Language versions (Node.js, Rust, Go, PHP)
- Current time display
- Tokyo Night color palette

```toml
# Change the username/branding
[ icysec](bg:#a3aed2 fg:#090c0c)\
# Change to your username:
[ yourname](bg:#a3aed2 fg:#090c0c)\

# The prompt uses these colors:
# - #a3aed2 (light blue)
# - #769ff0 (medium blue)
# - #394260 (dark blue-gray)
# - #212736 (darker gray)
# - #1d2230 (darkest gray)
```

Browse more presets: https://starship.rs/presets/

### i3 Configuration

Edit: `~/.config/i3/config`

```bash
# Change gap sizes
gaps inner 15
gaps outer 10

# Change border size
for_window [class=".*"] border pixel 3

# Add custom keybindings
bindsym $mod+b exec firefox

# Colors use Catppuccin Mocha scheme
```

### Polybar

Edit: `~/.config/polybar/config.ini`

```ini
# Change bar height
height = 28pt

# Change modules
modules-left = xworkspaces xwindow
modules-center = date
modules-right = memory cpu temperature battery
```

### Zsh Aliases

Edit: `~/.zshrc`

The script includes these custom aliases:

```bash
# Pre-configured aliases
v / vim              # Neovim
ls / ll / la         # exa with icons
cat                  # bat with syntax
grep                 # ripgrep
find                 # fd-find
cls                  # clear
update               # system update
ports                # show ports
```

Add your own:

```bash
# Custom aliases (add to ~/.zshrc)
alias scan='nmap -sV -sC'
alias metasploit='msfconsole'
alias burp='java -jar ~/tools/burpsuite.jar'
```

---

## 🔧 Post-Installation

### Set Wallpaper

```bash
# Copy wallpaper to directory
cp your-wallpaper.jpg ~/Pictures/wallpapers/

# Set with nitrogen
nitrogen ~/Pictures/wallpapers/
```

Or edit i3 config:

```bash
exec_always --no-startup-id feh --bg-scale ~/Pictures/wallpapers/your-wallpaper.jpg
```

### Configure GTK Theme

```bash
# Open theme selector
lxappearance
```

Select:
- Widget: Catppuccin-Mocha-Standard-Mauve-Dark
- Icon Theme: Papirus-Dark
- Font: FiraCode Nerd Font 10

### Install Additional Fonts (Optional)

```bash
# Other popular Nerd Fonts
cd ~/.local/share/fonts

# JetBrainsMono
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/JetBrainsMono.zip
unzip JetBrainsMono.zip
rm JetBrainsMono.zip

# Hack
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/Hack.zip
unzip Hack.zip
rm Hack.zip

# Refresh font cache
fc-cache -fv
```

---

## 🐛 Troubleshooting

### WezTerm won't start

```bash
# Check if installed
wezterm --version

# Check config syntax
wezterm check-config

# Reinstall
sudo apt remove wezterm
sudo apt install wezterm
```

### Starship not showing

```bash
# Verify installation
starship --version

# Check if initialized in .zshrc
cat ~/.zshrc | grep starship
# Should show: eval "$(starship init zsh)"

# Reinstall
curl -sS https://starship.rs/install.sh | sh
```

### FiraCode font not displaying

```bash
# Check if installed
fc-list | grep -i fira

# Reinstall font
cd /tmp
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/FiraCode.zip
unzip FiraCode.zip -d ~/.local/share/fonts/FiraCode
fc-cache -fv
```

### Polybar not launching

```bash
# Check logs
tail -f /tmp/polybar.log

# Restart manually
~/.config/polybar/launch.sh
```

### i3 config errors

```bash
# Check for errors
i3 -C

# Reload config
i3-msg reload
```

### Custom prompt not showing "icysec"

The prompt displays "icysec" by default. To customize:

```bash
# Edit starship config
nano ~/.config/starship.toml

# Change line:
[ icysec](bg:#a3aed2 fg:#090c0c)\
# To your username:
[ jacob](bg:#a3aed2 fg:#090c0c)\
```

---

## 📁 Configuration File Locations

| Component | Config Location |
|-----------|-----------------|
| WezTerm | `~/.wezterm.lua` (home directory root) |
| Starship | `~/.config/starship.toml` |
| Zsh | `~/.zshrc` |
| i3 | `~/.config/i3/config` |
| Polybar | `~/.config/polybar/config.ini` |
| Picom | `~/.config/picom/picom.conf` |
| Rofi | `~/.config/rofi/config.rasi` |
| Neovim | `~/.config/nvim/init.vim` |

---

## 🔄 Updating

### Update Starship

```bash
curl -sS https://starship.rs/install.sh | sh
```

### Update WezTerm

```bash
sudo apt update
sudo apt upgrade wezterm
```

### Update Zsh plugins

```bash
cd ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git pull

cd ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
git pull
```

---

## 🗑️ Uninstallation

To remove everything installed by this script:

```bash
# Remove i3 and components
sudo apt remove --purge i3 i3status i3lock polybar rofi picom dunst

# Remove WezTerm
sudo apt remove --purge wezterm

# Remove Starship
sudo rm -f /usr/local/bin/starship

# Remove Oh-My-Zsh
rm -rf ~/.oh-my-zsh

# Remove config directories
rm -rf ~/.config/i3
rm -rf ~/.wezterm.lua
rm -rf ~/.config/polybar
rm -rf ~/.config/rofi
rm -rf ~/.config/picom
rm -rf ~/.config/starship.toml

# Change shell back to bash
chsh -s /bin/bash

# Reboot
sudo reboot
```

---

## 📚 Resources

### Documentation
- [i3 User Guide](https://i3wm.org/docs/userguide.html)
- [WezTerm Documentation](https://wezfurlong.org/wezterm/)
- [Starship Configuration](https://starship.rs/config/)
- [Polybar Wiki](https://github.com/polybar/polybar/wiki)
- [Rofi Manual](https://github.com/davatorium/rofi)

### Themes & Customization
- [Tokyo Night Theme](https://github.com/folke/tokyonight.nvim)
- [Catppuccin](https://github.com/catppuccin/catppuccin)
- [Nerd Fonts](https://www.nerdfonts.com/)
- [Starship Presets](https://starship.rs/presets/)
- [WezTerm Color Schemes](https://wezfurlong.org/wezterm/colorschemes/index.html)

### Learning Resources
- [i3 Tutorial](https://www.youtube.com/watch?v=j1I63wGcvU4)
- [Zsh Guide](https://scriptingosx.com/2019/06/moving-to-zsh/)
- [Vim/Neovim Tutorial](https://www.openvim.com/)

---

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

---

## 📝 License

This script is released under the GPL-3.0 License.

---

## 💬 Support

If you encounter any issues:

1. Check the Troubleshooting section above
2. Verify configuration file locations
3. Review WezTerm/Starship documentation
4. Check that FiraCode font is installed: `fc-list | grep -i fira`

---

## 🎓 Quick Start Guide

### First Login After Installation

1. Select **i3** from login screen dropdown
2. Press `Mod+Enter` to open WezTerm
3. You'll see the custom "icysec" Starship prompt
4. Press `Mod+d` to open Rofi launcher
5. Type application names to launch them

### Essential First Commands

```bash
# Check your prompt is working
echo $SHELL  # Should show /usr/bin/zsh

# Check Starship
starship --version

# Check WezTerm
wezterm --version

# List installed fonts
fc-list | grep -i nerd
```

---

Happy hacking with your custom setup! 🐲💀
