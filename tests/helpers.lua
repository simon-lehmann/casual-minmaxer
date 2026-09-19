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
  -- Init.lua creates CMM.L with `CMM.L or ...`; pre-seeding it keeps specs that load single files working.
  local ns = { L = setmetatable({}, { __index = function(_, k) return k end }) }
  for _, f in ipairs(tocFiles("CasualMinMaxer/CasualMinMaxer.toc")) do
    local isUI = f:match("^UI/") or f:match("embeds%.xml") or f:match("^Libs/")
    if f:match("%.lua$") and (not isUI or opts.ui) then
      local path = "CasualMinMaxer/" .. f
      local fh = io.open(path, "r")
      if fh then
        fh:close()
        local chunk, err = loadfile(path)
        assert(chunk, err)
        chunk(H.ADDON, ns)
      elseif not (opts.allowMissing or opts.skipMissing) then
        error("missing addon file " .. path)
      end
    end
  end
  H.ns = ns
  _G.CasualMinMaxer = ns
  return ns
end

-- Loads the addon, installs the fixture data pack, initializes SavedVariables and refreshes the player.
-- Returns the namespace. opts.player mutates the stub player before the refresh.
H.DEFAULT_PLAYER = {
  class = "Warrior", classToken = "WARRIOR", classId = 1, level = 62, faction = "Alliance",
  race = "Human", raceToken = "Human", name = "Tester", realm = "Test",
  talents = { { "Arms", 31 }, { "Fury", 12 }, { "Protection", 0 } },
  skills = { { "Blacksmithing", 300, 375 }, { "Mining", 300, 375 } },
  zone = "Zangarmarsh",
}

function H.ResetPlayer()
  local p = H.wow.player
  for k, v in pairs(H.DEFAULT_PLAYER) do
    if type(v) == "table" then
      local c = {}
      for i, x in ipairs(v) do c[i] = type(x) == "table" and { x[1], x[2], x[3] } or x end
      p[k] = c
    else
      p[k] = v
    end
  end
  p.equipped, p.completedQuests, p.factions = {}, {}, {}
end

-- Deterministic weights used by the logic specs (independent of the shipped Weights.lua content).
-- Only Warrior/Arms exists so spec-fallback tests stay meaningful.
H.TEST_WEIGHTS = {
  WARRIOR = {
    ARMS = { name = "Arms", role = "melee", tabIndex = 1, phases = {
      { STR = 1, AGI = 0.6, STA = 0.7, AP = 0.5, CRIT = 12, HIT = 10, DPS = 4, SPEEDPREF = 1, ARMOR = 0.02 },
      { STR = 1, AGI = 0.6, STA = 0.6, AP = 0.5, CRIT = 12, HIT = 10, DPS = 4, SPEEDPREF = 1, ARMOR = 0.02 },
      { STR = 1, AGI = 0.6, STA = 0.5, AP = 0.5, CRIT = 12, HIT = 10, DPS = 4.5, SPEEDPREF = 1, ARMOR = 0.02 },
      { STR = 1, AGI = 0.6, STA = 0.45, AP = 0.5, CRIT = 14, HIT = 12, DPS = 5, SPEEDPREF = 1, ARMOR = 0.01, EXP = 16 },
      { STR = 1, AGI = 0.6, STA = 0.3, AP = 0.5, CRIT = 16, HIT = 16, DPS = 5.5, SPEEDPREF = 1, ARMOR = 0.01, EXP = 20, ARP = 0.1 },
    } },
  },
}

function H.Boot(opts)
  opts = opts or {}
  local ns = H.LoadAddon(opts)
  if not opts.realWeights then
    ns.Weights.DEFAULTS = CopyTable(H.TEST_WEIGHTS)
    ns.Weights.GEMS = {}
    ns.Weights.SOCKET_BONUS = {}
    ns.Specials.TABLE = {}
  end
  H.ResetPlayer()
  H.LoadFixtureData()
  if opts.player then for k, v in pairs(opts.player) do H.wow.player[k] = v end end
  ns.Core.InitSavedVariables()
  ns.Player.Refresh()
  ns.Data.Load()
  return ns
end

-- Simulates a missing / disabled data addon after it was loaded once in this test.
function H.RemoveData(ns)
  ns.Data.Unload()
  H.wow.dataLoader = nil
  H.wow.loadedAddons = {}
  _G.CasualMinMaxer_Data = nil
end

-- Convenience: a scoring context for the current player.
function H.Ctx(ns, slotKey, overrides)
  local p = ns.Player.Get()
  local ctx = { level = p.level, weights = ns.Core.ActiveWeights(), class = p.class, spec = p.spec, slotKey = slotKey or "HEAD",
    weightsAt = ns.Core.ActiveWeightsAt, phase = 5 }
  for k, v in pairs(overrides or {}) do ctx[k] = v end
  return ctx
end

-- Install a fixture data pack: fn receives the table that becomes CasualMinMaxer_Data
function H.UseData(fillFn)
  H.wow.dataLoader = function()
    local D = {}
    _G.CasualMinMaxer_Data = D
    D.items, D.src, D.quests, D.npcs, D.bosses, D.dungeons, D.objects, D.zones, D.specials = {}, {}, {}, {}, {}, {}, {}, {}, {}
    D.rsuffix, D.rprop, D.randprop, D.sbonus, D.rpool = {}, {}, {}, {}, {}
    D.meta = { version = "test", built = "2026-09-19", items = 0, quests = 0, phases = 5 }
    fillFn(D)
  end
end

function H.LoadFixtureData()
  H.UseData(function(D) dofile("tests/fixtures/data.lua")(D) end)
end

return H
