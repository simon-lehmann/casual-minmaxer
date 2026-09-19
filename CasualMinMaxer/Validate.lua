-- /cmm validate [n]: compares n random data-pack items against the client's GetItemStats.
-- Reports mismatches so data builds can be verified in game.
local _, CMM = ...
local V = CMM.Validate
local Data = CMM.Data
local Scoring = CMM.Scoring
local Compat = CMM.Compat

-- Keys that the client reports differently or that we derive: compared with tolerance / skipped.
local SKIP = { SPEED = true, DPS = true, RDPS = true }
local TOLERANCE = { ARMOR = 0 }

local function compareStats(item, clientStats)
  local diffs = {}
  local seen = {}
  for key, v in pairs(item.stats) do
    if not SKIP[key] then
      seen[key] = true
      local cv = clientStats[key] or 0
      local tol = TOLERANCE[key] or 0
      if math.abs(cv - v) > tol then diffs[#diffs + 1] = { key = key, pack = v, client = cv } end
    end
  end
  for key, cv in pairs(clientStats) do
    if not seen[key] and not SKIP[key] and cv ~= 0 then diffs[#diffs + 1] = { key = key, pack = 0, client = cv } end
  end
  return diffs
end

-- Compare one item; returns nil when the client has no stats for it (not cached), else the diff list.
function V.CheckItem(id)
  local item = Data.Item(id)
  if not item then return nil, "not in data pack" end
  local mods = Compat.GetItemStats("item:" .. id)
  if not mods then return nil, "not cached by client" end
  return compareStats(item, Scoring.FromItemStats(mods))
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
  CMM.Print("validate: %d checked, %d ok, %d mismatched, %d pending (not cached yet, run again)",
    result.checked, result.ok, #result.mismatches, result.pending)
  for _, m in ipairs(result.mismatches) do
    local parts = {}
    for _, d in ipairs(m.diffs) do
      parts[#parts + 1] = string.format("%s pack=%s client=%s", d.key, tostring(d.pack), tostring(d.client))
    end
    CMM.Print("  [%d] %s: %s", m.id, m.name, table.concat(parts, ", "))
  end
end
