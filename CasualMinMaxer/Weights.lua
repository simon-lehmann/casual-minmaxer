-- luacheck: no max line length
-- Default stat weights per class / spec / level phase, default gems and socket bonuses.
-- API is fixed by docs/ARCHITECTURE.md §5; the content tables are hand-authored.
--
-- Conventions (docs/ARCHITECTURE.md §2): primary stats per point, ratings PER 1 % after conversion
-- (DEF and EXP per skill point), DPS per weapon-DPS point, HEAL/SP per point. Extra keys:
-- SPEEDPREF / SPEEDPREF_OH (-1 fast, 0 none, +1 slow), DPS_OH for dual-wield off-hands, RDPS for
-- ranged weapons. The main stat of each spec is normalised to 1.0. Phases: 1-19, 20-39, 40-57,
-- 58-69, 70. Leveling phases favour weapon DPS, stamina and (for casters) spirit and wand DPS;
-- hit is nearly worthless against same-level mobs until 70; expertise only appears at 58+.
local _, CMM = ...
local W = CMM.Weights

W.PHASES = { { 1, 19 }, { 20, 39 }, { 40, 57 }, { 58, 69 }, { 70, 70 } }

-- W.DEFAULTS[classToken][specKey] = { name = "Arms", role = "melee"|"tank"|"caster"|"healer"|"ranged",
--   tabIndex = 1, phases = { [1] = {STA=..}, [2] = {...}, [3] = {...}, [4] = {...}, [5] = {...} } }
W.DEFAULTS = W.DEFAULTS or {}

W.DEFAULTS.WARRIOR = {
  -- Arms: slow two-hander, strength first; crit/hit/expertise only matter at 70.
  ARMS = { name = "Arms", role = "melee", tabIndex = 1, phases = {
    { STR = 1, AGI = 0.5, STA = 0.6, AP = 0.5, CRIT = 8, HIT = 3, DPS = 6, SPEEDPREF = 1, ARMOR = 0.02 },
    { STR = 1, AGI = 0.5, STA = 0.5, AP = 0.5, CRIT = 9, HIT = 4, DPS = 6, SPEEDPREF = 1, ARMOR = 0.02 },
    { STR = 1, AGI = 0.5, STA = 0.45, AP = 0.5, CRIT = 10, HIT = 5, DPS = 5.5, SPEEDPREF = 1, ARMOR = 0.015 },
    { STR = 1, AGI = 0.5, STA = 0.4, AP = 0.5, CRIT = 12, HIT = 8, EXP = 12, DPS = 5.5, SPEEDPREF = 1, ARMOR = 0.01, ARP = 0.05 },
    { STR = 1, AGI = 0.55, STA = 0.3, AP = 0.5, CRIT = 16, HIT = 16, EXP = 20, HASTE = 8, DPS = 5.5, SPEEDPREF = 1, ARMOR = 0.01, ARP = 0.1 },
  } },
  -- Fury: dual wield from level 20, slow main hand + fast off hand, crit-hungry at 70.
  FURY = { name = "Fury", role = "melee", tabIndex = 2, phases = {
    { STR = 1, AGI = 0.5, STA = 0.6, AP = 0.5, CRIT = 8, HIT = 3, DPS = 6, SPEEDPREF = 1, ARMOR = 0.02 },
    { STR = 1, AGI = 0.5, STA = 0.5, AP = 0.5, CRIT = 10, HIT = 4, DPS = 5.5, DPS_OH = 2.5, SPEEDPREF = 1, SPEEDPREF_OH = -1, ARMOR = 0.02 },
    { STR = 1, AGI = 0.5, STA = 0.45, AP = 0.5, CRIT = 12, HIT = 5, DPS = 5.5, DPS_OH = 3, SPEEDPREF = 1, SPEEDPREF_OH = -1, ARMOR = 0.015 },
    { STR = 1, AGI = 0.55, STA = 0.4, AP = 0.5, CRIT = 15, HIT = 9, EXP = 10, DPS = 5, DPS_OH = 3, SPEEDPREF = 1, SPEEDPREF_OH = -1, ARMOR = 0.01, ARP = 0.04 },
    { STR = 1, AGI = 0.55, STA = 0.3, AP = 0.5, CRIT = 20, HIT = 18, EXP = 18, HASTE = 10, DPS = 5, DPS_OH = 3, SPEEDPREF = 1, SPEEDPREF_OH = -1, ARMOR = 0.01, ARP = 0.08 },
  } },
  -- Protection: levels as a strength/DPS warrior with a shield, becomes an avoidance/stamina tank at 58+.
  PROTECTION = { name = "Protection", role = "tank", tabIndex = 3, phases = {
    { STR = 1, STA = 0.8, AGI = 0.5, AP = 0.45, DPS = 5, CRIT = 6, HIT = 3, ARMOR = 0.03, DEF = 0.5, DODGE = 6, PARRY = 4, BLOCK = 2, BLOCKV = 0.3, SPEEDPREF = -1 },
    { STR = 1, STA = 0.9, AGI = 0.5, AP = 0.45, DPS = 4.5, CRIT = 6, HIT = 3, ARMOR = 0.035, DEF = 0.7, DODGE = 8, PARRY = 6, BLOCK = 3, BLOCKV = 0.4, SPEEDPREF = -1 },
    { STR = 0.9, STA = 1, AGI = 0.45, AP = 0.35, DPS = 3.5, CRIT = 5, HIT = 3, ARMOR = 0.04, DEF = 1, DODGE = 12, PARRY = 9, BLOCK = 5, BLOCKV = 0.5, SPEEDPREF = -1 },
    { STR = 0.7, STA = 1.1, AGI = 0.4, AP = 0.25, DPS = 2.5, CRIT = 4, HIT = 4, EXP = 6, ARMOR = 0.045, DEF = 1.3, DODGE = 16, PARRY = 13, BLOCK = 7, BLOCKV = 0.6, SPEEDPREF = -1 },
    { STR = 0.5, STA = 1.2, AGI = 0.4, AP = 0.15, DPS = 1.5, CRIT = 3, HIT = 5, EXP = 8, ARMOR = 0.05, DEF = 1.5, DODGE = 20, PARRY = 16, BLOCK = 8, BLOCKV = 0.7, SPEEDPREF = -1 },
  } },
}

