-- Pawn scale string import / export.
-- Pawn rating weights are per rating point; ours are per 1 %, so Import needs the character level.
local _, CMM = ...
local P = CMM.Pawn
local C = CMM.Constants
local Ratings = CMM.Ratings

P.NAME_TO_KEY = {
  Strength = "STR", Agility = "AGI", Stamina = "STA", Intellect = "INT", Spirit = "SPI", Armor = "ARMOR",
  Ap = "AP", AttackPower = "AP", Rap = "RAP", RangedAttackPower = "RAP", FeralAp = "FAP",
  SpellDamage = "SP", SpellPower = "SP", Healing = "HEAL", SpellHealing = "HEAL", Mp5 = "MP5", Hp5 = "HP5",
  HitRating = "HIT", SpellHitRating = "SPHIT", CritRating = "CRIT", SpellCritRating = "SPCRIT",
  HasteRating = "HASTE", SpellHasteRating = "SPHASTE", ExpertiseRating = "EXP", DefenseRating = "DEF",
  DodgeRating = "DODGE", ParryRating = "PARRY", BlockRating = "BLOCK", BlockValue = "BLOCKV",
  ResilienceRating = "RES", ArmorPenetration = "ARP", ArmorPenetrationRating = "ARP", Dps = "DPS",
  RangedDps = "RDPS", MeleeDps = "DPS",
  FireSpellDamage = "SPFIRE", FrostSpellDamage = "SPFROST", ShadowSpellDamage = "SPSHADOW",
  NatureSpellDamage = "SPNATURE", ArcaneSpellDamage = "SPARCANE", HolySpellDamage = "SPHOLY",
}
P.KEY_TO_NAME = {}
for name, key in pairs(P.NAME_TO_KEY) do
  if not P.KEY_TO_NAME[key] then P.KEY_TO_NAME[key] = name end
end
-- prefer the canonical Pawn names for export
P.KEY_TO_NAME.AP = "Ap"; P.KEY_TO_NAME.RAP = "Rap"; P.KEY_TO_NAME.SP = "SpellDamage"; P.KEY_TO_NAME.HEAL = "Healing"
P.KEY_TO_NAME.ARP = "ArmorPenetration"; P.KEY_TO_NAME.DPS = "Dps"

-- Parses `( Pawn: v1: "Name": Stamina=1, CritRating=0.6, ... )`. Returns weights (per 1 % for ratings), name.
function P.Import(str, level)
  if type(str) ~= "string" then return nil, "not a string" end
  level = level or 70
  local body = str:match("%(%s*Pawn%s*:%s*v%d+%s*:%s*(.-)%s*%)%s*$")
  if not body then return nil, "not a Pawn string" end
  local name, rest = body:match('^"(.-)"%s*:%s*(.*)$')
  if not name then name, rest = body:match("^([^:]-)%s*:%s*(.*)$") end
  if not rest then return nil, "missing scale values" end
  local weights, count = {}, 0
  for stat, value in rest:gmatch("([%w_]+)%s*=%s*(-?[%d%.]+)") do
    local key = P.NAME_TO_KEY[stat]
    local v = tonumber(value)
    if key and v then
      if C.RATING_KEYS[key] then v = v * Ratings.PerPercent(key, level) end
      weights[key] = (weights[key] or 0) + v
      count = count + 1
    end
  end
  if count == 0 then return nil, "no known stats" end
  return weights, name
end

-- Exports weights as a Pawn string (ratings converted back to per-point at `level`).
function P.Export(weights, name, level)
  level = level or 70
  local parts = {}
  local keys = {}
  for key, w in pairs(weights or {}) do
    if P.KEY_TO_NAME[key] and w and w ~= 0 then keys[#keys + 1] = key end
  end
  table.sort(keys)
  for _, key in ipairs(keys) do
    local w = weights[key]
    if C.RATING_KEYS[key] then w = w / Ratings.PerPercent(key, level) end
    parts[#parts + 1] = string.format("%s=%s", P.KEY_TO_NAME[key], string.format("%.4g", w))
  end
  return string.format('( Pawn: v1: "%s": %s )', name or "Casual MinMaxer", table.concat(parts, ", "))
end
