#!/bin/bash

# Exit on error
set -e

echo "Starting build process for Arch Linux..."

# Pull latest changes from GitHub
git pull origin main

# Get the latest version tag from GitHub and clean it
LATEST_TAG=$(git ls-remote --tags origin | sort -t '/' -k 3 -V | tail -n1 | awk -F/ '{print $3}' | sed 's/\^{}//g')
if [ -z "$LATEST_TAG" ]; then
    LATEST_TAG="v0.0.0"
fi
echo "Current version from GitHub: $LATEST_TAG"

# Extract version numbers
VERSION_PARTS=(${LATEST_TAG//[v.]/ })
MAJOR=${VERSION_PARTS[0]:-0}
MINOR=${VERSION_PARTS[1]:-0}
PATCH=${VERSION_PARTS[2]:-0}

# Increment patch version
NEW_PATCH=$((PATCH + 1))
NEW_VERSION="v$MAJOR.$MINOR.$NEW_PATCH"
echo "New version will be: $NEW_VERSION"

# Check for required build dependencies
deps=("git" "base-devel")
missing_deps=()

for dep in "${deps[@]}"; do
    if ! pacman -Qi "$dep" >/dev/null 2>&1; then
        missing_deps+=("$dep")
    fi
done

# Check for Flutter differently since it might be installed via snap or other means
if ! command -v flutter >/dev/null 2>&1; then
    missing_deps+=("flutter")
fi

if ! command -v dart >/dev/null 2>&1; then
    missing_deps+=("dart")
fi

if [ ${#missing_deps[@]} -ne 0 ]; then
    echo "Missing required dependencies: ${missing_deps[*]}"
    echo "Please install them using:"
    echo "sudo pacman -S ${missing_deps[*]}"
    exit 1
fi

# Get dependencies
echo "Getting dependencies..."
flutter pub get

# Build the project
echo "Building project..."
flutter build linux --release

# Create new git tag
git tag -a $NEW_VERSION -m "Release $NEW_VERSION"
git push origin $NEW_VERSION

echo "Build completed successfully!"
echo "Created and pushed new version tag: $NEW_VERSION" 