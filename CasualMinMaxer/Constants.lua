-- Slot keys, inventory-type map, stat keys, tier constants, class usability tables.
-- Everything here mirrors docs/ARCHITECTURE.md §2, §3 and §6.
local _, CMM = ...
local C = CMM.Constants

C.SLOT_KEYS = {
  "HEAD", "NECK", "SHOULDER", "BACK", "CHEST", "WRIST", "HANDS", "WAIST", "LEGS", "FEET",
  "FINGER", "TRINKET", "MAINHAND", "OFFHAND", "RANGED",
}
C.SLOT_INDEX = {}
for i, k in ipairs(C.SLOT_KEYS) do C.SLOT_INDEX[k] = i end

-- InventoryType -> primary slot key. 13 (one-hand) also feeds OFFHAND for dual wielders (Data index).
C.INV_TO_SLOT = {
  [1] = "HEAD", [2] = "NECK", [3] = "SHOULDER", [5] = "CHEST", [20] = "CHEST", [6] = "WAIST",
  [7] = "LEGS", [8] = "FEET", [9] = "WRIST", [10] = "HANDS", [16] = "BACK",
  [11] = "FINGER", [12] = "TRINKET",
  [13] = "MAINHAND", [17] = "MAINHAND", [21] = "MAINHAND",
  [22] = "OFFHAND", [14] = "OFFHAND", [23] = "OFFHAND",
  [15] = "RANGED", [25] = "RANGED", [26] = "RANGED", [28] = "RANGED",
}
C.INV_ONE_HAND, C.INV_TWO_HAND, C.INV_MAIN_HAND, C.INV_OFF_WEAPON = 13, 17, 21, 22
C.INV_SHIELD, C.INV_HELD = 14, 23

-- Equipment slot ids (GetInventoryItemID) per slot key; FINGER/TRINKET have two.
C.EQUIP_SLOTS = {
  HEAD = { 1 }, NECK = { 2 }, SHOULDER = { 3 }, CHEST = { 5 }, WAIST = { 6 }, LEGS = { 7 }, FEET = { 8 },
  WRIST = { 9 }, HANDS = { 10 }, FINGER = { 11, 12 }, TRINKET = { 13, 14 }, BACK = { 15 },
  MAINHAND = { 16 }, OFFHAND = { 17 }, RANGED = { 18 },
}

C.STAT_KEYS = {
  "STR", "AGI", "STA", "INT", "SPI", "ARMOR", "AP", "RAP", "FAP",
  "SP", "SPFIRE", "SPFROST", "SPSHADOW", "SPNATURE", "SPARCANE", "SPHOLY", "HEAL", "MP5", "HP5",
  "BLOCKV", "ARP",
  "HIT", "SPHIT", "CRIT", "SPCRIT", "HASTE", "SPHASTE", "EXP", "DEF", "DODGE", "PARRY", "BLOCK", "RES",
  "DPS", "SPEED", "RDPS",
}
C.STAT_SET = {}
for _, k in ipairs(C.STAT_KEYS) do C.STAT_SET[k] = true end

C.RATING_KEYS = {
  HIT = true, SPHIT = true, CRIT = true, SPCRIT = true, HASTE = true, SPHASTE = true, EXP = true,
  DEF = true, DODGE = true, PARRY = true, BLOCK = true, RES = true,
}
C.PRIMARY_KEYS = { STR = true, AGI = true, STA = true, INT = true, SPI = true }

-- Item record flags (§4.1)
C.FLAG_UNIQUE, C.FLAG_BOE, C.FLAG_BOP, C.FLAG_SET, C.FLAG_SPECIAL, C.FLAG_HEROIC = 1, 2, 4, 8, 16, 32
C.FLAG_ALLIANCE, C.FLAG_HORDE = 64, 128

-- Tunable obtainability constants (§6.5); DB.constants may override any of these.
C.TIER = {
  minutesPerQuest = 10, groupOverhead = 15, travel = 15, trashRun = 45, vendorWalk = 5,
  craftOwn = 20, craftOther = 30, lotteryBelowPct = 15, namedMinutes = 30, rareMinutes = 30,
  badgeGrind = 180, honorGrind = 240, arenaGrind = 900, repPerRank = 180,
}

-- Source-type filter key for a decoded source: vendors are split by currency (§6.4).
-- V gold, E badges, H honor / PvP tokens, A arena, F reputation; every other code is its own key.
C.SOURCE_FILTER_KEYS = { "Q", "B", "R", "N", "T", "G", "V", "E", "H", "A", "F", "K", "W" }
function C.SourceFilterKey(src)
  if src.t == "V" then
    local m = src.mode
    if m == "E" or m == "H" or m == "A" or m == "F" then return m end
    return "V"
  end
  return src.t
end
function C.DefaultSourceFilters()
  local out = {}
  for _, k in ipairs(C.SOURCE_FILTER_KEYS) do out[k] = (k ~= "W" and k ~= "A") end
  return out
