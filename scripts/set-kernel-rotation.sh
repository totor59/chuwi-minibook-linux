#!/usr/bin/env bash
# Rotate the kernel console and the boot splash on the Chuwi Minibook X.
#
# The DSI panel is native 1200x1920 mounted 270deg. This sets the kernel command line:
#   video=DSI-1:panel_orientation=right_side_up   -> DRM panel orientation property;
#                                                    Wayland/sway auto-rotate from it.
#   fbcon=rotate:1                                -> rotate the text console 90deg CW.
# and loads i915 early (initramfs) so the orientation is applied during early boot
# (Plymouth) instead of only once the GPU driver kicks in.
#
# This is the kernel/console layer, independent of the GRUB-menu rotation
# (see docs/grub-rotation.md). Idempotent.
#
# Run with: sudo bash scripts/set-kernel-rotation.sh
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()  { echo -e "${RED}[ERR ]${NC} $*" >&2; exit 1; }

[[ $EUID -ne 0 ]] && die "Run with sudo: sudo bash $0"

GRUB_FILE="/etc/default/grub"
MODULES_FILE="/etc/initramfs-tools/modules"
EXTRA="video=DSI-1:panel_orientation=right_side_up fbcon=rotate:1"

[[ -f "$GRUB_FILE" ]] || die "$GRUB_FILE not found."

# ── 1. Kernel command line ────────────────────────────────────────────────────
info "=== Kernel command line ==="
CURRENT=$(sed -n 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/\1/p' "$GRUB_FILE")
info "Current: \"$CURRENT\""

if echo "$CURRENT" | grep -q "panel_orientation"; then
    warn "panel_orientation already present — leaving GRUB_CMDLINE_LINUX_DEFAULT untouched."
else
    # Strip any stale fragments, then append ours.
    BASE=$(echo "$CURRENT" \
        | sed -E 's/ *video=DSI-1:[^ ]*//g; s/ *fbcon=rotate:[0-9]+//g' \
        | xargs)
    NEW="${BASE:+$BASE }$EXTRA"
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$NEW\"|" "$GRUB_FILE"
    ok "Set: \"$NEW\""
fi
update-grub

# ── 2. Load i915 early so the splash is rotated ───────────────────────────────
info "=== initramfs: load i915 early ==="
if [[ -f "$MODULES_FILE" ]] && grep -q '^i915' "$MODULES_FILE"; then
    warn "i915 already in $MODULES_FILE."
else
    echo "i915" >> "$MODULES_FILE"
    ok "Added i915 to $MODULES_FILE."
fi
update-initramfs -u

echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Kernel/console rotation configured.  ${NC}"
echo -e "${GREEN}  sudo reboot to apply.                ${NC}"
echo -e "${GREEN}  Check: cat /proc/cmdline             ${NC}"
echo -e "${GREEN}========================================${NC}"
