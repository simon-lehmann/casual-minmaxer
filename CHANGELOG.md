# Changelog

## 0.1.0 (unreleased)

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
