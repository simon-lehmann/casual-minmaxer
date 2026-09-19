# Casual MinMaxer — architecture and data contract

This file is the binding contract between the Python data pipeline, the data addon, the
addon logic modules, the UI and the tests. Change it first, then the code.

Design doc (source of product decisions): Casual MinMaxer — TBC Classic Addon Design Doc
(Claude Doc, 2026-09-19). Deviations from it are listed at the end.

## 1. Repository layout

```
casual-minmaxer/
  CasualMinMaxer/            addon: logic + UI, always loaded, no data
    CasualMinMaxer.toc
    Libs/                    LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0 (vendored)
    Locales/enUS.lua deDE.lua
    Init.lua                 namespace, version, module registry
    Compat.lua               client API differences (2.5.x builds), tooltip scanning helpers
    Constants.lua            slot keys, inventory-type map, stat keys, tier constants, skill lines
    Ratings.lua              rating -> percent conversion per level
    Weights.lua              default stat weights per class/spec/phase, default gems, socket bonus table
    Specials.lua             hand-assigned stat equivalents for proc / on-use items
    Data.lua                 loads CasualMinMaxer_Data, decodes records lazily, indexes by slot
    Player.lua               character snapshot (class, level, faction, spec, professions, equipped, quests)
    Scoring.lua              item score, slot-pair logic, sockets, phase weights
    Obtain.lua               tiers, expected time, hard gates, chain progress, longevity
    Query.lua                candidate selection, filters, sort, cache
    Pawn.lua                 Pawn string import / export
    Export.lua               character export string for the website
    Validate.lua             /cmm validate: compares data pack vs GetItemStats in game
    Core.lua                 events, slash commands, SavedVariables + migration
    UI/Window.lua            main window: slot strip, result list, filter bar
    UI/Rows.lua              row widgets (recycled), row detail panel
    UI/QuestAdvisor.lua      marks best reward on QuestFrame
    UI/Tooltip.lua           score line on item tooltips
    UI/Options.lua           weights editor (sliders), Pawn import, constants, phase
    UI/Minimap.lua           LDB data object + LibDBIcon button
  CasualMinMaxer_Data/       generated. Load-on-demand. Never edited by hand.
    CasualMinMaxer_Data.toc
    Meta.lua Items_*.lua Sources_*.lua Quests.lua Npcs.lua Bosses.lua Dungeons.lua Objects.lua Zones.lua
  pipeline/                  Python 3.12, stdlib only (sqlite3)
    extract_sqlite.py        MariaDB (docker) -> pipeline/work/tbcdb.sqlite
    build.py                 tbcdb.sqlite + overrides/ -> CasualMinMaxer_Data/ (+ JSON for the website)
    overrides/*.json         hand data: phases, boss times, specials, fixes, exclusions
    tests/                   pytest
  tests/                     busted specs for the Lua modules (run outside the game)
    stubs/wow.lua            minimal WoW API stub
    spec/*_spec.lua
  scripts/                   db-up.sh, package.sh (zip for CurseForge/Wago), run-tests.sh
  docs/ARCHITECTURE.md       this file
  Makefile                   make test | lint | data | package
```

## 2. Canonical stat keys

Weights, item records, specials and gems all use these keys. Ratings are stored as raw
rating on items and converted to percent for scoring; weights for rating keys are per 1 %.

