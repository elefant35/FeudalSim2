# Chunk 1: Farming

**Status:** playable, awaiting Tyler's first playtest

A first-person medieval farm through the year. You till, sow, water, weed, protect and harvest your
fields, thresh and winnow your grain, and sell the crop for gold. You also eat, sleep, and plan your
planting around the four seasons.

## Decisions (from Tyler)

- **Time:** one day ≈ 15 real minutes at 1×. A speed control cycles the world clock through 1×, 2× and 4×.
- **Seasons:** spring, summer, autumn and winter, 6 days each. Crops take one or two seasons, so
  planning around the seasons is the strategy.
- **Difficulty:** semi-difficult, not stressful. Mini-games are forgiving, but neglect (no water,
  weeds, pests, blight) clearly costs yield and quality.
- **Start:** a hoe, a little seed and a little gold. Everything else is earned.
- **Chain:** goes through threshing and winnowing. Milling and flour are left for the baking chunk.
- **Physical produce (playtest 3):** harvests stay in the world.
  - **Arms:** bulky goods go into your arms (turnips 8, cabbages 4, sheaves 3, grain sacks 4). Tools
    can't be used while you carry.
  - **Setting down:** E puts the load in the handcart, on the threshing floor (sheaves), onto a
    matching pile, or on the grass as a new pile.
  - **Pack:** holds a handful (6) of produce to eat.
  - **Handcart:** pullable (E at its handles); the buyer buys from a cart parked beside it.
  - **Threshing floor:** threshed grain stays on the floor; winnowed grain goes into sacks beside it.
- **Plots anywhere (playtest 3):** the hoe breaks new ground on open grass (with a green/red
  placement outline). Four beds start dug in the fenced garden.

## Scope

**World:** a farm in a small valley. It has a static house with a bed and a food shelf, a well, a fenced
field of plots, a threshing floor, a tool stall (buy seeds, tools, bread) and a produce buyer's cart
(sell crops). Day and night cycle, with weather (rain waters the fields).

**Needs:**
- Hunger: eat crops or bread.
- Fatigue: sleep in your bed to advance to morning. Exhaustion slows you; collapse wakes you at home.
- Gold: kept in a wallet.
- Autosave when you sleep.

**Crops:**

| Crop | Sow in | Grows | Notes |
|---|---|---|---|
| Turnip | spring, summer, autumn | ~3 days | hardy, cheap, eaten raw |
| Cabbage | spring, summer | ~5 days | caterpillars |
| Barley | spring | ~5 days | killed by winter, threshed |
| Wheat | autumn | ~8 days' growth, overwinters, ripe in spring | threshed, most valuable |

**Work and mini-games:**
- **Till:** timed hoe strikes break the sod.
- **Sow:** throw handfuls where you aim; even cover gives more plants.
- **Water:** wind the bucket up the well, then pour. Soil dries daily.
- **Weed:** tug the weeds out without snapping the root.
- **Pests:** shoo crows off fresh seed (a scarecrow helps); pick caterpillars off cabbages.
- **Blight:** pull diseased plants before it spreads.
- **Harvest:** sickle sweeps cut grain into sheaves; pull root crops by hand.
- **Thresh:** beat the sheaves with the flail in rhythm.
- **Winnow:** toss the grain when the wind gusts.
- **Sell:** better quality earns more.

## Shipped

- **World:**
  - the valley farm with a cottage you can walk into (bed, hearth, table, shelves)
  - a fenced field of 12 plots, a well with a working crank, and a threshing floor with a wind pennant
  - a Tools & Seed stall and a Produce Bought cart on the lane
  - trees, rocks and flowers around the farm
  - a day/night sky and rain
- **Needs, gold and saving:**
  - hunger and energy; eating (F / pack); sleeping after 18:00
  - collapse when exhausted
  - gold wallet; buying and selling with quality-based prices
  - autosave on sleep, save/new game/quit from the Esc menu
- **Time:** 1×/2×/4× world speed (T, the HUD button, or the Esc menu); four 6-day seasons.
- **Crops:** turnip, cabbage, barley and wheat, each with sowing seasons, growth rates, frost hardiness,
  four visible growth stages, and blighted and dead looks.
- **Mini-games:**
  - tilling (timed strikes)
  - broadcast sowing (aimed handfuls with a cover map)
  - winding the well (circle the mouse)
  - pouring (fill to the band)
  - pulling weeds, blighted plants and root crops (strain meter)
  - picking caterpillars
  - reaping (steady mouse sweeps)
  - binding sheaves
  - threshing (rhythm)
  - winnowing (toss on the gust)
- **Pests:** crows that fly in for fresh seed (walk up to scare them, or place a scarecrow); weeds;
  caterpillars on cabbages; blight that spreads if left.
- **Art and sound:**
  - our own Blender-scripted models (arms, tools, cottage, well, crops, crow…) plus Kenney CC0 props
  - Poly Haven textures
  - CC0 and synthesized sounds
  - see `assets/CREDITS.md`
- **Tests:** 23 headless tests. They cover plot logic and the full turnip loop end-to-end
  (till → sow → grow → harvest → sell), the well, threshing and winnowing, sleep, needs, first-week
  survival, and save/load.
