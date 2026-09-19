-- Regenerates pipeline/overrides/specials.json from CasualMinMaxer/Specials.lua.
-- Run from the repo root: ~/.local/bin/lua scripts/gen_specials_json.lua
local CMM = { Specials = {} }
local chunk = assert(loadfile("CasualMinMaxer/Specials.lua"))
chunk("CasualMinMaxer", CMM)
local ids = {}
for id in pairs(CMM.Specials.TABLE) do ids[#ids + 1] = id end
table.sort(ids)
local out = { "{" }
for i, id in ipairs(ids) do
  local keys, parts = {}, {}
  for k in pairs(CMM.Specials.TABLE[id]) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do parts[#parts + 1] = string.format('"%s": %s', k, tostring(CMM.Specials.TABLE[id][k])) end
  out[#out + 1] = string.format('  "%d": {%s}%s', id, table.concat(parts, ", "), i < #ids and "," or "")
end
out[#out + 1] = "}"
local f = assert(io.open("pipeline/overrides/specials.json", "w"))
f:write(table.concat(out, "\n"), "\n")
f:close()
print(#ids .. " specials written; ids: " .. table.concat(ids, ","))