end
-- Item RequiredReputationRank (4 friendly .. 7 exalted) -> client standingId (5 friendly .. 8 exalted)
C.REP_RANK_NAMES = { [4] = "Friendly", [5] = "Honored", [6] = "Revered", [7] = "Exalted" }
C.REP_STANDING_NEUTRAL = 4

C.TIER_NAMES = { [1] = "Guaranteed, solo", [2] = "Guaranteed, group", [3] = "Farmable drop", [4] = "Lottery drop", [5] = "Buyable" }

-- Quest types (quest_template.Type)
C.QUEST_NORMAL, C.QUEST_GROUP, C.QUEST_PVP, C.QUEST_RAID, C.QUEST_DUNGEON, C.QUEST_HEROIC = 0, 1, 41, 62, 81, 85
C.QUEST_GROUP_TYPES = { [1] = true, [81] = true, [85] = true }

-- Source codes in best-first display order
C.SOURCE_CODES = { "Q", "K", "V", "B", "G", "R", "N", "T", "W" }
C.SOURCE_NAMES = {
  Q = "Quest", K = "Crafted", V = "Vendor", B = "Boss drop", G = "Chest", R = "Rare spawn",
  N = "Mob drop", T = "Dungeon trash", W = "World drop",
}

-- Profession skill lines
C.SKILL_LINES = {
  [171] = "Alchemy", [164] = "Blacksmithing", [333] = "Enchanting", [202] = "Engineering",
  [165] = "Leatherworking", [197] = "Tailoring", [755] = "Jewelcrafting", [186] = "Mining",
  [182] = "Herbalism", [393] = "Skinning", [185] = "Cooking", [129] = "First Aid", [356] = "Fishing",
}
C.SKILL_LINE_BY_NAME = {}
for id, name in pairs(C.SKILL_LINES) do C.SKILL_LINE_BY_NAME[name] = id end
-- localized skill names are mapped by Compat when possible; German names as a courtesy
C.SKILL_LINE_BY_NAME["Alchimie"] = 171
C.SKILL_LINE_BY_NAME["Schmiedekunst"] = 164
C.SKILL_LINE_BY_NAME["Verzauberkunst"] = 333
C.SKILL_LINE_BY_NAME["Ingenieurskunst"] = 202
C.SKILL_LINE_BY_NAME["Lederverarbeitung"] = 165
C.SKILL_LINE_BY_NAME["Schneiderei"] = 197
C.SKILL_LINE_BY_NAME["Juwelenschleifen"] = 755
-- other client locales (profession skill-line names as shown by GetSkillLineInfo)
local LOCALIZED_SKILLS = {
  -- frFR
  { "Alchimie", 171 }, { "Forge", 164 }, { "Enchantement", 333 }, { "Ingénierie", 202 }, { "Travail du cuir", 165 },
  { "Couture", 197 }, { "Joaillerie", 755 },
  -- esES / esMX
  { "Alquimia", 171 }, { "Herrería", 164 }, { "Encantamiento", 333 }, { "Ingeniería", 202 }, { "Peletería", 165 },
  { "Sastrería", 197 }, { "Joyería", 755 },
  -- ptBR
  { "Alquimia", 171 }, { "Ferraria", 164 }, { "Encantamento", 333 }, { "Engenharia", 202 }, { "Couraria", 165 },
  { "Alfaiataria", 197 }, { "Joalheria", 755 },
  -- ruRU
  { "Алхимия", 171 }, { "Кузнечное дело", 164 }, { "Наложение чар", 333 }, { "Инженерное дело", 202 },
  { "Кожевничество", 165 }, { "Портняжное дело", 197 }, { "Ювелирное дело", 755 },
  -- koKR
  { "연금술", 171 }, { "대장기술", 164 }, { "마법부여", 333 }, { "기계공학", 202 }, { "가죽세공", 165 }, { "재봉술", 197 }, { "보석세공", 755 },
  -- zhCN
  { "炼金术", 171 }, { "锻造", 164 }, { "附魔", 333 }, { "工程学", 202 }, { "制皮", 165 }, { "裁缝", 197 }, { "珠宝加工", 755 },
  -- zhTW
  { "鍊金術", 171 }, { "鍛造", 164 }, { "附魔", 333 }, { "工程學", 202 }, { "製皮", 165 }, { "裁縫", 197 }, { "珠寶設計", 755 },
}
for _, e in ipairs(LOCALIZED_SKILLS) do C.SKILL_LINE_BY_NAME[e[1]] = e[2] end

-- Class bit masks (AllowableClass / quest RequiredClasses)
C.CLASS_MASK = {
  WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, SHAMAN = 64, MAGE = 128, WARLOCK = 256, DRUID = 1024,
}
C.CLASS_ID = { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11 }
C.ALL_CLASSES_MASK = 1535

-- Race bit masks (AllowableRace / quest RequiredRaces)
C.RACE_MASK = {
  Human = 1, Orc = 2, Dwarf = 4, NightElf = 8, Scourge = 16, Tauren = 32, Gnome = 64, Troll = 128,
  BloodElf = 512, Draenei = 1024,
}
C.ALLIANCE_MASK, C.HORDE_MASK = 1101, 690

