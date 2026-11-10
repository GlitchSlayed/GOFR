Name:           gofr-welcome
Version:        45.0.0
Release:        1%{?dist}
Summary:        Libadwaita Welcome application and UKI bootloader backend selector for GOFR
License:        MIT
URL:            https://github.com/GlitchSlayed/GOFR
BuildArch:      noarch

Requires:       python3
Requires:       python3-gobject
Requires:       libadwaita
Recommends:     gofr-rustyuki-integration

%description
Provides a modern Libadwaita onboarding application for GOFR live environments and
workstations. Allows users to select their preferred Unified Kernel Image (UKI)
bootloader backend (systemd-boot vs. Direct UKI) prior to or during OS installation.

%prep
# No prep required

%build
# No build required

%install
mkdir -p %{buildroot}%{_bindir}
mkdir -p %{buildroot}%{_datadir}/applications
mkdir -p %{buildroot}%{_datadir}/icons/hicolor/scalable/apps
mkdir -p %{buildroot}%{_sysconfdir}/xdg/autostart

# 1. Install executable
cat << 'EOF' > %{buildroot}%{_bindir}/gofr-welcome
#!/usr/bin/env python3
"""
GOFR Welcome & UKI Backend Selector (Libadwaita / GTK 4)

Provides a clean, modern Libadwaita onboarding screen for GOFR:
1. Welcome to GOFR overview page
2. UKI Bootloader Backend selection page (systemd-boot vs. Direct UKI)
"""

import sys
import os
import argparse
import subprocess
import gi

gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, Gio, GLib


