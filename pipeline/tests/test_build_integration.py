import re
"""Integration tests against the real tbcdb.sqlite snapshot and the generated data pack.

Skipped when pipeline/work/tbcdb.sqlite is missing. The pack is built once into a temp dir.
"""
import os
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
PIPE = os.path.dirname(HERE)
sys.path.insert(0, PIPE)
import build  # noqa: E402

DB = os.path.join(PIPE, "work", "tbcdb.sqlite")
pytestmark = pytest.mark.skipif(not os.path.exists(DB), reason="tbcdb.sqlite snapshot not present")

STAT_KEYS = set(build.STAT_KEYS)
GROUPS = build.GROUP_ORDER


@pytest.fixture(scope="module")
def pack(tmp_path_factory):
    out = tmp_path_factory.mktemp("data")
    b = build.Builder(DB, "test").build()
    b.write(str(out), None)
    return b, str(out)


def parse_file(path, key):
    out = {}
    for line in open(path, encoding="utf-8"):
        m = re.match(r'D\.%s\[(-?\d+)\]="(.*)"$' % key, line.rstrip("\n"))
        if m:
            out[int(m.group(1))] = m.group(2).replace('\\"', '"').replace("\\\\", "\\")
    return out


@pytest.fixture(scope="module")
def tables(pack):
    b, out = pack
    items, src = {}, {}
    for g in GROUPS:
        items.update(parse_file(os.path.join(out, f"Items_{g}.lua"), "items"))
        src.update(parse_file(os.path.join(out, f"Sources_{g}.lua"), "src"))
    return {
        "items": items, "src": src,
        "quests": parse_file(os.path.join(out, "Quests.lua"), "quests"),
        "npcs": parse_file(os.path.join(out, "Npcs.lua"), "npcs"),
        "bosses": parse_file(os.path.join(out, "Bosses.lua"), "bosses"),
        "objects": parse_file(os.path.join(out, "Objects.lua"), "objects"),
        "dungeons": b.out_dungeons,
        "rsuffix": parse_file(os.path.join(out, "Random.lua"), "rsuffix"),
        "rprop": parse_file(os.path.join(out, "Random.lua"), "rprop"),
        "randprop": parse_file(os.path.join(out, "Random.lua"), "randprop"),
        "rpool": parse_file(os.path.join(out, "Random.lua"), "rpool"),
        "sbonus": parse_file(os.path.join(out, "SocketBonus.lua"), "sbonus"),
    }


def test_random_suffix_greens(tables):
    # Talonguard Armor (24968): BoE mail chest ilvl 99 with the Outland suffix pool -> S + W sources
    rec = tables["items"][24968].split(";")
    assert rec[13] == "P-65"
    entries = tables["rpool"][-65].split(",")
    assert all(re.match(r"^-?\d+:\d+\.\d$", e) for e in entries), entries
    rand = [int(e.split(":")[0]) for e in entries]
    chances = [float(e.split(":")[1]) for e in entries]
    assert -7 in rand and -5 in rand and all(r < 0 for r in rand)
    assert chances == sorted(chances, reverse=True)
    assert 95 <= sum(chances) <= 105, sum(chances)
    assert "S" in tables["src"][24968].split("|")
    assert tables["rsuffix"][7] == "of the Bear;STR:6666,STA:10000"
    assert tables["rsuffix"][5] == "of the Monkey;AGI:6666,STA:10000"
    # scaling: Good group 0 at ilvl 99 = 46 -> +46 STA, +30 STR
    good = tables["randprop"][99].split(";")[2].split(",")
    assert good[0] == "46"
    assert build.scaled_suffix_stats({"STR": 6666, "STA": 10000}, 46) == {"STR": 30.0, "STA": 46.0}
    # vanilla fixed property pool exists and decodes through equip spells
    assert any(v.startswith("of the Monkey;") and "AGI:" in v for v in tables["rprop"].values())
    # every random item's ilvl has a RandPropPoints row and no S source without a drop source
    assert len(tables["sbonus"]) >= 60
    assert all(re.match(r"^[A-Z0-9]+:-?[\d.]+(,[A-Z0-9]+:-?[\d.]+)*$", v) for v in tables["sbonus"].values())


