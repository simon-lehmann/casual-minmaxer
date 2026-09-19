#!/usr/bin/env python3
"""Snapshot the CMaNGOS TBC-DB tables the pipeline needs into one SQLite file.

Reads from a running MariaDB (the docker container from scripts/db-up.sh) via the
`mariadb` CLI in tab-separated mode and writes pipeline/work/tbcdb.sqlite.  The
pipeline itself only ever reads that SQLite file, so a data build is reproducible
from the snapshot alone.
"""
import os
import re
import sqlite3
import subprocess
import sys

TABLES = {
    "item_template": None,
    "quest_template": None,
    "creature_template": None,
    "creature": None,
    "creature_spawn_entry": None,
    "creature_loot_template": None,
    "reference_loot_template": None,
    "gameobject_loot_template": None,
    "item_loot_template": None,
    "gameobject": None,
    "gameobject_template": None,
    "npc_vendor": None,
    "npc_vendor_template": None,
    "npc_trainer": None,
    "npc_trainer_template": None,
    "instance_template": None,
    "areatrigger_teleport": None,
    "instance_dungeon_encounters": None,
    "instance_encounters": None,
    "spawn_group": None,
    "spawn_group_entry": None,
    "pool_creature": None,
    "pool_creature_template": None,
    "pool_template": None,
    "creature_questrelation": None,
    "creature_involvedrelation": None,
    "gameobject_questrelation": None,
    "gameobject_involvedrelation": None,
    "skill_extra_item_template": None,
    "game_event_creature": None,
    "game_event": None,
    "conditions": None,
    # spell_template is wide; keep the columns the pipeline reads
    "spell_template": (
        "Id, SpellName, Rank1, SpellLevel, BaseLevel, Attributes, Stances, "
        "Effect1, Effect2, Effect3, EffectApplyAuraName1, EffectApplyAuraName2, EffectApplyAuraName3, "
        "EffectBasePoints1, EffectBasePoints2, EffectBasePoints3, EffectDieSides1, EffectDieSides2, EffectDieSides3, "
        "EffectMiscValue1, EffectMiscValue2, EffectMiscValue3, EffectMiscValueB1, EffectMiscValueB2, EffectMiscValueB3, "
        "EffectItemType1, EffectItemType2, EffectItemType3, EffectTriggerSpell1, EffectTriggerSpell2, EffectTriggerSpell3, "
        "ProcChance, ProcFlags, ProcCharges, DurationIndex, RecoveryTime, SchoolMask, EquippedItemClass, "
        "EquippedItemSubClassMask, EquippedItemInventoryTypeMask, Reagent1, Reagent2, Reagent3, Reagent4, "
        "Reagent5, Reagent6, Reagent7, Reagent8, ReagentCount1, ReagentCount2, ReagentCount3, ReagentCount4, "
        "ReagentCount5, ReagentCount6, ReagentCount7, ReagentCount8, SpellFamilyName, DmgClass"
    ),
}

CONTAINER = os.environ.get("CMM_DB_CONTAINER", "cmm-mariadb")
DBNAME = os.environ.get("CMM_DB_NAME", "tbcmangos")
DBPASS = os.environ.get("CMM_DB_PASS", "root")


def mariadb(sql):
    cmd = ["docker", "exec", CONTAINER, "mariadb", "-uroot", f"-p{DBPASS}", DBNAME, "-B", "-e", sql]
    out = subprocess.run(cmd, capture_output=True, check=True)
    return out.stdout.decode("utf-8", errors="replace")


_ESC = {"n": "\n", "t": "\t", "\\": "\\", "0": "\0"}


def unescape(v):
    # mariadb -B escapes newline, tab, backslash and NUL; NULL is printed literally
    if v == "NULL":
        return None
    if "\\" not in v:
        return v
    return re.sub(r"\\(.)", lambda m: _ESC.get(m.group(1), m.group(1)), v)


def column_types(table):
    """Map column name -> SQLite affinity, read from the MariaDB schema."""
    text = mariadb(
        "SELECT column_name, data_type FROM information_schema.columns "
        f"WHERE table_schema='{DBNAME}' AND table_name='{table}'"
    )
    types = {}
    for line in text.split("\n")[1:]:
        if not line:
            continue
        name, dtype = line.split("\t")
        dtype = dtype.lower()
        if dtype in ("float", "double", "decimal"):
            types[name] = "REAL"
        elif "int" in dtype:
            types[name] = "INTEGER"
        else:
            types[name] = "TEXT"
    return types


def main(out_path):
    if os.path.exists(out_path):
        os.remove(out_path)
    db = sqlite3.connect(out_path)
    for table, cols in TABLES.items():
        sel = cols or "*"
        types = column_types(table)
        text = mariadb(f"SELECT {sel} FROM `{table}`")
        lines = text.split("\n")
        header = lines[0].split("\t")
        rows = [l.split("\t") for l in lines[1:] if l != ""]
        db.execute(f"CREATE TABLE {table} ({', '.join(f'[{c}] {types.get(c, chr(84)+chr(69)+chr(88)+chr(84))}' for c in header)})")
        ph = ",".join("?" * len(header))
        db.executemany(
            f"INSERT INTO {table} VALUES ({ph})",
            ([unescape(v) for v in r] for r in rows if len(r) == len(header)),
        )
        bad = sum(1 for r in rows if len(r) != len(header))
        print(f"{table}: {len(rows) - bad} rows" + (f" ({bad} skipped: column count mismatch)" if bad else ""))
        db.commit()
    for t, c in [
        ("item_template", "entry"), ("quest_template", "entry"), ("creature_template", "Entry"),
        ("creature", "id"), ("creature_loot_template", "entry"), ("reference_loot_template", "entry"),
        ("gameobject_loot_template", "entry"), ("gameobject", "id"), ("gameobject_template", "entry"),
        ("npc_vendor", "entry"), ("npc_vendor_template", "entry"), ("spell_template", "Id"),
        ("npc_trainer", "entry"), ("npc_trainer_template", "entry"), ("creature_spawn_entry", "guid"),
        ("pool_creature", "guid"), ("pool_creature_template", "id"), ("conditions", "condition_entry"),
("item_loot_template", "entry"), ("game_event_creature", "guid"),
    ]:
        try:
            db.execute(f"CREATE INDEX idx_{t}_{c} ON {t}([{c}])")
        except sqlite3.OperationalError:
            pass
    db.commit()
    db.close()
    print("wrote", out_path)


if __name__ == "__main__":
    os.makedirs("pipeline/work", exist_ok=True)
    main(sys.argv[1] if len(sys.argv) > 1 else "pipeline/work/tbcdb.sqlite")