| Key | Meaning | Stored as | Scored as |
| --- | --- | --- | --- |
| STR AGI STA INT SPI | primary stats | flat | flat |
| ARMOR | armor value (item_template.armor) | flat | flat |
| AP | melee attack power | flat | flat |
| RAP | ranged attack power | flat | flat |
| FAP | feral attack power (aura 99 with a shapeshift stance mask) | flat | flat |
| SP | spell damage and healing, all schools (aura 13, misc 126) | flat | flat |
| SPFIRE SPFROST SPSHADOW SPNATURE SPARCANE SPHOLY | school-only spell damage | flat | flat |
| HEAL | healing (aura 135) | flat | flat |
| MP5 | mana per 5 s (aura 85, power type 0) | flat | flat |
| HP5 | health per 5 s (aura 85 power type 1 / aura 161) | flat | flat |
| BLOCKV | shield block value (item block column + aura 158) | flat | flat |
| ARP | armor penetration (aura 123) | flat | flat |
| HIT SPHIT CRIT SPCRIT HASTE SPHASTE EXP DEF DODGE PARRY BLOCK RES | ratings | rating | percent (DEF, EXP: skill points) |
| DPS | weapon DPS (melee weapons; also wands) | float | float |
| SPEED | weapon speed in seconds (delay / 1000) | float | see 6.3 |
| RDPS | ranged weapon DPS (bow, gun, crossbow, thrown) | float | float |

Item stat_type mapping: 3 AGI, 4 STR, 5 INT, 6 SPI, 7 STA, 12 DEF, 13 DODGE, 14 PARRY, 15 BLOCK,
16 HIT, 17 HIT, 18 SPHIT, 19 CRIT, 20 CRIT, 21 SPCRIT, 28 HASTE, 29 HASTE, 30 SPHASTE, 31 HIT,
32 CRIT, 35 RES, 36 HASTE, 37 EXP. Stat types 0/1 (mana/health) are ignored.
Rating aura 189 mask bits: 2 DEF, 4 DODGE, 8 PARRY, 16 BLOCK, 32|64 HIT, 128 SPHIT, 256|512 CRIT,
1024 SPCRIT, 114688 RES, 131072|262144 HASTE, 524288 SPHASTE, 8388608 EXP.

Rating conversion (Ratings.lua): rating per 1 % = base60[key] × f(L):
f(L) = 2/52 for L ≤ 10, (L − 8)/52 for 11 ≤ L ≤ 59, 82/(262 − 3L) for 60 ≤ L ≤ 70.
base60: HIT 10, SPHIT 8, CRIT 14, SPCRIT 14, HASTE 10, SPHASTE 10, DEF 1.5, DODGE 12, PARRY 15,
BLOCK 5, RES 25, EXP 2.5. Check: at 70, HIT 15.77, CRIT 22.08, DEF 2.37, RES 39.42.

## 3. Slot keys

| Key | Inventory types | Notes |
| --- | --- | --- |
| HEAD 1, NECK 2, SHOULDER 3, CHEST 5 and 20, WAIST 6, LEGS 7, FEET 8, WRIST 9, HANDS 10, BACK 16 | armor | |
| FINGER 11 | rings | two equipped, compare vs weaker, unique-equipped respected |
| TRINKET 12 | trinkets | as rings |
| MAINHAND | 13 (1H), 17 (2H), 21 (MH) | candidates for the main-hand slot |
| OFFHAND | 13 (1H, dual-wield specs only), 22 (OH weapon), 14 (shield), 23 (held) | |
| RANGED | 15 bow, 25 thrown, 26 gun/crossbow/wand, 28 relic | one key; the class decides which subclasses are usable |

Inventory type 4 (shirt), 18 (bag), 19 (tabard), 24 (ammo) and 27 (quiver) are excluded by the pipeline.

Weapon subclasses (item class 2): 0 axe, 1 2H axe, 2 bow, 3 gun, 4 mace, 5 2H mace, 6 polearm,
7 sword, 8 2H sword, 10 staff, 13 fist, 15 dagger, 16 thrown, 18 crossbow, 19 wand.
Armor subclasses (class 4): 0 misc, 1 cloth, 2 leather, 3 mail, 4 plate, 6 shield, 7 libram, 8 idol, 9 totem.

## 4. Data pack format (CasualMinMaxer_Data)

