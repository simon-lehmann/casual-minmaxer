-- Character snapshot: class, level, faction, race, spec, professions, equipped items, completed quests.
local _, CMM = ...
local P = CMM.Player
local C = CMM.Constants
local Compat = CMM.Compat

local snapshot
local questCache = {}

-- Spec key from talent tabs: the tab with most points, mapped through Weights.Specs tabIndex.
-- Falls back to the first spec of the class (or the tab name upper-cased) when no points are spent.
function P.DetectSpec(classToken)
  local tabs = Compat.TalentTabs()
  local bestIdx, bestPts = 1, -1
  for i, t in ipairs(tabs) do
    if t.points > bestPts then bestIdx, bestPts = i, t.points end
  end
  local specs = CMM.Weights.Specs(classToken)
  for _, s in ipairs(specs) do
    if s.tabIndex == bestIdx then return s.key end
  end
  if specs[1] then return specs[1].key end
  local name = tabs[bestIdx] and tabs[bestIdx].name
  return name and name:upper():gsub("%s+", "") or "DEFAULT"
end

local function equipped()
  local out = {}
  for slotKey, ids in pairs(C.EQUIP_SLOTS) do
    if #ids == 1 then
      out[slotKey] = Compat.InventoryItemID(ids[1])
    else
      out[slotKey] = { Compat.InventoryItemID(ids[1]), Compat.InventoryItemID(ids[2]) }
    end
  end
  return out
end

function P.Refresh()
  local className, classToken, classId = UnitClass("player")
  local level = UnitLevel("player") or 1
  local faction = UnitFactionGroup("player")
  local raceName, raceToken = UnitRace("player")
  local charDB = _G.CasualMinMaxerCharDB
  local spec = (charDB and charDB.specOverride) or P.DetectSpec(classToken)
  local usable = { armor = {}, weapon = {} }
  local u = C.USABLE[classToken]
  if u then
    for sub in pairs(u.armor) do usable.armor[sub] = C.CanUseArmor(classToken, sub, level) end
    for sub in pairs(u.weapon) do usable.weapon[sub] = true end
  end
  snapshot = {
    class = classToken,
    className = className,
    classId = classId or C.CLASS_ID[classToken],
    classMask = C.CLASS_MASK[classToken] or 0,
    level = level,
    faction = faction,
    factionMask = faction == "Horde" and C.HORDE_MASK or C.ALLIANCE_MASK,
    race = raceName,
    raceToken = raceToken,
    raceMask = C.RACE_MASK[raceToken] or 0,
    spec = spec,
    specDetected = P.DetectSpec(classToken),
    professions = Compat.Professions(),
    equipped = equipped(),
    zoneName = Compat.ZoneName(),
    canDualWield = C.CanDualWield(classToken, spec, level),
    usable = usable,
    name = UnitName and UnitName("player") or "",
  }
  questCache = {}
  return snapshot
end

function P.Get()
  return snapshot or P.Refresh()
end

function P.QuestDone(questId)
  local v = questCache[questId]
  if v == nil then
    v = Compat.IsQuestCompleted(questId)
    questCache[questId] = v
  end
  return v
end

function P.InvalidateQuests()
  questCache = {}
end

-- Equipped item id(s) for a slot key: id or {id1, id2} for rings/trinkets
function P.Equipped(slotKey)
  local s = P.Get()
  return s.equipped[slotKey]
end

-- True if the item id is currently equipped in any slot.
function P.IsEquipped(itemId)
  local s = P.Get()
  for _, v in pairs(s.equipped) do
    if type(v) == "table" then
      if v[1] == itemId or v[2] == itemId then return true end
    elseif v == itemId then return true end
  end
  return false
end