def test_slave_pens_bosses_in_order(pack):
    b, _ = pack
    d = b.out_dungeons[547]
    assert d["bosses"] == [17941, 17991, 17942]  # Mennu, Rokmar, Quagmirran
    assert d["name"] == "The Slave Pens" and d["heroic"] is True and len(d["t"]) == 3


def test_heroic_boss_entries_share_map_and_index(tables):
    assert tables["bosses"][17991] == "547;1;0"
    assert tables["bosses"][19895] == "547;1;1"


def test_rokmar_reference_group_gives_20_percent(tables):
    for iid in (24376, 24378, 24379, 24380, 24381):
        assert "B17991:20" in tables["src"][iid].split("|"), iid


def test_quest_chain_lost_in_action(tables):
    q = tables["quests"][9738].split(";")
    assert q[0] == "Lost in Action" and q[6] == "81" and q[7] == "9876" and q[5] == "3905"
    assert "25541" in q[10].split(",")
    prev = tables["quests"][9876].split(";")
    assert prev[8] == "9738"  # NextQuestInChain
    # the whole backward chain is shipped
    qid = 9738
    seen = 0
    while True:
        p = abs(int(tables["quests"][qid].split(";")[7]))
        if not p:
            break
        assert p in tables["quests"], p
        qid = p
        seen += 1
        assert seen < 20
    assert seen >= 2


def test_item_record_shape(tables):
    ranged_subs = {2, 3, 16, 18}
    for iid, rec in tables["items"].items():
        f = rec.split(";")
        assert len(f) == 14, (iid, rec)
        if f[13]:
            m = re.match(r"^P(-?\d+)$", f[13])
            assert m, (iid, f[13])
            pool = tables["rpool"][int(m.group(1))]
            for e in pool.split(","):
                assert re.match(r"^-?\d+:\d+\.\d$", e), (iid, e)
                r = int(e.split(":")[0])
                assert (r < 0 and -r in tables["rsuffix"]) or (r > 0 and r in tables["rprop"]), (iid, r)
                assert (int(m.group(1)) < 0) == (r < 0), (iid, "pool sign does not match its ids")
            assert int(f[5]) in tables["randprop"], (iid, "no RandPropPoints row for ilvl")
        assert f[0] and not re.search(r"[;|]", f[0])
        assert int(f[1]) in build.INV_GROUP and int(f[2]) in (2, 4) and int(f[4]) in (2, 3, 4)
        assert 1 <= int(f[12]) <= 5
        for kv in filter(None, f[9].split(",")):
            k, v = kv.split(":")
            assert k in STAT_KEYS, (iid, k)
            float(v)
        assert re.fullmatch(r"[RYBM]*", f[10])
        if int(f[2]) == 2:
            assert ("RDPS" in f[9]) == (int(f[3]) in ranged_subs), (iid, rec)
        if int(f[2]) == 4 and int(f[3]) in (1, 2, 3, 4, 6):
            assert "ARMOR:" in f[9], (iid, rec)


def test_every_item_has_sources_and_vice_versa(tables):
    # every sourced item exists; items without sources are raid-only (shipped for equipped scoring)
    assert set(tables["src"]) <= set(tables["items"])
    sourceless = set(tables["items"]) - set(tables["src"])
    assert 500 < len(sourceless) < 2500
    assert len(tables["items"]) > 8000


def test_sources_reference_existing_records(tables):
    src_re = re.compile(r"^(Q\d+|B\d+:[\d.]+|R\d+:[\d.]+|N\d+:[\d.]+|T\d+:[\d.]+|G\d+:[\d.]+|V\d+:(0|E|H|A|F\d+-\d)|K\d+:\d+|S|W[\d.]+)$")
    for iid, s in tables["src"].items():
        for part in s.split("|"):
            assert src_re.match(part), (iid, part)
            code, body = part[0], part[1:]
            if code == "S":
                assert tables["items"][iid].split(";")[13] != "", (iid, "S source on a non-random item")
                assert len(parts := s.split("|")) > 1, (iid, "S must pair with a drop source")
                continue
            ref = int(re.match(r"\d+", body).group(0)) if code in "QBRNTGK" else None
            if code == "Q":
                assert ref in tables["quests"], (iid, part)
                q = tables["quests"][ref].split(";")
                assert str(iid) in (q[10] + "," + q[11]).split(","), (iid, part)
            elif code == "B":
                assert ref in tables["bosses"] and ref in tables["npcs"], (iid, part)
                assert int(tables["bosses"][ref].split(";")[0]) in tables["dungeons"]
            elif code in "RN":
                assert ref in tables["npcs"], (iid, part)
            elif code == "T":
                assert ref in tables["dungeons"], (iid, part)
            elif code == "G":
                assert ref in tables["objects"], (iid, part)
                assert int(tables["objects"][ref].split(";")[1]) in tables["dungeons"]
            elif code == "K":
                assert ref in build.CRAFT_SKILLS
            if code in "BGRNT":
                pct = float(body.split(":")[1])
                assert 0.01 <= pct <= 100


