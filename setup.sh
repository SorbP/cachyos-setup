#!/bin/bash
# CachyOS post-install — ASUS TUF FX505DV
# Kör som vanlig användare (inte root). sudo-lösenord krävs vid behov.
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
info() { echo -e "${CYAN}[..] $*${NC}"; }
warn() { echo -e "${YELLOW}[!!]${NC} $*"; }
die()  { echo -e "${RED}[FEL]${NC} $*"; exit 1; }

echo -e "\n${CYAN}=== CachyOS post-install: FX505DV ===${NC}\n"

# ---------------------------------------------------------------------------
# 0. Kontrollera nätverk
# ---------------------------------------------------------------------------
info "Kontrollerar nätverksanslutning..."
ping -c 1 -W 3 archlinux.org &>/dev/null || die "Ingen nätverksanslutning."
ok "Nätverk OK"

# ---------------------------------------------------------------------------
# 1. Systemuppdatering
# ---------------------------------------------------------------------------
info "Uppdaterar systemet..."
sudo pacman -Syu --noconfirm
ok "System uppdaterat"

# ---------------------------------------------------------------------------
# 2. yay
# ---------------------------------------------------------------------------
if ! command -v yay &>/dev/null; then
    info "Installerar yay..."
    sudo pacman -S --noconfirm --needed git base-devel
    git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
    (cd /tmp/yay-bin && makepkg -si --noconfirm)
    rm -rf /tmp/yay-bin
    ok "yay installerat"
else
    ok "yay redan installerat"
fi

# ---------------------------------------------------------------------------
# 3. Hårdvara
# ---------------------------------------------------------------------------
info "Installerar hårdvarupaket..."
yay -S --noconfirm --needed envycontrol
yay -S --noconfirm --needed faustus-dkms
ok "Hårdvarupaket installerade"

# ---------------------------------------------------------------------------
# 4. Realtek 8822CE WiFi
# ---------------------------------------------------------------------------
info "Konfigurerar Realtek 8822CE (rtw88)..."
echo "options rtw88_8822ce disable_lps_deep=1 ips=0" | sudo tee /etc/modprobe.d/rtw88.conf > /dev/null
ok "WiFi-tweaken skriven"

# ---------------------------------------------------------------------------
# 5. Terminal-stack
# ---------------------------------------------------------------------------
info "Installerar terminal-stack..."
sudo pacman -S --noconfirm --needed \
    kitty zellij fish starship yazi \
    ffmpegthumbnailer jq poppler fd ripgrep fzf zoxide wofi

yay -S --noconfirm --needed ttf-jetbrains-mono-nerd
ok "Terminal-stack installerad"

# ---------------------------------------------------------------------------
# 6. Fish som default shell
# ---------------------------------------------------------------------------
FISH_PATH="$(which fish)"
if [ "$SHELL" != "$FISH_PATH" ]; then
    info "Sätter Fish som default shell..."
    sudo chsh -s "$FISH_PATH" "$USER"
    ok "Fish är nu default shell (gäller efter omstart)"
else
    ok "Fish är redan default shell"
fi

# ---------------------------------------------------------------------------
# 7. Configs (inbäddade — ingen nätverkshämtning)
# ---------------------------------------------------------------------------
info "Installerar configs..."

# Kitty — Okabe-Ito Deutan tema
mkdir -p "$HOME/.config/kitty/themes"
cat > "$HOME/.config/kitty/themes/okabe-ito-deutan.conf" << 'KITTY_EOF'
# Okabe-Ito Deutan — colorblind-friendly theme
background            #1c1c1c
foreground            #f0e442
selection_background  #0072b2
selection_foreground  #ffffff
cursor                #e69f00
cursor_text_color     #1c1c1c

color0   #1c1c1c
color8   #666666
color1   #d55e00
color9   #e69f00
color2   #56b4e9
color10  #009e73
color3   #f0e442
color11  #f0e442
color4   #0072b2
color12  #56b4e9
color5   #cc79a7
color13  #cc79a7
color6   #009e73
color14  #56b4e9
color7   #dddddd
color15  #ffffff
KITTY_EOF