W.DEFAULTS.PALADIN = {
  -- Holy: levels mostly by melee + healing self, so INT/STA/weapon DPS early; pure healer weights at 58+.
  HOLY = { name = "Holy", role = "healer", tabIndex = 1, phases = {
    { INT = 1, STA = 0.6, STR = 0.5, HEAL = 0.5, SP = 0.5, SPI = 0.4, MP5 = 1.5, DPS = 2.5, ARMOR = 0.02, SPCRIT = 2 },
    { INT = 1, STA = 0.55, STR = 0.45, HEAL = 0.6, SP = 0.5, SPI = 0.4, MP5 = 1.8, DPS = 2.5, ARMOR = 0.02, SPCRIT = 3 },
    { INT = 1, STA = 0.5, STR = 0.35, HEAL = 0.8, SP = 0.45, SPI = 0.35, MP5 = 2, DPS = 2, ARMOR = 0.015, SPCRIT = 4 },
    { HEAL = 1, INT = 0.75, STA = 0.35, SP = 0.3, SPI = 0.2, MP5 = 2, SPCRIT = 6, SPHASTE = 3, ARMOR = 0.01, DPS = 0.5 },
    { HEAL = 1, INT = 0.65, STA = 0.25, SP = 0.2, SPHOLY = 0.2, SPI = 0.15, MP5 = 2.2, SPCRIT = 8, SPHASTE = 5, ARMOR = 0.01 },
  } },
  -- Protection: strength/DPS while leveling; at 70 stamina, avoidance, block and spell damage for threat.
  PROTECTION = { name = "Protection", role = "tank", tabIndex = 2, phases = {
    { STR = 1, STA = 0.8, INT = 0.3, AGI = 0.4, AP = 0.45, DPS = 5, CRIT = 5, HIT = 3, ARMOR = 0.03, DEF = 0.5, DODGE = 6, PARRY = 4, BLOCK = 3, BLOCKV = 0.3, SP = 0.2 },
    { STR = 1, STA = 0.9, INT = 0.3, AGI = 0.4, AP = 0.4, DPS = 4.5, CRIT = 5, HIT = 3, ARMOR = 0.035, DEF = 0.7, DODGE = 8, PARRY = 6, BLOCK = 5, BLOCKV = 0.4, SP = 0.25 },
    { STR = 0.8, STA = 1, INT = 0.25, AGI = 0.4, AP = 0.3, DPS = 3.5, CRIT = 4, HIT = 3, ARMOR = 0.04, DEF = 1, DODGE = 12, PARRY = 9, BLOCK = 8, BLOCKV = 0.5, SP = 0.3 },
    { STR = 0.5, STA = 1.1, INT = 0.2, AGI = 0.35, AP = 0.2, DPS = 2, CRIT = 3, HIT = 3, ARMOR = 0.045, DEF = 1.3, DODGE = 16, PARRY = 12, BLOCK = 10, BLOCKV = 0.7, SP = 0.35, SPHIT = 2, MP5 = 0.4 },
    { STR = 0.3, STA = 1.2, INT = 0.15, AGI = 0.3, AP = 0.1, DPS = 1, CRIT = 2, HIT = 3, ARMOR = 0.05, DEF = 1.5, DODGE = 18, PARRY = 14, BLOCK = 12, BLOCKV = 0.8, SP = 0.35, SPHIT = 4, MP5 = 0.5 },
  } },
  -- Retribution: slow two-hander, strength, crit; spell damage helps seals a little.
  RETRIBUTION = { name = "Retribution", role = "melee", tabIndex = 3, phases = {
    { STR = 1, STA = 0.6, AGI = 0.4, INT = 0.25, AP = 0.5, DPS = 7, CRIT = 8, HIT = 3, SPEEDPREF = 1, ARMOR = 0.02, SP = 0.1 },
    { STR = 1, STA = 0.5, AGI = 0.4, INT = 0.2, AP = 0.5, DPS = 7, CRIT = 9, HIT = 4, SPEEDPREF = 1, ARMOR = 0.02, SP = 0.1 },
    { STR = 1, STA = 0.45, AGI = 0.4, INT = 0.15, AP = 0.5, DPS = 6.5, CRIT = 10, HIT = 5, SPEEDPREF = 1, ARMOR = 0.015, SP = 0.1 },
    { STR = 1, STA = 0.4, AGI = 0.4, INT = 0.1, AP = 0.5, DPS = 6, CRIT = 12, HIT = 8, EXP = 10, SPEEDPREF = 1, ARMOR = 0.01, SP = 0.15, ARP = 0.03 },
    { STR = 1, STA = 0.3, AGI = 0.4, INT = 0.1, AP = 0.5, DPS = 6, CRIT = 16, HIT = 15, EXP = 14, HASTE = 8, SPEEDPREF = 1, ARMOR = 0.01, SP = 0.15, ARP = 0.06 },
  } },
}

W.DEFAULTS.HUNTER = {
  -- Beast Mastery: ranged DPS and agility; melee weapons are stat sticks (DPS tiny); haste is strong at 70.
  BEASTMASTERY = { name = "Beast Mastery", role = "ranged", tabIndex = 1, phases = {
    { AGI = 1, RAP = 0.45, RDPS = 7, STA = 0.5, INT = 0.3, CRIT = 5, HIT = 2, DPS = 0.3, ARMOR = 0.02, MP5 = 0.5 },
    { AGI = 1, RAP = 0.45, RDPS = 7, STA = 0.45, INT = 0.3, CRIT = 6, HIT = 3, DPS = 0.3, ARMOR = 0.02, MP5 = 0.5 },
    { AGI = 1, RAP = 0.45, RDPS = 6.5, STA = 0.4, INT = 0.3, CRIT = 8, HIT = 4, DPS = 0.25, ARMOR = 0.015, MP5 = 0.5 },
    { AGI = 1, RAP = 0.45, RDPS = 6, STA = 0.35, INT = 0.3, CRIT = 11, HIT = 8, HASTE = 4, DPS = 0.2, ARMOR = 0.01, MP5 = 0.6, ARP = 0.02 },
    { AGI = 1, RAP = 0.45, RDPS = 6, STA = 0.3, INT = 0.25, CRIT = 14, HIT = 15, HASTE = 8, DPS = 0.2, ARMOR = 0.01, MP5 = 0.6, ARP = 0.04, STR = 0.05 },
  } },
  -- Marksmanship: like BM with more weight on crit and ranged attack power.
  MARKSMANSHIP = { name = "Marksmanship", role = "ranged", tabIndex = 2, phases = {
    { AGI = 1, RAP = 0.5, RDPS = 7, STA = 0.5, INT = 0.35, CRIT = 5, HIT = 2, DPS = 0.3, ARMOR = 0.02, MP5 = 0.5 },
    { AGI = 1, RAP = 0.5, RDPS = 7, STA = 0.45, INT = 0.35, CRIT = 7, HIT = 3, DPS = 0.3, ARMOR = 0.02, MP5 = 0.5 },
    { AGI = 1, RAP = 0.5, RDPS = 6.5, STA = 0.4, INT = 0.35, CRIT = 9, HIT = 4, DPS = 0.25, ARMOR = 0.015, MP5 = 0.5 },
    { AGI = 1, RAP = 0.5, RDPS = 6, STA = 0.35, INT = 0.3, CRIT = 12, HIT = 8, HASTE = 3, DPS = 0.2, ARMOR = 0.01, MP5 = 0.6, ARP = 0.02 },
    { AGI = 1, RAP = 0.5, RDPS = 6, STA = 0.3, INT = 0.3, CRIT = 15, HIT = 15, HASTE = 7, DPS = 0.2, ARMOR = 0.01, MP5 = 0.6, ARP = 0.04, STR = 0.05 },
  } },
  -- Survival: agility is king (Expose Weakness), slightly less attack power.
  SURVIVAL = { name = "Survival", role = "ranged", tabIndex = 3, phases = {
    { AGI = 1, RAP = 0.45, RDPS = 7, STA = 0.5, INT = 0.3, CRIT = 5, HIT = 2, DPS = 0.3, ARMOR = 0.02, MP5 = 0.5 },
    { AGI = 1, RAP = 0.45, RDPS = 7, STA = 0.45, INT = 0.3, CRIT = 6, HIT = 3, DPS = 0.3, ARMOR = 0.02, MP5 = 0.5 },
    { AGI = 1.05, RAP = 0.42, RDPS = 6.5, STA = 0.4, INT = 0.3, CRIT = 8, HIT = 4, DPS = 0.25, ARMOR = 0.015, MP5 = 0.5 },
    { AGI = 1.1, RAP = 0.4, RDPS = 6, STA = 0.35, INT = 0.3, CRIT = 11, HIT = 8, HASTE = 3, DPS = 0.2, ARMOR = 0.01, MP5 = 0.6, ARP = 0.02 },
    { AGI = 1.1, RAP = 0.4, RDPS = 6, STA = 0.3, INT = 0.25, CRIT = 13, HIT = 15, HASTE = 6, DPS = 0.2, ARMOR = 0.01, MP5 = 0.6, ARP = 0.04, STR = 0.05 },
  } },
}

