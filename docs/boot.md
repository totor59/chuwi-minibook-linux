# Boot: rotation + quiet

## The problem (Linux only)

The **firmware (UEFI) and Windows display upright** on the Minibook X. Only **Linux**
shows rotated content during boot. Why:

- The panel is native **1200x1920 (portrait)**, physically mounted **270°**.
- The firmware exposes a **raw portrait framebuffer**; the firmware and Windows apply
  the panel orientation and draw landscape, but **GRUB and the very early kernel use
  that raw framebuffer as-is**, so they render rotated.
- Linux only straightens up once `i915` + `fbcon=rotate:1` are active — i.e. from the
  Plymouth splash onward.

So the only rotated thing you actually see is **GRUB's own text**:

```
Booting `…`
Loading Linux …
Loading initial ramdisk …
```

plus a few early kernel messages before Plymouth.

## The approach: don't rotate GRUB — hide it

Rotating GRUB itself needs a **patched, unsigned** GRUB, which forces Secure Boot off,
breaks APT deps, and means re-signing on every rebuild. Not worth it for a menu that is
hidden anyway. Instead we:

1. **Rotate everything from the kernel onward** (console, Plymouth, desktop) via the
   kernel command line.
2. **Make GRUB + early boot quiet** so the rotated text is barely shown, and let the
   correctly-rotated Plymouth splash take over fast.

> If you really want the GRUB text upright too, the patched GRUB exists
> ([iggyZiggy/chuwi-grub-rotation-nix-patch](https://github.com/iggyZiggy/chuwi-grub-rotation-nix-patch)) —
> but it requires disabling Secure Boot and ongoing signing maintenance. We chose not to.

## What `scripts/configure-boot.sh` does

In `/etc/default/grub`:

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=0 vt.global_cursor_default=0 systemd.show_status=false rd.udev.log_level=3 video=DSI-1:panel_orientation=right_side_up fbcon=rotate:1"
GRUB_TIMEOUT=0
GRUB_TIMEOUT_STYLE=hidden
GRUB_GFXPAYLOAD_LINUX=keep
```

- **`video=DSI-1:panel_orientation=right_side_up`** — DRM panel orientation; Wayland
  compositors auto-rotate from it (so sway uses `transform normal`, see
  [desktop.md](desktop.md)).
- **`fbcon=rotate:1`** — rotates the text console 90° CW (matches the 270° mount).
- **`quiet … loglevel=0 … systemd.show_status=false`** — silence kernel/systemd text.
- **`GRUB_TIMEOUT=0` + `GRUB_TIMEOUT_STYLE=hidden`** — no menu.
- **`GRUB_GFXPAYLOAD_LINUX=keep`** — flash-free handoff so Plymouth appears immediately.

Plus:

- Adds **`i915`** to `/etc/initramfs-tools/modules` so the orientation applies early
  (during the splash, not after).
- Sets **`quiet_boot=1`** in `/etc/grub.d/10_linux` to drop the
  `Loading Linux …` / `Loading initial ramdisk …` lines.
  - This is a dpkg **conffile**; a grub update may prompt about the change.
  - **Ubuntu usually ships `quiet_boot=1` already**, so this step is often a no-op there.
- Runs `update-grub` + `update-initramfs -u`.

The one line that can't be removed without patching GRUB is the core
**`Booting \`…\``** message; `GRUB_TIMEOUT=0` + `keep` + immediate Plymouth reduce it to
a sub-second flash.

## Verify

```bash
cat /proc/cmdline        # panel_orientation=right_side_up + fbcon=rotate:1 + quiet flags
```

After `sudo reboot`: no GRUB menu, no `Loading …` lines, the upright Plymouth splash,
then an upright console (Ctrl+Alt+F2) and desktop.
