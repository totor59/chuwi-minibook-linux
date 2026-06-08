#!/usr/bin/env bash
# Configure an upright, quiet Linux boot on the Chuwi Minibook X.
#
# The firmware and Windows already display upright; only GRUB and the very early
# kernel render rotated, because they use the panel's raw portrait framebuffer
# (1200x1920). We don't rotate GRUB (that needs an unsigned custom build); instead we:
#   - rotate everything from the kernel onward (console, Plymouth, desktop), and
#   - make GRUB + early boot as quiet as possible so the rotated text is not seen,
#     letting the (correctly rotated) Plymouth splash take over fast.
#
# Idempotent. Run with: sudo bash scripts/configure-boot.sh
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()  { echo -e "${RED}[ERR ]${NC} $*" >&2; exit 1; }

[[ $EUID -ne 0 ]] && die "Run with sudo: sudo bash $0"

GRUB_FILE="/etc/default/grub"
MODULES_FILE="/etc/initramfs-tools/modules"
LINUX_TEMPLATE="/etc/grub.d/10_linux"
STAMP="$(date +%Y%m%d-%H%M%S)"

# Rotation (panel native 1200x1920 mounted 270deg) + quiet flags.
ROTATION="video=DSI-1:panel_orientation=right_side_up fbcon=rotate:1"
QUIET="quiet splash loglevel=0 vt.global_cursor_default=0 systemd.show_status=false rd.udev.log_level=3"

[[ -f "$GRUB_FILE" ]] || die "$GRUB_FILE not found."
cp -a "$GRUB_FILE" "$GRUB_FILE.bak.$STAMP"
ok "Backup: $GRUB_FILE.bak.$STAMP"

# set_grub_key <key> <value>: replace active OR commented line, else append.
set_grub_key() {
    local key="$1" val="$2"
    if grep -qE "^#?[[:space:]]*${key}=" "$GRUB_FILE"; then
        sed -i -E "s|^#?[[:space:]]*${key}=.*|${key}=${val}|" "$GRUB_FILE"
    else
        printf '%s=%s\n' "$key" "$val" >> "$GRUB_FILE"
    fi
}

info "=== /etc/default/grub ==="
set_grub_key GRUB_CMDLINE_LINUX_DEFAULT "\"$QUIET $ROTATION\""
set_grub_key GRUB_TIMEOUT          "0"
set_grub_key GRUB_TIMEOUT_STYLE    "hidden"
set_grub_key GRUB_GFXPAYLOAD_LINUX "keep"
ok "Keys set:"
grep -E '^GRUB_(TIMEOUT|TIMEOUT_STYLE|GFXPAYLOAD_LINUX|CMDLINE_LINUX_DEFAULT)=' "$GRUB_FILE"

# Suppress GRUB's "Loading Linux ... / Loading initial ramdisk ..." lines.
# 10_linux gates them on quiet_boot; flip its default 0 -> 1 (Ubuntu often ships 1).
# NOTE: 10_linux is a dpkg conffile; a grub package update may prompt about this edit.
if [[ -f "$LINUX_TEMPLATE" ]] && grep -q '^quiet_boot="0"' "$LINUX_TEMPLATE"; then
    cp -a "$LINUX_TEMPLATE" "$LINUX_TEMPLATE.bak.$STAMP"
    sed -i 's/^quiet_boot="0"/quiet_boot="1"/' "$LINUX_TEMPLATE"
    ok "quiet_boot=1 in $LINUX_TEMPLATE (hides 'Loading Linux/initrd' lines)."
else
    warn "quiet_boot already 1 / not found in $LINUX_TEMPLATE — nothing to do (normal on Ubuntu)."
fi

# Load i915 early so the panel orientation + console rotation apply during the splash.
info "=== initramfs: load i915 early ==="
if [[ -f "$MODULES_FILE" ]] && grep -q '^i915' "$MODULES_FILE"; then
    warn "i915 already in $MODULES_FILE."
else
    echo "i915" >> "$MODULES_FILE"
    ok "Added i915 to $MODULES_FILE."
fi

info "=== Plymouth check ==="
if ! command -v plymouthd >/dev/null 2>&1; then
    warn "Plymouth not installed — 'splash' will show nothing. Install: sudo apt install plymouth plymouth-themes"
fi

info "=== Regenerating ==="
update-grub
update-initramfs -u

echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Boot configured: rotated + quiet.    ${NC}"
echo -e "${GREEN}  sudo reboot to apply.                ${NC}"
echo -e "${GREEN}  Expect: no GRUB menu, no 'Loading'   ${NC}"
echo -e "${GREEN}  lines; upright Plymouth splash.      ${NC}"
echo -e "${GREEN}========================================${NC}"
