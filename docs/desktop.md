# Desktop (Wayland / sway)

On the Minibook X the desktop is the **easy** rotation layer: once the kernel sets
`panel_orientation=right_side_up` (see [boot.md](boot.md)), the
DRM connector reports the correct orientation and **Wayland compositors auto-rotate**.
sway therefore needs **`transform normal`** — the real work is HiDPI scaling on a tiny
high-resolution screen.

## The one thing that matters: scaling

The panel is 1920x1200 on a 10.5" screen, so 1:1 is unusably small. `desktop/sway/config`
uses:

```
output DSI-1 {
    resolution 1920x1200
    scale 1.75      # ~1097x686 logical; use 2.0 for bigger UI (960x600)
    transform normal
}
```

- **Do not** add a `transform 90/270` here — that would double-rotate on top of the
  kernel panel orientation. Keep `transform normal`.
- Tune `scale` to taste: `1.75` (more room) ↔ `2.0` (bigger).

## What's in `desktop/`

| File | Purpose |
| --- | --- |
| `sway/config` | window manager: scaling, keybindings (hjkl), workspaces, idle/lock, media keys |
| `waybar/config`, `waybar/style.css` | status bar, position bottom, Tokyo Night colours |
| `kitty/kitty.conf` | terminal (FiraCode Nerd Font, zsh shell, size 9) |
| `gtk-3.0/settings.ini` | dark GTK theme + font |
| `swaylock/config` | lock screen colours (Tokyo Night / Catppuccin mix) |
| `environment.d/wayland-scale.conf` | Wayland/HiDPI env vars (GDK, QT, MOZ, XDG) |
| `starship.toml` | shell prompt (Catppuccin Mocha) |

## Install

```bash
# Packages (Debian/Ubuntu names)
sudo apt install -y \
    sway swaybg swayidle swaylock xwayland wl-clipboard \
    waybar wofi mako-notifier kitty thunar gvfs tumbler \
    brightnessctl pipewire wireplumber starship \
    fonts-firacode fonts-noto-core

# FiraCode Nerd Font (for the waybar/kitty/starship glyphs)
mkdir -p ~/.local/share/fonts/FiraCodeNerd
curl -L https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip -o /tmp/FiraCode.zip
unzip -qo /tmp/FiraCode.zip -d ~/.local/share/fonts/FiraCodeNerd && fc-cache -f

# Drop the configs into ~/.config (backs up anything it replaces)
bash scripts/install-desktop-configs.sh
```

`waybar/config` pins the Wi-Fi interface to `wlp0s20f3`; adjust `"interface"` if
`ip link` shows a different name on your machine.

## Claude Code (dev tool)

Claude Code installs as a self-contained binary — no Node.js needed:

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

Installs to `~/.local/share/claude/` and symlinks to `~/.local/bin/claude`. Make sure
`~/.local/bin` is in `$PATH` (it is by default in Debian if the dir exists).

## Boot splash (Plymouth)

Plymouth is purely cosmetic here. Modern Plymouth reads the same DRM panel orientation,
so the splash is upright once `i915` loads early (kernel layer). The personal setup
used the [Hackers-Plymouth](https://github.com/mainframed/Hackers-Plymouth) `acidburn`
theme rendered at height **1200** (for the 1920x1200 landscape view) — optional and not
included here.
