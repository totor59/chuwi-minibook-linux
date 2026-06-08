#!/usr/bin/env bash
# Set (or change) the GRUB menu rotation, then regenerate grub.cfg.
# Requires the patched GRUB to be the one that boots (Secure Boot OFF + installed
# via disable-secureboot-install.sh); otherwise the rotation suffix is ignored.
#
# The kbader94 patch enables rotation through a suffix on GRUB_GFXMODE:
#   <width>x<height>[xdepth][-rotation]
# Minibook X panel: native 1200x1920 (portrait), mounted 270deg -> suffix -270.
#
# Idempotent: purges then rewrites the managed keys (never leaves duplicates).
#
# Usage: sudo bash scripts/set-grub-rotation.sh [ROTATION] [RESOLUTION]
#   ROTATION   : 90 | 180 | 270 | none   (default 270)
#   RESOLUTION : e.g. 1200x1920x32 | 1200x1920 | auto   (default 1200x1920x32)
#
# This script deliberately does NOT set GRUB_GFXPAYLOAD_LINUX=keep: keeping the
# kernel decoupled from the menu suffix means changing the rotation here can never
# break the console (the kernel console rotation is owned by the cmdline:
# `video=DSI-1:panel_orientation=right_side_up fbcon=rotate:1`, configured separately).
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[ OK ]${NC} $*"; }
die()  { echo -e "${RED}[ERR ]${NC} $*" >&2; exit 1; }

[[ $EUID -ne 0 ]] && die "Run with sudo: sudo bash $0 [rotation] [resolution]"

ROT="${1:-270}"
RES="${2:-1200x1920x32}"
case "$ROT" in
    90|180|270) GFXMODE="${RES}-${ROT}" ;;
    none|0)     GFXMODE="${RES}" ;;
    *)          die "Invalid ROTATION: $ROT (expected 90|180|270|none)" ;;
esac

GRUB_FILE="/etc/default/grub"
[[ -f "$GRUB_FILE" ]] || die "$GRUB_FILE not found."

BACKUP="${GRUB_FILE}.bak.$(date +%Y%m%d-%H%M%S)"
cp -a "$GRUB_FILE" "$BACKUP"
ok "Backup: $BACKUP"

# Purge managed keys (active AND commented lines) -> no duplicates.
sed -i -E '/^#?[[:space:]]*GRUB_GFXMODE=/d;
           /^#?[[:space:]]*GRUB_GFXPAYLOAD_LINUX=/d;
           /^#?[[:space:]]*GRUB_TERMINAL_OUTPUT=/d' "$GRUB_FILE"

{
    echo "GRUB_TERMINAL_OUTPUT=gfxterm"
    echo "GRUB_GFXMODE=${GFXMODE}"
} >> "$GRUB_FILE"

# Show the menu (now that it renders the right way up).
if grep -qE '^#?[[:space:]]*GRUB_TIMEOUT=' "$GRUB_FILE"; then
    sed -i -E 's|^#?[[:space:]]*GRUB_TIMEOUT=.*|GRUB_TIMEOUT=3|' "$GRUB_FILE"
else
    echo "GRUB_TIMEOUT=3" >> "$GRUB_FILE"
fi

echo
ok "Resulting config:"
grep -nE '^GRUB_(TIMEOUT|GFXMODE|GFXPAYLOAD_LINUX|TERMINAL_OUTPUT|CMDLINE_LINUX_DEFAULT)=' "$GRUB_FILE"
echo

info "=== update-grub ==="
update-grub
ok "grub.cfg regenerated (gfxmode = ${GFXMODE})."

echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  GRUB_GFXMODE = ${GFXMODE}"
echo -e "${GREEN}  sudo reboot to test.                 ${NC}"
echo -e "${GREEN}  Wrong way up? re-run with 90 / 180.  ${NC}"
echo -e "${GREEN}  Rollback: cp $BACKUP $GRUB_FILE; update-grub${NC}"
echo -e "${GREEN}========================================${NC}"
