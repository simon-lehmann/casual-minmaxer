"""Unit tests for the pure functions in pipeline/build.py (no database needed)."""
import os
import sys

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import build  # noqa: E402


# ------------------------------------------------------------------------------------------ loot
def test_ungrouped_rows_are_independent():
    rows = [(1, 50.0, 0, 1), (2, 25.0, 0, 1)]
    assert build.flatten_loot_table(rows, {}) == {1: 50.0, 2: 25.0}


def test_ungrouped_zero_chance_means_always():
    assert build.flatten_loot_table([(1, 0.0, 0, 1)], {}) == {1: 100.0}


def test_group_shares_remainder_equally():
    rows = [(1, 0.0, 1, 1), (2, 0.0, 1, 1), (3, 0.0, 1, 1), (4, 0.0, 1, 1), (5, 0.0, 1, 1)]
    out = build.flatten_loot_table(rows, {})
    assert all(abs(v - 20.0) < 1e-9 for v in out.values()) and len(out) == 5


def test_group_explicit_chance_kept_and_rest_shared():
    rows = [(1, 40.0, 1, 1), (2, 0.0, 1, 1), (3, 0.0, 1, 1)]
    out = build.flatten_loot_table(rows, {})
    assert out == {1: 40.0, 2: 30.0, 3: 30.0}


def test_group_full_explicit_leaves_nothing_for_equal_rows():
    rows = [(1, 100.0, 1, 1), (2, 0.0, 1, 1)]
    assert build.flatten_loot_table(rows, {}) == {1: 100.0}


def test_quest_only_rows_skipped():
    rows = [(1, -100.0, 0, 1), (2, 10.0, 0, 1)]
    assert build.flatten_loot_table(rows, {}) == {2: 10.0}


def test_reference_multiplies_through():
    refs = {40002: [(10, 0.0, 1, 1), (11, 0.0, 1, 1), (12, 0.0, 1, 1), (13, 0.0, 1, 1), (14, 0.0, 1, 1)]}
    rows = [(40002, 100.0, 0, -40002)]
    out = build.flatten_loot_table(rows, refs)
    assert out == {10: 20.0, 11: 20.0, 12: 20.0, 13: 20.0, 14: 20.0}


def test_reference_with_partial_chance():
    refs = {5: [(10, 50.0, 0, 1)]}
    assert build.flatten_loot_table([(5, 30.0, 0, -5)], refs) == {10: 15.0}


def test_nested_references():
    refs = {1: [(2, 50.0, 0, -2)], 2: [(99, 0.0, 1, 1), (98, 0.0, 1, 1)]}
    out = build.flatten_loot_table([(1, 100.0, 0, -1)], refs)
    assert out == {99: 25.0, 98: 25.0}


def test_reference_inside_group_gets_share():
    refs = {7: [(70, 0.0, 0, 1)]}
    rows = [(7, 0.0, 3, -7), (8, 0.0, 3, 1)]
    out = build.flatten_loot_table(rows, refs)
    assert out == {70: 50.0, 8: 50.0}


def test_excluded_reference_is_skipped():
    refs = {7: [(70, 0.0, 0, 1)]}
    rows = [(7, 100.0, 0, -7), (8, 5.0, 0, 1)]
    assert build.flatten_loot_table(rows, refs, exclude_refs={7}) == {8: 5.0}


def test_same_item_from_two_paths_keeps_max():
    refs = {1: [(5, 10.0, 0, 1)]}
    rows = [(1, 100.0, 0, -1), (5, 2.0, 0, 1)]
    assert build.flatten_loot_table(rows, refs) == {5: 10.0}


def test_missing_reference_yields_nothing():
    assert build.flatten_loot_table([(1, 100.0, 0, -1)], {}) == {}


