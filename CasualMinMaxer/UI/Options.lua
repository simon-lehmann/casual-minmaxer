-- Options panel: spec override, weight sliders, Pawn import/export, phase, lookahead, tier constants,
-- minimap toggle, character export.
local _, CMM = ...
local UI = CMM.UI
local L = CMM.L
local Options = {}
UI.Options = Options

local call = UI.Call
local panel, category

-- Ordered keys for the slider list: primaries first, then everything else alphabetically.
local PRIMARY_ORDER = { "STR", "AGI", "STA", "INT", "SPI", "AP", "RAP", "FAP", "SP", "HEAL", "MP5", "DPS", "DPS_OH", "RDPS" }
local EXTRA_KEYS = { SPEEDPREF = true, SPEEDPREF_OH = true }

local function ratingKey(key)
  local set = CMM.Constants and CMM.Constants.RATING_KEYS
  if set then return set[key] and true or false end
  local fallback = { HIT = 1, SPHIT = 1, CRIT = 1, SPCRIT = 1, HASTE = 1, SPHASTE = 1, EXP = 1, DEF = 1, DODGE = 1,
    PARRY = 1, BLOCK = 1, RES = 1 }
  return fallback[key] ~= nil
end

local function orderedKeys(weights)
  local keys, seen = {}, {}
  for _, k in ipairs(PRIMARY_ORDER) do
    if weights[k] ~= nil then keys[#keys + 1] = k seen[k] = true end
  end
  local rest = {}
  for k in pairs(weights) do if not seen[k] and not EXTRA_KEYS[k] then rest[#rest + 1] = k end end
  table.sort(rest)
  for _, k in ipairs(rest) do keys[#keys + 1] = k end
  return keys
end

function Options.DefaultWeights()
  local p = UI.Player()
  if not p then return {} end
  return call(CMM.Weights, "Get", p.class, UI.Spec(), p.level) or {}
end

function Options.SetWeight(key, value)
  local c = UI.CharDB()
  local spec = UI.Spec()
  c.weights[spec] = c.weights[spec] or {}
  c.weights[spec][key] = value
  if CMM.Fire then CMM.Fire("WEIGHTS_CHANGED") end
end

function Options.ResetWeights()
  local c = UI.CharDB()
  c.weights[UI.Spec()] = nil
  if CMM.Fire then CMM.Fire("WEIGHTS_CHANGED") end
  Options.Refresh()
end

function Options.ImportPawn(str)
  local p = UI.Player()
  local weights, name = call(CMM.Pawn, "Import", str, p and p.level or 70)
  if not weights or next(weights) == nil then
    CMM.Print(L["Could not read that Pawn string."])
    return false
  end
  local c = UI.CharDB()
  c.weights[UI.Spec()] = weights
  CMM.Print(L["Imported Pawn weights"] .. (name and (": " .. name) or ""))
  if CMM.Fire then CMM.Fire("WEIGHTS_CHANGED") end
  Options.Refresh()
  return true
end

function Options.ExportPawn()
  local str = call(CMM.Pawn, "Export", UI.Weights(), "CMM " .. UI.SpecName())
  if str then UI.ShowCopyBox(L["Pawn string"], str) end
end

function Options.ExportCharacter()
  local str = call(CMM.Export, "String", UI.Player(), UI.Weights())
  if str then UI.ShowCopyBox(L["Character export"], str) end
end

function Options.SetPhase(n)
  UI.DB().phase = n
  call(CMM.Query, "Invalidate")
  if CMM.Fire then CMM.Fire("SETTINGS_CHANGED") end
end

function Options.SetConstant(key, value)
  UI.DB().constants[key] = value
  if CMM.Constants and CMM.Constants.TIER then CMM.Constants.TIER[key] = value end
  call(CMM.Query, "Invalidate")
  if CMM.Fire then CMM.Fire("SETTINGS_CHANGED") end
end

function Options.SetRandomLimit(key, value)
  if CMM.Core and CMM.Core.SetRandomLimit then
    CMM.Core.SetRandomLimit(key, value)
    return
  end
  local db = UI.DB()
  db.random = db.random or {}
  db.random[key] = value
  if CMM.Constants and CMM.Constants.RANDOM then CMM.Constants.RANDOM[key] = value end
  call(CMM.Query, "Invalidate")
  if CMM.Fire then CMM.Fire("SETTINGS_CHANGED") end
end

function Options.SetSpecOverride(key)
  if CMM.Core and CMM.Core.SetSpecOverride then
    CMM.Core.SetSpecOverride(key) -- refreshes the player snapshot, invalidates queries, fires PLAYER_CHANGED
  else
    UI.CharDB().specOverride = key
    call(CMM.Query, "Invalidate")
  end
  if CMM.Fire then CMM.Fire("WEIGHTS_CHANGED") end
  Options.Refresh()
end

function Options.SetMinimapHidden(hidden)
  UI.DB().minimap.hide = hidden
  if UI.Minimap and UI.Minimap.Update then UI.Minimap.Update() end
end

---------------------------------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------------------------------
local function makeSlider(parent, label, minV, maxV, step, onChange)
  local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
  s:SetSize(150, 16)
  s:SetMinMaxValues(minV, maxV)
  s:SetValueStep(step)
  s:SetObeyStepOnDrag(true)
  s.label = s:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  s.label:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 2)
  s.label:SetText(label)
  s.valueBox = CreateFrame("EditBox", nil, s, "InputBoxTemplate")
  s.valueBox:SetSize(46, 18)
  s.valueBox:SetPoint("LEFT", s, "RIGHT", 10, 0)
  s.valueBox:SetAutoFocus(false)
  s.valueBox:SetScript("OnEnterPressed", function(self)
    local v = tonumber(self:GetText())
    if v then s:SetValue(v) end
    self:ClearFocus()
  end)
  s.valueBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  s:SetScript("OnValueChanged", function(self, v)
    if self.updating then return end
    self.valueBox:SetText(string.format("%.2f", v))
    if onChange then onChange(v, self) end
  end)
  s.Set = function(self, v)
    self.updating = true
    self:SetValue(v)
    self.valueBox:SetText(string.format("%.2f", v))
    self.updating = false
  end
  return s
end

local function buildPanel()
  panel = CreateFrame("Frame", "CasualMinMaxerOptions", UIParent)
  panel.name = L["CMM_TITLE"]
  panel:Hide()

  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText(L["CMM_TITLE"] .. " " .. tostring(CMM.version))
  local sub = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  sub:SetText(L["Weights are per stat point; rating weights are per 1 %. Saved per character and spec."])

  -- Spec override
  panel.specLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  panel.specLabel:SetPoint("TOPLEFT", 16, -56)
  panel.specLabel:SetText(L["Spec"])
  panel.spec = UI.CreateDropdown(panel, 140, function(_, level)
    local info = UI.MenuInfo()
    info.text = L["Auto (talents)"]
    info.checked = (UI.CharDB().specOverride == nil)
    info.func = function() Options.SetSpecOverride(nil) end
    if UIDropDownMenu_AddButton then UIDropDownMenu_AddButton(info, level) end
    local p = UI.Player()
    for _, s in ipairs(p and call(CMM.Weights, "Specs", p.class) or {}) do
      local si = UI.MenuInfo()
      si.text = s.name
      si.checked = (UI.CharDB().specOverride == s.key)
      si.func = function() Options.SetSpecOverride(s.key) end
      if UIDropDownMenu_AddButton then UIDropDownMenu_AddButton(si, level) end
    end
  end)
  panel.spec:SetPoint("LEFT", panel.specLabel, "RIGHT", -6, -2)

  -- Phase
  panel.phaseLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  panel.phaseLabel:SetPoint("LEFT", panel.spec, "RIGHT", -6, 2)
  panel.phaseLabel:SetText(L["Content phase"])
  panel.phase = UI.CreateDropdown(panel, 50, function(_, level)
    for n = 1, 5 do
      local info = UI.MenuInfo()
      info.text = tostring(n)
      info.checked = (UI.DB().phase == n)
      info.func = function() Options.SetPhase(n) Options.Refresh() end
      if UIDropDownMenu_AddButton then UIDropDownMenu_AddButton(info, level) end
    end
  end)
  panel.phase:SetPoint("LEFT", panel.phaseLabel, "RIGHT", -6, -2)

  -- Minimap toggle
  panel.minimap = UI.CreateCheck(panel, L["Show minimap button"], function(_, checked) Options.SetMinimapHidden(not checked) end)
  panel.minimap:SetPoint("LEFT", panel.phase, "RIGHT", 0, 2)

  -- Lookahead + tier constants
  panel.lookahead = makeSlider(panel, L["Levels ahead"], 0, 5, 1, function(v)
    UI.CharDB().lookahead = math.floor(v + 0.5)
    call(CMM.Query, "Invalidate")
    if CMM.Fire then CMM.Fire("SETTINGS_CHANGED") end
  end)
  panel.lookahead:SetPoint("TOPLEFT", 20, -110)
  panel.minutesPerQuest = makeSlider(panel, L["Minutes per quest"], 3, 30, 1,
    function(v) Options.SetConstant("minutesPerQuest", math.floor(v + 0.5)) end)
  panel.minutesPerQuest:SetPoint("LEFT", panel.lookahead, "RIGHT", 70, 0)
  panel.groupOverhead = makeSlider(panel, L["Group overhead (min)"], 5, 60, 1,
    function(v) Options.SetConstant("groupOverhead", math.floor(v + 0.5)) end)
  panel.groupOverhead:SetPoint("LEFT", panel.minutesPerQuest, "RIGHT", 70, 0)
  panel.travel = makeSlider(panel, L["Travel to other zone (min)"], 0, 45, 1,
    function(v) Options.SetConstant("travel", math.floor(v + 0.5)) end)
  panel.travel:SetPoint("TOPLEFT", panel.lookahead, "BOTTOMLEFT", 0, -34)
  panel.badgeGrind = makeSlider(panel, L["Badge gear (min)"], 30, 600, 10,
    function(v) Options.SetConstant("badgeGrind", math.floor(v + 0.5)) end)
  panel.badgeGrind:SetPoint("LEFT", panel.travel, "RIGHT", 70, 0)
  panel.honorGrind = makeSlider(panel, L["Honor gear (min)"], 30, 900, 10,
    function(v) Options.SetConstant("honorGrind", math.floor(v + 0.5)) end)
  panel.honorGrind:SetPoint("LEFT", panel.badgeGrind, "RIGHT", 70, 0)
  panel.arenaGrind = makeSlider(panel, L["Arena gear (min)"], 60, 3000, 30,
    function(v) Options.SetConstant("arenaGrind", math.floor(v + 0.5)) end)
  panel.arenaGrind:SetPoint("TOPLEFT", panel.travel, "BOTTOMLEFT", 0, -34)
  panel.repPerRank = makeSlider(panel, L["Reputation per rank (min)"], 30, 600, 10,
    function(v) Options.SetConstant("repPerRank", math.floor(v + 0.5)) end)
  panel.repPerRank:SetPoint("LEFT", panel.arenaGrind, "RIGHT", 70, 0)
  panel.auction = makeSlider(panel, L["Auction house (min)"], 0, 120, 5,
    function(v) Options.SetConstant("auction", math.floor(v + 0.5)) end)
  panel.auction:SetPoint("LEFT", panel.repPerRank, "RIGHT", 70, 0)
  -- Random-suffix listing limits (account-wide)
  panel.maxAuctionRows = makeSlider(panel, L["Auction rows per slot"], 0, 20, 1,
    function(v) Options.SetRandomLimit("maxAuctionRows", math.floor(v + 0.5)) end)
  panel.maxAuctionRows:SetPoint("TOPLEFT", panel.arenaGrind, "BOTTOMLEFT", 0, -34)
  panel.minChancePct = makeSlider(panel, L["Minimum suffix roll chance %"], 0, 5, 0.5,
    function(v) Options.SetRandomLimit("minChancePct", math.floor(v * 2 + 0.5) / 2) end)
  panel.minChancePct:SetPoint("LEFT", panel.maxAuctionRows, "RIGHT", 70, 0)

  -- Pawn import / exports
  panel.pawnLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  panel.pawnLabel:SetPoint("TOPLEFT", panel.maxAuctionRows, "BOTTOMLEFT", -4, -30)
  panel.pawnLabel:SetText(L["Pawn string"])
  panel.pawn = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
  panel.pawn:SetSize(300, 22)
  panel.pawn:SetPoint("LEFT", panel.pawnLabel, "RIGHT", 10, 0)
  panel.pawn:SetAutoFocus(false)
  panel.pawn:SetScript("OnEnterPressed", function(self) Options.ImportPawn(self:GetText()) self:ClearFocus() end)
  panel.pawn:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  panel.pawnImport = UI.CreateButton(panel, L["Import"], 70, function() Options.ImportPawn(panel.pawn:GetText()) end)
  panel.pawnImport:SetPoint("LEFT", panel.pawn, "RIGHT", 6, 0)
  panel.pawnExport = UI.CreateButton(panel, L["Export Pawn"], 100, Options.ExportPawn)
  panel.pawnExport:SetPoint("LEFT", panel.pawnImport, "RIGHT", 4, 0)
  panel.exportChar = UI.CreateButton(panel, L["Export character"], 120, Options.ExportCharacter)
  panel.exportChar:SetPoint("LEFT", panel.pawnExport, "RIGHT", 4, 0)

  -- Weights
  panel.weightsLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  panel.weightsLabel:SetPoint("TOPLEFT", panel.pawnLabel, "BOTTOMLEFT", 0, -20)
  panel.weightsLabel:SetText(L["Stat weights"])
  panel.reset = UI.CreateButton(panel, L["Reset to default"], 120, Options.ResetWeights)
  panel.reset:SetPoint("LEFT", panel.weightsLabel, "RIGHT", 10, 0)

  panel.scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  panel.scroll:SetPoint("TOPLEFT", panel.weightsLabel, "BOTTOMLEFT", 0, -8)
  panel.scroll:SetPoint("BOTTOMRIGHT", -30, 12)
  panel.content = CreateFrame("Frame", nil, panel.scroll)
  panel.content:SetSize(560, 400)
  panel.scroll:SetScrollChild(panel.content)
  panel.sliders = {}

  panel:SetScript("OnShow", function() Options.Refresh() end)
  panel.okay = function() end
  panel.cancel = function() end
  panel.refresh = function() Options.Refresh() end
  return panel
end

function Options.Refresh()
  if not panel then return end
  local c, db = UI.CharDB(), UI.DB()
  local p = UI.Player()
  panel.spec:SetLabel(c.specOverride and UI.SpecName() or L["Auto (talents)"] .. (p and p.spec and (" - " .. UI.SpecName()) or ""))
  panel.phase:SetLabel(tostring(db.phase or 5))
  panel.minimap:SetChecked(not db.minimap.hide)
  local tier = (CMM.Constants and CMM.Constants.TIER) or {}
  panel.lookahead:Set(c.lookahead or 2)
  panel.minutesPerQuest:Set(db.constants.minutesPerQuest or tier.minutesPerQuest or 10)
  panel.groupOverhead:Set(db.constants.groupOverhead or tier.groupOverhead or 15)
  panel.travel:Set(db.constants.travel or tier.travel or 15)
  panel.badgeGrind:Set(db.constants.badgeGrind or tier.badgeGrind or 180)
  panel.honorGrind:Set(db.constants.honorGrind or tier.honorGrind or 240)
  panel.arenaGrind:Set(db.constants.arenaGrind or tier.arenaGrind or 900)
  panel.repPerRank:Set(db.constants.repPerRank or tier.repPerRank or 180)
  panel.auction:Set(db.constants.auction or tier.auction or 10)
  local rnd = db.random or {}
  local rndDefaults = (CMM.Constants and CMM.Constants.RANDOM) or {}
  panel.maxAuctionRows:Set(rnd.maxAuctionRows or rndDefaults.maxAuctionRows or 8)
  panel.minChancePct:Set(rnd.minChancePct or rndDefaults.minChancePct or 0.5)

  local defaults = Options.DefaultWeights()
  local active = UI.Weights()
  local merged = {}
  for k, v in pairs(defaults) do merged[k] = v end
  for k, v in pairs(active) do merged[k] = v end
  local keys = orderedKeys(merged)
  local col, row = 0, 0
  for i, key in ipairs(keys) do
    local s = panel.sliders[i]
    if not s then
      s = makeSlider(panel.content, key, 0, 1, 0.05, function(v, self) Options.SetWeight(self.key, v) end)
      panel.sliders[i] = s
    end
    s.key = key
    local def = tonumber(defaults[key]) or 0
    local maxV = math.max(def * 2, ratingKey(key) and 10 or 1)
    s:SetMinMaxValues(0, maxV)
    s:SetValueStep(ratingKey(key) and 0.5 or 0.05)
    s.label:SetText(ratingKey(key) and (key .. " " .. L["(per 1 %)"]) or key)
    s:Set(tonumber(active[key]) or def)
    s:ClearAllPoints()
    s:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 10 + col * 270, -24 - row * 44)
    s:Show()
    col = col + 1
    if col == 2 then col = 0 row = row + 1 end
  end
  for i = #keys + 1, #panel.sliders do panel.sliders[i]:Hide() end
  panel.content:SetHeight(math.max(100, (row + 1) * 44 + 30))
end

function Options.Register()
  if panel then return panel end
  buildPanel()
  if Settings and Settings.RegisterCanvasLayoutCategory then
    category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    if category and Settings.RegisterAddOnCategory then Settings.RegisterAddOnCategory(category) end
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
  return panel
end

function Options.Open()
  Options.Register()
  if category and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(category.GetID and category:GetID() or category)
  elseif InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel) -- classic quirk: first call only opens the frame
  else
    panel:Show()
  end
end

-- Register on login so the panel exists in the options list even if the window was never opened.
local reg = CreateFrame("Frame")
reg:RegisterEvent("PLAYER_LOGIN")
reg:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_LOGIN")
  Options.Register()
end)
if CMM.On then
  CMM.On("WEIGHTS_CHANGED", function() if panel and panel:IsShown() then Options.Refresh() end end)
  CMM.On("PLAYER_CHANGED", function() if panel and panel:IsShown() then Options.Refresh() end end)
end
