#!/usr/bin/env python3
"""Casual MinMaxer data pipeline: tbcdb.sqlite + overrides/ -> CasualMinMaxer_Data/ (+ JSON).

Implements docs/ARCHITECTURE.md sections 2, 3, 4, 6.5 and 6.7. Stdlib only.

    python3 pipeline/build.py [--db pipeline/work/tbcdb.sqlite] [--out CasualMinMaxer_Data]
                              [--json pipeline/work/data.json] [--version 1.0.0]
"""
from __future__ import annotations

import argparse
import datetime as _dt
import json
import os
import re
import sqlite3
import sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OVERRIDES = os.path.join(HERE, "overrides")

# ---------------------------------------------------------------------------------------------
# Constants from the contract
# ---------------------------------------------------------------------------------------------

# InventoryType -> slot group file
INV_GROUP = {
    1: "Head", 2: "Neck", 3: "Shoulder", 16: "Back", 5: "Chest", 20: "Chest", 9: "Wrist", 10: "Hands",
    6: "Waist", 7: "Legs", 8: "Feet", 11: "Finger", 12: "Trinket",
    13: "Weapon", 17: "Weapon", 21: "Weapon", 22: "Weapon",
    14: "OffhandArmor", 23: "OffhandArmor",
    15: "Ranged", 25: "Ranged", 26: "Ranged", 28: "Ranged",
}
GROUP_ORDER = ["Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands", "Waist", "Legs", "Feet",
               "Finger", "Trinket", "Weapon", "OffhandArmor", "Ranged"]

STAT_TYPE = {3: "AGI", 4: "STR", 5: "INT", 6: "SPI", 7: "STA", 12: "DEF", 13: "DODGE", 14: "PARRY",
             15: "BLOCK", 16: "HIT", 17: "HIT", 18: "SPHIT", 19: "CRIT", 20: "CRIT", 21: "SPCRIT",
             28: "HASTE", 29: "HASTE", 30: "SPHASTE", 31: "HIT", 32: "CRIT", 35: "RES", 36: "HASTE",
             37: "EXP"}

# combat rating mask bits (aura 189 misc value) -> key
RATING_BITS = [(2, "DEF"), (4, "DODGE"), (8, "PARRY"), (16, "BLOCK"), (32, "HIT"), (64, "HIT"),
               (128, "SPHIT"), (256, "CRIT"), (512, "CRIT"), (1024, "SPCRIT"), (16384, "RES"),
               (32768, "RES"), (65536, "RES"), (131072, "HASTE"), (262144, "HASTE"),
               (524288, "SPHASTE"), (8388608, "EXP")]

SCHOOL_KEY = {2: "SPHOLY", 4: "SPFIRE", 8: "SPNATURE", 16: "SPFROST", 32: "SPSHADOW", 64: "SPARCANE"}

STAT_KEYS = ["STR", "AGI", "STA", "INT", "SPI", "ARMOR", "AP", "RAP", "FAP", "SP", "SPFIRE", "SPFROST",
             "SPSHADOW", "SPNATURE", "SPARCANE", "SPHOLY", "HEAL", "MP5", "HP5", "BLOCKV", "ARP", "HIT",
             "SPHIT", "CRIT", "SPCRIT", "HASTE", "SPHASTE", "EXP", "DEF", "DODGE", "PARRY", "BLOCK", "RES",
             "DPS", "SPEED", "RDPS"]
STAT_ORDER = {k: i for i, k in enumerate(STAT_KEYS)}

RANGED_SUBCLASS = {2, 3, 16, 18}
SOCKET_LETTER = {1: "M", 2: "R", 4: "Y", 8: "B"}

# recipe item subclass -> skill line
RECIPE_SKILL = {1: 165, 2: 197, 3: 202, 4: 164, 6: 171, 8: 333, 10: 755}
CRAFT_SKILLS = {171, 164, 333, 202, 165, 197, 755}

ALL_CLASS_MASK = 1503  # the 9 TBC classes
ALLIANCE_RACES = 1101
HORDE_RACES = 690

FLAG_UNIQUE, FLAG_BOE, FLAG_BOP, FLAG_SET, FLAG_SPECIAL, FLAG_HEROIC = 1, 2, 4, 8, 16, 32
FLAG_ALLIANCE, FLAG_HORDE = 64, 128  # proposed addition (AllowableRace restricted to one faction)

SRC_ORDER = {c: i for i, c in enumerate("QKVBGRNTW")}

BAD_NAME_PREFIX = ("Monster -", "Deprecated", "[PH]", "TEST", "OLD", "[DEP", "[DND", "(OLD)", "zzOLD", "Test ")

# maps that are raids or PvP even though instance_template says <= 10 players
NON_DUNGEON_MAPS = {532, 568, 249, 30, 489, 529, 566, 559, 562, 572, 169}

LOTTERY_BELOW_PCT = 15.0
# a chest whose table yields more shippable items than this is a generic world chest, not a dungeon chest
GENERIC_CHEST_ITEMS = 25


def clean(s: str | None) -> str:
    """Strip the separator characters from a name so it never breaks a packed record."""
    if not s:
        return ""
    s = s.replace("|", "").replace(";", "").replace(",", "").replace(":", "")
    s = re.sub(r"\s+", " ", s).strip()
    return s


def fmt_pct(p: float) -> str:
    p = max(0.01, min(100.0, p))
    if p >= 1:
        s = f"{p:.1f}"
    else:
        s = f"{p:.2f}"
    s = s.rstrip("0").rstrip(".")
    return s or "0.01"


def fmt_num(v: float) -> str:
    if abs(v - round(v)) < 1e-9:
        return str(int(round(v)))
    return f"{v:.1f}".rstrip("0").rstrip(".")


def load_override(name: str, default):
    path = os.path.join(OVERRIDES, name)
    if not os.path.exists(path):
        return default
    with open(path, encoding="utf-8") as f:
        return json.load(f)


