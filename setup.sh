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
ping -c 1 -W 3 archlinux.org &>/dev/null || die "Ingen nätverksanslutning. Koppla in ethernet och försök igen."
ok "Nätverk OK"

# ---------------------------------------------------------------------------
# 1. Systemuppdatering
# ---------------------------------------------------------------------------
info "Uppdaterar systemet..."
sudo pacman -Syu --noconfirm
ok "System uppdaterat"

# ---------------------------------------------------------------------------
# 2. Installera yay om det saknas
# ---------------------------------------------------------------------------
if ! command -v yay &>/dev/null; then
    info "Installerar yay (AUR-helper)..."
    sudo pacman -S --noconfirm --needed git base-devel
    git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
    (cd /tmp/yay-bin && makepkg -si --noconfirm)
    rm -rf /tmp/yay-bin
    ok "yay installerat"
else
    ok "yay redan installerat"
fi

# ---------------------------------------------------------------------------
# 3. Hårdvara — drivrutiner & FX505DV-specifikt
# ---------------------------------------------------------------------------
info "Installerar hårdvarupaket..."

# envycontrol — Optimus-hantering
yay -S --noconfirm --needed envycontrol

# faustus-dkms — tangentbordsbelysning + fläktlägen för ASUS TUF FX505DV
yay -S --noconfirm --needed faustus-dkms

# FFADO — RME Fireface 400 via FireWire
sudo pacman -S --noconfirm --needed ffado

ok "Hårdvarupaket installerade"

# ---------------------------------------------------------------------------
# 4. Realtek 8822CE WiFi-tweaken
# ---------------------------------------------------------------------------
info "Konfigurerar Realtek 8822CE (rtw88)..."
MODPROBE_CONF="/etc/modprobe.d/rtw88.conf"
echo "options rtw88_8822ce disable_lps_deep=1 ips=0" | sudo tee "$MODPROBE_CONF" > /dev/null
ok "WiFi-tweaken skriven till $MODPROBE_CONF"

# ---------------------------------------------------------------------------
# 5. Terminal-stack
# ---------------------------------------------------------------------------
info "Installerar terminal-stack..."
sudo pacman -S --noconfirm --needed \
    kitty \
    zellij \
    fish \
    starship \
    yazi \
    ffmpegthumbnailer unar jq poppler fd ripgrep fzf zoxide  # yazi-beroenden

# JetBrains Mono Nerd Font
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
# 7. Configs — kitty, starship, VS Code
# ---------------------------------------------------------------------------
info "Hämtar och installerar configs..."

CONFIGS_URL="https://raw.githubusercontent.com/SorbP/cachyos-setup/main/configs"

mkdir -p "$HOME/.config/kitty"
curl -fsSL "$CONFIGS_URL/kitty-okabe-ito-deutan.conf" -o "$HOME/.config/kitty/themes/okabe-ito-deutan.conf"
# Lägg till theme-inkludering om den saknas
if ! grep -q "okabe-ito-deutan" "$HOME/.config/kitty/kitty.conf" 2>/dev/null; then
    echo "include themes/okabe-ito-deutan.conf" >> "$HOME/.config/kitty/kitty.conf"
fi

mkdir -p "$HOME/.config"
curl -fsSL "$CONFIGS_URL/starship-deutan.toml" -o "$HOME/.config/starship.toml"

# Starship i fish
FISH_CONFIG="$HOME/.config/fish/config.fish"
mkdir -p "$(dirname "$FISH_CONFIG")"
grep -q "starship init" "$FISH_CONFIG" 2>/dev/null || \
    echo 'starship init fish | source' >> "$FISH_CONFIG"

ok "Configs installerade"

# ---------------------------------------------------------------------------
# 8. VS Code
# ---------------------------------------------------------------------------
info "Installerar VS Code..."
yay -S --noconfirm --needed visual-studio-code-bin

# VS Code deutan-settings
VSCODE_SETTINGS="$HOME/.config/Code/User/settings.json"
mkdir -p "$(dirname "$VSCODE_SETTINGS")"
if [ ! -f "$VSCODE_SETTINGS" ]; then
    curl -fsSL "$CONFIGS_URL/vscode-deutan-settings.json" -o "$VSCODE_SETTINGS"
    ok "VS Code settings installerade"
else
    warn "VS Code settings finns redan — hoppar över (kolla $VSCODE_SETTINGS manuellt)"
fi

# ---------------------------------------------------------------------------
# 9. Program
# ---------------------------------------------------------------------------
info "Installerar program..."

# Pacman-paket
sudo pacman -S --noconfirm --needed \
    steam \
    discord \
    btop \
    mangohud \
    nvtop

# AUR-paket
yay -S --noconfirm --needed \
    teamspeak6-client \
    fsearch-git \
    onedrive-abraunegg \
    arduino-ide-bin \
    gwe  # GreenWithEnvy

# Bottles (kör Windows-appar via Wine — Flatpak-version rekommenderas)
sudo pacman -S --noconfirm --needed flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub com.usebottles.bottles

# PlatformIO
sudo pacman -S --noconfirm --needed python-pip
pip install --user platformio

