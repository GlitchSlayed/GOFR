.PHONY: all deps rpms disk-image iso test-vm test-iso test-lifecycle test clean help

SHELL := /usr/bin/env bash

all: help

help:
	@echo "GOFR (Glitchy's Opinionated Fedora Remix) Build System"
	@echo ""
	@echo "Build Targets:"
	@echo "  deps            - Verify host tools and build dependencies"
	@echo "  rpms            - Build GOFR RPM packages in clean container"
	@echo "  disk-image      - Build bootable QEMU/OVMF GPT disk image (raw and qcow2)"
	@echo "  iso             - Build installable hybrid UEFI ISO"
	@echo ""
	@echo "Testing Targets:"
	@echo "  test            - Run all automated validation suites"
	@echo "  test-vm         - Test bootable disk image in QEMU/OVMF"
	@echo "  test-iso        - Test installable ISO in QEMU/OVMF"
	@echo "  test-lifecycle  - Test kernel update and fallback retention"
	@echo ""
	@echo "Clean Target:"
	@echo "  clean           - Remove output images, RPMs, and checksums"
	@echo ""

deps:
	@./scripts/build/check-deps.sh

rpms:
	@./scripts/build/build-rpms.sh

disk-image:
	@./scripts/build/build-disk-image.sh

iso:
	@./scripts/build/build-iso.sh

test-vm:
	@./scripts/test/test-vm-boot.sh

test-iso:
	@./scripts/test/test-iso-boot.sh

test-lifecycle:
	@./tests/integration/test_kernel_lifecycle.sh

test: test-vm test-iso test-lifecycle
	@echo "=== All GOFR validation suites completed successfully! ==="

clean:
	@rm -rf out/rpms/* out/*.iso out/*.qcow2 out/*.raw out/SHA256SUMS
	@echo "Cleaned build artifacts."