# ---------------------------------------------------------------------------------------------
# Loot flattening
# ---------------------------------------------------------------------------------------------

def flatten_loot_table(rows, ref_tables, _depth=0, exclude_refs=None):
    """Flatten one loot table into {item: pct}.

    rows: iterable of (item, chance, groupid, mincountOrRef). ref_tables: {ref_id: rows}.
    Rules (CMaNGOS LootTemplate): rows with chance < 0 are quest-only and skipped; a negative
    mincountOrRef references another table rolled with the row's chance; inside a groupid > 0
    exactly one entry drops: explicit-chance entries keep their chance, zero-chance entries share
    the remainder (100 - sum of explicit) equally; groupid 0 entries roll independently.
    """
    if _depth > 8:
        return {}
    groups = defaultdict(list)
    for item, chance, groupid, mcr in rows:
        if chance is None:
            chance = 0.0
        if chance < 0:
            continue
        if exclude_refs and mcr is not None and mcr < 0 and -mcr in exclude_refs:
            continue
        groups[groupid or 0].append((item, float(chance), mcr))

    out = defaultdict(float)

    def add(item, pct, mcr):
        if pct <= 0:
            return
        if mcr is not None and mcr < 0:
            sub = ref_tables.get(-mcr)
            if not sub:
                return
            for sub_item, sub_pct in flatten_loot_table(sub, ref_tables, _depth + 1, exclude_refs).items():
                out[sub_item] = max(out[sub_item], sub_pct * pct / 100.0)
        else:
            out[item] = max(out[item], pct)

    for gid, entries in groups.items():
        if gid == 0:
            for item, chance, mcr in entries:
                add(item, chance if chance > 0 else 100.0, mcr)
        else:
            explicit = [e for e in entries if e[1] > 0]
            equal = [e for e in entries if e[1] == 0]
            explicit_sum = sum(e[1] for e in explicit)
            for item, chance, mcr in explicit:
                add(item, min(chance, 100.0), mcr)
            if equal and explicit_sum < 100.0:
                share = (100.0 - explicit_sum) / len(equal)
                for item, _c, mcr in equal:
                    add(item, share, mcr)
    return dict(out)


def sort_sources(sources):
    """Best-first order per contract: Q, K, V, B, G, R, N, T, W; within a code higher pct first."""
    def key(s):
        code = s[0]
        pct = 0.0
        m = re.search(r":([\d.]+)$", s)
        if m and code in "BGRNTW":
            pct = float(m.group(1))
        elif code == "W":
            pct = float(s[1:])
        return (SRC_ORDER.get(code, 99), -pct, s)
    return sorted(set(sources), key=key)


# ---------------------------------------------------------------------------------------------
# Stat decoding
# ---------------------------------------------------------------------------------------------

def decode_item_stats(item: dict, spells: dict):
    """Return (stats dict, special flag) for an item_template row (dict) using spells {id: row}."""
    stats = defaultdict(float)
    special = False
    for i in range(1, 11):
        st, sv = item.get(f"stat_type{i}") or 0, item.get(f"stat_value{i}") or 0
        if st and sv:
            key = STAT_TYPE.get(st)
            if key:
                stats[key] += sv
    for i in range(1, 6):
        sid = item.get(f"spellid_{i}") or 0
        trig = item.get(f"spelltrigger_{i}")
        if not sid:
            continue
        if trig in (0, 2):  # use / chance on hit
            special = True
            continue
        if trig != 1:
            continue
        sp = spells.get(sid)
        if not sp:
            special = True
            continue
        for e in range(1, 4):
            eff = sp.get(f"Effect{e}") or 0
            if eff == 0:
                continue
            aura = sp.get(f"EffectApplyAuraName{e}") or 0
            base = (sp.get(f"EffectBasePoints{e}") or 0) + (sp.get(f"EffectDieSides{e}") or 0)
            misc = sp.get(f"EffectMiscValue{e}") or 0
            if eff != 6:  # not APPLY_AURA
                special = True
                continue
            if aura == 99:
                stats["FAP" if (sp.get("Stances") or 0) != 0 else "AP"] += base
            elif aura == 124:
                stats["RAP"] += base
            elif aura == 13:
                if misc == 126 or misc == 127:
                    stats["SP"] += base
                elif misc in SCHOOL_KEY:
                    stats[SCHOOL_KEY[misc]] += base
                else:
                    # multi-school but not all: count as generic SP of the lowest contribution
                    stats["SP"] += base
            elif aura == 135:
                stats["HEAL"] += base
            elif aura == 85:
                if misc == 0:
                    stats["MP5"] += base
                elif misc == 1:
                    stats["HP5"] += base
                else:
                    special = True
            elif aura == 161:
                stats["HP5"] += base
            elif aura == 158:
                stats["BLOCKV"] += base
            elif aura == 123:
                stats["ARP"] += base
            elif aura == 189:
                matched = False
                for bitv, key in RATING_BITS:
                    if misc & bitv:
                        if not matched or key not in stats or True:
                            pass
                        matched = True
                seen = set()
                for bitv, key in RATING_BITS:
                    if misc & bitv and key not in seen:
                        stats[key] += base
                        seen.add(key)
                if not matched:
                    special = True
            else:
                special = True
    # weapons
    cls = item.get("class")
    sub = item.get("subclass") or 0
    delay = item.get("delay") or 0
    if cls == 2 and delay > 0:
        dmg = 0.0
        for i in range(1, 3):
            mn, mx = item.get(f"dmg_min{i}") or 0, item.get(f"dmg_max{i}") or 0
            dmg += (mn + mx) / 2.0
        dps = dmg / (delay / 1000.0)
        if dps > 0:
            stats["RDPS" if sub in RANGED_SUBCLASS else "DPS"] = round(dps, 1)
            stats["SPEED"] = round(delay / 1000.0, 2)
    if cls == 4:
        armor = item.get("armor") or 0
        if armor > 0:
            stats["ARMOR"] += armor
        if sub == 6 and (item.get("block") or 0) > 0:
            stats["BLOCKV"] += item.get("block")
    out = {k: v for k, v in stats.items() if abs(v) > 1e-9}
    return out, special