# ----------------------------------------------------------------------------------------- stats
def item_row(**kw):
    base = {"class": 4, "subclass": 1, "armor": 0, "block": 0, "delay": 0}
    for i in range(1, 11):
        base[f"stat_type{i}"] = 0
        base[f"stat_value{i}"] = 0
    for i in range(1, 6):
        base[f"spellid_{i}"] = 0
        base[f"spelltrigger_{i}"] = 0
    for i in range(1, 3):
        base[f"dmg_min{i}"] = 0
        base[f"dmg_max{i}"] = 0
    base.update(kw)
    return base


def spell(aura, base, misc=0, effect=6, stances=0):
    row = {"Stances": stances}
    for e in range(1, 4):
        row[f"Effect{e}"] = 0
        row[f"EffectApplyAuraName{e}"] = 0
        row[f"EffectBasePoints{e}"] = 0
        row[f"EffectDieSides{e}"] = 0
        row[f"EffectMiscValue{e}"] = 0
    row["Effect1"], row["EffectApplyAuraName1"] = effect, aura
    row["EffectBasePoints1"], row["EffectDieSides1"], row["EffectMiscValue1"] = base - 1, 1, misc
    return row


def test_primary_stats_and_ratings_from_stat_columns():
    it = item_row(stat_type1=7, stat_value1=27, stat_type2=3, stat_value2=18, stat_type3=32, stat_value3=14,
                  stat_type4=31, stat_value4=10, armor=300)
    stats, special = build.decode_item_stats(it, {})
    assert stats == {"STA": 27, "AGI": 18, "CRIT": 14, "HIT": 10, "ARMOR": 300}
    assert not special


def test_equip_spells_decode_ap_sp_heal_mp5():
    spells = {1: spell(99, 36), 2: spell(13, 36, misc=126), 3: spell(135, 106), 4: spell(85, 6, misc=0)}
    it = item_row(spellid_1=1, spelltrigger_1=1, spellid_2=2, spelltrigger_2=1, spellid_3=3, spelltrigger_3=1,
                  spellid_4=4, spelltrigger_4=1)
    stats, special = build.decode_item_stats(it, spells)
    assert stats == {"AP": 36, "SP": 36, "HEAL": 106, "MP5": 6}
    assert not special


def test_feral_ap_uses_stance_mask():
    stats, _ = build.decode_item_stats(item_row(spellid_1=1, spelltrigger_1=1), {1: spell(99, 189, stances=0x9)})
    assert stats == {"FAP": 189}


def test_school_spell_damage():
    stats, _ = build.decode_item_stats(item_row(spellid_1=1, spelltrigger_1=1), {1: spell(13, 20, misc=32)})
    assert stats == {"SPSHADOW": 20}


def test_rating_aura_mask():
    spells = {1: spell(189, 14, misc=768), 2: spell(189, 10, misc=96), 3: spell(189, 20, misc=114688)}
    it = item_row(spellid_1=1, spelltrigger_1=1, spellid_2=2, spelltrigger_2=1, spellid_3=3, spelltrigger_3=1)
    stats, special = build.decode_item_stats(it, spells)
    assert stats == {"CRIT": 14, "HIT": 10, "RES": 20}
    assert not special


def test_use_and_proc_spells_flag_special():
    _, special = build.decode_item_stats(item_row(spellid_1=1, spelltrigger_1=0), {1: spell(99, 10)})
    assert special
    _, special = build.decode_item_stats(item_row(spellid_1=1, spelltrigger_1=2), {1: spell(99, 10)})
    assert special


def test_unknown_equip_aura_flags_special():
    _, special = build.decode_item_stats(item_row(spellid_1=1, spelltrigger_1=1), {1: spell(31, 8)})
    assert special


def test_weapon_dps_and_speed():
    it = item_row(**{"class": 2, "subclass": 7, "delay": 2600, "dmg_min1": 100, "dmg_max1": 160})
    stats, _ = build.decode_item_stats(it, {})
    assert stats == {"DPS": 50.0, "SPEED": 2.6}