class GofrWelcomeWindow(Adw.ApplicationWindow):
    def __init__(self, app, backend_file="/tmp/gofr-boot-backend", launch_installer=False):
        super().__init__(application=app, title="Welcome to GOFR")
        self.backend_file = backend_file
        self.launch_installer = launch_installer

        self.set_default_size(740, 600)
        self.set_size_request(600, 500)

        # Main Navigation View (2 pages)
        self.nav_view = Adw.NavigationView()

        # Build Page 1: Welcome
        self.welcome_page = self._build_welcome_page()
        self.nav_view.add(self.welcome_page)

        # Build Page 2: UKI Options
        self.uki_page = self._build_uki_page()

        self.set_content(self.nav_view)

    def _build_welcome_page(self):
        page = Adw.NavigationPage(title="Welcome", tag="welcome")
        root_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)

        header = Adw.HeaderBar()
        root_box.append(header)

        scroller = Gtk.ScrolledWindow()
        scroller.set_vexpand(True)
        scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)

        clamp = Adw.Clamp(maximum_size=620, tightening_threshold=480)
        content_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=24)
        content_box.set_margin_top(28)
        content_box.set_margin_bottom(32)
        content_box.set_margin_start(20)
        content_box.set_margin_end(20)

        # Hero Banner
        status = Adw.StatusPage(
            title="Welcome to GOFR",
            description="Glitchy's Opinionated Fedora Remix\nA high-performance, UKI-first Linux workstation built on Fedora 45.",
            icon_name="distributor-logo"
        )
        content_box.append(status)

        # Feature Highlights Group
        features_group = Adw.PreferencesGroup()
        features_group.set_title("Architecture Highlights")

        row_cachy = Adw.ActionRow(
            title="CachyOS Performance Kernel",
            subtitle="Tuned x86-64-v3 kernel with BORE/EEVDF CPU scheduler and modern hardware optimizations."
        )
        row_cachy.add_prefix(Gtk.Image.new_from_icon_name("utilities-terminal-symbolic"))
        features_group.add(row_cachy)

        row_btrfs = Adw.ActionRow(
            title="Btrfs Subvolume Layout and 4 GiB ESP",
            subtitle="Standardized @ and @home subvolumes with zstd compression and generous ESP allocation."
        )
        row_btrfs.add_prefix(Gtk.Image.new_from_icon_name("drive-harddisk-symbolic"))
        features_group.add(row_btrfs)

        row_uki = Adw.ActionRow(
            title="Unified Kernel Images (BLS Type #2)",
            subtitle="Kernel, initramfs, cmdline, and OS release bundled into single signed UEFI PE binaries."
        )
        row_uki.add_prefix(Gtk.Image.new_from_icon_name("security-high-symbolic"))
        features_group.add(row_uki)

        content_box.append(features_group)

        # Next Button
        action_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        action_box.set_halign(Gtk.Align.CENTER)
        action_box.set_margin_top(8)

        next_btn = Gtk.Button(label="Configure Boot Subsystem →")
        next_btn.add_css_class("suggested-action")
        next_btn.add_css_class("pill")
        next_btn.set_size_request(260, 48)
        next_btn.connect("clicked", lambda _: self.nav_view.push(self.uki_page))
        action_box.append(next_btn)

        content_box.append(action_box)

        clamp.set_child(content_box)
        scroller.set_child(clamp)
        root_box.append(scroller)
        page.set_child(root_box)
        return page

    def _build_uki_page(self):
        page = Adw.NavigationPage(title="Boot Options", tag="uki-options")
        root_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)

        header = Adw.HeaderBar()
        root_box.append(header)

        scroller = Gtk.ScrolledWindow()
        scroller.set_vexpand(True)
        scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)

        clamp = Adw.Clamp(maximum_size=620, tightening_threshold=480)
        content_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        content_box.set_margin_top(20)
        content_box.set_margin_bottom(32)
        content_box.set_margin_start(20)
        content_box.set_margin_end(20)

        # Section Header
        status = Adw.StatusPage(
            title="Choose UKI Bootloader",
            description="Select how UEFI firmware will discover and boot your Unified Kernel Images.",
            icon_name="system-run-symbolic"
        )
        content_box.append(status)

        # Boot Options Group
        group = Adw.PreferencesGroup()
        group.set_title("Available Bootloader Backends")
        group.set_description("Both backends are managed automatically by RustyUKI during kernel updates.")

        # Option 1: systemd-boot (Default)
        self.row_sdboot = Adw.ActionRow(
            title="systemd-boot (BLS Type #2)",
            subtitle="Automatic discovery in /efi/EFI/Linux/, interactive 3s boot menu, and reliable multi-kernel rollback slots. (Recommended)"
        )
        self.row_sdboot.add_prefix(Gtk.Image.new_from_icon_name("view-list-bullet-symbolic"))
        self.radio_sdboot = Gtk.CheckButton()
        self.radio_sdboot.set_active(True)
        self.row_sdboot.add_suffix(self.radio_sdboot)
        self.row_sdboot.set_activatable_widget(self.radio_sdboot)
        group.add(self.row_sdboot)

        # Option 2: Direct UKI
        self.row_direct = Adw.ActionRow(
            title="Direct UKI (UEFI NVRAM)",
            subtitle="UEFI firmware executes the UKI directly from ESP via efibootmgr. Fastest boot with BootNext trial fallbacks."
        )
        self.row_direct.add_prefix(Gtk.Image.new_from_icon_name("system-run-symbolic"))
        self.radio_direct = Gtk.CheckButton(group=self.radio_sdboot)
        self.row_direct.add_suffix(self.radio_direct)
        self.row_direct.set_activatable_widget(self.radio_direct)
        group.add(self.row_direct)

        content_box.append(group)

        # Bottom Buttons
        bottom_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        bottom_box.set_halign(Gtk.Align.CENTER)
        bottom_box.set_margin_top(12)

        install_btn = Gtk.Button(label="Proceed to Installer")
        install_btn.add_css_class("suggested-action")
        install_btn.add_css_class("pill")
        install_btn.set_size_request(260, 48)
        install_btn.connect("clicked", self._on_proceed_clicked)
        bottom_box.append(install_btn)

        content_box.append(bottom_box)

        clamp.set_child(content_box)
        scroller.set_child(clamp)
        root_box.append(scroller)
        page.set_child(root_box)
        return page

    def get_selected_backend(self):
        return "direct" if self.radio_direct.get_active() else "systemd-boot"

    def _on_proceed_clicked(self, _button):
        selected = self.get_selected_backend()
        print(f"Selected GOFR bootloader backend: {selected}", flush=True)

        target_files = [self.backend_file, "/run/gofr-boot-backend"]
        for path in target_files:
            try:
                os.makedirs(os.path.dirname(path), exist_ok=True)
                with open(path, "w", encoding="utf-8") as f:
                    f.write(f"{selected}\n")
                print(f"Recorded boot backend selection to {path}", flush=True)
            except Exception as e:
                print(f"Warning: could not write selection to {path}: {e}", file=sys.stderr)

        if self.launch_installer:
            self._launch_installer()

        self.close()

    def _launch_installer(self):
        installer_cmds = [
            ["liveinst"],
            ["anaconda", "--liveinst"],
            ["gnome-terminal", "--", "liveinst"]
        ]
        for cmd in installer_cmds:
            try:
                print(f"Launching installer via: {' '.join(cmd)}", flush=True)
                subprocess.Popen(cmd)
                return
            except FileNotFoundError:
                continue
        print("Note: liveinst / anaconda not found in PATH; selection saved for background installer.", flush=True)