def stats_to_str(stats: dict) -> str:
    return ",".join(f"{k}:{fmt_num(v)}" for k, v in sorted(stats.items(), key=lambda kv: STAT_ORDER.get(kv[0], 99)))


def item_flags(item: dict, sources, heroic_only: bool) -> int:
    flags = 0
    if (item.get("maxcount") or 0) == 1 or ((item.get("Flags") or 0) & 0x80000):
        flags |= FLAG_UNIQUE
    bonding = item.get("bonding") or 0
    if bonding == 2:
        flags |= FLAG_BOE
    elif bonding == 1:
        flags |= FLAG_BOP
    if (item.get("itemset") or 0) > 0:
        flags |= FLAG_SET
    if heroic_only:
        flags |= FLAG_HEROIC
    race = item.get("AllowableRace")
    if race not in (None, -1, 0, 32767, 1791):
        if race & ALLIANCE_RACES and not race & HORDE_RACES:
            flags |= FLAG_ALLIANCE
        elif race & HORDE_RACES and not race & ALLIANCE_RACES:
            flags |= FLAG_HORDE
    return flags


def races_field(mask: int | None) -> str:
    if not mask or mask in (-1, 32767, 1791):
        return "0"
    if mask & ALLIANCE_RACES and not mask & HORDE_RACES:
        return "A"
    if mask & HORDE_RACES and not mask & ALLIANCE_RACES:
        return "H"
    return str(mask)


def classmask_field(mask: int | None) -> int:
    if mask is None or mask < 0 or (mask & ALL_CLASS_MASK) == ALL_CLASS_MASK:
        return 0
    return mask & ALL_CLASS_MASK


