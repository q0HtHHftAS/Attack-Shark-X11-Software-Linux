#!/usr/bin/env bash
# Attack Shark X11 — Ubuntu installer (builds from source).
#   Install:   curl -fsSL https://raw.githubusercontent.com/q0HtHHftAS/Attack-Shark-X11-Software-Linux/main/install.sh | bash
#   Uninstall: curl -fsSL .../install.sh | bash -s -- --uninstall
set -euo pipefail

GITHUB_REPO="q0HtHHftAS/Attack-Shark-X11-Software-Linux"
APP_NAME="attack-shark-x11"
UDEV_RULES="/etc/udev/rules.d/99-${APP_NAME}.rules"
TAR_URL="https://github.com/${GITHUB_REPO}/archive/main.tar.gz"

# --- helpers -----------------------------------------------------------

color() { printf '\033[%sm%s\033[0m\n' "$1" "$2"; }
green() { color 32 "$*"; }
yellow() { color 33 "$*"; }
red() { color 31 "$*"; }

usage() {
	echo "Usage: install.sh [--uninstall]"
	echo "  (no args)     install ${APP_NAME} (udev rules, deps, build, desktop entry)"
	echo "  --uninstall   remove ${APP_NAME} (binary, desktop entry, icon, udev rules)"
}

# --- uninstall ---------------------------------------------------------

uninstall() {
	green "Uninstalling ${APP_NAME} …"
	rm -f "${HOME}/.local/bin/${APP_NAME}"
	rm -f "${HOME}/.local/share/applications/${APP_NAME}.desktop"
	rm -f "${HOME}/.local/share/icons/hicolor/scalable/apps/${APP_NAME}.svg"
	sudo rm -f "$UDEV_RULES"
	sudo udevadm control --reload-rules
	sudo udevadm trigger
	# .deb installs (if the user took that path)
	if dpkg -s "$APP_NAME" &>/dev/null 2>&1; then
		sudo dpkg -r "$APP_NAME"
	fi
	green "Done."
}

# --- udev rules --------------------------------------------------------

write_udev() {
	if [ -f "$UDEV_RULES" ]; then
		green "Udev rules already present, skipping."
		return
	fi
	yellow "Setting up udev rules (requires sudo) …"
	sudo tee "$UDEV_RULES" >/dev/null <<'UDEV'
SUBSYSTEM=="usb", ATTR{idVendor}=="1d57", ATTR{idProduct}=="fa60", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTR{idVendor}=="1d57", ATTR{idProduct}=="fa55", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTR{idVendor}=="1d57", ATTR{idProduct}=="fa61", MODE="0666", GROUP="plugdev"
UDEV
	sudo udevadm control --reload-rules
	sudo udevadm trigger
	# The device must be re-plugged (or the new rule triggered) to take effect.
	sudo udevadm trigger --subsystem-match=usb
}

# --- deps --------------------------------------------------------------

install_bun() {
	if command -v bun &>/dev/null; then return; fi
	yellow "Installing Bun …"
	curl -fsSL https://bun.sh/install | bash
	# shellcheck disable=SC2016
	echo 'export BUN_INSTALL="$HOME/.bun"' >> "$HOME/.bashrc"
	echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> "$HOME/.bashrc"
	export BUN_INSTALL="$HOME/.bun"
	export PATH="$BUN_INSTALL/bin:$PATH"
}

