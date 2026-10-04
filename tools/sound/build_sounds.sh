#!/bin/sh
# Builds assets/sounds/ from the CC0 packs in .vendor/ plus our synthesized sounds.
# Bank naming: <bank>_<n>.ogg; Sfx picks a random variant from a bank.
set -e
cd "$(dirname "$0")/../.."
V=.vendor
OUT=assets/sounds
TMP=$(mktemp -d)
mkdir -p $OUT
rm -f $OUT/*.ogg

ogg() { cp "$1" "$OUT/$2.ogg"; }
wav() { ffmpeg -loglevel error -y -i "$1" -c:a vorbis -strict -2 -ac 2 -ar 44100 -q:a 4 "$OUT/$2.ogg"; }

IMP="$V/kenney_impact-sounds/Audio"; RPG="$V/kenney_rpg-audio/Audio"; UI="$V/kenney_interface-sounds/Audio"
for i in 0 1 2 3 4; do ogg "$IMP/footstep_grass_00$i.ogg" step_grass_$((i+1)); ogg "$IMP/footstep_wood_00$i.ogg" step_wood_$((i+1)); done
for i in 0 1 2; do ogg "$IMP/impactSoft_heavy_00$i.ogg" hoe_strike_$((i+1)); ogg "$IMP/impactPlank_medium_00$i.ogg" thresh_$((i+1)); done
for i in 0 1; do ogg "$IMP/impactSoft_medium_00$i.ogg" pull_$((i+1)); ogg "$IMP/impactWood_light_00$i.ogg" snap_$((i+1)); done
ogg "$IMP/impactWood_heavy_000.ogg" thump_1
for i in 1 2 3 4; do ogg "$RPG/cloth$i.ogg" rustle_$i; done
for i in 1 2 3; do ogg "$RPG/creak$i.ogg" crank_$i; done
ogg "$RPG/knifeSlice.ogg" cut_1; ogg "$RPG/knifeSlice2.ogg" cut_2
ogg "$RPG/handleCoins.ogg" coins_1; ogg "$RPG/handleCoins2.ogg" coins_2
ogg "$UI/open_001.ogg" ui_open_1; ogg "$UI/close_001.ogg" ui_close_1; ogg "$UI/click_001.ogg" ui_click_1
W="$V/water-splash-slime-sfx"
for i in 1 2 3; do wav "$(find $W -name "splash_0$i.*" | head -1)" splash_$i; wav "$(find $W -name "slime_0$i.*" | head -1)" squish_$i; done
wav "$(find $W -name 'loop_water_01.*' | head -1)" pour
wav "$(find $W -name 'loop_rain.*' | head -1)" rain_loop
wav "$V/crow_caw.wav" crow_1

python3 tools/sound/synth.py "$TMP"
for f in "$TMP"/*.wav; do wav "$f" "$(basename "$f" .wav)"; done
rm -rf "$TMP"
ls $OUT | wc -l
