# Clean install: Ubuntu Server + LUKS, then configure the boot

The rotation/quiet work was done on a throwaway Debian 13 install with an
**unencrypted** disk. The target is a clean **Ubuntu Server** install with
**full-disk encryption (LUKS)**, **Secure Boot left ON**, stock signed GRUB.

## 1. Install Ubuntu Server with LUKS

Encryption is an **install-time** choice:

- Boot the Ubuntu Server installer.
- At the storage step, choose **"Use an entire disk"** → tick
  **"Encrypt the LVM group with LUKS"**, set a passphrase.
- Leave **Secure Boot enabled** (no reason to disable it now — we keep stock GRUB).
- Finish, reboot, confirm the LUKS passphrase prompt appears.

> Ubuntu's guided LUKS keeps **`/boot` as a separate, unencrypted partition**, so the
> passphrase is asked by the **initramfs** (kernel framebuffer / Plymouth), which is
> **rotated correctly** by `fbcon=rotate:1`. The only rotated thing left is GRUB's own
> text, which step 2 hides.

## 2. Configure rotation + quiet boot

```bash
git clone https://github.com/totor59/chuwi-minibook-linux.git
cd chuwi-minibook-linux

sudo bash scripts/configure-boot.sh
sudo reboot
```

See [docs/boot.md](boot.md) for what it sets. Then, optionally, the desktop
([docs/desktop.md](desktop.md)).

> **Ubuntu is already quieter than Debian**: it usually ships `quiet_boot=1` in
> `/etc/grub.d/10_linux`, so the "Loading Linux …" lines are gone by default and that
> part of `configure-boot.sh` becomes a no-op.

## 3. Secure Boot / TPM / LUKS

- **Secure Boot stays ON** — stock signed GRUB works with it, no maintenance.
- **LUKS passphrase** (the installer default) has **zero friction** with Secure Boot on.
  This is the recommended setup.
- **Optional TPM auto-unlock** (no passphrase): the Minibook X has a TPM 2.0 (Intel PTT).
  If you enroll it (`systemd-cryptenroll --tpm2-device=auto`):
  - bind to **PCR 7 (+ a PIN)** so it stays stable across kernel updates (avoid binding
    to the volatile boot-chain PCRs, which break on every update);
  - **set your final Secure Boot state first** — toggling Secure Boot changes PCR 7 and
    invalidates a TPM-sealed key (you'd fall back to the recovery passphrase).

## 4. Still manual

- Disk encryption choice at install time.
- User data and any dotfiles beyond `desktop/`.
