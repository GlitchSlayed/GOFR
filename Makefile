.PHONY: all deps rpms clean help test-deps

SHELL := /usr/bin/env bash

all: help

help:
	@echo "GOFR (Glitchy's Opinionated Fedora Remix) Build System"
	@echo ""
	@echo "Targets:"
	@echo "  deps        - Verify host tools and dependencies"
	@echo "  rpms        - Build GOFR RPM packages in containerized cleanroom"
	@echo "  clean       - Remove built RPMs and output artifacts"
	@echo ""

deps:
	@./scripts/build/check-deps.sh

rpms:
	@./scripts/build/build-rpms.sh

clean:
	@rm -rf out/rpms/* out/*.iso out/*.qcow2 out/*.raw
	@echo "Cleaned build artifacts."
