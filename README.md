# Chuwi Minibook X — custom GRUB screen rotation

The Chuwi Minibook X ships a DSI panel whose **native resolution is 1200x1920
(portrait)** but which is **physically mounted rotated 270°** inside the chassis.
Everything therefore comes up sideways unless told to rotate.

This repository covers **one specific layer: rotating the GRUB menu** (and the very
early boot) by building a **patched GRUB** that can rotate its `gfxterm` output.

**Hardware used here:** Chuwi Minibook X (2026 model), Intel N150, 16 GB RAM,
512 GB SSD, UEFI firmware.

> **Scope.** Only the custom GRUB build is handled here. The kernel/console/desktop
> rotation (done entirely through the kernel command line) is a related but separate
> topic, documented below as a prerequisite but **not scripted in this repo** — it
> will come in a later commit. See [Companion: kernel rotation](#companion-kernel-rotation).

Tested on **Debian 13 (trixie), grub2 2.12-9+deb13u2**, UEFI, Intel N150.
For Ubuntu, see [Ubuntu deltas](#ubuntu-deltas).

---

## TL;DR

```bash
# 1. Build & install the patched GRUB packages (~20-30 min compile)
bash scripts/build-patched-grub.sh

# 2. Disable Secure Boot in the firmware (REQUIRED — see the gotcha below)
#    reboot -> tap Esc/Del -> Security -> Secure Boot -> Disabled -> F10

# 3. Install the patched bootloader and apply the rotation
sudo bash scripts/disable-secureboot-install.sh

sudo reboot
```

After reboot the GRUB menu should be landscape, right way up, shown for 3 seconds.

---

## Why a custom GRUB

Stock GRUB cannot rotate its graphical terminal. The panel's firmware framebuffer is
portrait (1200x1920), so the stock menu is drawn the wrong way round and there is no
configuration knob to fix it.

The [kbader94 framebuffer-rotation patch series](https://github.com/iggyZiggy/chuwi-grub-rotation-nix-patch)
(vendored in [`patches/`](patches/)) adds rotation support to GRUB and exposes it
through a **suffix on `GRUB_GFXMODE`**:

```
GRUB_GFXMODE=<width>x<height>[xdepth][-rotation]      # rotation: 90 | 180 | 270
```

For the Minibook X the working value is:

```
GRUB_GFXMODE=1200x1920x32-270
```

i.e. the panel's **native** resolution `1200x1920`, depth `x32`, rotated `-270`.

---

## ⚠️ Gotcha #1 — Secure Boot (this is the big one)

The patched GRUB is **not signed**. With **Secure Boot enabled**, `shim` refuses to
run it and silently loads the **stock, signed** GRUB instead (`grub-efi-amd64-signed`),
which knows nothing about the `-270` suffix → the menu stays **portrait**.

**Diagnostic symptom:** at the GRUB prompt (`c`), `videoinfo` returns
**`access denied by secure boot policy`**. That message proves the *signed,
locked-down* GRUB is the one running, not the patched build.

**Fix:** disable Secure Boot in the firmware, then install GRUB with
`grub-install --no-uefi-secure-boot` (done by `scripts/disable-secureboot-install.sh`,
which refuses to run while Secure Boot is still on).

**Do NOT remove `grub-efi-amd64-signed`.** On Debian, `grub-common` and
`grub-efi-amd64-bin` (the patched packages you want to keep) depend on it — removing
it triggers a cascading removal of your patched GRUB.

With Secure Boot **off**, the boot chain `shim → grubx64.efi` still works: shim loads
`grubx64.efi` *without verifying it*, so it is enough that `grubx64.efi` is the
patched binary. `--no-uefi-secure-boot` writes exactly that and points the UEFI boot
entry straight at it.

---

## How the three scripts fit together

| Script | Runs as | Does |
| --- | --- | --- |
| [`scripts/build-patched-grub.sh`](scripts/build-patched-grub.sh) | user (calls sudo) | apt source `grub2`, apply [`patches/`](patches/), build, `dpkg -i` the patched packages. No bootloader/config change. |
| [`scripts/disable-secureboot-install.sh`](scripts/disable-secureboot-install.sh) | sudo | guard that Secure Boot is OFF, `grub-install --no-uefi-secure-boot`, then call `set-grub-rotation.sh 270`. |
| [`scripts/set-grub-rotation.sh`](scripts/set-grub-rotation.sh) | sudo | set/replace `GRUB_GFXMODE=<res>-<rot>` (idempotent), `update-grub`. Parameterised: `… 90`, `… 180`, `… 270 1200x1920`. |

---

## Verification

After `sudo reboot`:

1. At the GRUB menu press **`c`** and type `videoinfo`.
   - It **works now** (no "access denied") → the **patched** GRUB is running. ✅
   - Check that `1200x1920` appears in the mode list.
2. The menu is **landscape, right way up**, visible 3 s.

Wrong way up? Only the suffix needs changing:

```bash
sudo bash scripts/set-grub-rotation.sh 90      # then 180 if needed
```

`1200x1920x32` not offered by `videoinfo`? Use the exact mode it lists, e.g.:

```bash
sudo bash scripts/set-grub-rotation.sh 270 1200x1920
```

---

## Companion: kernel rotation

The console and the desktop (Wayland/sway) are rotated by the **kernel command line**,
independently of GRUB. This is *not* scripted in this repo (separate commit), but the
known-good values from the working Debian setup are recorded here because the GRUB
suffix is chosen to match them.

Known-good `/proc/cmdline` fragment:

```
video=DSI-1:panel_orientation=right_side_up fbcon=rotate:1
```

- `panel_orientation=right_side_up` — read by the DRM driver / Wayland compositor to
  auto-rotate the desktop.
- `fbcon=rotate:1` — rotates the text console 90° CW.
- `i915` is added to the initramfs modules so the panel orientation is applied early.

**Key mapping:** the kbader94 patch (`patches/0004.patch`) maps the GRUB suffix to the
kernel value — **`-270` ⇄ `fbcon=rotate:1`** — which is why the GRUB menu uses `-270`.

Known-good `/etc/default/grub` keys (Debian 13):

```
GRUB_TIMEOUT=3
GRUB_TERMINAL_OUTPUT=gfxterm
GRUB_GFXMODE=1200x1920x32-270
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=0 vt.global_cursor_default=0 video=DSI-1:panel_orientation=right_side_up fbcon=rotate:1"
```

---

## Ubuntu deltas

This repo was validated on Debian 13. To reproduce on **Ubuntu Server**:

- **Source packages.** Ubuntu 24.04+ uses the DEB822 format
  (`/etc/apt/sources.list.d/ubuntu.sources`). Enable sources by adding `deb-src` to
  its `Types:` line (`Types: deb deb-src`), then `sudo apt update` before
  `apt source grub2`. `build-patched-grub.sh` currently targets the legacy
  `/etc/apt/sources.list`, so adapt that step.
- **GRUB version.** Ubuntu 24.04 also ships grub **2.12**, so the patches should
  apply (possibly with fuzz, already handled). Re-check on 25.04+.
- **Secure Boot.** Ubuntu also ships `grub-efi-amd64-signed`; the exact same
  "disable Secure Boot + `--no-uefi-secure-boot`" approach applies.
- **Rebuild required.** The prebuilt Debian `.deb`s are **not** reusable on Ubuntu —
  re-run `build-patched-grub.sh` to compile against Ubuntu's grub source.

---

## Not in this repo

- The compiled `.deb` packages (large, distro-specific) — rebuild from source.
- The kernel source tree (no kernel patch is needed; everything is cmdline).
- Desktop setup (sway, plymouth, …) and the kernel-cmdline script — separate commits.

See [`.gitignore`](.gitignore).

---

## Credits

- Framebuffer rotation patches: **kbader94**.
- Packaging overlay / reference: **[iggyZiggy/chuwi-grub-rotation-nix-patch](https://github.com/iggyZiggy/chuwi-grub-rotation-nix-patch)**.