if [ ! -f "$HOME/.config/kitty/kitty.conf" ]; then
    touch "$HOME/.config/kitty/kitty.conf"
fi
grep -q "okabe-ito-deutan" "$HOME/.config/kitty/kitty.conf" || \
    echo "include themes/okabe-ito-deutan.conf" >> "$HOME/.config/kitty/kitty.conf"

# Starship — Okabe-Ito Deutan
cat > "$HOME/.config/starship.toml" << 'STARSHIP_EOF'
[character]
success_symbol = "[❯](bold #009e73)"
error_symbol   = "[❯](bold #d55e00)"

[directory]
style = "bold #56b4e9"
truncation_length = 3

[git_branch]
style  = "bold #e69f00"
symbol = " "

[git_status]
style = "#cc79a7"

[cmd_duration]
style    = "#f0e442"
min_time = 500

[username]
style_user  = "bold #0072b2"
show_always = false
STARSHIP_EOF

# Fish config
FISH_CONFIG="$HOME/.config/fish/config.fish"
mkdir -p "$(dirname "$FISH_CONFIG")"
grep -q "starship init" "$FISH_CONFIG" 2>/dev/null || \
    echo 'starship init fish | source' >> "$FISH_CONFIG"
grep -q "alias ls" "$FISH_CONFIG" 2>/dev/null || \
    echo "alias ls='eza --icons'" >> "$FISH_CONFIG"
grep -q "alias ll" "$FISH_CONFIG" 2>/dev/null || \
    echo "alias ll='eza --icons -la'" >> "$FISH_CONFIG"
grep -q "MANGOHUD" "$FISH_CONFIG" 2>/dev/null || \
    echo 'set -x MANGOHUD 1' >> "$FISH_CONFIG"

ok "Configs installerade"

# ---------------------------------------------------------------------------
# 8. Hyprland — svenska tangentbord + keybinds
# ---------------------------------------------------------------------------
info "Konfigurerar Hyprland..."
HYPR_CONF="$HOME/.config/hypr/hyprland.conf"
if [ -f "$HYPR_CONF" ]; then
    if ! grep -q "kb_layout" "$HYPR_CONF"; then
        cat >> "$HYPR_CONF" << 'HYPR_EOF'

# === Tillagt av setup.sh ===
input {
    kb_layout = se
}

bind = SUPER, R, exec, wofi --show drun
bind = SUPER, Q, killactive
bind = SUPER, F, fullscreen
bind = SUPER, V, togglefloating
bind = SUPER, left, movefocus, l
bind = SUPER, right, movefocus, r
bind = SUPER, up, movefocus, u
bind = SUPER, down, movefocus, d
HYPR_EOF
        ok "Hyprland keybinds + svenska tangentbord lagt till"
    else
        warn "Hyprland input redan konfigurerat — hoppar över"
    fi
else
    warn "hyprland.conf hittades inte — hoppar över"
fi

# ---------------------------------------------------------------------------
# 9. VS Code
# ---------------------------------------------------------------------------
info "Installerar VS Code..."
yay -S --noconfirm --needed visual-studio-code-bin

VSCODE_SETTINGS="$HOME/.config/Code/User/settings.json"
mkdir -p "$(dirname "$VSCODE_SETTINGS")"
if [ ! -f "$VSCODE_SETTINGS" ]; then
    cat > "$VSCODE_SETTINGS" << 'VSCODE_EOF'
{
    "editor.fontFamily": "'JetBrainsMono Nerd Font', monospace",
    "editor.fontSize": 14,
    "editor.fontLigatures": true,
    "terminal.integrated.fontFamily": "'JetBrainsMono Nerd Font'",
    "workbench.colorCustomizations": {
        "terminal.ansiBlack":   "#1c1c1c",
        "terminal.ansiRed":     "#d55e00",
        "terminal.ansiGreen":   "#009e73",
        "terminal.ansiYellow":  "#f0e442",
        "terminal.ansiBlue":    "#0072b2",
        "terminal.ansiMagenta": "#cc79a7",
        "terminal.ansiCyan":    "#56b4e9",
        "terminal.ansiWhite":   "#dddddd"
    }
}
VSCODE_EOF
    ok "VS Code settings installerade"