class GofrWelcomeApp(Adw.Application):
    def __init__(self, backend_file="/tmp/gofr-boot-backend", launch_installer=False):
        super().__init__(
            application_id="io.github.glitchslayed.gofr-welcome",
            flags=Gio.ApplicationFlags.DEFAULT_FLAGS
        )
        self.backend_file = backend_file
        self.launch_installer = launch_installer
        self.win = None

    def do_activate(self):
        if not self.win:
            self.win = GofrWelcomeWindow(
                self,
                backend_file=self.backend_file,
                launch_installer=self.launch_installer
            )
        self.win.present()


def main():
    parser = argparse.ArgumentParser(description="GOFR Welcome & UKI Backend Selector")
    parser.add_argument(
        "--backend-file",
        default="/tmp/gofr-boot-backend",
        help="Path where the chosen backend string is saved (default: /tmp/gofr-boot-backend)"
    )
    parser.add_argument(
        "--launch-installer",
        action="store_true",
        help="Automatically launch liveinst/anaconda upon completing selection"
    )
    parser.add_argument(
        "--test",
        action="store_true",
        help="Run non-blocking verification and verify widget tree initialization"
    )
    args = parser.parse_args()

    if args.test:
        Gtk.init()
        app = GofrWelcomeApp(backend_file=args.backend_file)
        app.do_activate()
        assert app.win is not None
        assert app.win.get_selected_backend() == "systemd-boot"
        app.win.radio_direct.set_active(True)
        assert app.win.get_selected_backend() == "direct"
        app.win._on_proceed_clicked(None)
        assert os.path.exists(args.backend_file)
        with open(args.backend_file) as f:
            assert f.read().strip() == "direct"
        print("Headless self-test completed successfully: Direct UKI and systemd-boot verified!")
        sys.exit(0)

    app = GofrWelcomeApp(
        backend_file=args.backend_file,
        launch_installer=args.launch_installer
    )
    return app.run(sys.argv)


if __name__ == "__main__":
    sys.exit(main())
EOF
chmod 0755 %{buildroot}%{_bindir}/gofr-welcome

# 2. Install desktop entry
cat << 'EOF' > %{buildroot}%{_datadir}/applications/io.github.glitchslayed.gofr-welcome.desktop
[Desktop Entry]
Name=Welcome to GOFR
Comment=Glitchy's Opinionated Fedora Remix Welcome & Bootloader Setup
Exec=gofr-welcome --launch-installer
Icon=io.github.glitchslayed.gofr-welcome
Terminal=false
Type=Application
Categories=System;Settings;Utility;
StartupNotify=true
X-GNOME-Autostart-enabled=true
EOF

cp %{buildroot}%{_datadir}/applications/io.github.glitchslayed.gofr-welcome.desktop \
   %{buildroot}%{_sysconfdir}/xdg/autostart/io.github.glitchslayed.gofr-welcome.desktop

# 3. Install icon
cat << 'EOF' > %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/io.github.glitchslayed.gofr-welcome.svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128">
  <defs>
    <linearGradient id="gofr-grad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#3584e4"/>
      <stop offset="50%" stop-color="#1c71d8"/>
      <stop offset="100%" stop-color="#1a5fb4"/>
    </linearGradient>
    <filter id="shadow" x="-10%" y="-10%" width="120%" height="120%">
      <feDropShadow dx="0" dy="4" stdDeviation="6" flood-opacity="0.25"/>
    </filter>
  </defs>
  <rect x="12" y="12" width="104" height="104" rx="28" fill="url(#gofr-grad)" filter="url(#shadow)"/>
  <path d="M 64 26 C 43 26 28 41 28 62 C 28 83 43 98 64 98 C 80 98 92 88 97 74 L 81 74 C 77 82 71 86 64 86 C 50 86 40 75 40 62 C 40 49 50 38 64 38 C 72 38 78 42 82 48 L 96 38 C 89 30 78 26 64 26 Z" fill="#ffffff"/>
  <circle cx="78" cy="62" r="8" fill="#57e389"/>
</svg>
EOF

%files
%{_bindir}/gofr-welcome
%{_datadir}/applications/io.github.glitchslayed.gofr-welcome.desktop
%{_sysconfdir}/xdg/autostart/io.github.glitchslayed.gofr-welcome.desktop
%{_datadir}/icons/hicolor/scalable/apps/io.github.glitchslayed.gofr-welcome.svg

%changelog
* Mon Nov 09 2026 GlitchSlayed <60859364+GlitchSlayed@users.noreply.github.com> - 45.0.0-1
- Initial release of Libadwaita Welcome application and UKI bootloader backend selector
