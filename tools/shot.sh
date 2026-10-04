#!/bin/sh
# Launch the game, take an in-game screenshot, quit. Usage: tools/shot.sh out.png [dev args...]
# Example: tools/shot.sh /tmp/a.png --hour=9 --pos=0,0,5 --look=180,-20
OUT="$1"; shift
GODOT=${GODOT:-/Applications/Godot_mono.app/Contents/MacOS/Godot}
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import >/dev/null 2>&1
perl -e 'alarm 60; exec @ARGV' "$GODOT" --path . -- --nosave --shot="$OUT" "$@" 2>&1 \
  | grep -E "ERROR|WARNING|DEV screenshot|^ +at: res|res://.*:[0-9]+" | grep -v "Model missing" | head -40
