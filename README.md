# Wine Launcher

A modern Wine and Proton prefix manager for Linux, built with Flutter.

## Features

- Manage Wine and Proton prefixes
- Launch Windows games and applications
- Automatic DXVK and VKD3D installation
- Visual C++ Runtime integration
- Game library management
- Dark/Light theme support

## Installation

### Ubuntu/Debian
```bash
# Dependencies
sudo apt install wine winetricks

# Download latest .deb from releases
sudo dpkg -i wine-launcher_*.deb
```

### Fedora
```bash
# Dependencies
sudo dnf install wine winetricks

# Download latest .rpm from releases
sudo rpm -i wine-launcher-*.rpm
```

### Arch Linux
```bash
# Dependencies
sudo pacman -S wine winetricks

# Install from AUR
yay -S wine-launcher
```

## Building from Source

1. Install Flutter:
```bash
git clone https://github.com/flutter/flutter.git
export PATH="$PATH:`pwd`/flutter/bin"
flutter doctor
```

2. Install dependencies:
```bash
flutter pub get
```

3. Build:
```bash
flutter build linux
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