W.DEFAULTS.ROGUE = {
  -- Assassination: daggers, agility, dual wield from level 10; speed preference neutral on the main hand.
  ASSASSINATION = { name = "Assassination", role = "melee", tabIndex = 1, phases = {
    { AGI = 1, STR = 0.55, STA = 0.55, AP = 0.5, CRIT = 8, HIT = 3, DPS = 6, DPS_OH = 2, SPEEDPREF = 0, SPEEDPREF_OH = -1, ARMOR = 0.02 },
    { AGI = 1, STR = 0.55, STA = 0.5, AP = 0.5, CRIT = 9, HIT = 4, DPS = 5.5, DPS_OH = 2.5, SPEEDPREF = 0, SPEEDPREF_OH = -1, ARMOR = 0.02 },
    { AGI = 1, STR = 0.55, STA = 0.45, AP = 0.5, CRIT = 10, HIT = 5, DPS = 5.5, DPS_OH = 2.5, SPEEDPREF = 0, SPEEDPREF_OH = -1, ARMOR = 0.015 },
    { AGI = 1, STR = 0.55, STA = 0.35, AP = 0.5, CRIT = 13, HIT = 8, EXP = 9, HASTE = 5, DPS = 5, DPS_OH = 2.5, SPEEDPREF = 0, SPEEDPREF_OH = -1, ARMOR = 0.01, ARP = 0.03 },
    { AGI = 1, STR = 0.55, STA = 0.25, AP = 0.5, CRIT = 16, HIT = 14, EXP = 14, HASTE = 9, DPS = 5, DPS_OH = 2.5, SPEEDPREF = 0, SPEEDPREF_OH = -1, ARMOR = 0.01, ARP = 0.05 },
  } },
  -- Combat: slow main hand (Sinister Strike), fast off hand, hit and expertise matter most at 70.
  COMBAT = { name = "Combat", role = "melee", tabIndex = 2, phases = {
    { AGI = 1, STR = 0.6, STA = 0.55, AP = 0.5, CRIT = 8, HIT = 3, DPS = 6, DPS_OH = 2, SPEEDPREF = 1, SPEEDPREF_OH = -1, ARMOR = 0.02 },
    { AGI = 1, STR = 0.6, STA = 0.5, AP = 0.5, CRIT = 9, HIT = 4, DPS = 6, DPS_OH = 2.5, SPEEDPREF = 1, SPEEDPREF_OH = -1, ARMOR = 0.02 },
    { AGI = 1, STR = 0.6, STA = 0.45, AP = 0.5, CRIT = 10, HIT = 5, DPS = 5.5, DPS_OH = 2.5, SPEEDPREF = 1, SPEEDPREF_OH = -1, ARMOR = 0.015 },
    { AGI = 1, STR = 0.6, STA = 0.35, AP = 0.5, CRIT = 13, HIT = 9, EXP = 10, HASTE = 6, DPS = 5.5, DPS_OH = 2.5, SPEEDPREF = 1, SPEEDPREF_OH = -1, ARMOR = 0.01, ARP = 0.04 },
    { AGI = 1, STR = 0.6, STA = 0.25, AP = 0.5, CRIT = 16, HIT = 16, EXP = 16, HASTE = 10, DPS = 5.5, DPS_OH = 2.5, SPEEDPREF = 1, SPEEDPREF_OH = -1, ARMOR = 0.01, ARP = 0.06 },
  } },
  -- Subtlety: agility-heavy (Sinister Calling), otherwise like Combat with slightly lower ratings.
  SUBTLETY = { name = "Subtlety", role = "melee", tabIndex = 3, phases = {
    { AGI = 1, STR = 0.5, STA = 0.55, AP = 0.5, CRIT = 8, HIT = 3, DPS = 6, DPS_OH = 2, SPEEDPREF = 1, SPEEDPREF_OH = -1, ARMOR = 0.02 },
    { AGI = 1, STR = 0.5, STA = 0.5, AP = 0.5, CRIT = 9, HIT = 4, DPS = 5.5, DPS_OH = 2, SPEEDPREF = 1, SPEEDPREF_OH = -1, ARMOR = 0.02 },
    { AGI = 1.05, STR = 0.5, STA = 0.45, AP = 0.5, CRIT = 10, HIT = 5, DPS = 5.5, DPS_OH = 2, SPEEDPREF = 1, SPEEDPREF_OH = -1, ARMOR = 0.015 },
    { AGI = 1.1, STR = 0.5, STA = 0.35, AP = 0.5, CRIT = 12, HIT = 8, EXP = 8, HASTE = 5, DPS = 5, DPS_OH = 2, SPEEDPREF = 1, SPEEDPREF_OH = -1, ARMOR = 0.01, ARP = 0.03 },
    { AGI = 1.1, STR = 0.5, STA = 0.25, AP = 0.5, CRIT = 14, HIT = 14, EXP = 12, HASTE = 8, DPS = 5, DPS_OH = 2, SPEEDPREF = 1, SPEEDPREF_OH = -1, ARMOR = 0.01, ARP = 0.05 },
  } },
}