The data addon fills the global `CasualMinMaxer_Data` (short: `D`). It is `LoadOnDemand`, loaded by
`Data.lua` on first use. Item records are packed strings decoded lazily into a cache (memory). All
strings are `;`-separated fields; lists inside a field use `,`; key-value lists use `KEY:value`. Fields
never contain `;` `,` `:` `|` (the pipeline strips them from names).

### 4.1 Items — `D.items[itemId] = "name;inv;cls;sub;q;ilvl;req;classmask;flags;stats;sockets;sbonus;phase"`

| # | Field | Values |
| --- | --- | --- |
| 1 | name | English item name |
| 2 | inv | InventoryType number (see §3) |
| 3 | cls | 2 weapon, 4 armor |
| 4 | sub | subclass number (see §3) |
| 5 | q | quality 2 uncommon, 3 rare, 4 epic |
| 6 | ilvl | item level |
| 7 | req | required character level |
| 8 | classmask | AllowableClass; 0 = any class. Bits: 1 Warrior, 2 Paladin, 4 Hunter, 8 Rogue, 16 Priest, 64 Shaman, 128 Mage, 256 Warlock, 1024 Druid |
| 9 | flags | bit sum: 1 unique-equipped, 2 BoE, 4 BoP, 8 set piece, 16 special effect not scored (use/proc/chance-on-hit/unknown aura), 32 heroic-only source, 64 Alliance-only item (AllowableRace), 128 Horde-only item |
| 10 | stats | `STA:27,AGI:18,AP:36,DPS:56.3,SPEED:2.6` (keys from §2, empty allowed) |
| 11 | sockets | letters in socket order: R red, Y yellow, B blue, M meta; empty if none |
| 12 | sbonus | socket bonus enchantment id, 0 if none |
| 13 | phase | 1–5 content phase in which the item becomes obtainable (see §7) |

Items are split by slot group into `Items_<Group>.lua`, groups: Head, Neck, Shoulder, Back, Chest,
Wrist, Hands, Waist, Legs, Feet, Finger, Trinket, Weapon (inv 13/17/21/22), OffhandArmor (14/23),
Ranged (15/25/26/28). The split is for file size only; every file writes into `D.items`.

### 4.2 Sources — `D.src[itemId] = "<src>|<src>|..."`

| Code | Format | Meaning |
| --- | --- | --- |
| Q | `Q<questId>` | quest reward (choice or fixed) |
| B | `B<npcEntry>:<pct>` | dungeon boss drop, pct is the flattened drop chance (0.01–100, one decimal) |
| R | `R<npcEntry>:<pct>` | rare or rare-elite spawn drop (creature rank 2 or 4) |
| N | `N<npcEntry>:<pct>` | named open-world creature drop with pct ≥ 1 (not boss, not rare) |
| T | `T<mapId>:<pct>` | dungeon trash drop; pct = highest per-mob chance on that map |
| G | `G<goEntry>:<pct>` | chest / game object loot |
| V | `V<price>:<mode>` | vendor. price in copper; mode 0 = gold, E = extended cost (badges, honor, arena, tokens), `F<factionId>-<rank>` = reputation vendor (rank 4 friendly .. 7 exalted). When both rep and extended cost apply, rep wins |
| K | `K<skillLine>:<skill>` | crafted; skill line 171 Alchemy, 164 Blacksmithing, 333 Enchanting, 202 Engineering, 165 Leatherworking, 197 Tailoring, 755 Jewelcrafting |
| W | `W<pct>` | world drop: a reference loot table shared by ≥ 5 loot owners outside one instance, outdoor chests, or ≥ 5 different creatures; pct = highest single-mob chance. N sources are capped at the 5 best creatures |

Decoded shape (`Data.ParseSources`, also `item.src`, parsed on access): `{t="Q", quest=id}`,
`{t="B"|"R"|"N", npc=entry, pct=n}`, `{t="T", map=id, pct=n}`, `{t="G", object=entry, pct=n}`,
`{t="V", price=copper, mode="0"|"E"|"F", faction=id, rank=n}`, `{t="K", skillLine=id, skill=n}`, `{t="W", pct=n}`.

