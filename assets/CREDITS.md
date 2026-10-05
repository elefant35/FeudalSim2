# Asset credits

Every model, texture and sound in the game, where it came from, and its license. Only CC0 or
CC-BY assets are allowed (see AGENTS.md). The downloaded packs live in the gitignored `.vendor/`
folder; the converters copy just the files the game uses.

## Third-party (all CC0 1.0, public domain — no attribution required, credited with thanks)

| What | Files in this repo | Source | Author |
|---|---|---|---|
| Trees, rocks, bushes, grass, flowers, fences, logs, stumps, Kenney crop models | `assets/models/` ids listed under "kenney_nature-kit" in `tools/blender/pack_models.json` | [Nature Kit](https://kenney.nl/assets/nature-kit) | Kenney (kenney.nl) |
| Market stall (red awning) | `assets/models/town_stall_red.glb` | [Fantasy Town Kit 2.0](https://kenney.nl/assets/fantasy-town-kit) | Kenney |
| Loaf (bread) | `assets/models/food_loaf.glb` | [Food Kit](https://kenney.nl/assets/food-kit) | Kenney |
| Footsteps, hoe thuds, threshing thwacks, pulls, snaps, thump | `assets/sounds/step_*`, `hoe_strike_*`, `thresh_*`, `pull_*`, `snap_*`, `thump_*` | [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney |
| Rustles, crank creaks, cuts, coins | `assets/sounds/rustle_*`, `crank_*`, `cut_*`, `coins_*` | [RPG Audio](https://kenney.nl/assets/rpg-audio) | Kenney |
| UI open/close/click | `assets/sounds/ui_*` | [Interface Sounds](https://kenney.nl/assets/interface-sounds) | Kenney |
| Splashes, squishes, pouring water, rain loop | `assets/sounds/splash_*`, `squish_*`, `pour`, `rain_loop` | [40 CC0 water / splash / slime SFX](https://opengameart.org/content/40-cc0-water-splash-slime-sfx) | rubberduck (OpenGameArt) |
| Crow caw | `assets/sounds/crow_1` | [Crow caw](https://opengameart.org/content/crow-caw) | zeroisnotnull (OpenGameArt) |
| Grass, furrowed field and soil textures | `assets/textures/grass_ground_*`, `farm_furrows_*`, `farm_soil_*` | [Poly Haven](https://polyhaven.com/textures) — grass_ground, farm_furrows, farm_soil | Poly Haven |

Downloaded but not yet used: OpenGameArt "100 CC0 SFX" by rubberduck; Kenney Survival Kit.

The Kenney Nature Kit colours are converted from sRGB and re-tinted by `tools/blender/import_packs.py`.

## Original (made for FeudalSim2)

| What | Made by |
|---|---|
| First-person arms, hoe, bucket, sickle, flail, winnowing basket, seed pouch, scarecrow, cottage (with interior and fireplace), barrel, crate, lantern post, farm cart, well (with working crank), threshing floor, signboard, sheaves, grain piles and sacks, turnip/cabbage/barley/wheat at four growth stages plus blighted and dead versions, harvested turnip and cabbage, weed, caterpillar, crow | `tools/blender/make_models.py` (Blender, scripted) |
| The villager: rigged low-poly character and all its animations (idle, walk, carry, pull, hoe, ...) | `tools/blender/make_villager.py` (Blender, scripted rig and keyframes) |
| Sowing, grain patter, sickle swish, basket toss, eating, wing flaps, countryside ambience | `tools/sound/synth.py` (numpy) |

## Rebuilding

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/blender/import_packs.py
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/blender/make_models.py
tools/sound/build_sounds.sh
```