W.DEFAULTS.PRIEST = {
  -- Discipline: levels with Smite and a wand (wand DPS is a DPS weight), becomes a mana-efficient healer at 58+.
  DISCIPLINE = { name = "Discipline", role = "healer", tabIndex = 1, phases = {
    { INT = 1, SPI = 0.8, STA = 0.6, SP = 0.9, HEAL = 0.4, DPS = 3, MP5 = 1.5, SPCRIT = 2, ARMOR = 0.01 },
    { INT = 1, SPI = 0.8, STA = 0.55, SP = 0.9, HEAL = 0.5, DPS = 3, MP5 = 1.8, SPCRIT = 3, ARMOR = 0.01 },
    { INT = 1, SPI = 0.7, STA = 0.5, SP = 0.8, HEAL = 0.7, DPS = 2.5, MP5 = 2, SPCRIT = 4, SPHIT = 1, ARMOR = 0.01 },
    { HEAL = 1, INT = 0.75, SPI = 0.6, STA = 0.35, SP = 0.4, DPS = 1, MP5 = 2.2, SPCRIT = 5, SPHASTE = 3, ARMOR = 0.01 },
    { HEAL = 1, INT = 0.7, SPI = 0.6, STA = 0.25, SP = 0.25, DPS = 0.3, MP5 = 2.2, SPCRIT = 6, SPHASTE = 6, ARMOR = 0.01 },
  } },
  -- Holy: same leveling profile; at 70 spirit and mp5 weigh more than crit.
  HOLY = { name = "Holy", role = "healer", tabIndex = 2, phases = {
    { INT = 1, SPI = 0.85, STA = 0.6, SP = 0.9, HEAL = 0.4, DPS = 3, MP5 = 1.5, SPCRIT = 2, ARMOR = 0.01 },
    { INT = 1, SPI = 0.85, STA = 0.55, SP = 0.9, HEAL = 0.5, DPS = 3, MP5 = 1.8, SPCRIT = 3, ARMOR = 0.01 },
    { INT = 1, SPI = 0.8, STA = 0.5, SP = 0.8, HEAL = 0.7, DPS = 2.5, MP5 = 2, SPCRIT = 4, SPHIT = 1, ARMOR = 0.01 },
    { HEAL = 1, INT = 0.7, SPI = 0.8, STA = 0.35, SP = 0.35, DPS = 1, MP5 = 2.3, SPCRIT = 6, SPHASTE = 3, ARMOR = 0.01 },
    { HEAL = 1, INT = 0.6, SPI = 0.8, STA = 0.25, SP = 0.2, DPS = 0.3, MP5 = 2.4, SPCRIT = 7, SPHASTE = 6, ARMOR = 0.01 },
  } },
  -- Shadow: shadow damage, spell hit to cap, haste; spirit still useful (Spirit Tap / Vampiric Touch mana).
  SHADOW = { name = "Shadow", role = "caster", tabIndex = 3, phases = {
    { SP = 1, SPSHADOW = 1, INT = 0.6, SPI = 0.6, STA = 0.5, DPS = 3, SPCRIT = 3, SPHIT = 1, MP5 = 0.8, ARMOR = 0.01 },
    { SP = 1, SPSHADOW = 1, INT = 0.55, SPI = 0.55, STA = 0.45, DPS = 3, SPCRIT = 3, SPHIT = 2, MP5 = 0.8, ARMOR = 0.01 },
    { SP = 1, SPSHADOW = 1, INT = 0.45, SPI = 0.5, STA = 0.4, DPS = 2.5, SPCRIT = 4, SPHIT = 3, MP5 = 0.7, ARMOR = 0.01 },
    { SP = 1, SPSHADOW = 1, INT = 0.3, SPI = 0.4, STA = 0.3, DPS = 1, SPCRIT = 5, SPHIT = 6, SPHASTE = 4, MP5 = 0.6, ARMOR = 0.01 },
    { SP = 1, SPSHADOW = 1, INT = 0.2, SPI = 0.3, STA = 0.2, DPS = 0.3, SPCRIT = 6, SPHIT = 10, SPHASTE = 8, MP5 = 0.6, ARMOR = 0.01 },
  } },
}