-- Armor subclasses
C.ARMOR_MISC, C.ARMOR_CLOTH, C.ARMOR_LEATHER, C.ARMOR_MAIL, C.ARMOR_PLATE, C.ARMOR_SHIELD = 0, 1, 2, 3, 4, 6
C.ARMOR_LIBRAM, C.ARMOR_IDOL, C.ARMOR_TOTEM = 7, 8, 9
-- Weapon subclasses
C.W_AXE, C.W_AXE2H, C.W_BOW, C.W_GUN, C.W_MACE, C.W_MACE2H, C.W_POLEARM, C.W_SWORD, C.W_SWORD2H = 0, 1, 2, 3, 4, 5, 6, 7, 8
C.W_STAFF, C.W_FIST, C.W_DAGGER, C.W_THROWN, C.W_CROSSBOW, C.W_WAND = 10, 13, 15, 16, 18, 19
C.RANGED_WEAPON_SUBS = { [2] = true, [3] = true, [16] = true, [18] = true }

local function set(list) local t = {} for _, v in ipairs(list) do t[v] = true end return t end

-- What each class can equip. armorAt40: classes that upgrade their armor class at level 40.
-- armor subclass 0 (misc: cloaks, rings, trinkets, necks, held items) is always usable.
C.USABLE = {
  WARRIOR = { armor = set({ 0, 1, 2, 3, 4, 6 }), weapon = set({ 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18 }), bestArmor = { 3, 4 } },
  PALADIN = { armor = set({ 0, 1, 2, 3, 4, 6, 7 }), weapon = set({ 0, 1, 4, 5, 6, 7, 8 }), bestArmor = { 3, 4 } },
  HUNTER = { armor = set({ 0, 1, 2, 3 }), weapon = set({ 0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18 }), bestArmor = { 2, 3 } },
  ROGUE = { armor = set({ 0, 1, 2 }), weapon = set({ 2, 3, 4, 7, 13, 15, 16, 18 }), bestArmor = { 2, 2 } },
  PRIEST = { armor = set({ 0, 1 }), weapon = set({ 4, 10, 15, 19 }), bestArmor = { 1, 1 } },
  SHAMAN = { armor = set({ 0, 1, 2, 3, 6, 9 }), weapon = set({ 0, 1, 4, 5, 10, 13, 15 }), bestArmor = { 2, 3 } },
  MAGE = { armor = set({ 0, 1 }), weapon = set({ 7, 10, 15, 19 }), bestArmor = { 1, 1 } },
  WARLOCK = { armor = set({ 0, 1 }), weapon = set({ 7, 10, 15, 19 }), bestArmor = { 1, 1 } },
  DRUID = { armor = set({ 0, 1, 2, 8 }), weapon = set({ 4, 5, 10, 13, 15 }), bestArmor = { 2, 2 } },
}

-- Best usable armor subclass at a level (bestArmor = { below 40, at 40+ })
function C.BestArmor(classToken, level)
  local u = C.USABLE[classToken]
  if not u then return C.ARMOR_CLOTH end
  return level >= 40 and u.bestArmor[2] or u.bestArmor[1]
end

-- Can the class equip an armor subclass at this level (mail/plate unlock at 40 for the upgrading classes)?
function C.CanUseArmor(classToken, sub, level)
  local u = C.USABLE[classToken]
  if not u or not u.armor[sub] then return false end
  if sub == C.ARMOR_MAIL and (classToken == "HUNTER" or classToken == "SHAMAN") and level < 40 then return false end
  if sub == C.ARMOR_PLATE and (classToken == "WARRIOR" or classToken == "PALADIN") and level < 40 then return false end
  return true
end

function C.CanUseWeapon(classToken, sub)
  local u = C.USABLE[classToken]
  return u ~= nil and u.weapon[sub] == true
end

-- Dual wield: rogues always, warriors and hunters from 20, enhancement shamans (talent).
function C.CanDualWield(classToken, specKey, level)
  if classToken == "ROGUE" then return true end
  if classToken == "WARRIOR" or classToken == "HUNTER" then return level >= 20 end
  if classToken == "SHAMAN" then return specKey == "ENHANCEMENT" end
  return false
end

-- Slot key aliases for /cmm <slot>
C.SLOT_ALIASES = {
  head = "HEAD", helm = "HEAD", neck = "NECK", shoulder = "SHOULDER", shoulders = "SHOULDER", back = "BACK",
  cloak = "BACK", chest = "CHEST", wrist = "WRIST", bracers = "WRIST", hands = "HANDS", gloves = "HANDS",
  waist = "WAIST", belt = "WAIST", legs = "LEGS", feet = "FEET", boots = "FEET", finger = "FINGER",
  ring = "FINGER", rings = "FINGER", trinket = "TRINKET", trinkets = "TRINKET", mainhand = "MAINHAND",
  mh = "MAINHAND", weapon = "MAINHAND", offhand = "OFFHAND", oh = "OFFHAND", shield = "OFFHAND",
  ranged = "RANGED", bow = "RANGED", gun = "RANGED", wand = "RANGED", relic = "RANGED",
}
