# Chunk 2: A farmer NPC

**Status:** playable, awaiting Tyler's playtest

Wynn, a neighbour, farms his own smallholding east of yours.
- **The year's work:** he tills, sows by season, waters, weeds, pulls blight and picks off
  caterpillars. He harvests, reaps, binds, threshes and winnows, and leaves a bed to go to seed when
  he's short.
- **Money:** he pulls his handcart to the buyer to sell, and buys seed and bread at the stall.
- **His own needs:** he eats when hungry and sleeps in his own bed at night.

He follows exactly the same rules as you: the same plots, crops, floor, cart and buyer.

## How it's built (the pattern every profession will follow)

- **`Actor`** (`core/actor.gd`) is anyone who lives in the world.
  - It owns needs, gold, the pack, what's in the arms, and the walking body.
  - `Player` and `Npc` both extend it.
  - World objects (plots, carts, barrels, piles, the threshing floor, the buyer and stall) take an
    `Actor`, so either can use them.
- **`Npc`** (`core/npc/npc.gd`) is the villager's body.
  - It walks the navigation mesh, plays animations and holds tools in its hand.
  - It looks after basic needs (sleeps at night, eats when hungry) and talks: a bubble above its head,
    and a line on E.
- **`Role`** (`core/npc/role.gd`) is a profession, and only its decisions.
  - `next_task()` hands out the next `Task`: `GoTo`, `Work`, `Sequence`, `DoNow` or `SleepTask`.
  - `FarmerRole` (`farming/farmer_role.gd`) is the first. A `BakerRole` later should need no changes
    to `Npc`.
- **Skill instead of minigames:** where your quality comes from how you play a minigame, a
  villager's comes from `FarmerRole.SKILL` (0.75) plus a little luck.
- **The villager model** (`tools/blender/make_villager.py`) is our own low-poly rig.
  - It has 14 keyframed actions: idle, walk, carry, pull, hoe, sow, pour, crank, crouch, reap, flail,
    winnow, eat.
  - A new profession's motions are new pose tables in the same file.
  - Clothes are recoloured per villager (`Npc.tint`).
  - Mixamo needs an account and upload, so that's for Tyler to try. Quaternius's CC0 animation library
    could be retargeted later.
- **Ownership:** carts and barrels have an `owner_key`, and the buyer only sells your own things to
  you. Piles have no owner yet, so you *can* take Wynn's; theft is a later system.
- **Time:** villagers' walking and work scale with the 1×/2×/4× speed. When you sleep, Wynn sleeps
  too and starts the morning at home.

## Done when (what Tyler watches)

- [x] Wynn tills, sows, waters, weeds and harvests his beds through the seasons.
- [x] He pulls his loaded cart to the Produce Buyer, sells, and brings it home.
- [x] He eats, goes home at 21:00, and sleeps in his bed (lying properly, "Zzz").
- [x] He keeps working sensibly at 4×, and across your sleeps.
- [x] E on Wynn gets a line about what he's doing or the season.
- [x] Tests: a full farming year headlessly (sows 18 beds, about 90 harvest jobs, 20 → about 400
  gold, never starves). Also save/load, waking after your sleep, and not selling his cart to you.

## Not verified yet (needs Tyler's eyes)

How the animations and walking feel in motion, and whether his pace and choices look natural.

## Left for later

- Hiring villagers, and dialogue (LLM conversation is a later chunk).
- Relationships, rumours, theft.
- Smarter planning: crop rotation, saving money.
- More villagers.
- Villager footstep sounds.
