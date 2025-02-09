#!/bin/bash

# Exit on error
set -e

# Set version
VERSION="1.5"

# Ensure Flutter is in PATH
export PATH="$PATH:$HOME/flutter/bin"

# Verify Flutter installation
if ! command -v flutter &> /dev/null; then
    echo "Flutter not found in PATH. Please ensure Flutter is installed in ~/flutter"
    exit 1
fi

# Install build dependencies
sudo dnf install -y cmake ninja-build gtk3-devel clang rpm-build

# Pre-build Flutter files
echo "Preparing Flutter build..."
flutter config --enable-linux-desktop
flutter clean
rm -rf build/
flutter pub get
flutter precache --linux

# Generate Linux build files
echo "Generating Linux build files..."
flutter build linux --release

# Create icon
mkdir -p assets/icons
cat > assets/icons/wine-launcher.svg << 'EOF'
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg xmlns="http://www.w3.org/2000/svg" height="48" width="48" viewBox="0 0 48 48">
  <circle cx="24" cy="24" r="20" fill="#722F37"/>
  <path d="M17 32l5-16h4l5 16h-3.5l-1-3.5h-5l-1 3.5H17zm3.8-6.5h3.4l-1.7-6-1.7 6z" fill="white"/>
</svg>
EOF

# Create necessary directories
mkdir -p ~/rpmbuild/{SOURCES,SPECS,BUILD,RPMS,SRPMS}

# Clean up any previous builds
rm -rf ~/rpmbuild/BUILD/*
rm -rf ~/rpmbuild/BUILDROOT/*

# Create a temporary directory for the source
TEMP_DIR=$(mktemp -d)
cp -r . $TEMP_DIR/wine-launcher-${VERSION}

# Create source tarball from the temporary directory
cd $TEMP_DIR
tar czf ~/rpmbuild/SOURCES/wine-launcher-${VERSION}.tar.gz wine-launcher-${VERSION}
cd -

# Clean up temporary directory
rm -rf $TEMP_DIR

# Copy spec file
cp packaging/wine-launcher.spec ~/rpmbuild/SPECS/

# Build RPM with verbose output
rpmbuild -vv -ba ~/rpmbuild/SPECS/wine-launcher.spec

# List contents of the RPM before installing
echo "Checking RPM contents..."
rpm -qlp ~/rpmbuild/RPMS/x86_64/wine-launcher-${VERSION}-1.*.x86_64.rpm

# Remove old installation before installing new package
echo "Removing old installation..."
sudo dnf remove -y wine-launcher || true
sudo rm -rf /usr/lib64/wine-launcher

# Install the package
echo "Installing package..."
sudo dnf install -y ~/rpmbuild/RPMS/x86_64/wine-launcher-${VERSION}-1.*.x86_64.rpm --setopt=strict=0

echo "Installation complete!" 