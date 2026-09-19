-- Item scoring: weighted stat sum with rating conversion, sockets, specials, weapon DPS/speed and
-- slot-pair logic (docs/ARCHITECTURE.md §6.2, §6.3).
local _, CMM = ...
local S = CMM.Scoring
local C = CMM.Constants
local Ratings = CMM.Ratings

local BASELINE_SPEED = 2.4

-- ITEM_MOD_* keys (GetItemStats) -> canonical stat keys. Used for equipped items missing from the
-- data pack and by Validate.
S.STAT_MOD_MAP = {
  ITEM_MOD_STRENGTH_SHORT = "STR", ITEM_MOD_AGILITY_SHORT = "AGI", ITEM_MOD_STAMINA_SHORT = "STA",
  ITEM_MOD_INTELLECT_SHORT = "INT", ITEM_MOD_SPIRIT_SHORT = "SPI", RESISTANCE0_NAME = "ARMOR",
  ITEM_MOD_ATTACK_POWER_SHORT = "AP", ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "RAP",
  ITEM_MOD_FERAL_ATTACK_POWER_SHORT = "FAP", ITEM_MOD_SPELL_POWER_SHORT = "SP",
  ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "SP", ITEM_MOD_SPELL_HEALING_DONE_SHORT = "HEAL",
  ITEM_MOD_MANA_REGENERATION_SHORT = "MP5", ITEM_MOD_HEALTH_REGENERATION_SHORT = "HP5",
  ITEM_MOD_HEALTH_REGEN_SHORT = "HP5", ITEM_MOD_BLOCK_VALUE_SHORT = "BLOCKV",
  ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "ARP",
  ITEM_MOD_HIT_RATING_SHORT = "HIT", ITEM_MOD_HIT_MELEE_RATING_SHORT = "HIT", ITEM_MOD_HIT_RANGED_RATING_SHORT = "HIT",
  ITEM_MOD_HIT_SPELL_RATING_SHORT = "SPHIT",
  ITEM_MOD_CRIT_RATING_SHORT = "CRIT", ITEM_MOD_CRIT_MELEE_RATING_SHORT = "CRIT", ITEM_MOD_CRIT_RANGED_RATING_SHORT = "CRIT",
  ITEM_MOD_CRIT_SPELL_RATING_SHORT = "SPCRIT",
  ITEM_MOD_HASTE_RATING_SHORT = "HASTE", ITEM_MOD_HASTE_MELEE_RATING_SHORT = "HASTE", ITEM_MOD_HASTE_RANGED_RATING_SHORT = "HASTE",
  ITEM_MOD_HASTE_SPELL_RATING_SHORT = "SPHASTE",
  ITEM_MOD_EXPERTISE_RATING_SHORT = "EXP", ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "DEF",
  ITEM_MOD_DODGE_RATING_SHORT = "DODGE", ITEM_MOD_PARRY_RATING_SHORT = "PARRY", ITEM_MOD_BLOCK_RATING_SHORT = "BLOCK",
  ITEM_MOD_RESILIENCE_RATING_SHORT = "RES",
  ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "DPS",
  ITEM_MOD_FIRE_SPELL_POWER_SHORT = "SPFIRE", ITEM_MOD_FROST_SPELL_POWER_SHORT = "SPFROST",
  ITEM_MOD_SHADOW_SPELL_POWER_SHORT = "SPSHADOW", ITEM_MOD_NATURE_SPELL_POWER_SHORT = "SPNATURE",
  ITEM_MOD_ARCANE_SPELL_POWER_SHORT = "SPARCANE", ITEM_MOD_HOLY_SPELL_POWER_SHORT = "SPHOLY",
}

-- Convert a GetItemStats table into canonical stats.
function S.FromItemStats(mods)
  local stats = {}
  if not mods then return stats end
  for k, v in pairs(mods) do
    local key = S.STAT_MOD_MAP[k]
    if key and type(v) == "number" and v ~= 0 then stats[key] = (stats[key] or 0) + v end
  end
  return stats
end

-- Effective value of one stat at a level (ratings -> percent).
function S.Effective(key, value, level)
  if C.RATING_KEYS[key] then return Ratings.ToPercent(key, value, level) end
  return value
end

-- Σ w[key] × v[key]. SPEED is not scored here (see ScoreWeapon); DPS/RDPS are plain stats.
function S.ScoreStats(stats, weights, level)
  local total = 0
  if not stats or not weights then return 0 end
  for key, value in pairs(stats) do
    if key ~= "SPEED" and C.STAT_SET[key] then
      local w = weights[key]
      if w and w ~= 0 then total = total + w * S.Effective(key, value, level) end
    end
  end
  return total
end

-- Weapon-specific contribution: DPS weight depends on the slot (off-hand uses DPS_OH) and the speed preference.
local function weaponScore(item, ctx)
  local w = ctx.weights
  local stats = item.stats
  local total = 0
  local offhand = ctx.slotKey == "OFFHAND"
  if stats.DPS then
    local wd = offhand and (w.DPS_OH or 0) or (w.DPS or 0)
    local pref = offhand and (w.SPEEDPREF_OH or 0) or (w.SPEEDPREF or 0)
    total = total + wd * stats.DPS
    if stats.SPEED and pref ~= 0 then
      total = total + pref * (stats.SPEED - BASELINE_SPEED) * wd * 2
    end
  end
  if stats.RDPS then total = total + (w.RDPS or 0) * stats.RDPS end
  return total
end

local function highestPrimaryWeight(weights)
  local best = 0
  for k in pairs(C.PRIMARY_KEYS) do
    local w = weights[k] or 0
    if w > best then best = w end
  end
  return best
