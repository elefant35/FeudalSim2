# AGENTS.md

Working agreement for AI agents (Claude and others) developing **FeudalSim2**.
Read this before every task. Keep it short; update it when a rule proves wrong.

## The destination

A single-player, first-person 3D medieval-fantasy game. Settlers land on an empty coast, survive, and
grow into feudal towns full of AI villagers. They share the player's skills, talk through LLMs layered
over hard-coded systems, and eventually feud and go to war. Every profession plays like its own game,
built from real steps and mini-games rather than "click to craft". Full brainstorm:
[docs/00-vision-original.md](docs/00-vision-original.md).

**That is the destination, not the task.** Nothing in it gets built until a chunk needs it.

## Why this repo exists

Tyler has started this game five or six times. Each time it started too big: first AI systems, then
survival, then civilization, with planning documents and infrastructure ahead of anything fun to play.
This repo does the opposite: **one small, playable game at a time**. Those games later merge into the big one.

This is a clean slate. **Do not open, copy, or take inspiration from Tyler's other projects** in
`~/Development` (or anywhere else): no code, assets, docs, folder structure or conventions. The only
inputs are this repo and the vision doc.

## The chunk rule

Each development cycle delivers one **chunk**: a complete mini-game Tyler can launch and play.

A chunk is done when:
- It launches with one command (below) and opens on something playable, not a menu of stubs.
- It has a full loop: start, do the work, see the result, and want to do it again.
- What the player touches has real models, animation and sound. Grey boxes are allowed while
  building, but not when the chunk ships.
- The agent has run it and looked at it (screenshots via the `game-development` skill). It can't be
  "done" based only on reading the code.
- Headless tests cover the logic (growth, needs, prices, save/load), and they pass.
- README "How to play" is updated, and `docs/chunks/NN-name.md` says what shipped and what's left.

**Roadmap** (Tyler decides the order; ask before starting a new chunk):
1. **Farming**, with basic needs (eat, sleep), gold, a tool shop and a produce buyer. *(done)*
2. **A farmer NPC** who works his own farm with the player's rules. *← current*
3. Baking (probably): flour, ovens, bread, and a baker NPC
4. Market
5. Tool craftsmen
6. Later: more professions, the settlement, society, conflict

Each profession now comes in two halves: the player's first-person version (minigames), then a
villager who can step into the same role.

## Keep the vision in mind, don't build it

Build what this chunk needs, shaped so it won't fight the future. Examples:

| Do | Don't (yet) |
|---|---|
| Anyone who lives in the world is an `Actor` (needs, gold, pack, arms, body); world objects take an `Actor` | Write world logic that only the player can use |
| A profession for villagers is a `Role`: decisions only, handing out `Task`s (GoTo, Work...) | Put profession logic in `Npc`, or give NPCs shortcuts around the rules |
| Villager motions are pose tables in `tools/blender/make_villager.py` on the one shared rig | Download a pre-animated character per profession |
| Gold is an integer in a wallet; shops read fixed prices from data | Build an economy sim, supply/demand, bartering |
| Items, crops and tools are data (`.tres` Resources), so baking can consume our wheat later | Build a generic crafting framework before a second profession needs one |
| World actions are methods on the object being acted on (`plot.till(actor)`), so any actor could call them | Add an action-planning or AI layer |
| One world scene that later chunks extend | Build a level/streaming/mod system |

Also not yet: LLM code and dialogue, networking, multiplayer, determinism frameworks, design bibles.
**Generalize on the second use, not the first.** When baking needs something farming built, extract it then.

## Stack and commands

- **Godot 4.7.2, GDScript only** (no C#). The installed binary is the .NET build; that's fine.
- Run the game: `/Applications/Godot_mono.app/Contents/MacOS/Godot --path .`
- Open the editor: add `-e`.
- Tests (headless): `/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s res://tests/run_tests.gd`
- Blender 5.1 (scripted models): `/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/blender/<script>.py -- <args>`
- Use static typing in GDScript (`var x: int`, typed function signatures). Keep scripts small and readable.

## Layout

```
project.godot
core/            shared across chunks: actor, player, npc (body, tasks, roles), needs, wallet, inventory, time
world/           the map: terrain, house, shops, props
farming/         plots, crops, farm tools, mini-games, and the FarmerRole
assets/          models/ sounds/ textures/ fonts/, and assets/CREDITS.md
tools/blender/   scripts that generate our own models
tests/           headless tests
docs/            vision + one short doc per chunk (docs/chunks/)
```

New chunks get their own top-level folder (`baking/`, `market/`…). Code moves into `core/` only when a
second chunk uses it.

## Assets

- **First-person**: the player sees their hands and tools, so first-person hand/tool animations matter
  most for the player's actions. World objects (growing crops, doors, chaff blowing) have their own animation.
- **Sources**: CC0 packs (e.g. Quaternius, Kenney, Poly Pizza CC0) plus our own Blender-scripted
  models and synthesized or recorded sounds. Licenses: CC0 or CC-BY only.
- **Ask Tyler before downloading anything.** Name the pack, the URL, the size and the license.
- Every asset gets a line in `assets/CREDITS.md`: file, source URL, author, license.
- Generated models: keep the script in `tools/blender/` and commit both the script and its `.glb` output.
- Keep the repo light. Flag it before the repo passes ~100 MB; switch to Git LFS if needed.

## Working agreement

- Ask Tyler when a choice changes how the game *feels*. Pick sensible defaults for everything else and say what you picked.
- Docs stay small: README, this file, the vision doc, and one page per chunk. No canon docs, ADRs, or plans for future chunks.
- Commit in small working steps; `main` must always launch. Push when Tyler asks.
- Realism is the flavor: medieval farming should look and feel like the real process (tools, crops,
  seasons), simplified only where that makes it more fun.