W.DEFAULTS.SHAMAN = {
  -- Elemental: nature (lightning) with some fire (Flame Shock); melee weapon still matters while leveling.
  ELEMENTAL = { name = "Elemental", role = "caster", tabIndex = 1, phases = {
    { SP = 1, SPNATURE = 1, SPFIRE = 0.4, INT = 0.7, STA = 0.5, SPI = 0.2, DPS = 2, MP5 = 1, SPCRIT = 3, SPHIT = 1, ARMOR = 0.02 },
    { SP = 1, SPNATURE = 1, SPFIRE = 0.4, INT = 0.65, STA = 0.45, SPI = 0.15, DPS = 1.5, MP5 = 1, SPCRIT = 4, SPHIT = 2, ARMOR = 0.02 },
    { SP = 1, SPNATURE = 1, SPFIRE = 0.4, INT = 0.5, STA = 0.4, SPI = 0.1, DPS = 1, MP5 = 0.9, SPCRIT = 5, SPHIT = 3, ARMOR = 0.015 },
    { SP = 1, SPNATURE = 1, SPFIRE = 0.4, INT = 0.4, STA = 0.3, SPI = 0.05, DPS = 0.3, MP5 = 0.8, SPCRIT = 7, SPHIT = 6, SPHASTE = 4, ARMOR = 0.01 },
    { SP = 1, SPNATURE = 1, SPFIRE = 0.4, INT = 0.3, STA = 0.2, SPI = 0.05, MP5 = 0.8, SPCRIT = 8, SPHIT = 10, SPHASTE = 7, ARMOR = 0.01 },
  } },
  -- Enhancement: 2 AP per strength, slow/slow dual wield from 40 (Dual Wield talent), haste and hit at 70.
  ENHANCEMENT = { name = "Enhancement", role = "melee", tabIndex = 2, phases = {
    { STR = 1, AGI = 0.5, STA = 0.6, INT = 0.35, AP = 0.5, DPS = 7, CRIT = 8, HIT = 3, SPEEDPREF = 1, ARMOR = 0.02, SP = 0.1 },
    { STR = 1, AGI = 0.5, STA = 0.5, INT = 0.3, AP = 0.5, DPS = 7, CRIT = 9, HIT = 4, SPEEDPREF = 1, ARMOR = 0.02, SP = 0.1 },
    { STR = 1, AGI = 0.55, STA = 0.45, INT = 0.3, AP = 0.5, DPS = 5.5, DPS_OH = 3.5, CRIT = 10, HIT = 5, SPEEDPREF = 1, SPEEDPREF_OH = 1, ARMOR = 0.015, SP = 0.1 },
    { STR = 1, AGI = 0.55, STA = 0.35, INT = 0.3, AP = 0.5, DPS = 5.5, DPS_OH = 4, CRIT = 12, HIT = 9, EXP = 8, HASTE = 5, SPEEDPREF = 1, SPEEDPREF_OH = 1, ARMOR = 0.01, SP = 0.15, ARP = 0.03 },
    { STR = 1, AGI = 0.55, STA = 0.3, INT = 0.3, AP = 0.5, DPS = 5.5, DPS_OH = 4, CRIT = 14, HIT = 14, EXP = 12, HASTE = 10, SPEEDPREF = 1, SPEEDPREF_OH = 1, ARMOR = 0.01, SP = 0.15, ARP = 0.06 },
  } },
  -- Restoration: chain-heal healer, mp5 is worth a lot; levels with melee + INT early.
  RESTORATION = { name = "Restoration", role = "healer", tabIndex = 3, phases = {
    { INT = 1, STA = 0.6, STR = 0.5, SP = 0.6, HEAL = 0.5, SPI = 0.2, DPS = 3, MP5 = 1.5, ARMOR = 0.02, SPCRIT = 2 },
    { INT = 1, STA = 0.55, STR = 0.4, SP = 0.6, HEAL = 0.6, SPI = 0.2, DPS = 2.5, MP5 = 1.8, ARMOR = 0.02, SPCRIT = 3 },
    { INT = 1, STA = 0.5, STR = 0.3, SP = 0.5, HEAL = 0.8, SPI = 0.15, DPS = 2, MP5 = 2.2, ARMOR = 0.015, SPCRIT = 4 },
    { HEAL = 1, INT = 0.7, STA = 0.35, SP = 0.25, SPI = 0.1, DPS = 0.5, MP5 = 2.4, SPCRIT = 5, SPHASTE = 3, ARMOR = 0.01 },
    { HEAL = 1, INT = 0.6, STA = 0.25, SP = 0.15, SPI = 0.1, MP5 = 2.5, SPCRIT = 6, SPHASTE = 5, ARMOR = 0.01 },
  } },
}

-- Mages share a leveling profile: spell damage, intellect, stamina, spirit for regen, wand DPS.
W.DEFAULTS.MAGE = {
  -- Arcane: mana-hungry, intellect and mp5 stay valuable at 70.
  ARCANE = { name = "Arcane", role = "caster", tabIndex = 1, phases = {
    { SP = 1, SPARCANE = 0.8, SPFROST = 0.4, INT = 0.7, STA = 0.5, SPI = 0.4, DPS = 3, SPCRIT = 3, SPHIT = 1, MP5 = 0.8, ARMOR = 0.01 },
    { SP = 1, SPARCANE = 0.8, SPFROST = 0.4, INT = 0.65, STA = 0.45, SPI = 0.35, DPS = 3, SPCRIT = 3, SPHIT = 2, MP5 = 0.8, ARMOR = 0.01 },
    { SP = 1, SPARCANE = 0.9, SPFROST = 0.3, INT = 0.55, STA = 0.4, SPI = 0.3, DPS = 2.5, SPCRIT = 4, SPHIT = 3, MP5 = 0.8, ARMOR = 0.01 },
    { SP = 1, SPARCANE = 1, SPFROST = 0.2, INT = 0.45, STA = 0.3, SPI = 0.2, DPS = 1, SPCRIT = 5, SPHIT = 6, SPHASTE = 4, MP5 = 0.8, ARMOR = 0.01 },
    { SP = 1, SPARCANE = 1, SPFROST = 0.2, INT = 0.4, STA = 0.2, SPI = 0.15, DPS = 0.3, SPCRIT = 6, SPHIT = 10, SPHASTE = 7, MP5 = 0.8, ARMOR = 0.01 },
  } },
  -- Fire: fire damage, crit (Ignite) and hit.
  FIRE = { name = "Fire", role = "caster", tabIndex = 2, phases = {
    { SP = 1, SPFIRE = 1, SPFROST = 0.3, INT = 0.7, STA = 0.5, SPI = 0.4, DPS = 3, SPCRIT = 3, SPHIT = 1, MP5 = 0.7, ARMOR = 0.01 },
    { SP = 1, SPFIRE = 1, SPFROST = 0.3, INT = 0.6, STA = 0.45, SPI = 0.35, DPS = 3, SPCRIT = 4, SPHIT = 2, MP5 = 0.7, ARMOR = 0.01 },
    { SP = 1, SPFIRE = 1, SPFROST = 0.2, INT = 0.5, STA = 0.4, SPI = 0.3, DPS = 2.5, SPCRIT = 5, SPHIT = 3, MP5 = 0.6, ARMOR = 0.01 },
    { SP = 1, SPFIRE = 1, SPFROST = 0.1, INT = 0.35, STA = 0.3, SPI = 0.15, DPS = 1, SPCRIT = 7, SPHIT = 6, SPHASTE = 4, MP5 = 0.5, ARMOR = 0.01 },
    { SP = 1, SPFIRE = 1, SPFROST = 0.1, INT = 0.25, STA = 0.2, SPI = 0.1, DPS = 0.3, SPCRIT = 9, SPHIT = 10, SPHASTE = 7, MP5 = 0.5, ARMOR = 0.01 },
  } },
  -- Frost: frost damage, hit, crit (Shatter) and haste.
  FROST = { name = "Frost", role = "caster", tabIndex = 3, phases = {
    { SP = 1, SPFROST = 1, SPFIRE = 0.3, INT = 0.7, STA = 0.5, SPI = 0.4, DPS = 3, SPCRIT = 3, SPHIT = 1, MP5 = 0.7, ARMOR = 0.01 },
    { SP = 1, SPFROST = 1, SPFIRE = 0.3, INT = 0.6, STA = 0.45, SPI = 0.35, DPS = 3, SPCRIT = 3, SPHIT = 2, MP5 = 0.7, ARMOR = 0.01 },
    { SP = 1, SPFROST = 1, SPFIRE = 0.2, INT = 0.5, STA = 0.4, SPI = 0.3, DPS = 2.5, SPCRIT = 4, SPHIT = 3, MP5 = 0.6, ARMOR = 0.01 },
    { SP = 1, SPFROST = 1, SPFIRE = 0.1, INT = 0.35, STA = 0.3, SPI = 0.15, DPS = 1, SPCRIT = 5, SPHIT = 6, SPHASTE = 4, MP5 = 0.5, ARMOR = 0.01 },
    { SP = 1, SPFROST = 1, SPFIRE = 0.1, INT = 0.25, STA = 0.2, SPI = 0.1, DPS = 0.3, SPCRIT = 7, SPHIT = 10, SPHASTE = 7, MP5 = 0.5, ARMOR = 0.01 },
  } },
}

