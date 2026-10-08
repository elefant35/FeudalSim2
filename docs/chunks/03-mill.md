# Chunk 3: The mill

**Status:** playable, awaiting Tyler's playtest

Grain now goes to a mill. Two post windmills stand on the map (placement is temporary until
construction roles exist):
- **Your windmill** is north-west of your house. You work it yourself.
- **The village mill** is north of the farms. **Osric** the miller works it and lives in the cottage
  beside it.

## What you do (the player's half)

1. **Face the wind.** The whole body turns on its post. Take the **tailpole** and walk it round; the
   body swings after you, slowly (it's heavy), and holds you back if you rush.
2. **Set the sails.** Brake the mill and let the sails stop, then spread or reef the cloth: bare, first
   reef, sword point, dagger point or full sail. More cloth or more wind means faster sails; past a point
   they "run away".
3. **Fill the hopper** with sacks of clean grain carried up the steps (4 at most).
4. **Let the brake off.** The stones grind into the meal bin (8 sacks): wheat into flour, barley into
   meal.
5. **Tend the stones.** The miller's craft. The tentering-lever mini-game (move the mouse) sets the gap
   between the stones:
   - Close stones grind fine but slowly. Too close and they grind the bran in (dusty, dark meal), and
     they run hot as the sails speed up.
   - Wide stones grind quickly but coarse.
   - The faster the sails turn, the wider the stones must be to keep the meal cool.

   Feel the meal at the spout (E, "rule of thumb") to judge it: hot, warm, dusty, gritty, rough or
   just right. Fine, cool, clean meal keeps the grain's quality; rough meal loses a grade, poor meal
   two. The lever shows the pace in sacks an hour, so the skill is grinding as wide as the meal
   allows. Running too fast, no gap gives the best meal, so reef in.
6. **Bag the flour** and sell it at the Produce Bought cart. Wheat flour sells for 13 at fair quality
   (grain 8); barley meal for 8 (grain 5).

The wind lives in the weather (`Clock`): a direction and strength that drift over the hours and
differ day to day. Calm days mean no milling; blustery ones mean reefing hard.

## The miller (the villager's half)

`MillerRole` (`milling/miller_role.gd`) works the same `PostMill` by the same rules:
- **Running the mill:** he walks the tailpole round when the wind shifts, brakes to set the cloth for
  the wind (judged with `SKILL`), carries grain up from his store, and lets the sails go.
- **Tending the stones:** he feels the meal at the spout and moves the tentering lever the way it says.
  That's the same reading you get, with no peeking at the numbers.
- **Selling:** he bags the flour and takes it to the buyer by handcart.
- **Closing up:** he brakes for the night and when the hopper runs dry.

He buys grain at his store with his own purse. Wynn now carts his grain to Osric instead of to the
buyer, and you can sell him yours.

## How it's built

- `PostMill` (`milling/post_mill.gd`):
  - **Structure:** a static trestle, plus a body that turns (a static body that's moved, on collision
    layer 2 so it's left out of the baked navigation).
  - **Interaction:** `MillPart` areas for each part you can aim at.
  - **Simulation:** the mill runs on `Clock.minutes_passed`, so headless tests and villagers use it
    exactly as the player does.
- **Villagers indoors:**
  - `GoTo` gained a `direct` mode (straight lines, no navmesh) for climbing the steps and moving about
    inside.
  - The body only turns while someone is outside on the tailpole, so spots computed when a task starts
    stay put.
- **Shared pieces** (from their second use):
  - `CartTrip` (Wynn's market trip, now also the miller's and Wynn's mill trip).
  - `WaitUntil`.
  - `ItemData.sack_model` (grain sacks, flour sacks).
  - `ItemData.mills_to`.
  - `tools/blender/kit.py` (shared by `make_models.py` and `make_mill.py`).
- **The produce buyer** stands in for the baker until chunk 4. It buys produce, flour and meal, but
  not raw grain.

## Done when

- [x] Your windmill: tailpole, cloth, brake, hopper, stones, tentering mini-game, meal bin.
- [x] Flour quality depends on the grain, the gap and the sail speed; flour sells for more than grain.
- [x] Osric works his mill through changing winds, sells flour, eats and sleeps.
- [x] Wynn sells grain to Osric; the buyer refuses raw grain; you can sell to Osric but not work his mill.
- [x] Models (trestle, turning body with interior, sails with reefable cloth, flour sack) and sounds
  (sails, stones, brake, cloth, creaks).
- [x] Tests:
  - The rules: wind, grinding, gap and quality, cloth with the brake, the tailpole, save/load,
    frame-sized time steps.
  - The grain trade.
  - A headless week of the miller: 28 sacks ground at about quality 1.5, and 60 → about 430 gold.

## Not verified yet (needs Tyler's eyes)

- Whether tending the stones is fun and suitably "semi-difficult".
- The feel of walking the tailpole round.
- Osric's pace.

## Known rough edges

- A handcart can be pulled through a mill's body and steps (carts only collide with the static
  world).
- Nothing carries you with a turning body: stand inside Osric's mill while he walks it round, and the
  walls will shove you.
- From the floor the hopper's rim is near eye level, so read its prompt for how many sacks are in it.

## Left for later

- Dressing the millstones as they wear (a mill-bill mini-game).
- A miller's toll for grinding other people's grain.
- The lord's mill rights.
- A sack hoist.
- The baker buying flour instead of the produce buyer (chunk 4).
- Weather vanes on the mills.
