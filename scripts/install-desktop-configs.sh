#!/usr/bin/env bash
# Copy the desktop config files (sway, waybar, kitty, gtk) into ~/.config.
# Backs up anything it would overwrite. Runs as your normal user (no sudo).
#
# Install the packages first (see docs/desktop.md), then run:
#   bash scripts/install-desktop-configs.sh
set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_DIR/desktop"
DEST="$HOME/.config"
STAMP="$(date +%Y%m%d-%H%M%S)"

mkdir -p "$DEST"
# Copy each top-level config dir, backing up an existing one first.
for d in "$SRC"/*/; do
    name="$(basename "$d")"
    if [[ -e "$DEST/$name" ]]; then
        mv "$DEST/$name" "$DEST/$name.bak.$STAMP"
        warn "Backed up existing ~/.config/$name -> $name.bak.$STAMP"
    fi
    cp -r "$d" "$DEST/$name"
    ok "Installed ~/.config/$name"
done

# Copy individual dotfiles at desktop/ root (e.g. starship.toml).
for f in "$SRC"/*.toml "$SRC"/*.conf "$SRC"/*.json; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f")"
    if [[ -e "$DEST/$name" ]]; then
        mv "$DEST/$name" "$DEST/$name.bak.$STAMP"
        warn "Backed up existing ~/.config/$name -> $name.bak.$STAMP"
    fi
    cp "$f" "$DEST/$name"
    ok "Installed ~/.config/$name"
done

echo
ok "Done. In sway, reload with Super+Shift+r (or log into a fresh sway session)."
