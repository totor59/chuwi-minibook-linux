# Chuwi Minibook X on Linux

Notes, scripts and config to run Linux nicely on the **Chuwi Minibook X (2026 model,
Intel N150, 16 GB RAM, 512 GB SSD)** — the main challenge being its screen.

The DSI panel is **natively 1200x1920 (portrait)** but **physically mounted rotated
270°**. The **firmware and Windows handle this and display upright**; only **Linux**
shows rotated content during boot, because GRUB and the early kernel use the raw
portrait framebuffer. This repo straightens Linux out and keeps the boot quiet.

> Validated on **Debian 13 (trixie)**; the target is a clean, encrypted **Ubuntu Server**
> install — see [docs/ubuntu-install.md](docs/ubuntu-install.md).

## Two layers

| Layer | What it covers | Where |
| --- | --- | --- |
| **Boot** | Rotate the console + Plymouth + desktop (kernel cmdline), and make GRUB / early boot **quiet** so the (unavoidably) rotated GRUB text is hidden rather than rotated. | [docs/boot.md](docs/boot.md) |
| **Desktop (Wayland/sway)** | The compositor auto-rotates from the DRM panel orientation; mostly a **HiDPI scaling** problem on a 10.5" 1920x1200 screen. | [docs/desktop.md](docs/desktop.md) |

We **don't** rotate the GRUB menu itself: that needs an unsigned custom GRUB (Secure
Boot off + signing maintenance), and the menu is hidden anyway. We keep **Secure Boot
on** and hide the rotated text instead. Rationale and the alternative are in
[docs/boot.md](docs/boot.md).

## Quick start

```bash
sudo bash scripts/configure-boot.sh   # rotation (cmdline + i915) + quiet boot
sudo reboot
# optional desktop:
bash scripts/install-desktop-configs.sh
```

## Layout

```
docs/      boot.md, desktop.md, ubuntu-install.md
scripts/   configure-boot.sh, install-desktop-configs.sh
desktop/   sway / waybar / kitty / gtk config (HiDPI-tuned)
```