An item with no source is not shipped. Sources are sorted best-first by the pipeline (Q, K, V, B, G, R, N, T, W)
but the addon recomputes the best source per character.

### 4.3 Quests — `D.quests[questId] = "title;minLevel;questLevel;races;classes;zone;type;prev;next;excl;choice;fixed"`

races: `A` (Alliance), `H` (Horde), `0` (any) or the raw race mask. classes: 0 or class mask.
zone: AreaTable id (ZoneOrSort > 0) or 0. type: quest_template.Type (0 normal, 1 group, 41 PvP,
62 raid, 81 dungeon, 85 heroic). prev: PrevQuestId (positive = must be completed first; negative =
must be active). next: NextQuestInChain. excl: ExclusiveGroup. choice / fixed: comma lists of reward
item ids. Only quests that reward at least one shipped item, plus every quest reachable backwards
through `prev` from those, are shipped (so chain length can be computed).

### 4.4 Creatures — `D.npcs[entry] = "name;level;rank;map;respawnMin"`

Shipped for every entry referenced by B, R or N. rank: 0 normal, 1 elite, 2 rare, 3 world boss,
4 rare elite. map: map id of its spawn (0 Eastern Kingdoms, 1 Kalimdor, 530 Outland, else instance).
respawnMin: minimum respawn in minutes (0 if unknown).

### 4.5 Bosses — `D.bosses[entry] = "map;index;heroic"`

index: encounter order from DungeonEncounter (0-based). heroic: 1 if this is the heroic version
of the creature (CMaNGOS HeroicEntry), 0 otherwise. Heroic bosses share the map id.

### 4.6 Dungeons — `D.dungeons[mapId] = { name=, min=, max=, zone=, heroic=, bosses={entry,...}, t={min,...} }`

`bosses` in encounter order; `t[i]` = hand-tuned minutes from instance entrance to boss i for a
leveling-appropriate group (overrides/dungeons.json; default 6 + 7 × i). `heroic` true when a
heroic mode exists (all TBC 5-mans). `zone` = AreaTable id of the entrance zone. Only 5-player
instances are shipped; raids are excluded (design non-goal).

### 4.7 Objects — `D.objects[goEntry] = "name;map"` for G sources.

### 4.8 Zones — `D.zones[areaId] = "English name"` hand-authored for leveling zones; the addon
prefers `C_Map.GetAreaInfo(areaId)` and falls back to this table.

### 4.9 Meta — `D.meta = { version=, built=, dbVersion=, items=, quests=, phases=5 }`

### 4.10 Specials — `D.specials[itemId] = "AP:90"` stat-equivalents added to the item's stats
before scoring, from overrides/specials.json. Items with a special entry drop flag 16.

## 5. Module API (Lua)

Every addon file starts with `local ADDON, CMM = ...` (WoW passes the addon name and a private
table). `Init.lua` also exposes `_G.CasualMinMaxer = CMM` for other addons and for tests.
Logic modules (`Constants`, `Ratings`, `Weights`, `Specials`, `Data`, `Scoring`, `Obtain`, `Query`,
`Pawn`, `Export`) must not touch frames or any global WoW API beyond what `Compat` wraps, so busted
can load them with `tests/stubs/wow.lua`.

