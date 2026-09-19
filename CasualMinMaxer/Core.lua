-- Core: event frame, SavedVariables (defaults + migration), slash commands, active weights.
local ADDON, CMM = ...
local Core = {}
CMM.Core = Core
local C = CMM.Constants

Core.DB_VERSION = 1
Core.CHAR_VERSION = 3

local function copy(t)
  local out = {}
  for k, v in pairs(t) do out[k] = type(v) == "table" and copy(v) or v end
  return out
end

local function fillDefaults(target, defaults)
  for k, v in pairs(defaults) do
    if type(v) == "table" then
      if type(target[k]) ~= "table" then target[k] = {} end
      fillDefaults(target[k], v)
    elseif target[k] == nil then
      target[k] = v
    end
  end
  return target
end

Core.DB_DEFAULTS = {
  version = Core.DB_VERSION,
  ui = { x = nil, y = nil, w = 760, h = 520, scale = 1 },
  minimap = { hide = false, minimapPos = 220 },
  constants = {},
  phase = 5,
  showSidegradesDefault = false,
  tooltip = true,
  questAdvisor = true,
}

Core.CHAR_DEFAULTS = {
  version = Core.CHAR_VERSION,
  specOverride = nil,
  weights = {},
  lookahead = 2,
  filters = {
    sources = CMM.Constants.DefaultSourceFilters(),
    tiers = { [1] = true, [2] = true, [3] = true, [4] = false, [5] = false },
    dungeon = nil, zone = nil, groupOnly = false, armor = "all", special = true, sidegrades = false, sort = "eff",
  },
  hidden = {},
  lastSlot = "HEAD",
}

-- Migrations run in order from the stored version up to the current one.
Core.DB_MIGRATIONS = {
  -- [1] = function(db) ... end  (migrate from version 1 to 2)
}
Core.CHAR_MIGRATIONS = {
  -- 1 -> 2: vendor sources split by currency (E badges, H honor, A arena, F reputation)
  [1] = function(db)
    local f = db.filters and db.filters.sources
    if type(f) == "table" then
      local defaults = CMM.Constants.DefaultSourceFilters()
      for k, v in pairs(defaults) do
        if f[k] == nil then
          if k == "E" or k == "H" or k == "F" then f[k] = (f.V ~= false) else f[k] = v end
        end
      end
    end
  end,
  -- 2 -> 3: auction-house random-suffix items (S) are a new source type, on by default
  [2] = function(db)
    local f = db.filters and db.filters.sources
    if type(f) == "table" and f.S == nil then f.S = true end
  end,
}

local function migrate(db, migrations, target)
  local v = tonumber(db.version) or 0
  while v < target do
    local m = migrations[v]
    if m then m(db) end
    v = v + 1
    db.version = v
  end
  db.version = target
end

function Core.InitSavedVariables()
  if type(_G.CasualMinMaxerDB) ~= "table" then _G.CasualMinMaxerDB = {} end
  if type(_G.CasualMinMaxerCharDB) ~= "table" then _G.CasualMinMaxerCharDB = {} end
  local db, cdb = _G.CasualMinMaxerDB, _G.CasualMinMaxerCharDB
  migrate(db, Core.DB_MIGRATIONS, Core.DB_VERSION)
  migrate(cdb, Core.CHAR_MIGRATIONS, Core.CHAR_VERSION)
  fillDefaults(db, Core.DB_DEFAULTS)
  fillDefaults(cdb, Core.CHAR_DEFAULTS)
  CMM.db, CMM.chardb = db, cdb
  return db, cdb
end

function Core.ResetSavedVariables()
  _G.CasualMinMaxerDB = copy(Core.DB_DEFAULTS)
  _G.CasualMinMaxerCharDB = copy(Core.CHAR_DEFAULTS)
  CMM.db, CMM.chardb = _G.CasualMinMaxerDB, _G.CasualMinMaxerCharDB
  CMM.Query.Invalidate()
  CMM.Fire("SETTINGS_CHANGED")
end

-- Current spec key: user override or the detected one.
function Core.ActiveSpec()
  local cdb = _G.CasualMinMaxerCharDB
  local p = CMM.Player.Get()
  return (cdb and cdb.specOverride) or p.spec
end

-- Default weights for the level overlaid with the character's custom weights for the spec.
function Core.ActiveWeightsAt(level)
  local p = CMM.Player.Get()
  local spec = Core.ActiveSpec()
  local w = CMM.Weights.Get(p.class, spec, level)
  local cdb = _G.CasualMinMaxerCharDB
  local custom = cdb and cdb.weights and cdb.weights[spec]
  if custom then
    for k, v in pairs(custom) do w[k] = v end
  end
  return w
end

function Core.ActiveWeights()
  return Core.ActiveWeightsAt(CMM.Player.Get().level)
end

function Core.SetCustomWeights(spec, weights)
  local cdb = _G.CasualMinMaxerCharDB
  cdb.weights[spec] = weights and copy(weights) or nil
  CMM.Query.Invalidate()
  CMM.Fire("WEIGHTS_CHANGED", spec)
end

function Core.SetSpecOverride(spec)
  local cdb = _G.CasualMinMaxerCharDB
  cdb.specOverride = spec
  CMM.Player.Refresh()
  CMM.Query.Invalidate()
  CMM.Fire("PLAYER_CHANGED")
end

function Core.SetPhase(phase)
  phase = tonumber(phase)
  if not phase or phase < 1 or phase > 5 then return false end
  _G.CasualMinMaxerDB.phase = phase
  CMM.Query.Invalidate()
  CMM.Fire("SETTINGS_CHANGED")
  return true
end

