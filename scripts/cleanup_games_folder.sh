#!/bin/bash

# Get the games folder path from settings
GAMES_PATH=$(flutter pub run wine_launcher:get_games_path)

# Check if wine_launcher folder exists in games directory
if [ -d "$GAMES_PATH/wine_launcher" ]; then
  echo "Moving wine_launcher folder out of games directory..."
  mv "$GAMES_PATH/wine_launcher" "$(dirname "$GAMES_PATH")/wine_launcher"
  echo "wine_launcher folder moved successfully"
else
  echo "wine_launcher folder not found in games directory"
fi