def test_ranged_weapon_uses_rdps_and_wand_uses_dps():
    bow = item_row(**{"class": 2, "subclass": 2, "delay": 2900, "dmg_min1": 100, "dmg_max1": 200})
    assert "RDPS" in build.decode_item_stats(bow, {})[0]
    wand = item_row(**{"class": 2, "subclass": 19, "delay": 1500, "dmg_min1": 30, "dmg_max1": 60})
    assert "DPS" in build.decode_item_stats(wand, {})[0]


def test_elemental_damage_slot_is_added():
    it = item_row(**{"class": 2, "subclass": 7, "delay": 2000, "dmg_min1": 40, "dmg_max1": 60, "dmg_min2": 10, "dmg_max2": 10})
    assert build.decode_item_stats(it, {})[0]["DPS"] == 30.0


def test_shield_block_value():
    it = item_row(**{"class": 4, "subclass": 6, "armor": 2000, "block": 45})
    assert build.decode_item_stats(it, {})[0] == {"ARMOR": 2000, "BLOCKV": 45}


def test_stats_to_str_is_ordered_and_numeric():
    assert build.stats_to_str({"AP": 36.0, "STA": 27, "DPS": 41.4, "AGI": 18}) == "AGI:18,STA:27,AP:36,DPS:41.4"


# --------------------------------------------------------------------------------------- sources
def test_sort_sources_best_first():
    srcs = ["W0.5", "B100:20", "Q10", "T547:1.2", "V500:0", "K164:80", "R5:9", "G3:30", "N7:3", "B100:5"]
    assert build.sort_sources(srcs) == ["Q10", "K164:80", "V500:0", "B100:20", "B100:5", "G3:30", "R5:9", "N7:3",
                                        "T547:1.2", "W0.5"]


def test_sort_sources_dedups():
    assert build.sort_sources(["Q1", "Q1"]) == ["Q1"]


def test_fmt_pct():
    assert build.fmt_pct(20.0) == "20"
    assert build.fmt_pct(16.666) == "16.7"
    assert build.fmt_pct(0.13) == "0.13"
    assert build.fmt_pct(0.001) == "0.01"
    assert build.fmt_pct(250) == "100"


# ---------------------------------------------------------------------------------------- format
def test_clean_strips_separators():
    assert build.clean("Foo; Bar, Baz: Qux|x") == "Foo Bar, Baz: Quxx"
    assert build.clean("  a   b ") == "a b"
    assert build.clean(None) == ""


def test_lua_str_escapes():
    assert build.lua_str('He said "hi" \\ there') == '"He said \\"hi\\" \\\\ there"'


def test_races_field():
    assert build.races_field(0) == "0"
    assert build.races_field(-1) == "0"
    assert build.races_field(1101) == "A"
    assert build.races_field(690) == "H"
    assert build.races_field(1) == "A"
    assert build.races_field(2) == "H"
    assert build.races_field(1 | 2) == "3"


def test_classmask_field():
    assert build.classmask_field(-1) == 0
    assert build.classmask_field(1503) == 0
    assert build.classmask_field(32767) == 0
    assert build.classmask_field(1024) == 1024
    assert build.classmask_field(1 | 2 | 1024) == 1027


def test_item_flags():
    it = {"maxcount": 1, "Flags": 0, "bonding": 1, "itemset": 0, "AllowableRace": -1}
    assert build.item_flags(it, [], False) == build.FLAG_UNIQUE | build.FLAG_BOP
    it = {"maxcount": 0, "Flags": 0x80000, "bonding": 2, "itemset": 5, "AllowableRace": 690}
    assert build.item_flags(it, [], True) == (build.FLAG_UNIQUE | build.FLAG_BOE | build.FLAG_SET |
                                              build.FLAG_HEROIC | build.FLAG_HORDE)