-- Loads the data addon on first use (UI calls this before its first query).
function Core.EnsureData()
  if CMM.Data.IsLoaded() then return true end
  local ok = CMM.Data.Load()
  if not ok then
    CMM.Print("the data addon CasualMinMaxer_Data is missing or disabled. Enable it in the addon list.")
  end
  return ok
end

-- Recompute the character snapshot and drop cached queries.
function Core.PlayerChanged(reason)
  CMM.Player.Refresh()
  CMM.Query.Invalidate()
  CMM.Fire("PLAYER_CHANGED", reason)
end

local PLAYER_EVENTS = {
  PLAYER_EQUIPMENT_CHANGED = true, PLAYER_LEVEL_UP = true, QUEST_TURNED_IN = true,
  CHARACTER_POINTS_CHANGED = true, PLAYER_TALENT_UPDATE = true, SKILL_LINES_CHANGED = true,
  ZONE_CHANGED_NEW_AREA = true,
}

function Core.OnEvent(_, event, ...)
  if event == "ADDON_LOADED" then
    local name = ...
    if name == ADDON then
      Core.InitSavedVariables()
      CMM.Fire("ADDON_LOADED")
    end
  elseif event == "PLAYER_LOGIN" then
    Core.InitSavedVariables()
    CMM.Player.Refresh()
    CMM.Fire("PLAYER_LOGIN")
    CMM.Fire("PLAYER_CHANGED", "login")
  elseif PLAYER_EVENTS[event] then
    if event == "QUEST_TURNED_IN" then CMM.Player.InvalidateQuests() end
    Core.PlayerChanged(event)
  end
end

local function ui(fnName, ...)
  local f = CMM.UI and CMM.UI[fnName]
  if f then return f(...) end
  CMM.Print("UI not loaded (%s)", fnName)
end

local HELP = {
  "/cmm - toggle the window",
  "/cmm <slot> - open a slot (head, neck, shoulder, back, chest, wrist, hands, waist, legs, feet, ring, trinket, mh, oh, ranged)",
  "/cmm options - weights and settings",
  "/cmm validate [n] - compare n data items with the client",
  "/cmm export - print the website export string",
  "/cmm phase <1-5> - set the realm's content phase",
  "/cmm spec <key|auto> - override the detected spec",
  "/cmm reset - reset all settings",
  "/cmm debug - toggle debug output",
}

function Core.Slash(msg)
  msg = strtrim and strtrim(msg or "") or (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local cmd, arg = msg:match("^(%S+)%s*(.*)$")
  cmd = cmd and cmd:lower() or ""
  if cmd == "" then return ui("Toggle") end
  if cmd == "help" or cmd == "?" then for _, l in ipairs(HELP) do CMM.Print(l) end return end
  if cmd == "options" or cmd == "config" or cmd == "weights" then return ui("OpenOptions") end
  if cmd == "validate" then
    if Core.EnsureData() then CMM.Validate.Run(tonumber(arg) or 50) end
    return
  end
  if cmd == "export" then
    local s = CMM.Export.String(CMM.Player.Get(), Core.ActiveWeights())
    CMM.Print("export string (copy from the options window if this is cut off): %s", s)
    if CMM.UI and CMM.UI.ShowExport then CMM.UI.ShowExport(s) end
    return
  end
  if cmd == "phase" then
    if Core.SetPhase(arg) then CMM.Print("content phase set to %s", arg) else CMM.Print("usage: /cmm phase <1-5>") end
    return
  end
  if cmd == "spec" then
    if arg == "" then
      CMM.Print("spec: %s (detected %s)", Core.ActiveSpec(), CMM.Player.Get().specDetected or "?")
    elseif arg:lower() == "auto" then
      Core.SetSpecOverride(nil)
      CMM.Print("spec detection set to automatic")
    else
      local key = arg:upper()
      local found = false
      for _, s in ipairs(CMM.Weights.Specs(CMM.Player.Get().class)) do if s.key == key then found = true end end
      if found then Core.SetSpecOverride(key) CMM.Print("spec set to %s", key) else CMM.Print("unknown spec %s", arg) end
    end
    return
  end
  if cmd == "reset" then
    Core.ResetSavedVariables()
    CMM.Print("settings reset")
    return
  end
  if cmd == "debug" then
    CMM.debug = not CMM.debug
    CMM.Print("debug %s", CMM.debug and "on" or "off")
    return
  end
  if cmd == "hide" and arg ~= "" then
    local id = tonumber(arg)
    if id then _G.CasualMinMaxerCharDB.hidden[id] = true CMM.Query.Invalidate() CMM.Print("hidden item %d", id) ui("Refresh") end
    return
  end
  if cmd == "unhide" then
    _G.CasualMinMaxerCharDB.hidden = {}
    CMM.Query.Invalidate()
    CMM.Print("hidden items cleared")
    return ui("Refresh")
  end
  local slot = C.SLOT_ALIASES[cmd]
  if slot then return ui("Show", slot) end
  CMM.Print("unknown command '%s'. /cmm help", cmd)
end

-- Frame and registration
Core.frame = CreateFrame("Frame", "CasualMinMaxerEventFrame")
Core.frame:RegisterEvent("ADDON_LOADED")
Core.frame:RegisterEvent("PLAYER_LOGIN")
for ev in pairs(PLAYER_EVENTS) do Core.frame:RegisterEvent(ev) end
Core.frame:SetScript("OnEvent", Core.OnEvent)

_G.SLASH_CASUALMINMAXER1 = "/cmm"
_G.SLASH_CASUALMINMAXER2 = "/casualminmaxer"
SlashCmdList["CASUALMINMAXER"] = Core.Slash