def lua_str(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


# ---------------------------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------------------------

class Builder:
    def __init__(self, db_path: str, version: str):
        self.db = sqlite3.connect(db_path)
        self.db.row_factory = sqlite3.Row
        self.version = version
        self.phases = load_override("phases.json", {})
        self.dungeon_over = load_override("dungeons.json", {})
        self.zones_over = load_override("zones.json", {})
        self.specials = load_override("specials.json", {})
        self.fixes = load_override("fixes.json", {})
        self.report = defaultdict(int)

    # -- helpers -------------------------------------------------------------------------------
    def rows(self, sql, *args):
        return [dict(r) for r in self.db.execute(sql, args)]

    # -- world model ---------------------------------------------------------------------------
    def load_world(self):
        # instances
        self.instances = {}
        for r in self.rows("select map, levelMin, levelMax, maxPlayers from instance_template"):
            self.instances[r["map"]] = r
        self.dungeon_maps = {m for m, r in self.instances.items()
                             if 0 < (r["maxPlayers"] or 0) <= 10 and m not in NON_DUNGEON_MAPS}
        self.raid_maps = {m for m in self.instances if m not in self.dungeon_maps}

        # creature templates
        self.ct = {}
        for r in self.rows("select Entry, Name, Rank, MinLevel, MaxLevel, LootId, HeroicEntry, VendorTemplateId, "
                           "NpcFlags from creature_template"):
            self.ct[r["Entry"]] = r
        self.heroic_of = {}  # heroicEntry -> normal entry
        for e, r in self.ct.items():
            if r["HeroicEntry"]:
                self.heroic_of[r["HeroicEntry"]] = e

        # spawns: entry -> {maps}, respawn
        self.spawn_maps = defaultdict(set)
        self.respawn = {}
        for r in self.rows("select id, map, spawntimesecsmin from creature where id > 0"):
            self.spawn_maps[r["id"]].add(r["map"])
            m = (r["spawntimesecsmin"] or 0) // 60
            if m > 0:
                self.respawn[r["id"]] = min(self.respawn.get(r["id"], 10 ** 9), m)
        for r in self.rows("select c.map, c.spawntimesecsmin, cse.entry from creature c "
                           "join creature_spawn_entry cse on cse.guid = c.guid"):
            self.spawn_maps[r["entry"]].add(r["map"])
            m = (r["spawntimesecsmin"] or 0) // 60
            if m > 0:
                self.respawn[r["entry"]] = min(self.respawn.get(r["entry"], 10 ** 9), m)
        # heroic entries inherit their normal entry's spawn maps
        for h, n in self.heroic_of.items():
            if n in self.spawn_maps:
                self.spawn_maps[h] |= self.spawn_maps[n]

        # bosses via encounters
        self.bosses = {}  # entry -> (map, index, heroic)
        enc = self.rows("select e.MapId, e.EncounterIndex, e.EncounterName, ie.creditType, ie.creditEntry "
                        "from instance_dungeon_encounters e join instance_encounters ie on ie.entry = e.Id "
                        "where e.Difficulty = 0 order by e.MapId, e.EncounterIndex")
        for r in enc:
            if r["creditType"] != 0 or not r["creditEntry"]:
                continue
            entry = r["creditEntry"]
            if entry in self.bosses:
                continue
            self.bosses[entry] = (r["MapId"], r["EncounterIndex"], 0)
            h = self.ct.get(entry, {}).get("HeroicEntry")
            if h:
                self.bosses[h] = (r["MapId"], r["EncounterIndex"], 1)
        for k, v in (self.fixes.get("bosses") or {}).items():  # {"entry": [map, index, heroic]}
            self.bosses[int(k)] = tuple(v)

        # dungeon boss order
        self.dungeon_bosses = defaultdict(list)
        for entry, (m, idx, heroic) in self.bosses.items():
            if heroic == 0:
                self.dungeon_bosses[m].append((idx, entry))
        for m in self.dungeon_bosses:
            self.dungeon_bosses[m].sort()

        # dungeon names from areatriggers
        self.at_names = defaultdict(list)
        for r in self.rows("select name, target_map from areatrigger_teleport"):
            self.at_names[r["target_map"]].append(r["name"] or "")

        # game objects (chests)
        self.go_loot = {}  # go entry -> loot id
        self.go_name = {}
        self.go_map = {}
        for r in self.rows("select entry, name, data1 from gameobject_template where type = 3 and data1 > 0"):
            self.go_loot[r["entry"]] = r["data1"]
            self.go_name[r["entry"]] = r["name"]
        for r in self.rows("select id, map from gameobject"):
            if r["id"] in self.go_loot and r["id"] not in self.go_map:
                self.go_map[r["id"]] = r["map"]

        # spells
        self.spells = {}
        for r in self.rows("select * from spell_template"):
            self.spells[r["Id"]] = r

    # -- loot ----------------------------------------------------------------------------------
    def load_loot(self):
        refs = defaultdict(list)
        for r in self.rows("select entry, item, ChanceOrQuestChance, groupid, mincountOrRef from reference_loot_template"):
            refs[r["entry"]].append((r["item"], r["ChanceOrQuestChance"], r["groupid"], r["mincountOrRef"]))
        self.refs = refs
        # how many creatures use each reference table (for W classification)
        self.ref_users = defaultdict(set)
        creature_loot = defaultdict(list)
        for r in self.rows("select entry, item, ChanceOrQuestChance, groupid, mincountOrRef from creature_loot_template"):
            creature_loot[r["entry"]].append((r["item"], r["ChanceOrQuestChance"], r["groupid"], r["mincountOrRef"]))
            if r["mincountOrRef"] is not None and r["mincountOrRef"] < 0:
                self.ref_users[-r["mincountOrRef"]].add(r["entry"])
        # ref -> items it (transitively) yields, for "broad reference" detection
        self.creature_loot = creature_loot
        go_loot = defaultdict(list)
        for r in self.rows("select entry, item, ChanceOrQuestChance, groupid, mincountOrRef from gameobject_loot_template"):
            go_loot[r["entry"]].append((r["item"], r["ChanceOrQuestChance"], r["groupid"], r["mincountOrRef"]))
            if r["mincountOrRef"] is not None and r["mincountOrRef"] < 0:
                self.ref_users[-r["mincountOrRef"]].add(("go", r["entry"]))
        self.go_loot_rows = go_loot
        # maps where each GO loot id is spawned
        self.go_loot_maps = defaultdict(set)
        for go, loot_id in self.go_loot.items():
            if go in self.go_map:
                self.go_loot_maps[loot_id].add(self.go_map[go])

    def compute_broad_refs(self):
        """Reference tables used by >= 5 creatures that are not all inside one instance = world-drop tables."""
        broad = set()
        for ref_id, users in self.ref_users.items():
            if len(users) < 5 or ref_id not in self.refs:
                continue
            maps = set()
            for u in users:
                if isinstance(u, tuple):
                    maps |= self.go_loot_maps.get(u[1], set())
                else:
                    maps |= self.spawn_maps.get(u, set())
            inst = maps & (self.dungeon_maps | self.raid_maps)
            if maps and maps == inst and len(inst) == 1:
                continue  # shared trash table of a single instance
            broad.add(ref_id)
        # a reference that only points at broad references is broad too
        changed = True
        while changed:
            changed = False
            for ref_id, rows in self.refs.items():
                if ref_id in broad:
                    continue
                subs = [-r[3] for r in rows if r[3] is not None and r[3] < 0]
                if subs and all(sr in broad for sr in subs) and len(subs) == len(rows):
                    broad.add(ref_id)
                    changed = True
        self.broad_refs = broad
        return broad

    def broad_ref_items(self):
        """Items that come from world-drop reference tables -> {item: max pct}."""
        out = {}
        for ref_id in self.broad_refs:
            for item, pct in flatten_loot_table(self.refs[ref_id], self.refs).items():
                out[item] = max(out.get(item, 0.0), pct)
        return out

    # -- items ---------------------------------------------------------------------------------
    def candidate_items(self):
        items = {}
        for r in self.rows("select * from item_template where InventoryType > 0 and Quality between 2 and 4 "
                           "and class in (2, 4)"):
            inv = r["InventoryType"]
            if inv not in INV_GROUP:
                continue
            if r["class"] == 2 and r["subclass"] == 20:
                continue
            name = r["name"] or ""
            if any(name.startswith(p) for p in BAD_NAME_PREFIX) or not name.strip():
                continue
            if (r["RandomProperty"] or 0) != 0 or (r["RandomSuffix"] or 0) != 0:
                continue
            items[r["entry"]] = r
        return items

    def build(self):
        self.load_world()
        self.load_loot()
        items = self.candidate_items()
        item_ids = set(items)
        sources = defaultdict(list)       # item -> [src strings]
        raid_only = defaultdict(bool)
        used_npcs, used_objects, used_quests = set(), set(), set()
        heroic_src = defaultdict(list)    # item -> [bool heroic] per source

        # quests
        quest_rows = self.rows("select * from quest_template")
        self.quests = {q["entry"]: q for q in quest_rows}
        for q in quest_rows:
            rewards = [q[f"RewChoiceItemId{i}"] for i in range(1, 7)] + [q[f"RewItemId{i}"] for i in range(1, 5)]
            for it in rewards:
                if it and it in item_ids:
                    sources[it].append(f"Q{q['entry']}")
                    used_quests.add(q["entry"])
                    heroic_src[it].append(q["Type"] == 85)

        # creature loot: direct rows only; world-drop reference tables become W sources
        self.compute_broad_refs()
        broad = self.broad_ref_items()
        creature_hits = defaultdict(dict)  # item -> {entry: pct}
        for entry, rows in self.creature_loot.items():
            ct = self.ct.get(entry)
            if not ct:
                continue
            for item, pct in flatten_loot_table(rows, self.refs, exclude_refs=self.broad_refs).items():
                if item in item_ids:
                    creature_hits[item][entry] = max(creature_hits[item].get(entry, 0.0), pct)
        for item, hits in creature_hits.items():
            trash = defaultdict(float)
            named = []
            raid_hits = 0
            for entry, pct in hits.items():
                ct = self.ct[entry]
                maps = self.spawn_maps.get(entry, set())
                boss = self.bosses.get(entry)
                if boss:
                    m, _idx, heroic = boss
                    if m in self.dungeon_maps:
                        sources[item].append(f"B{entry}:{fmt_pct(pct)}")
                        used_npcs.add(entry)
                        heroic_src[item].append(heroic == 1)
                    else:
                        raid_hits += 1
                    continue
                if not maps:
                    continue
                if maps & self.raid_maps and not maps & self.dungeon_maps and not (maps - self.raid_maps):
                    raid_hits += 1
                    continue
                dmaps = maps & self.dungeon_maps
                if dmaps:
                    for m in dmaps:
                        trash[m] = max(trash[m], pct)
                    continue
                if ct["Rank"] in (2, 4):
                    sources[item].append(f"R{entry}:{fmt_pct(pct)}")
                    used_npcs.add(entry)
                    heroic_src[item].append(False)
                elif ct["Rank"] == 3:
                    raid_hits += 1  # outdoor world boss: raid-level content
                elif pct >= 1.0:
                    named.append((pct, entry))
            for m, pct in trash.items():
                sources[item].append(f"T{m}:{fmt_pct(pct)}")
                heroic_src[item].append(False)
            bonding = items[item]["bonding"] or 0
            world_pct = broad.get(item)
            outdoor_count = sum(1 for e in hits if self.spawn_maps.get(e) and not (self.spawn_maps[e] & (self.dungeon_maps | self.raid_maps)))
            if world_pct is not None or (bonding == 2 and outdoor_count >= 5):
                wp = max([world_pct or 0.0] + [p for p, e in named])
                if wp <= 0:
                    wp = max(hits.values())
                sources[item].append(f"W{fmt_pct(wp)}")
                heroic_src[item].append(False)
                named = [(p, e) for p, e in named if p > wp * 4 and p >= 5.0]  # a genuinely better named source
            named.sort(reverse=True)
            for pct, entry in named[:5]:
                sources[item].append(f"N{entry}:{fmt_pct(pct)}")
                used_npcs.add(entry)
                heroic_src[item].append(False)
            if raid_hits and not sources[item]:
                raid_only[item] = True

        for item, wp in broad.items():
            if item in item_ids and not any(s[0] == "W" for s in sources[item]):
                sources[item].append(f"W{fmt_pct(wp)}")
                heroic_src[item].append(False)

        # game object loot
        chest_world = {}
        for go, loot_id in self.go_loot.items():
            m = self.go_map.get(go)
            if m is None:
                continue
            rows = self.go_loot_rows.get(loot_id)
            if not rows:
                continue
            flat = flatten_loot_table(rows, self.refs, exclude_refs=self.broad_refs)
            generic = sum(1 for i in flat if i in item_ids) > GENERIC_CHEST_ITEMS
            for item, pct in flat.items():
                if item in item_ids:
                    if m in self.raid_maps:
                        raid_only[item] = raid_only[item] or True
                        continue
                    if m not in self.dungeon_maps or generic:
                        # outdoor and generic chests hold world-drop tables: fold into W
                        chest_world[item] = max(chest_world.get(item, 0.0), pct)
                        continue
                    sources[item].append(f"G{go}:{fmt_pct(pct)}")
                    used_objects.add(go)
                    heroic_src[item].append(False)
        for item, wp in chest_world.items():
            if not any(s[0] == "W" for s in sources[item]):
                sources[item].append(f"W{fmt_pct(wp)}")
                heroic_src[item].append(False)

        # vendors
        vendor_items = defaultdict(list)  # item -> [(entry, ext)]
        spawned = {e for e, maps in self.spawn_maps.items() if maps}
        for r in self.rows("select entry, item, ExtendedCost from npc_vendor"):
            if r["entry"] in spawned:
                vendor_items[r["item"]].append((r["entry"], r["ExtendedCost"] or 0))
        tmpl = defaultdict(list)
        for r in self.rows("select entry, item, ExtendedCost from npc_vendor_template"):
            tmpl[r["entry"]].append((r["item"], r["ExtendedCost"] or 0))
        for entry, ct in self.ct.items():
            vt = ct["VendorTemplateId"]
            if vt and entry in spawned:
                for item, ext in tmpl.get(vt, []):
                    vendor_items[item].append((entry, ext))
        for item, vend in vendor_items.items():
            if item not in item_ids:
                continue
            it = items[item]
            price = it["BuyPrice"] or 0
            ext = any(e for _, e in vend)
            if (it["RequiredReputationFaction"] or 0) > 0:
                mode = f"F{it['RequiredReputationFaction']}-{it['RequiredReputationRank'] or 0}"
            elif ext:
                mode = "E"
            else:
                mode = "0"
            sources[item].append(f"V{price}:{mode}")
            heroic_src[item].append(False)

        # crafted
        craft_spells = {}  # spell id -> item created
        for sid, sp in self.spells.items():
            for e in range(1, 4):
                if sp.get(f"Effect{e}") == 24 and sp.get(f"EffectItemType{e}") in item_ids:
                    craft_spells[sid] = sp[f"EffectItemType{e}"]
        craft_req = {}  # item -> (skillline, skill)
        for r in self.rows("select spell, reqskill, reqskillvalue from npc_trainer_template where reqskill > 0 "
                           "union select spell, reqskill, reqskillvalue from npc_trainer where reqskill > 0"):
            item = craft_spells.get(r["spell"])
            if item and r["reqskill"] in CRAFT_SKILLS:
                cur = craft_req.get(item)
                if cur is None or r["reqskillvalue"] < cur[1]:
                    craft_req[item] = (r["reqskill"], r["reqskillvalue"] or 0)
        for r in self.rows("select subclass, RequiredSkill, RequiredSkillRank, spellid_2 from item_template "
                           "where class = 9 and spellid_2 > 0"):
            item = craft_spells.get(r["spellid_2"])
            if not item or item in craft_req:
                continue
            skill = r["RequiredSkill"] or RECIPE_SKILL.get(r["subclass"])
            if skill in CRAFT_SKILLS:
                craft_req[item] = (skill, r["RequiredSkillRank"] or 0)
        for item, (skill, val) in craft_req.items():
            sources[item].append(f"K{skill}:{val}")
            heroic_src[item].append(False)

        # manual source fixes: {"itemId": ["Q123", ...]} added, {"itemId": null} removes the item
        for k, v in (self.fixes.get("sources") or {}).items():
            iid = int(k)
            if v is None:
                sources.pop(iid, None)
                item_ids.discard(iid)
            elif iid in item_ids:
                sources[iid].extend(v)
                heroic_src[iid].extend([False] * len(v))

        # assemble items
        self.out_items = {}
        self.out_src = {}
        for iid, it in items.items():
            srcs = sources.get(iid)
            if not srcs:
                self.report["dropped_no_source"] += 1
                if raid_only.get(iid):
                    self.report["dropped_raid_only"] += 1
                continue
            stats, special = decode_item_stats(it, self.spells)
            if str(iid) in self.specials:
                special = False
            heroic_only = bool(heroic_src[iid]) and all(heroic_src[iid])
            flags = item_flags(it, srcs, heroic_only)
            if special:
                flags |= FLAG_SPECIAL
            sockets = "".join(SOCKET_LETTER.get(it[f"socketColor_{i}"] or 0, "") for i in range(1, 4))
            phase = self.phase_for(it, srcs)
            rec = [clean(it["name"]), str(it["InventoryType"]), str(it["class"]), str(it["subclass"] or 0),
                   str(it["Quality"]), str(it["ItemLevel"] or 0), str(it["RequiredLevel"] or 0),
                   str(classmask_field(it["AllowableClass"])), str(flags), stats_to_str(stats), sockets,
                   str(it["socketBonus"] or 0), str(phase)]
            self.out_items[iid] = rec
            self.out_src[iid] = sort_sources(srcs)
            self.report[f"group_{INV_GROUP[it['InventoryType']]}"] += 1
            for s in self.out_src[iid]:
                self.report[f"src_{s[0]}"] += 1
            if special:
                self.report["special"] += 1

        # quests: those rewarding shipped items + backward closure
        shipped = set(self.out_items)
        keep = set()
        for qid in used_quests:
            q = self.quests[qid]
            rewards = [q[f"RewChoiceItemId{i}"] for i in range(1, 7)] + [q[f"RewItemId{i}"] for i in range(1, 5)]
            if any(r in shipped for r in rewards if r):
                keep.add(qid)
        stack = list(keep)
        while stack:
            qid = stack.pop()
            prev = abs(self.quests[qid]["PrevQuestId"] or 0)
            if prev and prev in self.quests and prev not in keep:
                keep.add(prev)
                stack.append(prev)
        self.out_quests = {}
        for qid in sorted(keep):
            q = self.quests[qid]
            choice = [q[f"RewChoiceItemId{i}"] for i in range(1, 7)]
            fixed = [q[f"RewItemId{i}"] for i in range(1, 5)]
            self.out_quests[qid] = [
                clean(q["Title"]), str(q["MinLevel"] or 0), str(q["QuestLevel"] or 0),
                races_field(q["RequiredRaces"]), str(classmask_field(q["RequiredClasses"]) if q["RequiredClasses"] else 0),
                str(q["ZoneOrSort"] if (q["ZoneOrSort"] or 0) > 0 else 0), str(q["Type"] or 0),
                str(q["PrevQuestId"] or 0), str(q["NextQuestInChain"] or 0), str(q["ExclusiveGroup"] or 0),
                ",".join(str(c) for c in choice if c and c in shipped),
                ",".join(str(c) for c in fixed if c and c in shipped),
            ]

        # npcs
        self.out_npcs = {}
        for entry in sorted(used_npcs):
            ct = self.ct[entry]
            maps = self.spawn_maps.get(entry) or set()
            m = min(maps) if maps else 0
            self.out_npcs[entry] = [clean(ct["Name"]), str(ct["MaxLevel"] or ct["MinLevel"] or 0),
                                    str(ct["Rank"] or 0), str(m), str(self.respawn.get(entry, 0))]

        # bosses (all bosses of shipped dungeons, so the dungeon filter can list every boss)
        self.out_bosses = {}
        self.out_dungeons = {}
        for m in sorted(self.dungeon_maps):
            over = self.dungeon_over.get(str(m), {})
            inst = self.instances[m]
            bosses = [e for _i, e in self.dungeon_bosses.get(m, [])]
            if not bosses and not over:
                continue
            name = over.get("name") or self.dungeon_name(m)
            t = over.get("t") or [6 + 7 * i for i in range(len(bosses))]
            if len(t) < len(bosses):
                t = list(t) + [t[-1] + 7 * (i + 1) if t else 6 + 7 * i for i in range(len(t), len(bosses))]
            self.out_dungeons[m] = {
                "name": name, "min": over.get("min", inst["levelMin"] or 0), "max": over.get("max", inst["levelMax"] or 0),
                "zone": over.get("zone", 0), "heroic": bool(over.get("heroic", m >= 500)),
                "bosses": bosses, "t": t[:len(bosses)],
            }
            for i, e in enumerate(bosses):
                self.out_bosses[e] = [str(m), str(i), "0"]
                h = self.ct.get(e, {}).get("HeroicEntry")
                if h:
                    self.out_bosses[h] = [str(m), str(i), "1"]
        for entry in used_npcs:
            if entry in self.bosses and entry not in self.out_bosses:
                m, idx, heroic = self.bosses[entry]
                self.out_bosses[entry] = [str(m), str(idx), str(heroic)]
        # every B source must have a boss and npc record
        for entry in list(self.out_bosses):
            if entry not in self.out_npcs and entry in self.ct:
                ct = self.ct[entry]
                self.out_npcs[entry] = [clean(ct["Name"]), str(ct["MaxLevel"] or ct["MinLevel"] or 0),
                                        str(ct["Rank"] or 0), str(self.out_bosses[entry][0]), "0"]

        # objects
        self.out_objects = {go: [clean(self.go_name.get(go, "")), str(self.go_map.get(go, 0))] for go in sorted(used_objects)}

        # zones: overrides + every quest zone referenced
        self.out_zones = {int(k): v for k, v in self.zones_over.items()}
        for q in self.out_quests.values():
            z = int(q[5])
            if z and z not in self.out_zones:
                self.report["zone_unnamed"] += 1
                self.unnamed_zones = getattr(self, "unnamed_zones", set())
                self.unnamed_zones.add(z)
        return self

    def dungeon_name(self, m: int) -> str:
        names = self.at_names.get(m) or []
        best = ""
        for n in names:
            n = re.sub(r"\s*\((Entrance|Exit)\)", "", n)
            n = re.sub(r"\s*-\s*(Entering|Exit|Entrance).*$", "", n)
            n = re.sub(r"\s*,\s*(Entrance|Exit).*$", "", n)
            n = n.strip()
            if n and (not best or len(n) < len(best)):
                best = n
        return clean(best or f"Map {m}")

    def phase_for(self, it: dict, srcs) -> int:
        rules = self.phases
        iid = str(it["entry"])
        if iid in (rules.get("items") or {}):
            return int(rules["items"][iid])
        name = it["name"] or ""
        for prefix, ph in (rules.get("name_prefix") or {}).items():
            if name.startswith(prefix):
                return int(ph)
        phase = 1
        maps = set()
        for s in srcs:
            if s[0] in "BT":
                ref = int(re.match(r"[BT](\d+)", s).group(1))
                maps.add(self.bosses[ref][0] if s[0] == "B" and ref in self.bosses else ref)
        by_map = rules.get("maps") or {}
        if maps:
            # item phase = the earliest phase among its sources
            phases = [int(by_map.get(str(m), 1)) for m in maps]
            phase = min(phases)
        badge = rules.get("badge_vendor") or {}  # {"ilvl": phase}
        if badge and srcs and all(s[0] == "V" and s.endswith(":E") for s in srcs):
            ph = badge.get(str(it["ItemLevel"] or 0))
            if ph:
                phase = max(phase, int(ph))
        return phase

    # -- output --------------------------------------------------------------------------------
    def write(self, out_dir: str, json_path: str | None):
        os.makedirs(out_dir, exist_ok=True)
        for f in os.listdir(out_dir):
            if f.endswith(".lua") or f.endswith(".toc"):
                os.remove(os.path.join(out_dir, f))
        built = _dt.date.today().isoformat()
        db_version = ""
        try:
            db_version = str(self.db.execute("select version from db_version limit 1").fetchone()[0])
        except Exception:
            pass
        meta = {"version": self.version, "built": built, "dbVersion": db_version or "tbc-db",
                "items": len(self.out_items), "quests": len(self.out_quests), "phases": 5}
        files = []

        def w(name, lines):
            path = os.path.join(out_dir, name)
            with open(path, "w", encoding="utf-8", newline="\n") as f:
                f.write("\n".join(lines) + "\n")
            files.append(name)

        w("Meta.lua", [
            "-- Generated by pipeline/build.py. Do not edit.",
            "CasualMinMaxer_Data = CasualMinMaxer_Data or {}",
            "local D = CasualMinMaxer_Data",
            "D.items, D.src, D.quests, D.npcs, D.bosses, D.dungeons, D.objects, D.zones, D.specials = "
            "{}, {}, {}, {}, {}, {}, {}, {}, {}",
            "D.meta = { version = %s, built = %s, dbVersion = %s, items = %d, quests = %d, phases = 5 }" % (
                lua_str(meta["version"]), lua_str(meta["built"]), lua_str(meta["dbVersion"]), meta["items"], meta["quests"]),
        ])
        by_group = defaultdict(list)
        for iid, rec in self.out_items.items():
            by_group[INV_GROUP[int(rec[1])]].append(iid)
        for g in GROUP_ORDER:
            ids = sorted(by_group.get(g, []))
            w(f"Items_{g}.lua", ["local D = CasualMinMaxer_Data"] +
              [f"D.items[{iid}]={lua_str(';'.join(self.out_items[iid]))}" for iid in ids])
            w(f"Sources_{g}.lua", ["local D = CasualMinMaxer_Data"] +
              [f"D.src[{iid}]={lua_str('|'.join(self.out_src[iid]))}" for iid in ids])
        w("Quests.lua", ["local D = CasualMinMaxer_Data"] +
          [f"D.quests[{q}]={lua_str(';'.join(rec))}" for q, rec in self.out_quests.items()])
        w("Npcs.lua", ["local D = CasualMinMaxer_Data"] +
          [f"D.npcs[{e}]={lua_str(';'.join(rec))}" for e, rec in sorted(self.out_npcs.items())])
        w("Bosses.lua", ["local D = CasualMinMaxer_Data"] +
          [f"D.bosses[{e}]={lua_str(';'.join(rec))}" for e, rec in sorted(self.out_bosses.items())])
        dl = ["local D = CasualMinMaxer_Data"]
        for m, d in sorted(self.out_dungeons.items()):
            dl.append("D.dungeons[%d]={name=%s,min=%d,max=%d,zone=%d,heroic=%s,bosses={%s},t={%s}}" % (
                m, lua_str(d["name"]), d["min"], d["max"], d["zone"], "true" if d["heroic"] else "false",
                ",".join(str(b) for b in d["bosses"]), ",".join(str(t) for t in d["t"])))
        w("Dungeons.lua", dl)
        w("Objects.lua", ["local D = CasualMinMaxer_Data"] +
          [f"D.objects[{e}]={lua_str(';'.join(rec))}" for e, rec in self.out_objects.items()])
        w("Zones.lua", ["local D = CasualMinMaxer_Data"] +
          [f"D.zones[{z}]={lua_str(clean(n))}" for z, n in sorted(self.out_zones.items())])
        w("Specials.lua", ["local D = CasualMinMaxer_Data"] +
          [f"D.specials[{int(k)}]={lua_str(v if isinstance(v, str) else stats_to_str(v))}"
           for k, v in sorted(self.specials.items(), key=lambda kv: int(kv[0])) if int(k) in self.out_items])
        toc = ["## Interface: 20505", "## Title: Casual MinMaxer Data",
               "## Notes: Item, quest and dungeon data for Casual MinMaxer (generated from CMaNGOS TBC-DB, GPL-3).",
               "## Author: Simon Lehmann", "## Version: @project-version@", "## LoadOnDemand: 1",
               "## Dependencies: CasualMinMaxer", "## X-License: GPL-3.0-or-later",
               f"## X-Data-Built: {built}", ""] + files
        with open(os.path.join(out_dir, "CasualMinMaxer_Data.toc"), "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(toc) + "\n")
        if json_path:
            os.makedirs(os.path.dirname(json_path) or ".", exist_ok=True)
            with open(json_path, "w", encoding="utf-8") as f:
                json.dump({
                    "meta": meta,
                    "items": {str(k): ";".join(v) for k, v in self.out_items.items()},
                    "src": {str(k): "|".join(v) for k, v in self.out_src.items()},
                    "quests": {str(k): ";".join(v) for k, v in self.out_quests.items()},
                    "npcs": {str(k): ";".join(v) for k, v in self.out_npcs.items()},
                    "bosses": {str(k): ";".join(v) for k, v in self.out_bosses.items()},
                    "dungeons": {str(k): v for k, v in self.out_dungeons.items()},
                    "objects": {str(k): ";".join(v) for k, v in self.out_objects.items()},
                    "zones": {str(k): v for k, v in self.out_zones.items()},
                    "specials": {str(k): (v if isinstance(v, str) else stats_to_str(v))
                                 for k, v in self.specials.items() if int(k) in self.out_items},
                }, f, separators=(",", ":"))
        size = sum(os.path.getsize(os.path.join(out_dir, f)) for f in os.listdir(out_dir))
        return meta, size

    def print_report(self, meta, size):
        print(f"items {meta['items']}  quests {meta['quests']}  npcs {len(self.out_npcs)}  bosses {len(self.out_bosses)}  "
              f"dungeons {len(self.out_dungeons)}  objects {len(self.out_objects)}  zones {len(self.out_zones)}  "
              f"specials {sum(1 for k in self.specials if int(k) in self.out_items)}  size {size / 1024:.0f} KB")
        print("per slot group: " + ", ".join(f"{g} {self.report.get('group_' + g, 0)}" for g in GROUP_ORDER))
        print("per source code: " + ", ".join(f"{c} {self.report.get('src_' + c, 0)}" for c in "QKVBGRNTW"))
        tiers = defaultdict(int)
        for srcs in self.out_src.values():
            tiers[self.tier_guess(srcs)] += 1
        print("best-tier heuristic (no character): " + ", ".join(f"T{t} {n}" for t, n in sorted(tiers.items())))
        print(f"dropped: no source {self.report.get('dropped_no_source', 0)} (raid-only {self.report.get('dropped_raid_only', 0)}), "
              f"special-flagged {self.report.get('special', 0)}")
        if getattr(self, "unnamed_zones", None):
            print(f"WARNING: {len(self.unnamed_zones)} quest zones without a name in overrides/zones.json: "
                  f"{sorted(self.unnamed_zones)}")

    def tier_guess(self, srcs):
        best = 5
        for s in srcs:
            c = s[0]
            if c == "Q":
                q = self.out_quests.get(int(s[1:]))
                t = 2 if q and q[6] in ("1", "81", "85", "62") else 1
            elif c in "BG":
                pct = float(s.split(":")[1])
                t = 3 if pct >= LOTTERY_BELOW_PCT else 4
            elif c in "RNTW":
                t = 4
            else:
                t = 5
            best = min(best, t)
        return best


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--db", default=os.path.join(HERE, "work", "tbcdb.sqlite"))
    ap.add_argument("--out", default=os.path.join(ROOT, "CasualMinMaxer_Data"))
    ap.add_argument("--json", default=os.path.join(HERE, "work", "data.json"))
    ap.add_argument("--version", default="dev")
    args = ap.parse_args(argv)
    if not os.path.exists(args.db):
        print(f"snapshot not found: {args.db} (run pipeline/extract_sqlite.py first)", file=sys.stderr)
        return 2
    b = Builder(args.db, args.version).build()
    meta, size = b.write(args.out, args.json)
    b.print_report(meta, size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
