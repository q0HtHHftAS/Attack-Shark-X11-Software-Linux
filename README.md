# Attack Shark X11 Linux

<img width="1410" height="908" alt="image" src="https://github.com/user-attachments/assets/00625c5b-63b9-48ae-aad1-c6474ea9bbf1" />

This app controls the Attack Shark X11 and R1 gaming mouse on Ubuntu.
You can change DPI, button mapping, macros, lighting, polling rate, and battery display.
The app uses Electron and Vue 3.

## Install

Run the command below:

```bash
curl -fsSL https://raw.githubusercontent.com/q0HtHHftAS/Attack-Shark-X11-Software-Linux/main/install.sh | bash
```

The script installs dependencies, sets USB access through udev, builds the app, and adds the app to the app menu.
If the system does not detect the mouse after install, unplug the mouse and plug the mouse back in.

## Run

Start the app with one of the methods below.
Open Attack Shark X11 from the app menu.
If you use the terminal, run the command below:

```bash
attack-shark-x11
```

## Uninstall

Run the command below:

```bash
curl -fsSL https://raw.githubusercontent.com/q0HtHHftAS/Attack-Shark-X11-Software-Linux/main/install.sh | bash -s -- --uninstall
```

The script removes the app from the host and removes the app menu entry.
If the system keeps the app icon after removal, log out and log back in.

## Install in Thai

Run the command below:

```bash
curl -fsSL https://raw.githubusercontent.com/q0HtHHftAS/Attack-Shark-X11-Software-Linux/main/install.sh | bash
```

The script installs dependencies, sets USB access through udev, builds the app, and adds the app to the app menu.
If the system does not detect the mouse after install, unplug the mouse and plug the mouse back in once.
To start the app, open Attack Shark X11 from the app menu or run attack-shark-x11 in the terminal.
To remove the app, run the uninstall command above.

## Credits

This project builds on [attack-shark-x11-electron](https://github.com/dressedinblack5/attack-shark-x11-electron) by [dressedinblack5](https://github.com/dressedinblack5).
That project provides the driver and the reverse engineering of the protocol.
That project also provides the original app that uses Electron and Vue.

## License

This project uses the MIT license.
See LICENSE for the full text.
This project has no affiliation with Attack Shark.
When you use the app, you accept the risk.
