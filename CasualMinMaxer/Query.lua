-- Candidate selection, filtering, scoring, sorting and caching (docs/ARCHITECTURE.md §5, §6.1).
local _, CMM = ...
local Q = CMM.Query
local C = CMM.Constants
local Data = CMM.Data
local Scoring = CMM.Scoring
local Obtain = CMM.Obtain

local cache = {}


Q.DEFAULT_FILTERS = {
  sources = C.DefaultSourceFilters(),
  tiers = { [1] = true, [2] = true, [3] = true, [4] = false, [5] = false },
  dungeon = nil, zone = nil, groupOnly = false, armor = "all", special = true, sidegrades = false, sort = "eff",
}

function Q.Invalidate()
  cache = {}
end

local function serialize(v, depth)
  depth = depth or 0
  if type(v) ~= "table" then return tostring(v) end
  if depth > 4 then return "…" end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = tostring(k) end
  table.sort(keys)
  local parts = {}
  for _, k in ipairs(keys) do
    local val = v[k]
    if val == nil then val = v[tonumber(k)] end
    parts[#parts + 1] = k .. "=" .. serialize(val, depth + 1)
  end
  return "{" .. table.concat(parts, ",") .. "}"
end
Q.Serialize = serialize

local function weightsAtFactory(opts, player)
  if opts.weightsAt then return opts.weightsAt end
  if CMM.Core and CMM.Core.ActiveWeightsAt then return CMM.Core.ActiveWeightsAt end
  local spec = opts.spec or player.spec
  return function(L) return CMM.Weights.Get(player.class, spec, L) end
end

local function resolveOpts(opts, player)
  opts = opts or {}
  local charDB = _G.CasualMinMaxerCharDB
  local db = _G.CasualMinMaxerDB
  local filters = opts.filters or (charDB and charDB.filters) or Q.DEFAULT_FILTERS
  local weights = opts.weights or (CMM.Core and CMM.Core.ActiveWeights and CMM.Core.ActiveWeights())
    or CMM.Weights.Get(player.class, opts.spec or player.spec, player.level)
  local r = {
    filters = filters,
    sort = opts.sort or filters.sort or "eff",
    sidegrades = opts.sidegrades,
    lookahead = opts.lookahead or (charDB and charDB.lookahead) or 2,
    phase = opts.phase or (db and db.phase) or 5,
    dungeon = opts.dungeon or filters.dungeon,
    zone = opts.zone or filters.zone,
    showSpecial = opts.showSpecial,
    hidden = opts.hidden or (charDB and charDB.hidden) or {},
    weights = weights,
    spec = opts.spec or player.spec,
    weightsAt = weightsAtFactory(opts, player),
    longevity = opts.longevity ~= false,
  }
  if r.sidegrades == nil then r.sidegrades = filters.sidegrades or false end
  if r.showSpecial == nil then r.showSpecial = filters.special ~= false end
  return r
end

local function makeCtx(slotKey, player, o)
  return {
    level = player.level, weights = o.weights, class = player.class, spec = o.spec, slotKey = slotKey,
    weightsAt = o.weightsAt, phase = o.phase,
  }
end

-- opts.lookahead (default 0) or opts.level: the level at which armor unlocks (mail/plate at 40) are judged.
local function usableBySlot(item, slotKey, player, opts)
  local level = (opts and opts.level) or (player.level + ((opts and opts.lookahead) or 0))
  if item.cls == 4 then
    if not C.CanUseArmor(player.class, item.sub, level) then return false end
  elseif item.cls == 2 then
    if not C.CanUseWeapon(player.class, item.sub) then return false end
  end
  if slotKey == "OFFHAND" and item.inv == C.INV_ONE_HAND and not player.canDualWield then return false end
  if slotKey == "MAINHAND" and item.inv == C.INV_ONE_HAND and item.cls == 2 then
    -- one-hand weapons are fine in main hand for everyone who can use the subclass
    return true
  end
  return true
end
Q.UsableBySlot = usableBySlot

local function armorFilterOk(item, o, player)
  if o.filters.armor ~= "best" or item.cls ~= 4 then return true end
  if item.sub == C.ARMOR_MISC or item.sub == C.ARMOR_SHIELD or item.sub >= 7 then return true end
  return item.sub == C.BestArmor(player.class, player.level + o.lookahead)
end

-- Source filter closure for Obtain.Evaluate: source type, dungeon, zone, group filters.
local function sourceFilter(o, player)
  local f = o.filters
  return function(src, e)
    if f.sources and not f.sources[C.SourceFilterKey(src)] then return false end
    if f.groupOnly == "solo" or f.groupOnly == true then
      if e.group then return false end
    end
    if o.dungeon then
      local d = Data.Dungeon(o.dungeon)
      local dungeonQuest = false
      if e.quest and e.quest.type == C.QUEST_DUNGEON and e.zone and d then
        if d.zone == e.zone then dungeonQuest = true end
        for _, z in ipairs(d.qz or {}) do if z == e.zone then dungeonQuest = true end end
      end
      if e.map ~= o.dungeon and not dungeonQuest then return false end
    end
    if o.zone and o.zone ~= "any" then
      local wanted = o.zone
      if wanted == "current" then
        local name = e.zone and Data.ZoneName(e.zone)
        if not name or name ~= player.zoneName then return false end
      elseif e.zone ~= wanted then
        return false
      end
    end
    return true
  end
end

-- Best score among usable one-hand candidates for a slot (for 2H <-> 1H+OH comparisons).
local function bestOneHandScore(slotKey, player, o, ctx)
  local best = 0
  for _, id in ipairs(Data.ItemsForSlot(slotKey)) do
    local item = Data.Item(id)
    if item and item.inv ~= C.INV_TWO_HAND and item.req <= player.level + o.lookahead
      and usableBySlot(item, slotKey, player, o) and Obtain.Gate(item, player, o) then
      local s = Scoring.ScoreItem(item, ctx)
      if s > best then best = s end
    end
  end
  return best
end

local SORTS = {
  eff = function(a, b) if a.eff ~= b.eff then return a.eff > b.eff end return a.gain > b.gain end,
  gain = function(a, b) if a.gain ~= b.gain then return a.gain > b.gain end return a.minutes < b.minutes end,
  fast = function(a, b) if a.minutes ~= b.minutes then return a.minutes < b.minutes end return a.gain > b.gain end,
  value = function(a, b) if a.value ~= b.value then return a.value > b.value end return a.gain > b.gain end,
}

local function cacheKey(slotKey, player, o)
  return table.concat({
    slotKey, player.class, o.spec, player.level, player.faction, player.zoneName or "",
    serialize(o.weights), serialize(o.filters), o.sort, tostring(o.sidegrades), o.lookahead, o.phase,
    tostring(o.dungeon), tostring(o.zone), tostring(o.showSpecial), serialize(o.hidden),
    serialize(player.equippedLinks or player.equipped), serialize(player.professions), tostring(o.longevity),
  }, "|")
end

-- Faction twins (Alliance/Horde honor gear, Aldor/Scryer rewards) are separate item ids with the same name,
-- stats and source text. Keep the first (best-sorted) of each such group.
local function statsSignature(item)
  local keys = {}
  for k, v in pairs(item.stats or {}) do keys[#keys + 1] = k .. "=" .. tostring(v) end
  table.sort(keys)
  return table.concat(keys, ",")
end

function Q.Dedupe(rows)
  local seen, out = {}, {}
  for _, row in ipairs(rows) do
    local sig = row.item.name .. "|" .. statsSignature(row.item) .. "|" .. tostring(row.obtain and row.obtain.text)
    if not seen[sig] then
      seen[sig] = true
      out[#out + 1] = row
    end
  end
  return out
end

function Q.Run(slotKey, player, opts)
  player = player or CMM.Player.Get()
  local o = resolveOpts(opts, player)
  local key = cacheKey(slotKey, player, o)
  local hit = cache[key]
  if hit then return hit end

  local ctx = makeCtx(slotKey, player, o)
  if slotKey == "MAINHAND" then
    ctx.bestOffhand = bestOneHandScore("OFFHAND", player, o, makeCtx("OFFHAND", player, o))
  elseif slotKey == "OFFHAND" then
    ctx.bestMainhand1H = bestOneHandScore("MAINHAND", player, o, makeCtx("MAINHAND", player, o))
  end
  local filterFn = sourceFilter(o, player)
  local evalOpts = { lookahead = o.lookahead, phase = o.phase, sourceFilter = filterFn }
  local equippedScore, equippedId = Scoring.EquippedScore(slotKey, ctx, player)
  local rows = {}

  for _, id in ipairs(Data.ItemsForSlot(slotKey)) do
    local item = Data.Item(id)
    if item and not o.hidden[id] and #item.src > 0 and item.req <= player.level + o.lookahead
      and usableBySlot(item, slotKey, player, o) and armorFilterOk(item, o, player)
      and not ((slotKey == "FINGER" or slotKey == "TRINKET") and Data.HasFlag(item, C.FLAG_UNIQUE) and CMM.Player.IsEquipped(id))
      and id ~= equippedId then
      local special = Data.HasFlag(item, C.FLAG_SPECIAL)
      if (o.showSpecial or not special) and Obtain.Gate(item, player, evalOpts) then
        local obtain = Obtain.Evaluate(item, player, evalOpts)
        if obtain and (not o.filters.tiers or o.filters.tiers[obtain.tier]) then
          local gain, gainPct, score = Scoring.Gain(item, slotKey, ctx, player)
          local keep = gain > 0
          if not keep and o.sidegrades then
            local base = score - gain
            keep = gain >= -0.05 * base
          end
          if keep then
            local hours = math.max(obtain.minutes, 1) / 60
            local lasts = o.longevity and Obtain.LastsUntil(item, slotKey, ctx, player) or 70
            local eff = gain / hours
            rows[#rows + 1] = {
              id = id, item = item, score = score, gain = gain, gainPct = gainPct, tier = obtain.tier,
              minutes = obtain.minutes, eff = eff, obtain = obtain, lastsUntil = lasts,
              value = eff * (lasts - player.level + 1), special = special, set = Data.HasFlag(item, C.FLAG_SET),
            }
          end
        end
      end
    end
  end
  table.sort(rows, SORTS[o.sort] or SORTS.eff)
  rows = Q.Dedupe(rows)
  local result = { rows = rows, equippedScore = equippedScore, equippedId = equippedId, slotKey = slotKey }
  cache[key] = result
  return result
end

-- Reverse lookup: everything wanted from one dungeon, grouped by boss entry (0 = trash/chests/quests).
function Q.RunDungeon(mapId, player, opts)
  player = player or CMM.Player.Get()
  opts = opts or {}
  local merged = {}
  for k, v in pairs(opts) do merged[k] = v end
  merged.dungeon = mapId
  local baseFilters = opts.filters or (_G.CasualMinMaxerCharDB and _G.CasualMinMaxerCharDB.filters) or Q.DEFAULT_FILTERS
  local filters = {}
  for k, v in pairs(baseFilters) do filters[k] = v end
  filters.tiers = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true }
  filters.sources = { Q = true, B = true, G = true, T = true }
  filters.dungeon = mapId
  merged.filters = filters
  merged.longevity = opts.longevity == true
  local out = {}
  for _, slotKey in ipairs(C.SLOT_KEYS) do
    local res = Q.Run(slotKey, player, merged)
    for _, row in ipairs(res.rows) do
      local boss = row.obtain.boss or 0
      out[boss] = out[boss] or {}
      local list = out[boss]
      list[#list + 1] = row
    end
  end
  for _, list in pairs(out) do table.sort(list, SORTS.gain) end
  return out
end

-- Weakest slot by equipped score relative to the best available upgrade (for the slot strip).
function Q.SlotSummary(player, opts)
  player = player or CMM.Player.Get()
  local out = {}
  for _, slotKey in ipairs(C.SLOT_KEYS) do
    local res = Q.Run(slotKey, player, opts)
    local top = res.rows[1]
    out[slotKey] = { equippedScore = res.equippedScore, equippedId = res.equippedId, bestGain = top and top.gain or 0, count = #res.rows }
  end
  return out
end
