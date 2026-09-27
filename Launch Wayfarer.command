#!/bin/bash
set -e
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -x "$PROJECT_DIR/builds/Wayfarer.app/Contents/MacOS/Wayfarer" ]; then
  exec "$PROJECT_DIR/builds/Wayfarer.app/Contents/MacOS/Wayfarer"
fi
exec /Applications/Godot.app/Contents/MacOS/Godot --path "$PROJECT_DIR"
