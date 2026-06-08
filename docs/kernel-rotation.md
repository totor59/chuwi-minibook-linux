# Kernel / console rotation

Rotating the **text console** and the **boot splash** (Plymouth). This is independent
of the [GRUB menu rotation](grub-rotation.md): GRUB rotates its own `gfxterm`, while
the kernel rotates the framebuffer console and exposes the panel orientation to the
display server.

Script: [`scripts/set-kernel-rotation.sh`](../scripts/set-kernel-rotation.sh).

## What it sets

Two kernel command-line parameters (added to `GRUB_CMDLINE_LINUX_DEFAULT` in
`/etc/default/grub`, then `update-grub`):

```
video=DSI-1:panel_orientation=right_side_up fbcon=rotate:1
```

- **`video=DSI-1:panel_orientation=right_side_up`** — sets the DRM connector's
  *panel orientation* property. Wayland compositors (sway, GNOME, …) read it and
  **auto-rotate** the desktop, so no compositor-side `transform` is needed
  (see [desktop.md](desktop.md)).
- **`fbcon=rotate:1`** — rotates the framebuffer text console 90° clockwise.

Plus `i915` is added to `/etc/initramfs-tools/modules` (then `update-initramfs -u`)
so the Intel driver loads **early**, applying the panel orientation during the splash
rather than only after the root pivot.

## The mapping that ties the layers together

The kbader94 GRUB patch (`patches/0004.patch`) maps the GRUB `GRUB_GFXMODE` rotation
suffix to the kernel value:

| Panel mount | GRUB suffix | kernel |
| --- | --- | --- |
| 270° (Minibook X) | `-270` | `fbcon=rotate:1` |
| 90° | `-90` | `fbcon=rotate:3` |
| 180° | `-180` | `fbcon=rotate:2` |

So the Minibook X uses GRUB `-270` and kernel `fbcon=rotate:1` consistently.

> The GRUB and kernel layers are kept **decoupled** on purpose: `set-grub-rotation.sh`
> does *not* set `GRUB_GFXPAYLOAD_LINUX=keep`, so changing the GRUB menu suffix can
> never silently change the console rotation. The console is owned solely by the
> command line configured here.

## Known-good values (Debian 13)

`/proc/cmdline` fragment:

```
video=DSI-1:panel_orientation=right_side_up fbcon=rotate:1
```

`/etc/default/grub`:

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=0 vt.global_cursor_default=0 video=DSI-1:panel_orientation=right_side_up fbcon=rotate:1"
```

## Verify

```bash
cat /proc/cmdline                       # contains panel_orientation + fbcon=rotate:1
cat /sys/class/drm/card0-DSI-1/modes    # 1200x1920 (native)
```

After reboot the text console (Ctrl+Alt+F2) and the Plymouth splash should be upright.
