-- Loads the CasualMinMaxer_Data addon, decodes its packed records lazily and indexes items by slot.
-- Record formats: docs/ARCHITECTURE.md §4.
local _, CMM = ...
local Data = CMM.Data
local C = CMM.Constants

local DATA_ADDON = "CasualMinMaxer_Data"
local D -- CasualMinMaxer_Data once loaded
local itemCache, questCache, npcCache, bossCache, objectCache = {}, {}, {}, {}, {}
local suffixCache = {}
local slotIndex -- [slotKey] = array of ids

local function split(s, sep)
  local out, n = {}, 0
  local pattern = "([^" .. sep .. "]*)" .. sep
  for piece in (s .. sep):gmatch(pattern) do
    n = n + 1
    out[n] = piece
  end
  return out
end

local function parseStats(field)
  local stats = {}
  if field == nil or field == "" then return stats end
  for pair in field:gmatch("[^,]+") do
    local k, v = pair:match("^(%w+):(-?[%d%.]+)$")
    if k and v then stats[k] = tonumber(v) end
  end
  return stats
end
Data.ParseStats = parseStats

local function parseIdList(field)
  local out = {}
  if field == nil or field == "" then return out end
  for id in field:gmatch("%d+") do out[#out + 1] = tonumber(id) end
  return out
end

-- Source record decoding (§4.2)
local function parseSource(tok)
  local code = tok:sub(1, 1)
  local body = tok:sub(2)
  if code == "Q" then return { t = "Q", quest = tonumber(body) } end
  if code == "B" or code == "R" or code == "N" then
    local npc, pct = body:match("^(%d+):([%d%.]+)$")
    return { t = code, npc = tonumber(npc), pct = tonumber(pct) or 0 }
  end
  if code == "T" then
    local map, pct = body:match("^(%d+):([%d%.]+)$")
    return { t = "T", map = tonumber(map), pct = tonumber(pct) or 0 }
  end
  if code == "G" then
    local go, pct = body:match("^(%d+):([%d%.]+)$")
    return { t = "G", object = tonumber(go), pct = tonumber(pct) or 0 }
  end
  if code == "V" then
    local price, mode = body:match("^(%d+):(.*)$")
    local rec = { t = "V", price = tonumber(price) or 0, mode = "0" }
    if mode == "E" or mode == "H" or mode == "A" then rec.mode = mode
    elseif mode and mode:sub(1, 1) == "F" then
      local faction, rank = mode:match("^F(%d+)%-(%d+)$")
      rec.mode = "F"; rec.faction = tonumber(faction); rec.rank = tonumber(rank)
    end
    return rec
  end
  if code == "K" then
    local skill, value = body:match("^(%d+):(%d+)$")
    return { t = "K", skillLine = tonumber(skill), skill = tonumber(value) or 0 }
  end
  if code == "W" then return { t = "W", pct = tonumber(body) or 0 } end
  if code == "S" then return { t = "S" } end
  return nil
end
Data.ParseSource = parseSource

function Data.ParseSources(field)
  local out = {}
  if field == nil or field == "" then return out end
  for tok in field:gmatch("[^|]+") do
    local rec = parseSource(tok)
    if rec then out[#out + 1] = rec end
  end
  return out
end

function Data.IsLoaded()
  return D ~= nil
end

function Data.Raw()
  return D
end

local function buildIndex()
  slotIndex = {}
  for _, k in ipairs(C.SLOT_KEYS) do slotIndex[k] = {} end
  for id, rec in pairs(D.items) do
    local inv = tonumber(rec:match("^[^;]*;(%d+);"))
    local slot = inv and C.INV_TO_SLOT[inv]
    if slot then
      local list = slotIndex[slot]
      list[#list + 1] = id
      if inv == C.INV_ONE_HAND then
        local oh = slotIndex.OFFHAND
        oh[#oh + 1] = id
      end
    end
  end
  for _, list in pairs(slotIndex) do table.sort(list) end
end

-- Loads the data addon (once). Returns true when data is available.
function Data.Load()
  if D then return true end
  if not CMM.Compat.IsAddOnLoaded(DATA_ADDON) then
    local ok = CMM.Compat.LoadAddOn(DATA_ADDON)
    if not ok and not _G[DATA_ADDON] then return false end
  end
  D = _G[DATA_ADDON]
  if not D or not D.items then D = nil return false end
  D.src = D.src or {}
  D.quests = D.quests or {}
  D.npcs = D.npcs or {}
  D.bosses = D.bosses or {}
  D.dungeons = D.dungeons or {}
  D.objects = D.objects or {}
  D.zones = D.zones or {}
  D.specials = D.specials or {}
  D.rsuffix = D.rsuffix or {}
  D.rprop = D.rprop or {}
  D.randprop = D.randprop or {}
  D.sbonus = D.sbonus or {}
  D.meta = D.meta or {}
  itemCache, questCache, npcCache, bossCache, objectCache = {}, {}, {}, {}, {}
  suffixCache = {}
  buildIndex()
  CMM.Fire("DATA_LOADED")
  return true
end

-- Test / reload helper: forget the loaded pack.
function Data.Unload()
  D, slotIndex = nil, nil
  itemCache, questCache, npcCache, bossCache, objectCache = {}, {}, {}, {}, {}
  suffixCache = {}
end

function Data.Meta()
  return D and D.meta or {}
end

local srcMeta = {
  __index = function(item, key)
    if key == "src" then return Data.ParseSources(D.src[item.id]) end
    if key == "rand" and rawget(item, "randRaw") then
      -- random-enchant pool, parsed on access like sources (26 ids per Outland green add up)
      local rand = {}
      for tok in item.randRaw:gmatch("-?%d+") do rand[#rand + 1] = tonumber(tok) end
      return rand
    end
    return nil
  end,
}

function Data.Item(id)
  if not D then return nil end
  id = tonumber(id)
  if not id then return nil end
  local cached = itemCache[id]
  if cached then return cached end
  local rec = D.items[id]
  if not rec then return nil end
  local f = split(rec, ";")
  local item = {
    id = id,
    name = f[1] or "",
    inv = tonumber(f[2]) or 0,
    cls = tonumber(f[3]) or 0,
    sub = tonumber(f[4]) or 0,
    q = tonumber(f[5]) or 2,
    ilvl = tonumber(f[6]) or 0,
    req = tonumber(f[7]) or 0,
    classmask = tonumber(f[8]) or 0,
    flags = tonumber(f[9]) or 0,
    stats = parseStats(f[10]),
    sockets = f[11] or "",
    sbonus = tonumber(f[12]) or 0,
    phase = tonumber(f[13]) or 1,
  }
  if f[14] and f[14] ~= "" then item.randRaw = f[14] end
  item.slot = C.INV_TO_SLOT[item.inv]
  local special = D.specials[id]
  if special and special ~= "" then item.special = parseStats(special) end
  -- Sources are parsed on access and not cached: a full 15-slot sweep decodes every item, and keeping
  -- ~2 source tables per item would add ~3 MB. Parsing a few short tokens per candidate is cheap.
  setmetatable(item, srcMeta)
  itemCache[id] = item
  return item
end

-- Random enchants (§4.11). id < 0: ItemRandomSuffix (scaling), id > 0: ItemRandomProperties (fixed).
function Data.Suffix(id)
  if not D or not id or id == 0 then return nil end
  local cached = suffixCache[id]
  if cached ~= nil then return cached or nil end
  local rec
  if id < 0 then
    local raw = D.rsuffix[-id]
    if raw then
      local f = split(raw, ";")
      rec = { id = id, name = f[1] or "", alloc = parseStats(f[2]) }
    end
  else
    local raw = D.rprop[id]
    if raw then
      local f = split(raw, ";")
      rec = { id = id, name = f[1] or "", stats = parseStats(f[2]) }
    end
  end
  suffixCache[id] = rec or false
  return rec
end

function Data.SuffixName(id)
  local rec = Data.Suffix(id)
  return rec and rec.name or nil
end

-- RandPropPoints column group by inventory type (§4.11)
local RPP_GROUP = { [1] = 0, [5] = 0, [20] = 0, [7] = 0, [17] = 0, [3] = 1, [6] = 1, [8] = 1, [10] = 1, [12] = 1,
  [2] = 2, [9] = 2, [11] = 2, [16] = 2, [14] = 2, [23] = 2, [13] = 3, [21] = 3, [22] = 3,
  [15] = 4, [25] = 4, [26] = 4, [28] = 4 }

function Data.RandPropPoints(ilvl, quality, inv)
  if not D then return 0 end
  local raw = D.randprop[ilvl]
  local group = RPP_GROUP[inv]
  if not raw or not group then return 0 end
  local cols = split(raw, ";")
  local col = (quality >= 4) and cols[1] or (quality == 3 and cols[2] or cols[3])
  if not col then return 0 end
  local vals = split(col, ",")
  return tonumber(vals[group + 1]) or 0
end

-- Stats a suffix grants on this base item (scaling suffixes use the item's level, quality and slot).
function Data.SuffixStats(item, id)
  local rec = Data.Suffix(id)
  if not rec then return nil end
  if rec.stats then
    local out = {}
    for k, v in pairs(rec.stats) do out[k] = v end
    return out
  end
  local points = Data.RandPropPoints(item.ilvl, item.q, item.inv)
  local out = {}
  for k, pct in pairs(rec.alloc) do
    local v = math.floor(pct * points / 10000)
    if v > 0 then out[k] = v end
  end
  return out
end

-- Virtual item: the base item with one suffix applied (same id, `suffix` set, stats merged).
function Data.WithSuffix(item, id)
  local extra = Data.SuffixStats(item, id)
  if not extra then return nil end
  local stats = {}
  for k, v in pairs(item.stats) do stats[k] = v end
  for k, v in pairs(extra) do stats[k] = (stats[k] or 0) + v end
  local copy = {}
  for k, v in pairs(item) do copy[k] = v end
  copy.stats = stats
  copy.suffixStats = extra
  copy.suffix = id
  copy.rand = false -- a virtual item never expands again
  copy.randRaw = nil
  copy.name = item.name .. " " .. (Data.SuffixName(id) or "")
  copy.src = item.src -- parsed list (the base parses on access)
  copy.link = string.format("item:%d:0:0:0:0:0:%d", item.id, id)
  return copy
end

function Data.SocketBonus(enchantId)
  if not D or not enchantId or enchantId == 0 then return nil end
  local raw = D.sbonus[enchantId]
  if not raw or raw == "" then return nil end
  return parseStats(raw)
end

function Data.HasFlag(item, flag)
  return item.flags % (flag * 2) >= flag
end

function Data.ItemsForSlot(slotKey)
  if not slotIndex then return {} end
  return slotIndex[slotKey] or {}
end

function Data.AllItemIds()
  local out = {}
  if not D then return out end
  for id in pairs(D.items) do out[#out + 1] = id end
  table.sort(out)
  return out
end

local function parseRaces(field)
  if field == "A" then return C.ALLIANCE_MASK end
  if field == "H" then return C.HORDE_MASK end
  return tonumber(field) or 0
end

function Data.Quest(id)
  if not D then return nil end
  id = tonumber(id)
  local cached = questCache[id]
  if cached then return cached end
  local rec = D.quests[id]
  if not rec then return nil end
  local f = split(rec, ";")
  local q = {
    id = id,
    title = f[1] or "",
    minLevel = tonumber(f[2]) or 0,
    questLevel = tonumber(f[3]) or 0,
    races = parseRaces(f[4]),
    classes = tonumber(f[5]) or 0,
    zone = tonumber(f[6]) or 0,
    type = tonumber(f[7]) or 0,
    prev = tonumber(f[8]) or 0,
    next = tonumber(f[9]) or 0,
    excl = tonumber(f[10]) or 0,
    choice = parseIdList(f[11]),
    fixed = parseIdList(f[12]),
  }
  questCache[id] = q
  return q
end

function Data.Npc(entry)
  if not D then return nil end
  entry = tonumber(entry)
  local cached = npcCache[entry]
  if cached then return cached end
  local rec = D.npcs[entry]
  if not rec then return nil end
  local f = split(rec, ";")
  local npc = {
    entry = entry, name = f[1] or "", level = tonumber(f[2]) or 0, rank = tonumber(f[3]) or 0,
    map = tonumber(f[4]) or 0, respawnMin = tonumber(f[5]) or 0,
  }
  npcCache[entry] = npc
  return npc
end

function Data.Boss(entry)
  if not D then return nil end
  entry = tonumber(entry)
  local cached = bossCache[entry]
  if cached then return cached end
  local rec = D.bosses[entry]
  if not rec then return nil end
  local f = split(rec, ";")
  local boss = { entry = entry, map = tonumber(f[1]) or 0, index = tonumber(f[2]) or 0, heroic = (tonumber(f[3]) or 0) == 1 }
  bossCache[entry] = boss
  return boss
end

function Data.Dungeon(map)
  if not D then return nil end
  return D.dungeons[tonumber(map)]
end

function Data.Dungeons()
  local out = {}
  if not D then return out end
  for map, d in pairs(D.dungeons) do out[#out + 1] = { map = map, name = d.name, min = d.min, max = d.max } end
  table.sort(out, function(a, b) if a.min ~= b.min then return (a.min or 0) < (b.min or 0) end return a.name < b.name end)
  return out
end

function Data.Object(entry)
  if not D then return nil end
  entry = tonumber(entry)
  local cached = objectCache[entry]
  if cached then return cached end
  local rec = D.objects[entry]
  if not rec then return nil end
  local f = split(rec, ";")
  local obj = { entry = entry, name = f[1] or "", map = tonumber(f[2]) or 0 }
  objectCache[entry] = obj
  return obj
end

function Data.ZoneName(areaId)
  areaId = tonumber(areaId)
  if not areaId or areaId == 0 then return nil end
  local name = CMM.Compat.AreaName(areaId)
  if name then return name end
  return D and D.zones[areaId] or nil
end

-- Localized item name when the client has it cached, else the data pack's English name.
function Data.ItemName(id)
  local name = CMM.Compat.GetItemInfo(id)
  if name then return name end
  local item = Data.Item(id)
  return item and item.name or ("item:" .. tostring(id))
end
