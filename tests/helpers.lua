-- Loads the addon's Lua files the way the WoW client does: in .toc order, passing (ADDON, namespace).
local H = {}
H.wow = require("tests.stubs.wow")
H.ADDON = "CasualMinMaxer"

local function tocFiles(tocPath)
  local files = {}
  for line in io.lines(tocPath) do
    line = line:gsub("\r", "")
    if line ~= "" and not line:match("^#") then files[#files + 1] = (line:gsub("\\", "/")) end
  end
  return files
end

-- Load the logic modules (everything in the .toc except Libs/embeds.xml and UI/ unless opts.ui)
function H.LoadAddon(opts)
  opts = opts or {}
  H.wow.Reset()
  local ns = {}
  for _, f in ipairs(tocFiles("CasualMinMaxer/CasualMinMaxer.toc")) do
    local isUI = f:match("^UI/") or f:match("embeds%.xml") or f:match("^Libs/")
    if f:match("%.lua$") and (not isUI or opts.ui) then
      local chunk, err = loadfile("CasualMinMaxer/" .. f)
      -- opts.skipMissing: tolerate files that another agent has not written yet (UI-only runs)
      if chunk then
        chunk(H.ADDON, ns)
      elseif not (opts.skipMissing and err and err:find("No such file")) then
        assert(chunk, err)
      end
    end
  end
  H.ns = ns
  return ns
end

-- Install a fixture data pack: fn receives the table that becomes CasualMinMaxer_Data
function H.UseData(fillFn)
  H.wow.dataLoader = function()
    local D = {}
    _G.CasualMinMaxer_Data = D
    D.items, D.src, D.quests, D.npcs, D.bosses, D.dungeons, D.objects, D.zones, D.specials = {}, {}, {}, {}, {}, {}, {}, {}, {}
    D.meta = { version = "test", built = "2026-09-19", items = 0, quests = 0, phases = 5 }
    fillFn(D)
  end
end

function H.LoadFixtureData()
  H.UseData(function(D) dofile("tests/fixtures/data.lua")(D) end)
end

return H
