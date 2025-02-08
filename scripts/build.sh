#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Version management
VERSION_FILE="pubspec.yaml"
CURRENT_VERSION=$(grep 'version:' $VERSION_FILE | sed 's/version: //')

# Build configuration
BUILD_DIR="build"
RELEASE_DIR="release"
RPM_BUILD_DIR="$HOME/rpmbuild"

# Function to show menu
show_menu() {
    clear
    echo -e "${BLUE}Wine Launcher Build Script${NC}"
    echo -e "${BLUE}Current version: ${GREEN}$CURRENT_VERSION${NC}"
    echo
    echo "1) Build packages"
    echo "2) Release major version"
    echo "3) Release minor version"
    echo "4) Release patch version"
    echo "5) Open build directory"
    echo "6) Clean build"
    echo "7) Check Flutter"
    echo "0) Exit"
    echo
    read -p "Choose an option: " choice
}

# Function to check Flutter installation
check_flutter() {
    if ! command -v flutter &> /dev/null; then
        echo -e "${RED}Flutter not found. Please install Flutter first.${NC}"
        return 1
    fi

    # Add Flutter to safe directories
    FLUTTER_PATH=$(which flutter)
    FLUTTER_DIR=$(dirname $(dirname $FLUTTER_PATH))
    git config --global --add safe.directory $FLUTTER_DIR

    # Check Flutter version
    FLUTTER_VERSION=$(flutter --version | head -n 1 | awk '{print $2}')
    echo -e "${BLUE}Flutter version: ${GREEN}$FLUTTER_VERSION${NC}"
    
    # Run Flutter doctor
    echo -e "\n${YELLOW}Running Flutter doctor...${NC}"
    flutter doctor
    
    return 0
}

# Function to check dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for rpm-build
    if ! command -v rpmbuild &> /dev/null; then
        missing_deps+=("rpm-build")
    fi
    
    # Check for GitHub CLI
    if ! command -v gh &> /dev/null; then
        missing_deps+=("gh")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${RED}Missing dependencies: ${missing_deps[*]}${NC}"
        echo -e "${YELLOW}Please install them with: sudo dnf install ${missing_deps[*]}${NC}"
        return 1
    fi
    
    # Check if gh is authenticated
    if command -v gh &> /dev/null; then
        if ! gh auth status &> /dev/null; then
            echo -e "${RED}GitHub CLI not authenticated${NC}"
            echo -e "${YELLOW}Please run: gh auth login${NC}"
            return 1
        fi
    fi
    
    return 0
}

