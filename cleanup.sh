#!/bin/bash

# Make script executable
chmod +x cleanup.sh

# Remove platform-specific directories
echo "Removing platform-specific directories..."
rm -rf android/
rm -rf ios/
rm -rf windows/
rm -rf macos/
rm -rf web/

# Remove platform-specific files
echo "Removing platform-specific files..."
rm -f android.iml
rm -f ios.iml
rm -f windows.iml
rm -f macos.iml
rm -f web.iml

# Clean up pubspec.yaml
echo "Cleaning pubspec.yaml..."
sed -i '/cupertino_icons/d' pubspec.yaml  # Remove iOS icons dependency

# Remove platform-specific comments from pubspec.yaml
sed -i '/In Android/d' pubspec.yaml
sed -i '/In iOS/d' pubspec.yaml
sed -i '/In Windows/d' pubspec.yaml
sed -i '/In macOS/d' pubspec.yaml
sed -i '/# Read more about.*versioning/d' pubspec.yaml

# Clean up .gitignore
echo "Cleaning .gitignore..."
cat > .gitignore << EOL
# Miscellaneous
*.class
*.log
*.pyc
*.swp
.DS_Store
.atom/
.buildlog/
.history
.svn/
migrate_working_dir/

# IntelliJ related
*.iml
*.ipr
*.iws
.idea/

# Flutter/Dart/Pub related
**/doc/api/
**/ios/Flutter/.last_build_id
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
.pub-cache/
.pub/
/build/

# Symbolication related
app.*.symbols

# Obfuscation related
app.*.map.json

# Coverage
coverage/

# Project specific
/downloads/
*.exe
EOL

# Clean up analysis_options.yaml to focus on Linux
echo "Updating analysis_options.yaml..."
cat > analysis_options.yaml << EOL
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_const_constructors: true
    prefer_const_declarations: true
    avoid_print: true
    use_key_in_widget_constructors: true
    prefer_const_literals_to_create_immutables: true

analyzer:
  exclude:
    - build/**
    - lib/generated_plugin_registrant.dart
EOL

echo "Cleanup complete!" 