```lua
CMM.Constants.SLOT_KEYS            -- ordered list of slot keys (§3)
CMM.Constants.INV_TO_SLOT[inv]     -- inventory type -> slot key (13 -> "MAINHAND"; Query adds OFFHAND for dual wielders)
CMM.Constants.STAT_KEYS            -- ordered list of §2 keys
CMM.Constants.RATING_KEYS          -- set of rating keys
CMM.Constants.TIER                 -- { minutesPerQuest=10, groupOverhead=15, travel=15, trashRun=45, vendorWalk=5, craftOwn=20, craftOther=30, lotteryBelowPct=15 }

CMM.Ratings.PerPercent(key, level) -> rating needed for 1 %
CMM.Ratings.ToPercent(key, rating, level) -> percent

CMM.Weights.Specs(classToken) -> { specKey, ... }            -- e.g. "ARMS", "FURY", "PROTECTION"
CMM.Weights.Get(classToken, specKey, level) -> weights table  -- phase blended, then char overrides applied by Core
CMM.Weights.DefaultGem(classToken, specKey, level, color) -> stats table (uncommon gems < 70, rare at 70)
CMM.Weights.SocketBonus(enchantId) -> stats table or nil
CMM.Weights.PHASES                 -- { {1,19}, {20,39}, {40,57}, {58,69}, {70,70} }

CMM.Data.Load() -> bool                      -- loads the LoD addon, builds slot indexes
CMM.Data.Item(id) -> item or nil             -- decoded: { id, name, inv, cls, sub, q, ilvl, req, classmask, flags, stats={}, sockets="RY", sbonus, phase, src={ {t="B", npc=, pct=}, ... } }
CMM.Data.ItemsForSlot(slotKey) -> array of ids  (OFFHAND includes 1H weapons; caller filters)
CMM.Data.Quest(id), Data.Npc(entry), Data.Boss(entry), Data.Dungeon(map), Data.Object(entry), Data.ZoneName(areaId)

CMM.Player.Get() -> snapshot { class="WARRIOR", classId, level, faction="Alliance"|"Horde", race, raceMask,
                               spec="ARMS", professions={[skillLine]=skill}, equipped={[slotKey]=itemId or {id1,id2}},
                               zoneName, canDualWield, usable = { armor = {[sub]=true}, weapon = {[sub]=true} } }
CMM.Player.QuestDone(questId) -> bool        -- cached C_QuestLog.IsQuestFlaggedCompleted

CMM.Scoring.ScoreStats(stats, weights, level) -> number
CMM.Scoring.ScoreItem(item, ctx) -> number   -- ctx = { level, weights, class, spec, slotKey } handles sockets, specials, DPS/speed
CMM.Scoring.EquippedScore(slotKey, ctx, player) -> number, itemId   -- weaker of two for rings/trinkets; MH+OH sum when comparing 2H
CMM.Scoring.Gain(candidate, slotKey, ctx, player) -> gain, gainPct  -- slot-pair aware (§6.3)

CMM.Obtain.Gate(item, player, opts) -> ok, reason          -- hard gates (§6.4)
CMM.Obtain.Evaluate(item, player, opts) -> { tier=1..5, minutes=, src=<best source record>, text="Quest, 3 steps left, Zangarmarsh", group=bool, zone=areaId }
CMM.Obtain.ChainRemaining(questId, player) -> steps, firstQuestId
CMM.Obtain.LastsUntil(item, slotKey, ctx, player) -> level or 70

CMM.Query.Run(slotKey, player, opts) -> { rows = { row, ... }, equippedScore=, equippedId= }
  -- row = { id, item, score, gain, gainPct, tier, minutes, eff (gain per hour), obtain=<Evaluate result>, lastsUntil, special=bool, set=bool }
  -- opts = { filters = <CharDB.filters>, sort = "eff"|"gain"|"fast"|"value", sidegrades=bool, lookahead=n, dungeon=mapId or nil, zone="current"|areaId|nil, showSpecial=bool }
CMM.Query.RunDungeon(mapId, player, opts) -> { [bossEntry] = { rows } }   -- reverse lookup
CMM.Query.Invalidate()

CMM.Pawn.Import(str) -> weights table, specName   -- "( Pawn: v1: "name": Stamina=1, ... )" (Pawn stat names mapped to §2 keys)
CMM.Pawn.Export(weights, name) -> str
CMM.Export.String(player, weights) -> base64 string;  CMM.Export.Parse(str) -> table
```

