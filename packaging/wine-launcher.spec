Name:           wine-launcher
Version:        1.5
Release:        1%{?dist}
Summary:        A Wine and Proton prefix manager for Linux
License:        MIT
URL:            https://github.com/yourusername/wine-launcher
Source0:        %{name}-%{version}.tar.gz

# Runtime dependencies
Requires:       (wine or wine-staging or winehq-staging)
Requires:       gtk3
Requires:       libappindicator-gtk3

# Build dependencies
BuildRequires:  cmake
BuildRequires:  ninja-build
BuildRequires:  gtk3-devel
BuildRequires:  clang

# Disable debug package
%define debug_package %{nil}

%description
A Wine and Proton prefix manager for Linux systems.

%prep
%autosetup -n %{name}-%{version}

%build
# Skip Flutter build as it's done before RPM build
echo "Using pre-built Flutter files"

%install
rm -rf %{buildroot}

# Create directory structure
mkdir -p %{buildroot}%{_libdir}/%{name}
mkdir -p %{buildroot}%{_bindir}
mkdir -p %{buildroot}%{_datadir}/applications
mkdir -p %{buildroot}%{_datadir}/icons/hicolor/scalable/apps

# Copy all build artifacts
cp -r build/linux/x64/release/bundle/* %{buildroot}%{_libdir}/%{name}/

# Ensure binary has correct name
if [ -f %{buildroot}%{_libdir}/%{name}/wine-launcher ]; then
    chmod +x %{buildroot}%{_libdir}/%{name}/wine-launcher
else
    echo "Error: wine-launcher binary not found in build output"
    exit 1
fi

# Install icon
cp assets/icons/%{name}.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/

# Create wrapper script
cat > %{buildroot}%{_bindir}/%{name} << 'EOF'
#!/bin/bash
set -e

APP_DIR="/usr/lib64/wine-launcher"
cd "$APP_DIR"
exec ./wine-launcher "$@"
EOF
chmod +x %{buildroot}%{_bindir}/%{name}

# Install desktop file
cat > %{buildroot}%{_datadir}/applications/%{name}.desktop << EOF
[Desktop Entry]
Name=Wine Launcher
Comment=Wine and Proton prefix manager
Exec=%{name}
Icon=%{name}
Terminal=false
Type=Application
Categories=Game;Utility;
EOF

%files
%{_bindir}/%{name}
%{_libdir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/scalable/apps/%{name}.svg

%changelog
* Wed Mar 20 2024 Your Name <your.email@example.com> - 1.4.1-1
- Initial package 