end

-- Socket contribution: default gem per colored socket; socket bonus if every non-meta socket got a gem.
function S.SocketScore(item, ctx)
  if not item.sockets or item.sockets == "" then return 0 end
  local total, allMatched, colored = 0, true, 0
  for i = 1, #item.sockets do
    local color = item.sockets:sub(i, i)
    if color ~= "M" then
      colored = colored + 1
      local gem = CMM.Weights.DefaultGem(ctx.class, ctx.spec, ctx.level, color)
      local gemScore = S.ScoreStats(gem, ctx.weights, ctx.level)
      if gemScore <= 0 then allMatched = false end
      total = total + gemScore
    end
  end
  if colored > 0 and allMatched and item.sbonus and item.sbonus > 0 then
    local bonus = CMM.Weights.SocketBonus(item.sbonus)
    if bonus then
      total = total + S.ScoreStats(bonus, ctx.weights, ctx.level)
    else
      total = total + 3 * highestPrimaryWeight(ctx.weights)
    end
  end
  return total
end

-- Full item score in a context { level, weights, class, spec, slotKey }.
function S.ScoreItem(item, ctx)
  if not item then return 0 end
  local w = ctx.weights or {}
  local total = 0
  for key, value in pairs(item.stats) do
    if key ~= "SPEED" and key ~= "DPS" and key ~= "RDPS" then
      local wk = w[key]
      if wk and wk ~= 0 then total = total + wk * S.Effective(key, value, ctx.level) end
    end
  end
  total = total + weaponScore(item, ctx)
  local special = item.special or CMM.Specials.Get(item.id)
  if special then total = total + S.ScoreStats(special, w, ctx.level) end
  total = total + S.SocketScore(item, ctx)
  return total
end

-- Score an equipped item id: data pack first, client GetItemStats (full link, so random-suffix stats
-- count) plus tooltip-scanned equip effects as fallback.
function S.ScoreEquippedId(id, slotKey, ctx, link)
  if not id then return 0, nil end
  local item = CMM.Data.Item(id)
  if item then
    local c = ctx
    if ctx.slotKey ~= slotKey then
      c = {}
      for k, v in pairs(ctx) do c[k] = v end
      c.slotKey = slotKey
    end
    return S.ScoreItem(item, c), item
  end
  local stats = CMM.Compat.ItemStatsFromClient(link or ("item:" .. id))
  if not stats then return 0, nil end
  local pseudo = { id = id, stats = stats, sockets = "", sbonus = 0, flags = 0, src = {} }
  local c = {}
  for k, v in pairs(ctx) do c[k] = v end
  c.slotKey = slotKey
  return S.ScoreItem(pseudo, c), pseudo, link
end

local function isTwoHand(item)
  return item ~= nil and item.inv == C.INV_TWO_HAND
end

-- Equipped score for a slot. Rings/trinkets: the weaker of the two. MAINHAND with a 2H equipped:
-- the 2H's score. Returns score, itemId (the item the candidate would replace).
function S.EquippedScore(slotKey, ctx, player)
  local eq = player.equipped[slotKey]
  local links = player.equippedLinks and player.equippedLinks[slotKey]
  if slotKey == "FINGER" or slotKey == "TRINKET" then
    local a, b = eq and eq[1], eq and eq[2]
    local sa = S.ScoreEquippedId(a, slotKey, ctx, links and links[1])
    local sb = S.ScoreEquippedId(b, slotKey, ctx, links and links[2])
    if a and b then
      if sb < sa then return sb, b end
      return sa, a
    end
    if a then return 0, nil end -- second slot empty: any usable ring is a gain over nothing
    if b then return 0, nil end
    return 0, nil
  end
  local score, item = S.ScoreEquippedId(eq, slotKey, ctx, type(links) == "string" and links or nil)
  return score, eq, item
end

-- Combined main-hand + off-hand equipped score (for two-hand candidates).
function S.EquippedWeaponPairScore(ctx, player)
  local mh, oh = player.equipped.MAINHAND, player.equipped.OFFHAND
  local links = player.equippedLinks or {}
  local smh = S.ScoreEquippedId(mh, "MAINHAND", ctx, links.MAINHAND)
  local soh = S.ScoreEquippedId(oh, "OFFHAND", ctx, links.OFFHAND)
  return smh + soh, smh, soh
end

-- Gain of a candidate over what it replaces (§6.3). ctx.bestOffhand / ctx.bestMainhand1H are the
-- scores of the best available one-hand candidates (Query fills them; default 0).
function S.Gain(candidate, slotKey, ctx, player)
  local score = S.ScoreItem(candidate, ctx)
  local base
  if slotKey == "MAINHAND" then
    local mhId = player.equipped.MAINHAND
    local mhItem = mhId and CMM.Data.Item(mhId)
    local pair, smh = S.EquippedWeaponPairScore(ctx, player)
    if isTwoHand(candidate) then
      base = pair
    elseif isTwoHand(mhItem) then
      base = math.max(0, smh - (ctx.bestOffhand or 0))
    else
      base = smh
    end
  elseif slotKey == "OFFHAND" then
    local mhId = player.equipped.MAINHAND
    local mhItem = mhId and CMM.Data.Item(mhId)
    local _, smh, soh = S.EquippedWeaponPairScore(ctx, player)
    if isTwoHand(mhItem) then
      base = math.max(0, smh - (ctx.bestMainhand1H or 0))
    else
      base = soh
    end
  else
    base = S.EquippedScore(slotKey, ctx, player)
  end
  local gain = score - base
  local pct = base > 0 and (gain / base * 100) or (gain > 0 and 100 or 0)
  return gain, pct, score, base
end