-- Warlocks: stamina matters more than for other casters (Life Tap, Demonic Knowledge); wand DPS while leveling.
W.DEFAULTS.WARLOCK = {
  -- Affliction: shadow DoTs cannot crit, so crit is near zero; spell hit is the top rating.
  AFFLICTION = { name = "Affliction", role = "caster", tabIndex = 1, phases = {
    { SP = 1, SPSHADOW = 1, SPFIRE = 0.3, STA = 0.7, INT = 0.5, SPI = 0.4, DPS = 3, SPCRIT = 1, SPHIT = 1, MP5 = 0.5, ARMOR = 0.01 },
    { SP = 1, SPSHADOW = 1, SPFIRE = 0.3, STA = 0.6, INT = 0.45, SPI = 0.35, DPS = 3, SPCRIT = 1, SPHIT = 2, MP5 = 0.5, ARMOR = 0.01 },
    { SP = 1, SPSHADOW = 1, SPFIRE = 0.2, STA = 0.5, INT = 0.35, SPI = 0.3, DPS = 2.5, SPCRIT = 1.5, SPHIT = 4, MP5 = 0.4, ARMOR = 0.01 },
    { SP = 1, SPSHADOW = 1, SPFIRE = 0.2, STA = 0.35, INT = 0.2, SPI = 0.2, DPS = 1, SPCRIT = 2, SPHIT = 7, SPHASTE = 4, MP5 = 0.3, ARMOR = 0.01 },
    { SP = 1, SPSHADOW = 1, SPFIRE = 0.2, STA = 0.25, INT = 0.15, SPI = 0.15, DPS = 0.3, SPCRIT = 2, SPHIT = 12, SPHASTE = 7, MP5 = 0.3, ARMOR = 0.01 },
  } },
  -- Demonology: stamina converts to spell damage (Demonic Knowledge), mixed shadow/fire.
  DEMONOLOGY = { name = "Demonology", role = "caster", tabIndex = 2, phases = {
    { SP = 1, SPSHADOW = 0.9, SPFIRE = 0.5, STA = 0.8, INT = 0.5, SPI = 0.35, DPS = 3, SPCRIT = 2, SPHIT = 1, MP5 = 0.5, ARMOR = 0.01 },
    { SP = 1, SPSHADOW = 0.9, SPFIRE = 0.5, STA = 0.7, INT = 0.45, SPI = 0.3, DPS = 3, SPCRIT = 2, SPHIT = 2, MP5 = 0.5, ARMOR = 0.01 },
    { SP = 1, SPSHADOW = 0.9, SPFIRE = 0.5, STA = 0.6, INT = 0.35, SPI = 0.25, DPS = 2.5, SPCRIT = 3, SPHIT = 4, MP5 = 0.4, ARMOR = 0.01 },
    { SP = 1, SPSHADOW = 0.9, SPFIRE = 0.5, STA = 0.5, INT = 0.25, SPI = 0.15, DPS = 1, SPCRIT = 4, SPHIT = 7, SPHASTE = 4, MP5 = 0.3, ARMOR = 0.01 },
    { SP = 1, SPSHADOW = 0.9, SPFIRE = 0.5, STA = 0.4, INT = 0.2, SPI = 0.1, DPS = 0.3, SPCRIT = 5, SPHIT = 11, SPHASTE = 7, MP5 = 0.3, ARMOR = 0.01 },
  } },
  -- Destruction: fire (Incinerate/Conflagrate) with shadow bolt filler, crit-friendly.
  DESTRUCTION = { name = "Destruction", role = "caster", tabIndex = 3, phases = {
    { SP = 1, SPSHADOW = 0.8, SPFIRE = 0.6, STA = 0.7, INT = 0.5, SPI = 0.4, DPS = 3, SPCRIT = 2, SPHIT = 1, MP5 = 0.5, ARMOR = 0.01 },
    { SP = 1, SPSHADOW = 0.8, SPFIRE = 0.6, STA = 0.6, INT = 0.45, SPI = 0.35, DPS = 3, SPCRIT = 3, SPHIT = 2, MP5 = 0.5, ARMOR = 0.01 },
    { SP = 1, SPSHADOW = 0.7, SPFIRE = 0.8, STA = 0.5, INT = 0.35, SPI = 0.3, DPS = 2.5, SPCRIT = 4, SPHIT = 4, MP5 = 0.4, ARMOR = 0.01 },
    { SP = 1, SPSHADOW = 0.7, SPFIRE = 1, STA = 0.35, INT = 0.25, SPI = 0.15, DPS = 1, SPCRIT = 6, SPHIT = 7, SPHASTE = 4, MP5 = 0.3, ARMOR = 0.01 },
    { SP = 1, SPSHADOW = 0.7, SPFIRE = 1, STA = 0.25, INT = 0.2, SPI = 0.1, DPS = 0.3, SPCRIT = 8, SPHIT = 12, SPHASTE = 7, MP5 = 0.3, ARMOR = 0.01 },
  } },
}

