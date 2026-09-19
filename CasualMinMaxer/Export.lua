-- Character export string for the website: base64 of `v1;class;level;spec;equippedIds;weights`.
local _, CMM = ...
local E = CMM.Export
local C = CMM.Constants
local Compat = CMM.Compat

local function equippedList(player)
  local parts = {}
  for _, slotKey in ipairs(C.SLOT_KEYS) do
    local v = player.equipped[slotKey]
    if type(v) == "table" then
      parts[#parts + 1] = slotKey .. "=" .. tostring(v[1] or 0) .. "/" .. tostring(v[2] or 0)
    else
      parts[#parts + 1] = slotKey .. "=" .. tostring(v or 0)
    end
  end
  return table.concat(parts, ",")
end

local function weightsList(weights)
  local keys = {}
  for k, v in pairs(weights or {}) do if type(v) == "number" and v ~= 0 then keys[#keys + 1] = k end end
  table.sort(keys)
  local parts = {}
  for _, k in ipairs(keys) do parts[#parts + 1] = k .. ":" .. string.format("%.4g", weights[k]) end
  return table.concat(parts, ",")
end

function E.Raw(player, weights)
  return table.concat({ "v1", player.class or "", tostring(player.level or 0), player.spec or "",
    equippedList(player), weightsList(weights) }, ";")
end

function E.String(player, weights)
  return Compat.Base64Encode(E.Raw(player, weights))
end

function E.Parse(str)
  if type(str) ~= "string" then return nil, "not a string" end
  local raw = Compat.Base64Decode(str)
  if not raw then return nil, "bad base64" end
  local version, class, level, spec, equipped, weights = raw:match("^([^;]*);([^;]*);([^;]*);([^;]*);([^;]*);(.*)$")
  if version ~= "v1" then return nil, "unknown version" end
  local out = { version = version, class = class, level = tonumber(level) or 0, spec = spec, equipped = {}, weights = {} }
  for slot, val in equipped:gmatch("(%u+)=([%d/]+)") do
    local a, b = val:match("^(%d+)/(%d+)$")
    if a then
      out.equipped[slot] = { tonumber(a), tonumber(b) }
      if out.equipped[slot][1] == 0 then out.equipped[slot][1] = nil end
      if out.equipped[slot][2] == 0 then out.equipped[slot][2] = nil end
    else
      local id = tonumber(val)
      out.equipped[slot] = id ~= 0 and id or nil
    end
  end
  for k, v in weights:gmatch("(%w+):(-?[%d%.eE+-]+)") do out.weights[k] = tonumber(v) end
  return out
end
