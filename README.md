# Casual MinMaxer

A World of Warcraft **TBC Classic** addon that answers one question:

> "My slot X is weak. What is the biggest upgrade I can get quickly?"

Click a slot, get a ranked list of every obtainable upgrade for your class and spec, with a
score gain against what you wear and an honest estimate of how hard each item is to get: quest
(with chain length), dungeon boss (with drop chance), rare spawn, vendor, crafted, world drop.
Fully offline. All data ships with the addon.

## Features

- Slot strip with equipped scores; the weakest slot is highlighted.
- Ranked upgrade list per slot: score gain, source, obtainability tier, drop % or quest steps,
  "lasts until level X".
- Row detail: quest chain steps with your progress, dungeon and boss position, vendor price,
  profession and skill.
- Dungeon mode: pick a dungeon and see what you want from every boss across all slots.
- Quest reward advisor: the best reward is marked on the quest turn-in frame.
- Tooltip line with score and gain on any item.
- Weights editor per spec, Pawn string import/export, level-phase aware defaults for all 27 specs.
- Hard gates: faction, race, class, completed quests, level, content phase, reputation.
- Random-suffix greens ("of the Bear") from the auction house, one row per useful suffix with exact stats
  for the item level, and BoE world drops: the fastest way to gear up.
- Filters: source type, tier, dungeon, zone, group needed, armor type, lookahead, sidegrades.
- Export string for the companion website.

`/cmm` opens the window, `/cmm head` jumps to a slot, `/cmm options`, `/cmm validate 50`,
`/cmm export`, `/cmm phase 3`.

## Install

Copy `CasualMinMaxer` and `CasualMinMaxer_Data` into `World of Warcraft/_classic_/Interface/AddOns/`,
or install from CurseForge / Wago. Both folders are required; the data addon loads on demand
the first time you open the window.

## Repository layout

See `docs/ARCHITECTURE.md` for the module and data contract. Short version:

| Path | What |
| --- | --- |
| `CasualMinMaxer/` | the addon (logic + UI). Logic modules are pure Lua and unit-tested outside the game |
| `CasualMinMaxer_Data/` | generated data pack (items, sources, quests, dungeons); never edited by hand |
| `pipeline/` | Python pipeline: CMaNGOS TBC-DB → SQLite snapshot → Lua data pack + JSON |
| `pipeline/overrides/` | hand data: content phases, time-to-boss, zone names, special-item scores, fixes |
| `tests/` | busted specs and the WoW API stub |

## Development

Toolchain: Lua 5.1, LuaRocks with `busted` and `luacheck`, Python 3.12, Docker (for the
database import only).

```sh
make lint      # luacheck
make test      # busted unit tests for the Lua modules
make pytest    # pipeline tests (integration tests skip without the SQLite snapshot)
make package   # dist/CasualMinMaxer-<version>.zip
```

### Rebuilding the data pack

```sh
git clone --depth 1 https://github.com/cmangos/tbc-db.git /some/where/tbc-db
scripts/db-up.sh /some/where/tbc-db     # MariaDB in Docker, full DB + updates + Spell DBC dump
make data-snapshot                       # -> pipeline/work/tbcdb.sqlite
make data                                # -> CasualMinMaxer_Data/
```

### Validating in game

After a data build, log in on any character and run `/cmm validate 50`. The addon compares
50 random shipped items against the client's own item stats and prints every mismatch. Use
`/cmm validate 200` for a broader check. Report mismatches (or wrong sources) with the
"report wrong data" entry in a result row's right-click menu; it copies a string to paste
into an issue.

## Data and license

Item, quest, loot and vendor data is derived from the [CMaNGOS TBC-DB](https://github.com/cmangos/tbc-db)
project and the CMaNGOS Spell DBC dump, both GPL. Drop chances in emulator databases are
estimates; the addon therefore shows obtainability tiers first and raw percentages second.

Casual MinMaxer is released under the GNU General Public License v3.0 or later. See `LICENSE`.
Bundled libraries (LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0) keep their own licenses.