def test_vendor_mode_classification():
    from build import Builder
    item = {"RequiredReputationFaction": 0, "RequiredReputationRank": 0, "name": "Some Helm", "itemset": 0, "ItemLevel": 100}
    badge, raid = {18525}, {23381}
    prefixes = ("Merciless Gladiator's", "Vengeful Gladiator's", "Brutal Gladiator's")
    tokens = {120, 133, 146, 154, 159}
    vm = Builder.vendor_mode
    assert vm(item, [(1, 0)], badge, raid, prefixes, tokens) == "0"
    assert vm(item, [(1, 0), (18525, 5)], badge, raid, prefixes, tokens) == "0"  # gold wins
    assert vm(item, [(18525, 5)], badge, raid, prefixes, tokens) == "E"
    assert vm(item, [(999, 5)], badge, raid, prefixes, tokens) == "H"
    assert vm(item, [(23381, 5)], badge, raid, prefixes, tokens) is None  # raid token vendor
    assert vm(dict(item, name="Brutal Gladiator's Plate Helm", itemset=1, ItemLevel=159), [(999, 5)], badge, raid, prefixes, tokens) == "A"
    assert vm(dict(item, name="Gladiator's Plate Helm", itemset=1, ItemLevel=123), [(999, 5)], badge, raid, prefixes, tokens) == "H"
    assert vm(dict(item, name="Warbringer Chestguard", itemset=1, ItemLevel=120), [(999, 5)], badge, raid, prefixes, tokens) is None
    assert vm(dict(item, RequiredReputationFaction=942, RequiredReputationRank=6), [(999, 5)], badge, raid, prefixes, tokens) == "F942-6"


def test_decode_enchant_flat_stat_and_spell():
    spells = {7471: {"Effect1": 6, "EffectApplyAuraName1": 29, "EffectBasePoints1": 0, "EffectDieSides1": 1,
                     "EffectMiscValue1": 1}}  # +1 Agility (MOD_STAT agility)
    flat = {"Effect_0": "5", "EffectArg_0": "7", "EffectPointsMin_0": "0", "Effect_1": "0", "EffectArg_1": "0",
            "EffectPointsMin_1": "0", "Effect_2": "0", "EffectArg_2": "0", "EffectPointsMin_2": "0"}
    stats, keys = build.decode_enchant(flat, spells)
    assert stats == {} and keys == ["STA"]  # scaling enchant: key only
    fixed = dict(flat, EffectPointsMin_0="4")
    assert build.decode_enchant(fixed, spells)[0] == {"STA": 4.0}
    spell = dict(flat, Effect_0="3", EffectArg_0="7471")
    assert build.decode_enchant(spell, spells) == ({"AGI": 1.0}, ["AGI"])
    assert build.decode_enchant(dict(flat, Effect_0="4"), spells) == ({}, [])  # resistance ignored


def test_rpp_points_and_scaling():
    rpp = {60: {"Epic_0": "44", "Superior_0": "34", "Good_0": "26", "Good_1": "20", "Good_2": "15", "Good_3": "11", "Good_4": "8"}}
    assert build.rpp_points(rpp, 60, 2, 5) == 26     # uncommon chest
    assert build.rpp_points(rpp, 60, 3, 1) == 34     # rare head
    assert build.rpp_points(rpp, 60, 4, 17) == 44    # epic 2H
    assert build.rpp_points(rpp, 60, 2, 11) == 15    # ring -> group 2
    assert build.rpp_points(rpp, 61, 2, 5) == 0      # unknown ilvl
    assert build.scaled_suffix_stats({"STA": 10000, "STR": 6666}, 26) == {"STA": 26.0, "STR": 17.0}
    assert build.scaled_suffix_stats({"STA": 100}, 26) == {}


def test_sort_sources_places_auction_after_vendor():
    assert build.sort_sources(["W0.5", "S", "V100:0", "B1:20"]) == ["V100:0", "S", "B1:20", "W0.5"]
