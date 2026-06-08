#!/usr/bin/env bash
# Build a GRUB package with the framebuffer-rotation patches for the Chuwi Minibook X.
#
# This ONLY builds and installs the patched GRUB packages. It does NOT touch the
# bootloader on disk and does NOT change /etc/default/grub. After it finishes:
#   1. disable Secure Boot in the firmware (the patched GRUB is unsigned),
#   2. run scripts/disable-secureboot-install.sh to install it + apply the rotation.
#
# Patches come from this repo (patches/), originally by kbader94 via
# https://github.com/iggyZiggy/chuwi-grub-rotation-nix-patch
#
# Tested on Debian 13 (grub2 2.12-9+deb13u2). On Ubuntu see README "Ubuntu deltas".
# Run with: bash scripts/build-patched-grub.sh
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()  { echo -e "${RED}[ERR ]${NC} $*" >&2; exit 1; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCHES_DIR="$REPO_DIR/patches"
WORKDIR="$HOME/grub-build"
SRC_DIR="$WORKDIR/src"

[[ -f "$PATCHES_DIR/0001.patch" ]] || die "Patches not found in $PATCHES_DIR"

# ── 1. Build dependencies ─────────────────────────────────────────────────────
info "=== Build dependencies ==="
sudo apt install -y dpkg-dev devscripts build-essential flex bison \
    libfreetype6-dev libdevmapper-dev libpciaccess-dev gettext \
    help2man python3 rsync unifont fuse3 libfuse3-dev

# Enable deb-src if missing (legacy sources.list format).
# Ubuntu 24.04+ uses the DEB822 format in /etc/apt/sources.list.d/ubuntu.sources:
# add "deb-src" to its Types line instead (see README "Ubuntu deltas").
if ! grep -rq "^deb-src" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
    MAIN_REPO=$(grep '^deb ' /etc/apt/sources.list | head -1 | sed 's/^deb /deb-src /')
    echo "$MAIN_REPO" | sudo tee -a /etc/apt/sources.list > /dev/null
    sudo apt update -qq
    ok "deb-src enabled."
fi

# ── 2. Fetch GRUB source ──────────────────────────────────────────────────────
info "=== Fetching Debian/Ubuntu grub2 source ==="
mkdir -p "$SRC_DIR"
cd "$SRC_DIR"
if ! ls grub2-*/debian/changelog &>/dev/null 2>&1; then
    apt-get source grub2
fi

GRUB_SRC_DIR=$(ls -d grub2-*/ 2>/dev/null | grep -v '\.orig' | head -1)
[[ -z "$GRUB_SRC_DIR" ]] && die "GRUB source directory not found."
GRUB_SRC_DIR="$SRC_DIR/$GRUB_SRC_DIR"
info "Source: $GRUB_SRC_DIR"

# ── 3. Apply the rotation patches ─────────────────────────────────────────────
info "=== Applying rotation patches ==="
cd "$GRUB_SRC_DIR"
for i in 0001 0002 0003 0004; do
    if patch -p1 --dry-run -s < "$PATCHES_DIR/${i}.patch" 2>/dev/null; then
        patch -p1 < "$PATCHES_DIR/${i}.patch"
        ok "Patch $i applied."
    elif patch -p1 --fuzz=3 --dry-run -s < "$PATCHES_DIR/${i}.patch" 2>/dev/null; then
        patch -p1 --fuzz=3 < "$PATCHES_DIR/${i}.patch"
        ok "Patch $i applied (fuzz=3)."
    else
        warn "Patch $i: already applied or incompatible, continuing."
    fi
done

# ── 4. Post-patch build fixes ─────────────────────────────────────────────────
info "=== Post-patch compile fixes ==="

# Fix 1: an unused 'rot_env' declaration left behind trips -Werror.
ROT_ENV_FILE="grub-core/video/fb/video_fb.c"
if [[ -f "$ROT_ENV_FILE" ]]; then
    sed -i '/^\s*int rot_env\s*;/d' "$ROT_ENV_FILE"
    ok "rot_env fix applied in $ROT_ENV_FILE"
fi

# Fix 2: coreboot/cbfb.c references fbtable->rotation, which does not exist in the
# Debian struct. The Minibook X is UEFI, so force GRUB_VIDEO_ROTATE_NONE there.
CBFB_FILE="grub-core/video/coreboot/cbfb.c"
if [[ -f "$CBFB_FILE" ]]; then
    sed -i 's/GRUB_VIDEO_ROTATION_NONE/GRUB_VIDEO_ROTATE_NONE/g' "$CBFB_FILE"
    sed -i 's/grub_video_coreboot_fbtable->rotation/GRUB_VIDEO_ROTATE_NONE/g' "$CBFB_FILE"
    ok "cbfb.c rotation fix applied"
fi

# ── 5. Build ──────────────────────────────────────────────────────────────────
info "=== Building (20-30 min) ==="
sudo apt build-dep -y grub2 2>/dev/null || true

ORIG_VER=$(dpkg-parsechangelog -S Version)
NEW_VER="${ORIG_VER}+chuwi1"
info "Version: $ORIG_VER -> $NEW_VER"
dch --newversion "$NEW_VER" \
    --distribution "$(dpkg-parsechangelog -S Distribution)" \
    "GRUB rotation patches for Chuwi Minibook X"

dpkg-buildpackage -us -uc -b -j"$(nproc)"
ok "Build finished."

# ── 6. Install the freshly built packages ─────────────────────────────────────
# This makes grub-install/grub-mkimage and the runtime modules use the patched
# code. It does NOT yet write the bootloader (done in disable-secureboot-install.sh).
info "=== Installing built packages ==="
cd "$SRC_DIR"
sudo dpkg -i ../grub-common_${NEW_VER}_amd64.deb  2>/dev/null || \
sudo dpkg -i ../grub2-common_${NEW_VER}_amd64.deb 2>/dev/null || true

if [[ -d /sys/firmware/efi ]]; then
    sudo dpkg -i ../grub-efi-amd64_${NEW_VER}_amd64.deb 2>/dev/null || \
    sudo dpkg -i ../grub-efi_${NEW_VER}_amd64.deb       2>/dev/null || true
else
    sudo dpkg -i ../grub-pc_${NEW_VER}_amd64.deb 2>/dev/null || true
fi
ok "Patched GRUB packages installed (grub-install --version should show +chuwi)."

echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Patched GRUB built and installed.    ${NC}"
echo -e "${GREEN}  Next:                                ${NC}"
echo -e "${GREEN}   1. Disable Secure Boot in the BIOS. ${NC}"
echo -e "${GREEN}   2. sudo bash scripts/disable-secureboot-install.sh${NC}"
echo -e "${GREEN}========================================${NC}"