W.DEFAULTS.DRUID = {
  -- Balance: arcane (Starfire/Moonfire) and nature (Wrath), spirit still counts (Intensity / Dreamstate).
  BALANCE = { name = "Balance", role = "caster", tabIndex = 1, phases = {
    { SP = 1, SPARCANE = 0.8, SPNATURE = 0.7, INT = 0.7, SPI = 0.5, STA = 0.5, DPS = 0.5, SPCRIT = 3, SPHIT = 1, MP5 = 0.8, ARMOR = 0.02 },
    { SP = 1, SPARCANE = 0.8, SPNATURE = 0.7, INT = 0.65, SPI = 0.45, STA = 0.45, DPS = 0.5, SPCRIT = 4, SPHIT = 2, MP5 = 0.8, ARMOR = 0.02 },
    { SP = 1, SPARCANE = 0.8, SPNATURE = 0.7, INT = 0.5, SPI = 0.4, STA = 0.4, DPS = 0.3, SPCRIT = 5, SPHIT = 3, MP5 = 0.7, ARMOR = 0.015 },
    { SP = 1, SPARCANE = 0.8, SPNATURE = 0.7, INT = 0.4, SPI = 0.35, STA = 0.3, SPCRIT = 6, SPHIT = 6, SPHASTE = 4, MP5 = 0.6, ARMOR = 0.01 },
    { SP = 1, SPARCANE = 0.8, SPNATURE = 0.7, INT = 0.3, SPI = 0.3, STA = 0.2, SPCRIT = 8, SPHIT = 10, SPHASTE = 6, MP5 = 0.6, ARMOR = 0.01 },
  } },
  -- Feral: blended cat/bear set. Feral attack power is the big leveling stat; weapon DPS is irrelevant,
  -- armor and stamina matter for bear, agility/strength/crit for cat.
  FERAL = { name = "Feral", role = "melee", tabIndex = 2, phases = {
    { AGI = 1, STR = 0.9, FAP = 0.55, AP = 0.5, STA = 0.7, CRIT = 6, HIT = 2, ARMOR = 0.06, DODGE = 4, DEF = 0.3, DPS = 0.2 },
    { AGI = 1, STR = 0.9, FAP = 0.55, AP = 0.5, STA = 0.65, CRIT = 8, HIT = 3, ARMOR = 0.07, DODGE = 5, DEF = 0.4 },
    { AGI = 1, STR = 0.9, FAP = 0.55, AP = 0.5, STA = 0.6, CRIT = 9, HIT = 4, ARMOR = 0.07, DODGE = 6, DEF = 0.5 },
    { AGI = 1, STR = 0.9, FAP = 0.55, AP = 0.5, STA = 0.55, CRIT = 11, HIT = 7, EXP = 7, HASTE = 3, ARMOR = 0.08, DODGE = 7, DEF = 0.6, ARP = 0.03 },
    { AGI = 1, STR = 0.9, FAP = 0.55, AP = 0.5, STA = 0.5, CRIT = 12, HIT = 10, EXP = 10, HASTE = 4, ARMOR = 0.08, DODGE = 8, DEF = 0.6, ARP = 0.05 },
  } },
  -- Restoration: healing, mp5 and spirit (Living Spirit / Intensity); levels by casting so SP early.
  RESTORATION = { name = "Restoration", role = "healer", tabIndex = 3, phases = {
    { INT = 1, SPI = 0.8, STA = 0.6, SP = 0.8, HEAL = 0.5, DPS = 0.5, MP5 = 1.5, SPCRIT = 2, ARMOR = 0.02 },
    { INT = 1, SPI = 0.8, STA = 0.55, SP = 0.8, HEAL = 0.6, DPS = 0.5, MP5 = 1.8, SPCRIT = 2, ARMOR = 0.02 },
    { INT = 1, SPI = 0.8, STA = 0.5, SP = 0.6, HEAL = 0.8, DPS = 0.3, MP5 = 2, SPCRIT = 2, ARMOR = 0.015 },
    { HEAL = 1, INT = 0.7, SPI = 0.8, STA = 0.35, SP = 0.25, MP5 = 2.3, SPCRIT = 2, SPHASTE = 3, ARMOR = 0.01 },
    { HEAL = 1, INT = 0.6, SPI = 0.8, STA = 0.25, SP = 0.15, MP5 = 2.5, SPCRIT = 2, SPHASTE = 5, ARMOR = 0.01 },
  } },
}

