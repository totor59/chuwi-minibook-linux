#!/usr/bin/env bash
# Install the patched (unsigned) GRUB as the boot binary, once Secure Boot is OFF,
# then apply the screen rotation.
#
# Why: with Secure Boot ENABLED, shim refuses the unsigned grubx64.efi and loads
# the stock SIGNED Debian/Ubuntu GRUB instead, which ignores the rotation suffix
# (GRUB_GFXMODE=...-270) -> portrait menu, and `videoinfo` at the GRUB prompt prints
# "access denied by secure boot policy". With Secure Boot OFF, shim loads grubx64.efi
# without verifying it, so it is enough for grubx64.efi to be the patched binary.
#
# Prerequisite: Secure Boot disabled in the firmware (Security -> Secure Boot ->
# Disabled, F10). This script REFUSES to run while Secure Boot is still enabled.
#
# Run with: sudo bash scripts/disable-secureboot-install.sh
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()  { echo -e "${RED}[ERR ]${NC} $*" >&2; exit 1; }

[[ $EUID -ne 0 ]] && die "Run with sudo: sudo bash $0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 1. Secure Boot guard ──────────────────────────────────────────────────────
info "=== Checking Secure Boot state ==="
SB_STATE="$(mokutil --sb-state 2>/dev/null || true)"
echo "  $SB_STATE"
if echo "$SB_STATE" | grep -qi 'enabled'; then
    die "Secure Boot is STILL ENABLED. Disable it first in the firmware:
       reboot -> tap Esc/Del -> Security -> Secure Boot -> Disabled -> F10.
       Otherwise the unsigned patched GRUB cannot boot."
fi
ok "Secure Boot disabled — safe to install the patched GRUB."

# ── 2. Sanity-check that the installed GRUB is the patched build ──────────────
GRUB_VER="$(grub-install --version 2>/dev/null || true)"
info "grub-install: $GRUB_VER"
echo "$GRUB_VER" | grep -q 'chuwi' || \
    warn "Active grub-install does not look like the +chuwi build. Rotation may not apply.
       Run scripts/build-patched-grub.sh first."

# ── 3. (Re)install grubx64.efi from the patched core, with a direct boot entry ─
info "=== grub-install (patched core, bypassing the shim/signed chain) ==="
grub-install --target=x86_64-efi --efi-directory=/boot/efi \
    --bootloader-id=debian --no-uefi-secure-boot --recheck
ok "Patched grubx64.efi installed."

# ── 4. Apply the reference rotation (reuses set-grub-rotation.sh) ──────────────
info "=== Applying -270 rotation ==="
bash "$SCRIPT_DIR/set-grub-rotation.sh" 270

echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Patched GRUB installed + rotation -270.${NC}"
echo -e "${GREEN}  sudo reboot to test.                 ${NC}"
echo -e "${GREEN}  At the GRUB menu: press 'c', type     ${NC}"
echo -e "${GREEN}  'videoinfo' — it must WORK now        ${NC}"
echo -e "${GREEN}  (= the patched GRUB is running).      ${NC}"
echo -e "${GREEN}========================================${NC}"