ensure_deps() {
	yellow "Checking system dependencies …"
	if grep -qi "ubuntu\|debian" /etc/os-release 2>/dev/null; then
		local missing=()
		command -v rustc &>/dev/null || missing+=(rustc cargo)
		command -v gcc &>/dev/null || missing+=(build-essential)
		dpkg -s libusb-1.0-0-dev &>/dev/null 2>&1 || missing+=(libusb-1.0-0-dev)
		if [ ${#missing[@]} -gt 0 ]; then
			yellow "Installing: ${missing[*]}"
			sudo apt update -qq && sudo apt install -y "${missing[@]}"
		fi
	elif [ -f /etc/arch-release ]; then
		local missing=()
		command -v rustc &>/dev/null || missing+=(rust)
		command -v gcc &>/dev/null || missing+=(base-devel)
		ldconfig -p | grep -q libusb 2>/dev/null || missing+=(libusb)
		if [ ${#missing[@]} -gt 0 ]; then
			yellow "Installing: ${missing[*]}"
			sudo pacman -S --needed --noconfirm "${missing[@]}"
		fi
	else
		# assume the user has rust etc.
		command -v rustc &>/dev/null || { red "rustc required — install rustup: https://rustup.rs"; exit 1; }
		command -v gcc &>/dev/null || { red "C compiler required — install build-essential / base-devel"; exit 1; }
	fi
}

# --- build from source -------------------------------------------------

build_from_source() {
	# Use a dir on the root filesystem — tmpfs triggers EOVERFLOW on copyfile
	local tmp_dir
	tmp_dir=$(mktemp -d -p /var/tmp)
	cd "$tmp_dir"

	yellow "Downloading source …"
	curl -fsSL "$TAR_URL" -o source.tar.gz
	tar xzf source.tar.gz
	cd attack-shark-x11-* 2>/dev/null || cd */ 2>/dev/null

	yellow "Installing JS dependencies …"
	bun install 2>&1 | tail -1

	yellow "Building (this will take a minute) …"
	bun run package 2>&1

	# install the .deb when the builder produced one, else the AppImage
	local deb
	deb=$(ls dist/*.deb 2>/dev/null | head -1)
	if [ -n "$deb" ]; then
		yellow "Installing .deb …"
		sudo dpkg -i "$deb" 2>/dev/null || sudo apt install -f -y
		cd / && rm -rf "$tmp_dir"
		return
	fi

	local appimage
	appimage=$(ls dist/*.AppImage 2>/dev/null | head -1)
	if [ -z "$appimage" ]; then
		red "Build output not found in dist/"
		exit 1
	fi

	local bin_dir="${HOME}/.local/bin"
	local desktop_dir="${HOME}/.local/share/applications"
	local icon_dir="${HOME}/.local/share/icons/hicolor/scalable/apps"
	mkdir -p "$bin_dir" "$desktop_dir" "$icon_dir"

	cp "$appimage" "${bin_dir}/${APP_NAME}"
	chmod +x "${bin_dir}/${APP_NAME}"

	# icon — matches Icon=attack-shark-x11 in the .desktop entry
	cp assets/attack-shark-x11.svg "${icon_dir}/${APP_NAME}.svg" 2>/dev/null || true

	cat >"${desktop_dir}/${APP_NAME}.desktop" <<EOF
[Desktop Entry]
Name=Attack Shark X11
Comment=Configuration tool for the Attack Shark X11 gaming mouse
Exec=${bin_dir}/${APP_NAME}
Icon=${APP_NAME}
Terminal=false
Type=Application
Categories=HardwareSettings;Settings;
Keywords=mouse;gaming;driver;
EOF

	cd / && rm -rf "$tmp_dir"

	if ! echo "$PATH" | tr ':' '\n' | grep -qxF "$bin_dir"; then
		yellow "Tip: add ~/.local/bin to your PATH:"
		echo "  export PATH=\"\$HOME/.local/bin:\$PATH\"  # >> ~/.bashrc"
	fi

	green "Installed to ${bin_dir}/${APP_NAME}"
}

# --- main --------------------------------------------------------------

main() {
	if [ "${1:-}" = "--uninstall" ]; then
		uninstall
		return
	fi
	if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
		usage
		return
	fi
	green "=== Attack Shark X11 Installer ==="
	echo "   building from source"
	echo

	write_udev
	install_bun
	ensure_deps
	build_from_source

	echo
	green "Done. Launch 'Attack Shark X11' from your app menu or run: ${APP_NAME}"
	green "If the mouse is not detected, unplug it and plug it back in once (udev)."
}

main "$@"