function W.Specs(classToken)
  local out = {}
  for key, spec in pairs(W.DEFAULTS[classToken] or {}) do out[#out + 1] = { key = key, name = spec.name, role = spec.role, tabIndex = spec.tabIndex } end
  table.sort(out, function(a, b) return (a.tabIndex or 0) < (b.tabIndex or 0) end)
  return out
end

function W.PhaseIndex(level)
  for i, p in ipairs(W.PHASES) do
    if level >= p[1] and level <= p[2] then return i end
  end
  return #W.PHASES
end

-- Blend the weights of the phase containing `level` with the next phase over the last 3 levels
-- before the boundary, so a level 57 character already leans toward 58-69 weights.
local BLEND = 3
function W.Get(classToken, specKey, level)
  local spec = W.DEFAULTS[classToken] and W.DEFAULTS[classToken][specKey]
  if not spec then return {} end
  local i = W.PhaseIndex(level)
  local cur, nxt = spec.phases[i], spec.phases[i + 1]
  local out = {}
  for k, v in pairs(cur) do out[k] = v end
  if nxt then
    local boundary = W.PHASES[i][2] + 1
    local d = boundary - level -- 1..BLEND
    if d <= BLEND then
      local t = (BLEND - d + 1) / (BLEND + 1) -- level 57 (d=1) -> 0.75 toward next
      for k, v in pairs(nxt) do out[k] = (out[k] or 0) * (1 - t) + v * t end
      for k, v in pairs(cur) do if nxt[k] == nil then out[k] = v * (1 - t) end end
    end
  end
  return out
end

-- Default gem stats by socket color for the spec's role. Uncommon gems below 70, rare gems at 70.
-- Uncommon: red +6 STR / +6 AGI / +7 SP / +13 HEAL(+4 SP); yellow +6 crit / +6 INT / +6 def; blue +9 STA / +2 MP5.
-- Rare: red +8 STR / +8 AGI / +9 SP / +18 HEAL(+6 SP); yellow +8 crit / +8 INT / +8 def; blue +12 STA / +3 MP5.
W.GEMS = {
  melee = {
    uncommon = { R = { STR = 6 }, Y = { CRIT = 6 }, B = { STA = 9 }, M = {} },
    rare = { R = { STR = 8 }, Y = { CRIT = 8 }, B = { STA = 12 }, M = {} },
  },
  ranged = {
    uncommon = { R = { AGI = 6 }, Y = { CRIT = 6 }, B = { STA = 9 }, M = {} },
    rare = { R = { AGI = 8 }, Y = { CRIT = 8 }, B = { STA = 12 }, M = {} },
  },
  tank = {
    uncommon = { R = { STR = 6 }, Y = { DEF = 6 }, B = { STA = 9 }, M = {} },
    rare = { R = { AGI = 8 }, Y = { DEF = 8 }, B = { STA = 12 }, M = {} },
  },
  caster = {
    uncommon = { R = { SP = 7 }, Y = { INT = 6 }, B = { STA = 9 }, M = {} },
    rare = { R = { SP = 9 }, Y = { SPCRIT = 8 }, B = { STA = 12 }, M = {} },
  },
  healer = {
    uncommon = { R = { HEAL = 13, SP = 4 }, Y = { INT = 6 }, B = { MP5 = 2 }, M = {} },
    rare = { R = { HEAL = 18, SP = 6 }, Y = { INT = 8 }, B = { MP5 = 3 }, M = {} },
  },
}
function W.DefaultGem(classToken, specKey, level, color)
  local spec = W.DEFAULTS[classToken] and W.DEFAULTS[classToken][specKey]
  local role = spec and spec.role or "melee"
  local tier = level >= 70 and "rare" or "uncommon"
  local byRole = W.GEMS[role] or W.GEMS.melee or {}
  local byTier = byRole[tier] or {}
  return byTier[color] or {}
end

-- Socket bonus enchantment id -> stats table. Best-effort assignment inferred from the set of items
-- that share each enchantment id in the TBC item database (an id is one bonus text, so a mix of caster
-- and melee items means a role-neutral bonus such as stamina or hit). Unknown ids return nil and the
-- addon estimates them. Ratings are raw rating points (the addon converts). Verify in game.
W.SOCKET_BONUS = {
  [2889] = { SP = 5, HEAL = 5 },      -- +5 Spell Damage: Aran's Sorcerous Slacks, Robes of the Aldor, Cyclone Faceguard
  [2890] = { SP = 4, HEAL = 4 },      -- +4 Spell Damage: Incanter's Cowl, Hallowed Crown, Kilt of the Night Strider
  [2880] = { SP = 3, HEAL = 3 },      -- +3 Spell Damage: Frozen Shadoweave set, Spaulders of Oblivion, Mindfire Waistband
  [2875] = { SPCRIT = 2 },            -- +2 Spell Crit Rating: Battlecast Pants, Netherfury Belt, Anger-Spark Gloves
  [2872] = { SP = 5, HEAL = 5 },      -- +5 Spell Damage: Vest of Living Lightning, Vestments of the Avatar, Pontifex Kilt
  [2866] = { HEAL = 9, SP = 3 },      -- +9 Healing: Mitts of the Treemender, Hands of Eternal Light, Cord of Reconstruction
  [3097] = { HEAL = 7, SP = 2 },      -- +7 Healing: Wand of Cleansing Light, Thunderheart Belt, Slippers of Dutiful Mending
  [3098] = { HEAL = 9, SP = 3 },      -- +9 Healing: Bracers of Martyrdom, Belt of Absolution, Thunderheart Legguards
  [2895] = { HIT = 3, SPHIT = 3 },    -- +3 Hit Rating: Spellfire set, Netherblade Shoulderpads, Felstalker Belt, Beast Lord Mantle
  [2925] = { HIT = 2, SPHIT = 2 },    -- +2 Hit Rating: True-Aim Stalker Bands, Felstalker Bracers, Fool's Bane
  [2859] = { STA = 3 },               -- +3 Stamina: Gladiator's shoulders (cloth/leather/mail), Mana-Etched Gloves, Slippers of Serenity
  [2878] = { STA = 4 },               -- +4 Stamina: Gladiator's helms, Durotan's Battle Harness, Wastewalker Leggings
  [2874] = { STA = 4 },               -- +4 Stamina: Gladiator's chests (plate/leather/linked), Moonglade Robe, Breastplate of Kings
  [2867] = { STA = 3 },               -- +3 Stamina: General's/Marshal's bracers, Slayer's Leggings, Hierophant's Leggings
  [2951] = { RES = 4 },               -- +4 Resilience: Gladiator's Silk Raiment, Mail Armor, Lamellar Chestpiece (PvP chests)
  [2856] = { RES = 4 },               -- +4 Resilience: Gladiator's Dreadweave/Satin/Wyrmhide robes (PvP chests)
  [2953] = { RES = 2 },               -- +2 Resilience: PvP cloth cuffs (General's/Marshal's/Veteran's/Vindicator's)
  [3164] = { RES = 2 },               -- +2 Resilience: Veteran's/Vindicator's pendants
  [2879] = { AP = 4 },                -- +4 Attack Power: Gauntlets of the Iron Tower, Warbringer Shoulderplates, Nordrassil Feral-Mantle
  [2936] = { AGI = 4 },               -- +4 Agility: Demon Stalker Harness, Deathmantle Helm, Wastewalker Helm, Blade of the Unrequited
  [2927] = { STR = 4 },               -- +4 Strength: Gladiator's Plate Helm, Destroyer Breastplate, Warhelm of the Bold
  [2873] = { STA = 4 },               -- +4 Stamina: Felsteel Helm, Enchanted Adamantite Breastplate, Warbringer Battle-Helm
  [2871] = { STA = 4 },               -- +4 Stamina: Felsteel Leggings, Heavy Clefthoof Vest/Leggings, Eternium Greathelm
  [2870] = { STR = 3 },               -- +3 Strength: Flamebane Gloves, Felsteel Gloves, Ironblade Gauntlets, Fanblade Pauldrons
  [2860] = { CRIT = 3 },              -- +3 Crit Rating: Felfury Gauntlets, Deft Handguards, Beast Lord Handguards, Edgewalker Longboots
  [2902] = { AGI = 3 },               -- +3 Agility: Rift Stalker Leggings, Bracers of the Pathfinder, Gronnstalker's Gloves
  [3149] = { AGI = 4 },               -- +4 Agility: Gronnstalker's Leggings, Nordrassil Feral-Kilt, Cataclysm Legplates
  [2887] = { STR = 3 },               -- +3 Strength: Steelgrip Gauntlets, Warchief's Mantle, Red Belt of Battle, Girdle of the Endless Pit
  [2952] = { STA = 6 },               -- +6 Stamina: Hauberk of Desolation, Doomplate Chestguard, Warbringer Breastplate
  [2861] = { DEF = 3 },               -- +3 Defense Rating: Ironsole Clompers, Spaulders of the Righteous, Boots of the Colossus
  [2892] = { DODGE = 3 },             -- +3 Dodge Rating: Helm of the Stalwart Defender, Circle's Stalwart Helmet
  [2932] = { DEF = 4 },               -- +4 Defense Rating: Breastplate of the Bold, Justicar Chestguard, Crystalforge Chestguard
  [2863] = { INT = 3 },               -- +3 Intellect: Soulcloth Gloves/Shoulders, Primal Mooncloth Belt/Robe, Hallowed Pauldrons
  [2974] = { INT = 4 },               -- +4 Intellect: Gloves of Saintly Blessings, Mantle of the Avatar, Lightbringer Pauldrons
  [2864] = { HEAL = 9, SP = 3 },      -- +9 Healing: Robes of the Augurer, Auchenai Anchorite's Robe, Nordrassil Chestpiece
  [2868] = { SP = 4, HEAL = 4 },      -- +4 Spell Damage: Spellstrike Hood, Voidheart Robe, Raiments of Divine Authority
  [2882] = { STA = 4 },               -- +4 Stamina: Storm Helm, Spellstrike Pants, Tankatronic Goggles, Cenarion Thicket set
  [1584] = { STA = 3 },               -- +3 Stamina: Fel Leather Gloves/Boots, Enchanted Felscale Gloves/Boots, Blastguard Boots
  [1585] = { STA = 4 },               -- +4 Stamina: Adamantite Breastplate, Fel Leather Leggings, Blastguard Pants
}
function W.SocketBonus(enchantId)
  return W.SOCKET_BONUS[enchantId]
end