# Function to build all packages
build_packages() {
    echo -e "${YELLOW}Building packages...${NC}"
    
    # Check dependencies
    if ! check_dependencies; then
        return 1
    fi
    
    # Clean previous builds
    echo -e "${YELLOW}Cleaning previous builds...${NC}"
    rm -rf $RPM_BUILD_DIR/RPMS/x86_64/wine-launcher-*.rpm
    rm -rf $RELEASE_DIR/*.rpm
    
    # Check Flutter first
    if ! check_flutter; then
        return 1
    fi
    
    # Update dependencies
    echo -e "${YELLOW}Updating dependencies...${NC}"
    if ! flutter pub get; then
        echo -e "${RED}Failed to get dependencies${NC}"
        return 1
    fi
    
    # Create build directories
    mkdir -p $BUILD_DIR
    mkdir -p $RELEASE_DIR
    
    # Build for production
    echo -e "${YELLOW}Building Flutter release...${NC}"
    if ! flutter build linux --release; then
        echo -e "${RED}Build failed${NC}"
        return 1
    fi
    
    # Setup RPM environment
    setup_rpm_env
    
    # Build RPM
    echo -e "${YELLOW}Building RPM package...${NC}"
    if ! rpmbuild -bb $RPM_BUILD_DIR/SPECS/wine-launcher.spec; then
        echo -e "${RED}Failed to build RPM${NC}"
        return 1
    fi
    
    # Copy single RPM to release directory
    if ! cp $RPM_BUILD_DIR/RPMS/x86_64/wine-launcher-*.rpm $RELEASE_DIR/; then
        echo -e "${RED}Failed to copy RPM to release directory${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Build complete!${NC}"
    return 0
}

# Function to create GitHub release
create_github_release() {
    local version=$1
    local release_notes=$2
    
    echo -e "${YELLOW}Creating GitHub release v$version...${NC}"
    
    # Save current branch
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    
    # Create a temporary branch for the release
    git checkout -b release-$version
    
    # Stage and commit version change
    if ! git add pubspec.yaml; then
        echo -e "${RED}Failed to stage version change${NC}"
        git checkout $current_branch
        git branch -D release-$version
        return 1
    fi
    
    if ! git commit -m "Bump version to $version"; then
        echo -e "${RED}Failed to commit version update${NC}"
        git checkout $current_branch
        git branch -D release-$version
        return 1
    fi
    
    # Push changes to remote
    if ! git push origin release-$version; then
        echo -e "${RED}Failed to push changes to remote${NC}"
        git checkout $current_branch
        git branch -D release-$version
        return 1
    fi
    
    # Create and push tag
    if ! git tag -a "v$version" -m "Release v$version"; then
        echo -e "${RED}Failed to create tag${NC}"
        git checkout $current_branch
        git branch -D release-$version
        return 1
    fi
    
    if ! git push origin "v$version"; then
        echo -e "${RED}Failed to push tag${NC}"
        git checkout $current_branch
        git branch -D release-$version
        return 1
    fi
    
    # Create GitHub release
    if ! gh release create "v$version" \
        $RELEASE_DIR/*.rpm \
        --title "Release v$version" \
        --notes "$release_notes"; then
        echo -e "${RED}Failed to create GitHub release${NC}"
        git checkout $current_branch
        git branch -D release-$version
        return 1
    fi
    
    # Merge release branch to main
    git checkout $current_branch
    if ! git merge release-$version; then
        echo -e "${RED}Failed to merge release branch${NC}"
        git branch -D release-$version
        return 1
    fi
    
    # Push main branch
    if ! git push origin $current_branch; then
        echo -e "${RED}Failed to push main branch${NC}"
        return 1
    fi
    
    # Cleanup release branch
    git branch -D release-$version
    
    echo -e "${GREEN}GitHub release created!${NC}"
    return 0
}

# Update the setup_rpm_env function with corrected paths and permissions:

setup_rpm_env() {
    echo -e "${YELLOW}Setting up RPM build environment...${NC}"
    
    # Create RPM build directories
    mkdir -p $RPM_BUILD_DIR/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
    
    # Create source tarball
    echo -e "${YELLOW}Creating source tarball...${NC}"
    cd $BUILD_DIR/linux/x64/release/bundle
    tar czf $RPM_BUILD_DIR/SOURCES/wine-launcher-$CURRENT_VERSION.tar.gz *
    cd - > /dev/null
    
    # Copy additional files
    cp assets/wine-launcher.desktop $RPM_BUILD_DIR/SOURCES/
    cp assets/wine-launcher.png $RPM_BUILD_DIR/SOURCES/
    
    # Create spec file
    cat > $RPM_BUILD_DIR/SPECS/wine-launcher.spec << EOF
Name:           wine-launcher
Version:        $CURRENT_VERSION
Release:        1%{?dist}
Summary:        A Wine and Proton prefix manager for Linux

License:        MIT
URL:            https://github.com/yourusername/wine-launcher
BuildArch:      x86_64

Source0:        %{name}-%{version}.tar.gz
Source1:        %{name}.desktop
Source2:        %{name}.png

Requires:       wine
Requires:       winetricks
Requires:       gtk3

# Disable debug package
%define debug_package %{nil}

%description
A Flutter-based game launcher for Wine and Proton with support for managing
multiple Wine prefixes and game configurations.

%prep
%setup -q -c

%build
# No build needed

%install
rm -rf %{buildroot}

# Create directories
mkdir -p %{buildroot}%{_bindir}
mkdir -p %{buildroot}%{_libdir}/%{name}
mkdir -p %{buildroot}%{_datadir}/applications
mkdir -p %{buildroot}%{_datadir}/icons/hicolor/128x128/apps

# Install application files
cp -r * %{buildroot}%{_libdir}/%{name}/

# Create wrapper script
echo '#!/bin/bash' > %{buildroot}%{_bindir}/%{name}
echo 'exec %{_libdir}/%{name}/wine-launcher "\$@"' >> %{buildroot}%{_bindir}/%{name}
chmod 755 %{buildroot}%{_bindir}/%{name}

# Install desktop file and icon
install -D -m 644 %{SOURCE1} %{buildroot}%{_datadir}/applications/%{name}.desktop
install -D -m 644 %{SOURCE2} %{buildroot}%{_datadir}/icons/hicolor/128x128/apps/%{name}.png

%files
%{_bindir}/%{name}
%{_libdir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/128x128/apps/%{name}.png

%post
/bin/touch --no-create %{_datadir}/icons/hicolor &>/dev/null || :
/usr/bin/gtk-update-icon-cache %{_datadir}/icons/hicolor &>/dev/null || :

%postun
if [ \$1 -eq 0 ] ; then
    /bin/touch --no-create %{_datadir}/icons/hicolor &>/dev/null
    /usr/bin/gtk-update-icon-cache %{_datadir}/icons/hicolor &>/dev/null || :
fi

%changelog
* $(date '+%a %b %d %Y') Builder <builder@localhost> - %{version}-%{release}
- Initial package release
EOF
}

# Main loop
while true; do
    show_menu
    case $choice in
        1)
            build_packages
            read -p "Press Enter to continue..."
            ;;
        2)
            NEW_VERSION=$(increment_version $CURRENT_VERSION "major")
            echo -e "${YELLOW}Updating version to $NEW_VERSION${NC}"
            update_version $NEW_VERSION
            if ! build_packages; then
                echo -e "${RED}Build failed${NC}"
                read -p "Press Enter to continue..."
                continue
            fi
            if ! create_github_release $NEW_VERSION "Release $NEW_VERSION"; then
                echo -e "${RED}Release failed${NC}"
            fi
            read -p "Press Enter to continue..."
            ;;
        3)
            NEW_VERSION=$(increment_version $CURRENT_VERSION "minor")
            echo -e "${YELLOW}Updating version to $NEW_VERSION${NC}"
            update_version $NEW_VERSION
            if ! build_packages; then
                echo -e "${RED}Build failed${NC}"
                read -p "Press Enter to continue..."
                continue
            fi
            if ! create_github_release $NEW_VERSION "Release $NEW_VERSION"; then
                echo -e "${RED}Release failed${NC}"
            fi
            read -p "Press Enter to continue..."
            ;;
        4)
            NEW_VERSION=$(increment_version $CURRENT_VERSION "patch")
            echo -e "${YELLOW}Updating version to $NEW_VERSION${NC}"
            update_version $NEW_VERSION
            if ! build_packages; then
                echo -e "${RED}Build failed${NC}"
                read -p "Press Enter to continue..."
                continue
            fi
            if ! create_github_release $NEW_VERSION "Release $NEW_VERSION"; then
                echo -e "${RED}Release failed${NC}"
            fi
            read -p "Press Enter to continue..."
            ;;
        5)
            if [ -d "$BUILD_DIR" ]; then
                xdg-open $BUILD_DIR
            else
                echo -e "${RED}Build directory not found. Run build first.${NC}"
                read -p "Press Enter to continue..."
            fi
            ;;
        6)
            clean_build
            read -p "Press Enter to continue..."
            ;;
        7)
            check_flutter
            read -p "Press Enter to continue..."
            ;;
        0)
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            read -p "Press Enter to continue..."
            ;;
    esac
done 