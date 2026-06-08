# Clean install: Ubuntu Server + LUKS, then re-apply rotation

This repo's rotation work was done on a throwaway Debian 13 install with an
**unencrypted** disk. The plan is to reinstall cleanly on **Ubuntu Server** with
**full-disk encryption (LUKS)**, then reproduce the rotation from this repo.

## 1. Install Ubuntu Server with LUKS

Encryption is an **install-time** choice (it cannot be added comfortably afterwards):

- Boot the Ubuntu Server installer (or use the Desktop installer if you want a GUI base).
- At the storage step, choose **"Use an entire disk"** → tick
  **"Encrypt the LVM group with LUKS"**, set a passphrase.
- Finish the install, reboot, confirm you get the LUKS passphrase prompt.

> The LUKS passphrase prompt appears **before** GRUB hands off, so it lives in the
> early-boot framebuffer — it will look rotated until the rest of this repo is applied.

## 2. Re-apply screen rotation

Clone this repo, then follow the three layers:

```bash
git clone https://github.com/totor59/chuwi-minibook-linux.git
cd chuwi-minibook-linux

# Layer 1 — patched GRUB menu (see docs/grub-rotation.md)
bash scripts/build-patched-grub.sh
#   … disable Secure Boot in the BIOS …
sudo bash scripts/disable-secureboot-install.sh

# Layer 2 — kernel console + boot splash
sudo bash scripts/set-kernel-rotation.sh

sudo reboot
```

Then, optionally, the desktop layer ([docs/desktop.md](desktop.md)).

## 3. Ubuntu-specific differences vs Debian

The scripts were validated on Debian 13. On Ubuntu, watch for:

- **Source packages (DEB822).** Ubuntu 24.04+ uses
  `/etc/apt/sources.list.d/ubuntu.sources` with `Types: deb`. Enable sources by adding
  `deb-src`:
  ```
  Types: deb deb-src
  ```
  then `sudo apt update` before `apt source grub2`. `build-patched-grub.sh` currently
  targets the legacy `/etc/apt/sources.list`, so adapt that one step.
- **GRUB version.** Ubuntu 24.04 also ships grub **2.12**, so the patches in
  `patches/` should apply (with fuzz at worst, already handled by the build script).
  Re-check on 25.04+ if grub has moved on.
- **Secure Boot.** Ubuntu ships `grub-efi-amd64-signed` too, so the exact same
  "disable Secure Boot + `grub-install --no-uefi-secure-boot`" approach applies, and
  the same broken-deps cleanup is handled by the scripts
  (see [docs/grub-rotation.md](grub-rotation.md) — Gotcha #2).
- **Server has no GUI.** The kernel/console layer is enough for a server; the desktop
  layer is only needed if you add a compositor later.
- **Prebuilt `.deb`s are not reusable.** They were compiled against Debian's grub;
  rebuild from source with `build-patched-grub.sh`.

## 4. What you still have to do by hand

- The **20–30 min GRUB compile** (`build-patched-grub.sh`) — unavoidable, but now a
  guided copy/paste rather than a research session.
- Disabling **Secure Boot** in the firmware.
- Re-creating user data, dotfiles beyond `desktop/`, and any services — out of scope here.
