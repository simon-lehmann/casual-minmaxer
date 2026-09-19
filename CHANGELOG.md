# Changelog

## 0.2.1 (2026-09-19)

- Random-suffix rows carry the roll chance from the loot tables; rare rolls cost proportionally more time and
  rolls under 0.5 % are not listed.
- One row per base item with the best suffix; the other good suffixes and their chances sit in the detail panel.
- At most 8 auction-house rows per slot (options: "Auction rows per slot", "Minimum suffix roll chance %").
- Saved tier constants are re-applied after a reload (previously lost until changed again).

## 0.2.0 (2026-09-19)

- Random-suffix and random-property greens are listed as auction-house candidates, one row per useful
  suffix (best 3 per base item), with stats computed from the client's ItemRandomSuffix / RandPropPoints tables.
- Equipped random-suffix items are scored exactly from the link's suffix id.
- Socket bonuses come from the client's SpellItemEnchantment table instead of hand estimates.
- New source filters: Auction house (default on); World drop (BoE) now defaults to on.
- Interface number 20506 (TBC Classic 2.5.6).

## 0.1.0 (2026-09-19)

First complete build.

- Main window with slot strip, ranked upgrade list, filter bar and dungeon mode.
- Row detail: quest chain with progress, boss position and drop chance, vendor and profession info.
- Quest reward advisor, tooltip score line, weights editor with Pawn import/export, minimap button.
- Obtainability model: five tiers, expected time per source, hard gates (faction, race, class,
  completed quests, level, content phase, heroic), reputation time penalty, longevity ("lasts until").
- Default weights for all 27 specs across five level phases, default gems, socket bonuses, ~200 hand-scored
  proc and on-use items.
- Data pack built from CMaNGOS TBC-DB: 9.7k items, 2.9k quests, 35 dungeons, vendors classified by
  currency (gold, badges, honor, arena, reputation), crafted recipes, rare spawns, world drops.
- `/cmm validate` compares the data pack with the client's item stats.
- English and German UI.
