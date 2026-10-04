# FeudalSim2

A first-person medieval-fantasy game, built one playable chunk at a time. Each chunk is a small, complete
game (farming, then baking, then a market…). The chunks eventually merge into one living medieval world.
See [docs/00-vision-original.md](docs/00-vision-original.md) for the long-term vision and
[AGENTS.md](AGENTS.md) for how it's built.

## Status

**Chunk 1: Farming** is playable. See [docs/chunks/01-farming.md](docs/chunks/01-farming.md) for what's in it.

## Running

Requires Godot 4.7.2 (at `/Applications/Godot_mono.app`).

```bash
/Applications/Godot_mono.app/Contents/MacOS/Godot --path .
```

Tests (headless): `/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s res://tests/run_tests.gd`

## How to play

It's the first morning of spring. You have a cottage, a fenced field of twelve plots, a hoe, a little turnip
seed, five loaves of bread and 12 gold. Everything else you earn.

**Your first days**
1. Walk to the field (east of the house). With the **hoe** in hand, look at a plot and click. A marker
   swings along a bar; click when it's in the green. Fresh sod takes a few good strikes.
2. Select your **turnip seed** and click to throw handfuls onto the tilled plot. The little 3×3 map shows
   your cover. Aim for every square green; bare squares grow nothing and orange ones are overcrowded.
   About four well-placed handfuls cover a plot.
3. Seed needs water. Walk south down the lane to the **Tools & Seed** stall and buy a **bucket**. At the
   **well**, hold the left button and circle the mouse to wind the bucket up. Then hold the left button over
   a plot to pour, and fill the soil to the marked band. A full bucket waters about three plots. Rain waters
   everything for you.
4. Each day, check your plots. Look at a plot to see its state. With empty **hands**: hold to pull weeds
   (ease off before the strain hits red, or the root snaps and regrows), click caterpillars off cabbages,
   and pull blighted plants before the blight spreads. Crows eat fresh seed; walk up to scare them, or buy a
   **scarecrow** and set it up beside the plots.
5. When a crop is ripe, pull root crops by hand. Grain is reaped with the **sickle**: hold and sweep the
   mouse across it in steady strokes. Then click the cut stalks to bind them into sheaves.
6. Take sheaves to the **threshing floor** (north-west of the house). Press E to lay them out, then use the
   **flail**, clicking as the ring closes on the circle. Then **winnow** with the basket: hold to lift and
   release to toss when the pennant shows a gust.
7. Sell produce and clean grain at the **Produce Bought** cart. Better quality earns more.

**Staying alive.** Hunger and energy drain through the day. **F** eats the plainest food you carry, or eat
from your pack (**Tab**). Turnips are edible raw, and bread is sold at the stall. Sleep in your bed (E)
after 18:00 to end the day; **the game saves whenever you sleep** (and from the Esc menu). If you work
yourself to exhaustion you'll collapse and wake at home the next morning.

**Seasons.** Each season lasts 6 days. Turnips: spring, summer or autumn, about 5 days, survive frost.
Cabbage: spring or summer, about 8 days. Barley: spring only, about 8 days, killed by winter. Wheat: sow in
autumn; it grows slowly through winter and ripens in early summer. Plan your plots around the year.

**Time speed.** **T** (or the button under the clock, or the Esc menu) cycles 1× / 2× / 4×. It speeds up
the *world*: the clock, crop growth, soil drying, hunger and energy. It does **not** speed up your walking
or the mini-games. At 1× a day lasts about 15 minutes.

| Key | Action |
|---|---|
| WASD, mouse | Move, look |
| Shift / Space | Run / jump |
| Left click (hold) | Use what's in your hand |
| Right click | Stop the current task |
| E | Interact (bed, stall, cart, threshing floor) |
| F | Eat |
| Tab | Pack (inventory) |
| 1–9, mouse wheel | Choose tool |
| T | Time speed |
| Esc | Menu (save, new game, quit) |
