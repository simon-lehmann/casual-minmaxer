-- /cmm validate [n]: compares n random data-pack items against the client's GetItemStats.
-- Reports mismatches so data builds can be verified in game.
local _, CMM = ...
local V = CMM.Validate
local Data = CMM.Data
local Scoring = CMM.Scoring
local Compat = CMM.Compat

-- Keys the client's GetItemStats reports on the Classic client: primary stats, armor, ratings.
-- Spell-derived keys (AP, SP, HEAL, MP5, BLOCKV, FAP ...) are never in GetItemStats; they are compared
-- through the tooltip scan when the tooltip yields them, and otherwise skipped.
local SKIP = { SPEED = true, DPS = true, RDPS = true }
local TOLERANCE = { ARMOR = 0 }
V.CLIENT_KEYS = { STR = true, AGI = true, STA = true, INT = true, SPI = true, ARMOR = true,
  HIT = true, SPHIT = true, CRIT = true, SPCRIT = true, HASTE = true, SPHASTE = true, EXP = true, DEF = true,
  DODGE = true, PARRY = true, BLOCK = true, RES = true }

local function compareStats(item, clientStats, scanned)
  local diffs = {}
  local seen = {}
  scanned = scanned or {}
  for key, v in pairs(item.stats) do
    if not SKIP[key] then
      seen[key] = true
      if V.CLIENT_KEYS[key] then
        local cv = clientStats[key] or 0
        local tol = TOLERANCE[key] or 0
        if math.abs(cv - v) > tol then diffs[#diffs + 1] = { key = key, pack = v, client = cv } end
      elseif key == "RAP" then
        -- the client shows "+X Attack Power" for spells that grant both melee and ranged AP
        local cv = scanned.RAP or scanned.AP
        if cv and cv ~= v then diffs[#diffs + 1] = { key = key, pack = v, client = cv, via = "tooltip" } end
      elseif scanned[key] ~= nil then
        if scanned[key] ~= v then diffs[#diffs + 1] = { key = key, pack = v, client = scanned[key], via = "tooltip" } end
      end
    end
  end
  for key, cv in pairs(clientStats) do
    if not seen[key] and V.CLIENT_KEYS[key] and cv ~= 0 then diffs[#diffs + 1] = { key = key, pack = 0, client = cv } end
  end
  for key, cv in pairs(scanned) do
    if not seen[key] and not V.CLIENT_KEYS[key] and cv ~= 0 then
      diffs[#diffs + 1] = { key = key, pack = 0, client = cv, via = "tooltip" }
    end
  end
  return diffs
end

-- Compare one item; returns nil when the client has no stats for it (not cached), else the diff list.
function V.CheckItem(id)
  local item = Data.Item(id)
  if not item then return nil, "not in data pack" end
  local link = "item:" .. id
  local mods = Compat.GetItemStats(link)
  if not mods then return nil, "not cached by client" end
  local scanned = Compat.ScanEquipStats(link)
  return compareStats(item, Scoring.FromItemStats(mods), scanned)
end

local function pick(ids, n, rng)
  local out, used = {}, {}
  local total = #ids
  if total == 0 then return out end
  n = math.min(n, total)
  local r = rng or math.random
  while #out < n do
    local i = r(total)
    if not used[i] then used[i] = true out[#out + 1] = ids[i] end
  end
  return out
end

-- Runs the check on n random items. Items the client has not cached are requested and reported as
-- "pending"; run the command again after a few seconds to include them.
-- Returns { checked=, ok=, pending=, mismatches = { {id=, name=, diffs=} } }
function V.Run(n, opts)
  opts = opts or {}
  n = tonumber(n) or 50
  if not Data.Load() then
    CMM.Print("data pack not available")
    return nil
  end
  local ids = opts.ids or pick(Data.AllItemIds(), n, opts.rng)
  local result = { checked = 0, ok = 0, pending = 0, mismatches = {} }
  for _, id in ipairs(ids) do
    local diffs, why = V.CheckItem(id)
    if diffs then
      result.checked = result.checked + 1
      if #diffs == 0 then result.ok = result.ok + 1
      else result.mismatches[#result.mismatches + 1] = { id = id, name = Data.Item(id).name, diffs = diffs } end
    elseif why == "not cached by client" then
      result.pending = result.pending + 1
      Compat.OnItemLoad(id, function() end) -- ask the client to cache it for the next run
    end
  end
  if not opts.quiet then V.Report(result) end
  return result
end

function V.Report(result)
  local keys = {}
  for k in pairs(V.CLIENT_KEYS) do keys[#keys + 1] = k end
  table.sort(keys)
  CMM.Print("compared via GetItemStats: %s; spell effects (AP, SP, HEAL, MP5, BLOCKV, FAP, ...) via tooltip scan",
    table.concat(keys, " "))
  CMM.Print("validate: %d checked, %d ok, %d mismatched, %d pending (not cached yet, run again)",
    result.checked, result.ok, #result.mismatches, result.pending)
  for _, m in ipairs(result.mismatches) do
    local parts = {}
    for _, d in ipairs(m.diffs) do
      parts[#parts + 1] = string.format("%s pack=%s client=%s%s", d.key, tostring(d.pack), tostring(d.client),
        d.via and (" (" .. d.via .. ")") or "")
    end
    CMM.Print("  [%d] %s: %s", m.id, m.name, table.concat(parts, ", "))
  end
end