### 5.1 Core, events and UI entry points
Core owns the event frame, SavedVariables (`CasualMinMaxerDB`, `CasualMinMaxerCharDB` with defaults +
migration), and `/cmm` (`/cmm` toggle window; `/cmm <slot>` e.g. `/cmm head` opens that slot; `/cmm options`;
`/cmm validate [n]`; `/cmm export`; `/cmm phase <1-5>`; `/cmm reset`; `/cmm debug`). Core fires on the
internal bus (`CMM.On/CMM.Fire`): `"PLAYER_CHANGED"` (level, spec, professions, equipment or quests changed;
Query cache already invalidated), `"DATA_LOADED"`, `"WEIGHTS_CHANGED"`, `"SETTINGS_CHANGED"`.
UI exposes `CMM.UI.Toggle(slotKey)`, `CMM.UI.Show(slotKey)`, `CMM.UI.Hide()`, `CMM.UI.Refresh()`,
`CMM.UI.OpenOptions()`; Core calls them only if present, so logic tests run without UI files.
Active weights: `CMM.Core.ActiveWeights()` = `Weights.Get(class, spec, level)` overlaid with
`CharDB.weights[spec]` (user sliders / Pawn import). Spec: `CharDB.specOverride or Player.Get().spec`.

## 6. Rules

### 6.1 Candidate set for a slot
Items whose slot key matches, whose class mask allows the class, whose armor/weapon subclass the
class can use (Constants.USABLE[class]), whose required level ≤ level + lookahead, and that pass the
hard gates. Armor filter "highest usable only" keeps subclass == the class's best armor at that level
(Warrior/Paladin mail < 40, plate ≥ 40; Hunter/Shaman leather < 40, mail ≥ 40).

### 6.2 Score
`Score = Σ w[key] × v[key]` over the item's stats plus specials, with rating values converted to
percent at the character level, plus socket contribution (default gem per socket color; socket bonus
only if every default gem matches its socket color; meta sockets are ignored). Enchants and gems on
the equipped item are ignored: base item vs base item.

### 6.3 Weapons
DPS is a stat with its own weight; wands use DPS too. Speed preference: `w.SPEEDPREF` in
{ -1, 0, 1 }: +1 rewards slow weapons, −1 fast; contribution = SPEEDPREF × (SPEED − 2.4) × w.DPS × 2.
Off-hand weapons use `w.DPS_OH` (0 for non-dual-wield specs) and `w.SPEEDPREF_OH`. Ranged weapons use RDPS.
Two-hand candidates compare against MH + OH equipped combined; a 1H candidate for MAINHAND compares
against the equipped MH (or, if a 2H is equipped, against 2H score minus the best OFFHAND candidate's
score, floor 0). Feral druids and casters have w.DPS = 0 so weapon choice follows stats.

### 6.4 Hard gates (item removed)
1. Wrong class/race/faction for the item or all of its sources.
2. Every quest source already completed (Player.QuestDone), or quest race/class mask excludes the character.
3. Quest minLevel > level + lookahead.
4. Source creature level > level + 3 (content too high); dungeon min level > level + lookahead.
5. Item phase > current phase (CharDB/DB setting).
6. Reputation vendor rank above current standing (GetFactionInfoByID) — only when the faction is known to the client.
7. Heroic-only sources are gated to level 70.
Filter (not gate): source type, tier, dungeon, zone, group, armor type, special, sidegrades.

### 6.5 Tiers and expected minutes
| Tier | When | Minutes |
| --- | --- | --- |
| 1 guaranteed solo | normal quest (type 0) or crafted with own profession at skill | remaining chain × 10 (+15 if the quest zone ≠ current zone); craft 20 |
| 2 guaranteed group | dungeon / group / heroic quest (type 81, 1, 85) | 15 + remaining chain × 10 |
| 3 farmable drop | boss pct ≥ 15, chest pct ≥ 15 | (15 + t[boss]) / (pct/100) |
| 4 lottery | boss/chest pct < 15, rare spawn, named mob, trash, world drop | boss formula; rare: max(respawn, 30) / p; named/world: 30 / p; trash: 45 / p |
| 5 buyable | vendor (gold or extended), crafted by another profession, BoE listed only when the filter allows | vendor 5, craft 30 |