def test_sources_are_sorted_best_first(tables):
    for iid, s in tables["src"].items():
        parts = s.split("|")
        assert parts == build.sort_sources(parts), iid


def test_raid_items_have_no_dungeon_sources(tables):
    for raid_item in (19019, 28830, 20580, 30099):  # Thunderfury, Dragonspine Trophy, Hammer of Bestial Fury, Frenzied Nightsaber? (any raid id)
        assert raid_item not in tables["src"] or not any(p[0] in "BT" for p in tables["src"][raid_item].split("|"))


def test_dungeon_records(tables):
    for m, d in tables["dungeons"].items():
        assert d["name"] and d["bosses"] and len(d["t"]) == len(d["bosses"]), m
        assert all(t2 > t1 for t1, t2 in zip(d["t"], d["t"][1:])) or m == 189, m  # SM wings restart
        for b in d["bosses"]:
            assert b in tables["bosses"]
    assert 585 in tables["dungeons"] and 532 not in tables["dungeons"] and 568 not in tables["dungeons"]


def test_phase_rules_applied(tables):
    items = tables["items"]
    # Magisters' Terrace drops are phase 5
    mgt = [i for i, s in tables["src"].items() if any(p.startswith("T585:") for p in s.split("|"))
           or any(p[0] == "B" and tables["bosses"].get(int(p[1:].split(":")[0]), "0").startswith("585;") for p in s.split("|"))]
    assert mgt and all(items[i].split(";")[12] == "5" for i in mgt)
    brutal = [i for i, r in items.items() if r.startswith("Brutal Gladiator's")]
    assert brutal and all(items[i].split(";")[12] == "5" for i in brutal)
    launch = [i for i, s in tables["src"].items() if "B17991:" in s]
    assert launch and all(items[i].split(";")[12] == "1" for i in launch)


def test_known_item_stats(tables):
    rec = tables["items"][24378].split(";")  # Coilfang Hammer of Renewal
    stats = dict(kv.split(":") for kv in rec[9].split(","))
    assert stats["HEAL"] == "106" and stats["SP"] == "36" and stats["INT"] == "13" and "DPS" in stats
    rec = tables["items"][24376].split(";")  # Runed Fungalcap: on-use trinket, unique, BoP
    assert int(rec[8]) & build.FLAG_SPECIAL and int(rec[8]) & build.FLAG_UNIQUE and int(rec[8]) & build.FLAG_BOP
    assert "RES:30" in rec[9]
    rec = tables["items"][2864].split(";")  # Runed Copper Breastplate, crafted
    assert "K164:80" in tables["src"][2864].split("|") and "ARMOR:" in rec[9]


def test_generic_world_chests_become_world_drops(tables):
    # no dungeon chest source should point at a generic Solid/Tattered chest
    for go, rec in tables["objects"].items():
        name = rec.split(";")[0]
        assert not name.startswith(("Solid Chest", "Tattered Chest", "Large Solid Chest", "Large Iron Bound Chest")), name


def test_lua_files_parse(pack):
    import shutil
    import subprocess
    luac = shutil.which("luac") or os.path.expanduser("~/.local/bin/luac")
    if not os.path.exists(luac):
        pytest.skip("luac not available")
    _, out = pack
    files = [os.path.join(out, f) for f in os.listdir(out) if f.endswith(".lua")]
    subprocess.run([luac, "-p", *files], check=True)


def test_size_budget(pack):
    _, out = pack
    size = sum(os.path.getsize(os.path.join(out, f)) for f in os.listdir(out))
    assert size < 2 * 1024 * 1024
