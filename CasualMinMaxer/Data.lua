-- Loads the CasualMinMaxer_Data addon, decodes its packed records lazily and indexes items by slot.
-- Record formats: docs/ARCHITECTURE.md §4.
local _, CMM = ...
local Data = CMM.Data
local C = CMM.Constants

local DATA_ADDON = "CasualMinMaxer_Data"
local D -- CasualMinMaxer_Data once loaded
local itemCache, questCache, npcCache, bossCache, objectCache = {}, {}, {}, {}, {}
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
    if mode == "E" then rec.mode = "E"
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
  D.meta = D.meta or {}
  itemCache, questCache, npcCache, bossCache, objectCache = {}, {}, {}, {}, {}
  buildIndex()
  CMM.Fire("DATA_LOADED")
  return true
end

-- Test / reload helper: forget the loaded pack.
function Data.Unload()
  D, slotIndex = nil, nil
  itemCache, questCache, npcCache, bossCache, objectCache = {}, {}, {}, {}, {}
end

function Data.Meta()
  return D and D.meta or {}
end

local srcMeta = {
  __index = function(item, key)
    if key == "src" then return Data.ParseSources(D.src[item.id]) end
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
  item.slot = C.INV_TO_SLOT[item.inv]
  local special = D.specials[id]
  if special and special ~= "" then item.special = parseStats(special) end
  -- Sources are parsed on access and not cached: a full 15-slot sweep decodes every item, and keeping
  -- ~2 source tables per item would add ~3 MB. Parsing a few short tokens per candidate is cheap.
  setmetatable(item, srcMeta)
  itemCache[id] = item
  return item
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