- **Dev tools:** `tools/shot.sh` takes in-game screenshots with dev flags (time, position, scenario, click).

## Playtest 1 feedback (fixed)

- **Props and setting:**
  - modern-looking props (orange barrel, street lamp, cardboard boxes) replaced with our own barrel,
    crate, lantern post and farm cart
  - unused Kenney models removed
  - the stall's display hoe was moved out of the canopy
- **Models and animation:**
  - crow wings re-attached; they fold when perched
  - the hoe is held properly: hands sit on the tool's grips (viewmodel rebuilt around grip points)
  - bread no longer shows as a magenta box
- **World glitches:**
  - fence collisions now match the fence models
  - the plot surface no longer flickers against its rim
  - the threshing-floor flag no longer flickers
  - no lip at the door; you also step over small ledges
  - rain stops at the roof and sounds muffled indoors
  - a real fireplace with flickering fire; the chimney is outside
  - sign text fits the board
- **Balance:**
  - crows are much rarer (max two at once)
  - crops grow faster (turnip 3 days, cabbage and barley 5, wheat 8)
  - you start with a bucket and a few turnips
- **Testing:** `tools/sandbox.sh` lets you test the later stages quickly.

## Playtest 2 feedback (fixed)

- **UI:**
  - the UI scales with the window, with larger text
  - prompts, hints and messages sit on readable backgrounds
  - the corners and hotbar no longer overlap
  - all seed shares one hotbar slot (press again to switch)
- **Clarity:**
  - a "Next:" line always names the next step (e.g. bind the cut stalks, then take sheaves to the
    threshing floor, then winnow)
  - field guide (G) with each crop's season, time and full field-to-market steps
  - a sign at the threshing floor listing its three steps
  - prompts on cut stalks say to switch to hands and bind them
- **Blight:** the misleading "burn it" text is gone; pulling a blighted plant is all it takes.

## Playtest 3 feedback (fixed)

- **Pack and hotbar:**
  - a visual pack: icon tiles rendered from the items' own 3D models, with counts and quality marks
  - you arrange the hotbar yourself (drag, or click then a slot; right-click to empty); slot 1 is
    always bare hands
  - new tools and seed fill free slots automatically, and the layout is saved
- **Mini-games:** their bars no longer overlap, and the hint sits lower.
- **Walking:** the player rides on a short foot ray, so door sills and small lips are walked over
  (checked by a scripted walk through the cottage door). The old step hack is gone.
- **Crop health:** a plot shows its health and what hurt it overnight (dry soil, weeds, caterpillars,
  waterlogging, left too long).

## Playtest 4 feedback (fixed)

- **Pack:** works like Minecraft.
  - Drag to move between the pack and the hotbar.
  - Clicking selects an item and shows its details and actions (Eat, put on or take off the hotbar);
    shift-click quick-moves.
  - Clicks act on release, so they never break a drag.
  - Panels refresh in place, so the cursor no longer jumps.
- **Icons:** framed from the model's real on-screen outline (the sickle is centred).
- **Sheaves:** set down, they lie flat in a stacked pile instead of standing on end.
- **Barrels:** buy one at the stall; it's set down beside it.
  - Fill it with E while carrying; E opens a window to take an armful or lift the barrel.
  - Carry it (contents and all, more slowly when full), set it down anywhere, or stand up to 3 in the
    handcart.
  - The buyer sells from barrels on a nearby cart or standing nearby.
- **Handcart:**
  - While pulling, both fists visibly grip the shafts' handle ends.
  - When the cart snags, it holds you back with a jolt and a message. You never silently let go;
    E releases it.

## Playtest 5 feedback (fixed)

- **Threshing:** you swing the flail yourself.
  - Mouse up raises it; a hard downswing brings the swingle cracking onto the sheaf.
  - Blow strength follows how fast you swing; a lazy swing barely counts, and you must raise it high first.
  - The swingle lags and whips over.
- **Winnowing:** each clean measure is bagged and set beside the floor as an ordinary pile of sacks
  (E picks them up). A message says where it went, and the HUD counts the sacks bagged.
- **Seed saving, done the realistic way:**
  - turnips and cabbages left in the ground after ripening bolt (flowering stalks) and give
    2 handfuls of seed each when pulled
  - grain is its own seed: keep a sack of clean grain as 6 handfuls of seed
  - for future crops, seed could also come from eating (e.g. dried peas and beans, apple cores)

## Not verified yet (needs Tyler's hands)

Every mini-game is exercised by tests and screenshots, but none of them has had a real mouse click.
The input routing, the trade/pack/menu panels, and the sleep fade still need a real playtest.

## Left for later

- **Polish:**
  - tool resting angles in first person
  - Kenney props whose colours clash with our palette (barrels, lantern)
  - seasonal tree colours and winter frost on the ground
- **More depth:**
  - soil fertility and crop rotation
  - manure
  - ploughing with an animal
  - more crops (peas, beans, onions, flax)
- **Straw and hay bales** for the animal chunk. Piles are generic (any bulky item), so a "straw" or "hay
  bale" item only needs a model and data.
- **Bigger systems, explicitly out of scope until their chunk:**
  - milling and flour (baking chunk)
  - real traders and price haggling (market chunk)
  - tool making (craftsmen chunk)
