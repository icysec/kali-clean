# Quick Reference Cheatsheet

## i3 Window Manager

### Essential
```
Mod + Enter          Open terminal
Mod + d              Open launcher
Mod + Shift + q      Kill window
Mod + Shift + e      Exit i3
Mod + Shift + r      Restart i3
```

### Navigation
```
Mod + h/j/k/l        Focus left/down/up/right
Mod + Shift + h/j/k/l Move window left/down/up/right
```

### Layout
```
Mod + v              Split horizontal
Mod + s              Split vertical
Mod + f              Fullscreen
Mod + Shift + Space  Toggle floating
Mod + r              Resize mode (then h/j/k/l)
```

### Workspaces
```
Mod + 1-0            Switch to workspace 1-10
Mod + Shift + 1-0    Move container to workspace 1-10
```

## WezTerm Terminal

### Panes
```
Ctrl + Shift + -     Split vertical
Ctrl + Shift + =     Split horizontal
Ctrl + Shift + w     Close pane
```

### Navigation
```
Ctrl + Shift + h/j/k/l Navigate between panes
```

### Copy/Paste
```
Ctrl + Shift + c     Copy
Ctrl + Shift + v     Paste
```

## Zsh Aliases

```bash
v / vim              Open Neovim
ls / ll / la         Better ls with exa
cat                  Better cat with bat
grep                 Ripgrep
find                 fd-find
cls                  Clear screen
update               System update
ports                Show open ports
```

## Custom Functions

```bash
mkcd <dir>           Create and cd into directory
extract <file>       Auto-extract any archive
```

## Rofi Launcher

```
Mod + d              Open launcher
Type to search       Filter applications
Enter                Launch selected app
Escape               Close launcher
```

## Pentesting Quick Commands

```bash
# Network scanning
nmap -sV -sC <target>
netdiscover -r <range>

# Web enumeration
gobuster dir -u <url> -w <wordlist>
nikto -h <target>

# Password attacks
hydra -l <user> -P <wordlist> <target> ssh
john --wordlist=<wordlist> <hash-file>

# Exploitation
msfconsole
searchsploit <search-term>

# Post-exploitation
linpeas.sh
python3 -m http.server 8000
```

## Systemctl Common Commands

```bash
systemctl start <service>
systemctl stop <service>
systemctl restart <service>
systemctl status <service>
systemctl enable <service>
systemctl disable <service>
```

## Git Quick Commands

```bash
git status
git add .
git commit -m "message"
git push origin main
git pull
git log --oneline
```

## File Operations

```bash
# Find files
fd <pattern>
find . -name <pattern>

# Search in files
rg <pattern>
grep -r <pattern> .

# Navigate
ranger          # Terminal file manager
thunar          # GUI file manager
```

## System Info

```bash
neofetch        # System info with style
htop            # Process monitor
df -h           # Disk usage
free -h         # Memory usage
ip a            # Network interfaces
```

## Screen/Screenshot

```bash
scrot           # Full screenshot
maim            # Better screenshot tool
maim -s         # Select area
```

## Tmux Alternative (in WezTerm)

WezTerm has built-in multiplexing:
- Use Ctrl+Shift+- and Ctrl+Shift+= for splits
- No need for tmux with WezTerm!

## Tips

1. Hold Mod key to drag floating windows
2. Mod + Right-click to resize windows
3. Use Mod + d (Rofi) instead of memorizing commands
4. Customize ~/.config/starship.toml for your perfect prompt
5. Edit ~/.zshrc for custom aliases and functions

## Emergency

```bash
# i3 not responding?
Ctrl + Alt + F2          # Switch to TTY2
killall i3               # Kill i3
startx                   # Restart X

# Reset configs
mv ~/.config/i3 ~/.config/i3.bak
# Re-run install script or restore defaults
```

## Remember

- **Mod** = Windows/Super key
- Config files in `~/.config/`
- Reload i3: Mod + Shift + r
- Check logs: `~/.xsession-errors` or `/tmp/polybar.log`
