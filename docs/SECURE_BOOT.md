# Secure Boot Architecture & Key Management

This document defines the Secure Boot strategy for GOFR, trust chain considerations, and implementation steps.

---

## 1. Principles & Trust Model

1. **Development Builds:**
   - Development images may be booted with UEFI Secure Boot disabled in firmware settings.

2. **Custom Key Enrollment (MOK / PK-KEK-db):**
   - Self-signed bootloaders or UKIs cannot boot on factory-default UEFI firmware without enrolling custom keys into the firmware database (`db`) or the Machine Owner Key (`MOK`) database via Shim.
   - Never claim an unsigned or locally signed image boots on factory Secure Boot without key enrollment.

3. **Key Safety:**
   - **Never** commit private signing keys or CA credentials into Git.
   - Signing keys must be generated ephemerally or stored securely in dedicated keychains.

---

## 2. Signing Pipeline

When Secure Boot signing is active:

1. **Key Generation:**
   ```bash
   openssl req -new -x509 -newkey rsa:2048 -nodes \
     -keyout gofr-sb.key -out gofr-sb.crt -days 3650 \
     -subj "/CN=GOFR Secure Boot Signing Key/"
   ```

2. **UKI Signing via ukify:**
   `systemd-ukify` supports native signing during compilation:
   ```bash
   ukify build \
     --linux=/boot/vmlinuz-... \
     --initrd=/tmp/initrd.img \
     --signtool=sbsign \
     --secureboot-private-key=gofr-sb.key \
     --secureboot-certificate=gofr-sb.crt \
     --output=/efi/EFI/Linux/gofr-signed.efi
   ```

3. **systemd-boot Signing:**
   The `systemd-boot` binary installed to `/efi/EFI/systemd/systemd-bootx64.efi` must be signed with the same key using `sbsign`:
   ```bash
   sbsign --key gofr-sb.key --cert gofr-sb.crt \
     --output /efi/EFI/BOOT/BOOTX64.EFI /usr/lib/systemd/boot/efi/systemd-bootx64.efi
   ```
