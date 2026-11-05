# Known Issues & Work in Progress

This tracker records known issues, external blockers, and upcoming milestones for GOFR.

---

## Current Status & Blockers

1. **RustyUKI Rework Needed (Upstream):**
   - *Status:* In progress by upstream author (@GlitchSlayed).
   - *Details:* The current version (`0.2.0`) of RustyUKI expects `rpm -q kernel` package names, defaults to `/boot/efi`, and injects direct `efibootmgr` NVRAM entries rather than relying on `systemd-boot` BLS Type #2 discovery under `/efi/EFI/Linux/*.efi`.
   - *Action Plan:* The author is setting up a separate project to redo and improve RustyUKI with generalized kernel querying (`kernel-cachyos`), BLS Type #2 systemd-boot support, and flexible ESP pathing.

2. **Unprivileged ISO Build Environments:**
   - *Status:* Mitigated via rootless Podman containers.
   - *Details:* Standard tools like `lorax` and `livemedia-creator` often require loop device mounting and root capabilities. Containerized rootless build scripts in `scripts/build/` are utilized to isolate builds.

3. **CachyOS x86-64-v3 Requirement:**
   - *Status:* Hardware dependency.
   - *Details:* CachyOS kernel packages feature compiler optimizations targeting x86-64-v3 (AVX, AVX2, BMI1/2). Older CPU architectures (pre-Haswell) require generic baseline builds.