# ---------------------------------------------------------------------------
# CLI-verktyg
# ---------------------------------------------------------------------------
info "Installerar CLI-verktyg..."
sudo pacman -S --noconfirm --needed \
    bat \        # cat med syntaxmarkering
    eza \        # modern ls
    dust \       # du-ersättare
    duf \        # df-ersättare
    tldr \       # kortfattade man-sidor
    fastfetch \  # systeminfo (neofetch-ersättare)
    p7zip \      # 7z-stöd
    unzip \
    wget \
    ffmpeg \
    yt-dlp \
    nmap \
    bandwhich    # nätverksbandbredd per process

# eza-alias i fish
grep -q "alias ls" "$HOME/.config/fish/config.fish" 2>/dev/null || \
    echo "alias ls='eza --icons'" >> "$HOME/.config/fish/config.fish"
grep -q "alias ll" "$HOME/.config/fish/config.fish" 2>/dev/null || \
    echo "alias ll='eza --icons -la'" >> "$HOME/.config/fish/config.fish"

ok "CLI-verktyg installerade"

# ---------------------------------------------------------------------------
# Claude Code
# ---------------------------------------------------------------------------
info "Installerar Claude Code..."
sudo pacman -S --noconfirm --needed nodejs npm
npm install -g @anthropic-ai/claude-code
ok "Claude Code installerat — kör 'claude' för att logga in"

# Wootility (AppImage)
info "Laddar ner Wootility (AppImage)..."
WOOTILITY_URL="https://api.github.com/repos/WootingKb/wootility/releases/latest"
WOOTILITY_APPIMAGE=$(curl -fsSL "$WOOTILITY_URL" | grep -oP '"browser_download_url": "\K[^"]+\.AppImage')
if [ -n "$WOOTILITY_APPIMAGE" ]; then
    mkdir -p "$HOME/Applications"
    curl -fsSL "$WOOTILITY_APPIMAGE" -o "$HOME/Applications/Wootility.AppImage"
    chmod +x "$HOME/Applications/Wootility.AppImage"
    ok "Wootility nedladdad till ~/Applications/Wootility.AppImage"
else
    warn "Kunde inte hämta Wootility automatiskt — ladda ner manuellt från wooting.io"
fi

ok "Program installerade"

# ---------------------------------------------------------------------------
# 10. MangoHud — aktivera för Steam globalt
# ---------------------------------------------------------------------------
info "Konfigurerar MangoHud..."
mkdir -p "$HOME/.config/MangoHud"
cat > "$HOME/.config/MangoHud/MangoHud.conf" << 'EOF'
legacy_layout=false
cpu_stats
gpu_stats
fps
frametime
ram
vram
cpu_temp
gpu_temp
EOF
# Lägg till MANGOHUD=1 i Steam launch options görs manuellt per spel,
# men global aktivering via environment:
grep -q "MANGOHUD" "$HOME/.config/fish/config.fish" 2>/dev/null || \
    echo 'set -x MANGOHUD 1' >> "$HOME/.config/fish/config.fish"
ok "MangoHud konfigurerat"

# ---------------------------------------------------------------------------
# 11. Batteritröskeln — kontroll
# ---------------------------------------------------------------------------
echo ""
info "Kontrollerar batteritröskeln (ASUS charge limit)..."
THRESHOLD_FILE="/sys/class/power_supply/BAT0/charge_control_end_threshold"
if [ -f "$THRESHOLD_FILE" ]; then
    CURRENT=$(cat "$THRESHOLD_FILE")
    ok "Batteritröskeln stöds! Nuvarande gräns: ${CURRENT}%"
    info "Sätt till 80% med: echo 80 | sudo tee $THRESHOLD_FILE"
else
    warn "Batteritröskeln stöds INTE på denna maskin (filen saknas)"
    warn "faustus-dkms fixar tangentbordsbelysning och fläktar men inte batteri"
fi

# ---------------------------------------------------------------------------
# 12. Sammanfattning
# ---------------------------------------------------------------------------
echo ""
echo -e "${CYAN}=== Klart! ===${NC}"
echo ""
echo "Gjort:"
echo "  - System uppdaterat"
echo "  - faustus-dkms (tangentbordsbelysning + fläktar)"
echo "  - envycontrol (kör 'sudo envycontrol -s nvidia' för gaming)"
echo "  - Realtek 8822CE WiFi-tweaken"
echo "  - FFADO (RME Fireface 400)"
echo "  - Terminal-stack: Kitty + Zellij + Fish + Starship + Yazi"
echo "  - JetBrains Mono Nerd Font"
echo "  - Okabe-Ito Kitty-tema + Starship deutan"
echo "  - VS Code"
echo "  - Steam, Discord, TeamSpeak 6, FSearch, Wootility, Bottles
  - CLI: bat, eza, dust, duf, tldr, fastfetch, ffmpeg, yt-dlp, nmap
  - Claude Code (kör 'claude' för att logga in efter omstart)"
echo "  - MangoHud, btop, nvtop, GreenWithEnvy"
echo "  - PlatformIO, Arduino IDE"
echo "  - onedrive-abraunegg"
echo ""
echo "Starta om för att aktivera faustus-dkms och WiFi-tweaken."
echo ""
