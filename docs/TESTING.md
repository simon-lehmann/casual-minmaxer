# In-game test checklist

Everything below the "Automated" line runs on this repo without a client. The rest needs a
TBC Classic client (2.5.x); nothing in the automated suite can prove the addon loads in game,
so run this checklist once per release and after every data build.

## Automated (run before every release)

```sh
make lint && make test && make pytest
```

- `tests/spec/realdata_spec.lua` runs the full query path against the shipped data pack for
  a level 62 Arms warrior, a Horde shaman, a shadow priest chain walk, a resto druid in
  Slave Pens dungeon mode and a level 70 rogue (heroic gating).
- `tests/spec/integration_spec.lua` drives the real UI against the real logic.

## Client smoke test (15 minutes)

1. Install both folders. Log in. Expected: no Lua error; the minimap button appears.
   Check the interface version: `/run print((select(4, GetBuildInfo())))` must match the
   `## Interface:` line of both `.toc` files, otherwise the client marks the addon out of date.
2. `/cmm` opens the window. The slot strip shows your equipped icons and scores. The
   weakest slot is highlighted. Click a slot: rows appear in under a second (first open loads
   the data addon, which takes a moment).
3. Hover a row: the item tooltip shows, with the "Casual MinMaxer" score line at the bottom.
   Shift-click links it to chat. Right-click → Hide removes it; `/cmm unhide` brings it back.
4. Click a row: the detail panel shows the quest chain (completed steps marked), or boss
   position and drop chance, or vendor / profession information.
5. Pick a dungeon in the filter bar. Rows regroup per boss in kill order.
6. Turn in a quest with a choice of rewards: the best upgrade is outlined on the reward frame.
7. `/cmm options`: move a weight slider, the list re-sorts. "Reset" restores defaults. Paste a
   Pawn string; the sliders follow it.
8. `/cmm validate 50`, then `/cmm validate 200`. Expected: 0 mismatches on the compared keys
   (primary stats, armor, ratings). Spell-derived stats (attack power, spell damage, healing,
   mp5) are compared through the tooltip scan; report any mismatch there too.
9. Level up or change gear: the window refreshes without reopening.
10. `/reload`: window position, filters and custom weights persist.

## Believability review (30 minutes, one character per role)

For each character, open every slot and sanity-check the top 5:
- No item you cannot use (armor class, weapon type, faction, class).
- No quest you already completed. No quest from the other faction.
- Dungeon rows say the right boss and a plausible drop chance.
- Honor, arena and badge items sit below quest and dungeon items unless the gain is huge.
- "Lasts until" is later for higher-level items.

Record wrong rows with the row's right-click → "Report wrong data" string and paste them into
an issue, with your class, spec and level.

## Known limits

- Drop chances are emulator estimates; the tier is the reliable part.
- Socket bonuses are inferred for the most common 39 enchant ids; the rest are estimated.
- Random-suffix greens ("of the Bear") are not listed as candidates.
- Raid loot is never recommended (design decision); raid items you wear are still scored.
- TomTom waypoints land at the zone centre; the data pack has no coordinates.
