#!/bin/sh
# Play a test sandbox: 200 gold, every tool, ripe crops of each kind, sheaves to thresh.
# Doesn't touch your real save.
cd "$(dirname "$0")/.."
exec /Applications/Godot_mono.app/Contents/MacOS/Godot --path . -- --nosave --scenario=sandbox --pos=-1,0,-3 --look=-90,-10