else
    warn "VS Code settings finns redan — hoppar över"
fi

# ---------------------------------------------------------------------------
# 10. Program
# ---------------------------------------------------------------------------
info "Installerar program..."

sudo pacman -S --noconfirm --needed \
    steam discord btop mangohud nvtop flatpak

yay -S --noconfirm --needed \
    teamspeak6-client fsearch-git onedrive-abraunegg arduino-ide-bin gwe

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub com.usebottles.bottles || warn "Bottles misslyckades"


sudo pacman -S --noconfirm --needed python-pip python-pipx
pipx install platformio

ok "Program installerade"

# ---------------------------------------------------------------------------
# 11. CLI-verktyg
# ---------------------------------------------------------------------------
info "Installerar CLI-verktyg..."
sudo pacman -S --noconfirm --needed \
    bat eza dust duf tldr fastfetch \
    p7zip unzip wget ffmpeg yt-dlp nmap bandwhich
ok "CLI-verktyg installerade"

# ---------------------------------------------------------------------------
# 12. Claude Code
# ---------------------------------------------------------------------------
info "Installerar Claude Code..."
sudo pacman -S --noconfirm --needed nodejs npm
npm install -g @anthropic-ai/claude-code
ok "Claude Code installerat — kör 'claude' för att logga in"

# ---------------------------------------------------------------------------
# 13. Wootility AppImage
# ---------------------------------------------------------------------------
info "Laddar ner Wootility..."
WOOTILITY_APPIMAGE=$(curl -fsSL "https://api.github.com/repos/WootingKb/wootility/releases/latest" \
    | grep -oP '"browser_download_url": "\K[^"]+\.AppImage') || true
if [ -n "${WOOTILITY_APPIMAGE:-}" ]; then
    mkdir -p "$HOME/Applications"
    curl -fsSL "$WOOTILITY_APPIMAGE" -o "$HOME/Applications/Wootility.AppImage"
    chmod +x "$HOME/Applications/Wootility.AppImage"
    ok "Wootility nedladdad till ~/Applications/"
else
    warn "Kunde inte hämta Wootility — ladda ner manuellt från wooting.io"
fi

# ---------------------------------------------------------------------------
# 14. MangoHud
# ---------------------------------------------------------------------------
info "Konfigurerar MangoHud..."
mkdir -p "$HOME/.config/MangoHud"
cat > "$HOME/.config/MangoHud/MangoHud.conf" << 'MANGO_EOF'
legacy_layout=false
cpu_stats
gpu_stats
fps
frametime
ram
vram
cpu_temp
gpu_temp
MANGO_EOF
ok "MangoHud konfigurerat"

# ---------------------------------------------------------------------------
# 15. Batteritröskeln
# ---------------------------------------------------------------------------
THRESHOLD_FILE="/sys/class/power_supply/BAT0/charge_control_end_threshold"
if [ -f "$THRESHOLD_FILE" ]; then
    ok "Batteritröskeln stöds! Nuvarande: $(cat $THRESHOLD_FILE)%"
    info "Sätt till 80%: echo 80 | sudo tee $THRESHOLD_FILE"
else
    warn "Batteritröskeln stöds inte på denna maskin"
fi

# ---------------------------------------------------------------------------
# Klart
# ---------------------------------------------------------------------------
echo ""
echo -e "${CYAN}=== Klart! ===${NC}"
echo ""
echo "  - Starta om för att aktivera faustus-dkms och WiFi-tweaken"
echo "  - Kör 'hyprctl reload' för att ladda om Hyprland-keybinds"
echo "  - Kör 'claude' för att logga in på Claude Code"
echo "  - Svenska tangentbord aktivt efter omstart"
echo ""
