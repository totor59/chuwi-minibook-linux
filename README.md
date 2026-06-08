# Chuwi Minibook X on Linux

Notes, scripts and config to run Linux nicely on the **Chuwi Minibook X (2026 model,
Intel N150, 16 GB RAM, 512 GB SSD)** — the main challenge being its screen.

The DSI panel is **natively 1200x1920 (portrait)** but **physically mounted rotated
270°**, so everything comes up sideways unless each layer of the boot/display stack is
told to rotate. This repo documents each layer separately.

> Validated on **Debian 13 (trixie)**; the rotation work was done there before moving
> to a clean, encrypted **Ubuntu Server** install. See [Ubuntu install](docs/ubuntu-install.md).

## The three rotation layers

| Layer | What it covers | Where |
| --- | --- | --- |
| **GRUB menu** | Custom (patched) GRUB so the boot menu renders the right way up. Includes the **Secure Boot** trap and the broken-APT-deps trap. | [docs/grub-rotation.md](docs/grub-rotation.md) |
| **Kernel / console** | Kernel command line (`panel_orientation` + `fbcon=rotate`) and early `i915`, so the text console and boot splash are upright. | [docs/kernel-rotation.md](docs/kernel-rotation.md) |
| **Desktop (Wayland/sway)** | The compositor auto-rotates from the DRM panel orientation; mostly a **HiDPI scaling** problem on a 10.5" 1920x1200 screen. | [docs/desktop.md](docs/desktop.md) |

The single most important value, shared across layers:

- Panel native resolution: **1200x1920**, mounted **270°**.
- GRUB rotation suffix **`-270`** ⇄ kernel **`fbcon=rotate:1`** ⇄ Wayland auto-rotates
  from `panel_orientation=right_side_up`.

## Quick start (rotation)

```bash
# GRUB menu (see docs/grub-rotation.md for the Secure Boot prerequisite)
bash scripts/build-patched-grub.sh
# … disable Secure Boot in the BIOS …
sudo bash scripts/disable-secureboot-install.sh

# Kernel console + boot splash
sudo bash scripts/set-kernel-rotation.sh

sudo reboot
```

## Layout

```
docs/      grub-rotation.md, kernel-rotation.md, desktop.md, ubuntu-install.md
scripts/   build-patched-grub.sh, disable-secureboot-install.sh,
           set-grub-rotation.sh, set-kernel-rotation.sh
patches/   kbader94 GRUB framebuffer-rotation patches (vendored)
desktop/   sway / waybar / kitty / gtk config (HiDPI-tuned)
```

## Credits

GRUB framebuffer rotation patches by **kbader94**, via
**[iggyZiggy/chuwi-grub-rotation-nix-patch](https://github.com/iggyZiggy/chuwi-grub-rotation-nix-patch)**.