Best source = lowest expected minutes among the character's usable sources; tier = that source's
tier. Efficiency = gain / (minutes / 60). Value over time = efficiency × (lastsUntil − level + 1).

### 6.6 Longevity
`LastsUntil(item)` = lowest level L > current where some tier-1/2 item for the same slot with
req ≤ L scores higher than the item at level L (weights for L, ratings at L); 70 if none.

### 6.7 Content phases
1 launch (all Classic content, all TBC dungeons and leveling, Karazhan/Gruul/Mag excluded as raids),
2 SSC/TK era: season 2 arena (Merciless), 3 Hyjal/BT: season 3 (Vengeful), badge gear 2.3? no — 4 ZA
and the 2.3 badge vendor additions, 5 Sunwell: Magisters' Terrace (map 585), season 4 (Brutal), 2.4
badge gear. Rules live in overrides/phases.json (by map, by name prefix, by item id list).

## 7. SavedVariables

```lua
CasualMinMaxerDB = { version=1, ui={x,y,w,h,scale}, minimap={hide=false, minimapPos=220},
                     constants={...TIER overrides...}, phase=5, showSidegradesDefault=false }
CasualMinMaxerCharDB = { version=1, specOverride=nil, weights={ [specKey]={...} }, lookahead=2,
                         filters={ sources={Q=true,...}, tiers={[1]=true,[2]=true,[3]=true}, dungeon=nil,
                                   zone=nil, groupOnly=false, armor="all", special=true, sidegrades=false, sort="eff" },
                         hidden={ [itemId]=true }, lastSlot="HEAD" }
```

## 8. Events and performance
`PLAYER_LOGIN` (init), `PLAYER_EQUIPMENT_CHANGED`, `PLAYER_LEVEL_UP`, `QUEST_TURNED_IN`,
`CHARACTER_POINTS_CHANGED`/`PLAYER_TALENT_UPDATE` (spec), `SKILL_LINES_CHANGED` (professions),
`ZONE_CHANGED_NEW_AREA`, `QUEST_COMPLETE` (advisor). No OnUpdate. Query results cached per
(slot, level, weights hash, filters hash) until invalidated. Names/icons for visible rows via
`Item:CreateFromItemID(id):ContinueOnItemLoad()` with the data-pack English name as immediate fallback.

## 9. Tests
- `make test` runs busted over `tests/spec`. `tests/stubs/wow.lua` provides the WoW globals the
  logic modules touch. `tests/helpers.lua` loads addon files in .toc order with the `(ADDON, CMM)` varargs
  and a small fixture data pack `tests/fixtures/data.lua` in the §4 format.
- `make lint` runs luacheck with `.luacheckrc` (WoW globals declared).
- `make data` rebuilds the data pack; `pipeline/tests` (pytest) cover loot flattening, stat decoding, chain
  extraction and format invariants on the real snapshot.
- `/cmm validate [n]` in game compares n random shipped items with `GetItemStats` and prints mismatches.

## 10. Deviations from the design doc
- No Ace3. Plain Lua modules + LibStub/CallbackHandler/LDB/LibDBIcon: smaller, no external SVN fetch,
  logic modules testable with a tiny stub.
- Load-on-demand works per addon, not per file: the whole data addon loads on first window open. Files are
  still split per slot group for size.
- Item records are packed strings from the start (the doc's fallback), decoded on first access.
- Boss order is taken from DungeonEncounter data instead of hand entry; only time-to-boss is hand-tuned.
