-- Main window: slot strip, result list, filter bar. Plain frames, event driven, no OnUpdate.
-- Every CMM.* logic call is guarded at call time so the UI files also load standalone in tests.
local _, CMM = ...
local UI = CMM.UI
local L = CMM.L

UI.WIDTH, UI.HEIGHT = 820, 560
UI.ROW_HEIGHT = 36
UI.HEADER_HEIGHT = 22
UI.DETAIL_LINE = 14
UI.STRIP_WIDTH = 150
UI.FILTER_HEIGHT = 62
UI.LIST_HEIGHT = UI.HEIGHT - 30 - UI.FILTER_HEIGHT - 4 - 14
UI.TIER_COLORS = {
  [1] = { 0.30, 0.85, 0.30 }, [2] = { 0.55, 0.85, 0.35 }, [3] = { 0.95, 0.80, 0.25 },
  [4] = { 0.95, 0.50, 0.20 }, [5] = { 0.60, 0.60, 0.95 },
}
UI.SLOT_ORDER = { "HEAD", "NECK", "SHOULDER", "BACK", "CHEST", "WRIST", "HANDS", "WAIST", "LEGS", "FEET",
  "FINGER", "TRINKET", "MAINHAND", "OFFHAND", "RANGED" }
UI.SLOT_NAMES = {
  HEAD = "Head", NECK = "Neck", SHOULDER = "Shoulder", BACK = "Back", CHEST = "Chest", WRIST = "Wrist",
  HANDS = "Hands", WAIST = "Waist", LEGS = "Legs", FEET = "Feet", FINGER = "Ring", TRINKET = "Trinket",
  MAINHAND = "Main hand", OFFHAND = "Off hand", RANGED = "Ranged",
}
UI.SLOT_EMPTY_ICON = {
  HEAD = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Head", NECK = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Neck",
  SHOULDER = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Shoulder", BACK = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest",
  CHEST = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest", WRIST = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Wrists",
  HANDS = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Hands", WAIST = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Waist",
  LEGS = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Legs", FEET = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Feet",
  FINGER = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Finger", TRINKET = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket",
  MAINHAND = "Interface\\PaperDoll\\UI-PaperDoll-Slot-MainHand", OFFHAND = "Interface\\PaperDoll\\UI-PaperDoll-Slot-SecondaryHand",
  RANGED = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Ranged",
}
UI.SOURCE_TYPES = { "Q", "B", "R", "N", "T", "G", "V", "K", "W" }
UI.SOURCE_NAMES = {
  Q = "Quest", B = "Boss drop", R = "Rare spawn", N = "Named mob", T = "Dungeon trash", G = "Chest",
  V = "Vendor", K = "Crafted", W = "World drop (BoE)",
}
UI.SORTS = { { "eff", "Efficiency" }, { "gain", "Score gain" }, { "fast", "Fastest" }, { "value", "Value over time" } }

UI.state = { slot = "HEAD", entries = {}, offset = 1, expanded = nil, slotSummary = {}, loading = false }

---------------------------------------------------------------------------------------------------
-- Guarded access to logic modules and SavedVariables
---------------------------------------------------------------------------------------------------
local function call(tbl, fn, ...)
  local f = tbl and tbl[fn]
  if type(f) == "function" then return f(...) end
  return nil
end
UI.Call = call

function UI.DB()
  _G.CasualMinMaxerDB = _G.CasualMinMaxerDB or {}
  local db = _G.CasualMinMaxerDB
  db.ui = db.ui or {}
  db.minimap = db.minimap or { hide = false }
  db.constants = db.constants or {}
  db.phase = db.phase or 5
  return db
end

function UI.CharDB()
  _G.CasualMinMaxerCharDB = _G.CasualMinMaxerCharDB or {}
  local c = _G.CasualMinMaxerCharDB
  c.weights = c.weights or {}
  c.hidden = c.hidden or {}
  c.lookahead = c.lookahead or 2
  c.lastSlot = c.lastSlot or "HEAD"
  if not c.filters then
    c.filters = { sources = {}, tiers = { [1] = true, [2] = true, [3] = true }, dungeon = nil, zone = nil,
      groupOnly = false, armor = "all", special = true, sidegrades = false, sort = "eff" }
    for _, s in ipairs(UI.SOURCE_TYPES) do c.filters.sources[s] = (s ~= "W") end
  end
  c.filters.sources = c.filters.sources or {}
  c.filters.tiers = c.filters.tiers or { [1] = true, [2] = true, [3] = true }
  return c
end

function UI.Player()
  return call(CMM.Player, "Get")
end

function UI.Spec()
  local c = UI.CharDB()
  local p = UI.Player()
  return c.specOverride or (p and p.spec) or "UNKNOWN"
end

function UI.SpecName()
  local p = UI.Player()
  local spec = UI.Spec()
  local specs = p and call(CMM.Weights, "Specs", p.class) or {}
  for _, s in ipairs(specs) do
    if s.key == spec then return s.name end
  end
  return spec
end

function UI.Weights()
  return call(CMM.Core, "ActiveWeights") or {}
end

function UI.Ctx(slotKey)
  local p = UI.Player()
  return { level = p and p.level or 1, weights = UI.Weights(), class = p and p.class, spec = UI.Spec(), slotKey = slotKey }
end

function UI.QueryOpts()
  local c = UI.CharDB()
  local f = c.filters
  return {
    filters = f, sort = f.sort or "eff", sidegrades = f.sidegrades and true or false, lookahead = c.lookahead or 2,
    dungeon = f.dungeon, zone = f.zone, showSpecial = f.special ~= false,
  }
end

function UI.DataReady()
  local ok = call(CMM.Core, "EnsureData")
  if ok == nil then ok = call(CMM.Data, "Load") end
  return ok and true or false
end

---------------------------------------------------------------------------------------------------
-- Formatting helpers (shared with Rows / Minimap / Options)
---------------------------------------------------------------------------------------------------
function UI.FormatMoney(copper)
  copper = tonumber(copper) or 0
  local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
  if g > 0 then return string.format("%d|cffffd700g|r %d|cffc7c7cfs|r", g, s) end
  if s > 0 then return string.format("%d|cffc7c7cfs|r %d|cffeda55fc|r", s, c) end
  return string.format("%d|cffeda55fc|r", c)
end

function UI.FormatMinutes(min)
  min = tonumber(min) or 0
  if min >= 120 then return string.format("%.1f h", min / 60) end
  if min >= 60 then return string.format("%d h %d min", math.floor(min / 60), math.floor(min % 60)) end
  return string.format("%d min", math.floor(min + 0.5))
end

function UI.FormatGain(gain, pct)
  gain = tonumber(gain) or 0
  pct = tonumber(pct) or 0
  local color = gain > 0 and "|cff33ff33" or (gain < 0 and "|cffff5555" or "|cffaaaaaa")
  return string.format("%s%+.0f (%+.0f %%)|r", color, gain, pct)
end

function UI.TierColor(tier)
  local c = UI.TIER_COLORS[tier] or { 0.7, 0.7, 0.7 }
  return c[1], c[2], c[3]
end

function UI.QualityColor(quality)
  local col = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1]
  if col then return col.r or 1, col.g or 1, col.b or 1 end
  return 1, 1, 1
end

function UI.SlotName(key)
  return L[UI.SLOT_NAMES[key] or key]
end

---------------------------------------------------------------------------------------------------
-- Widget helpers
---------------------------------------------------------------------------------------------------
function UI.CreateButton(parent, text, width, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width or 90, 22)
  b:SetText(text)
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

function UI.CreateCheck(parent, label, onClick)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(22, 22)
  local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("LEFT", cb, "RIGHT", 0, 0)
  fs:SetText(label)
  cb.label = fs
  cb:SetScript("OnClick", function(self) if onClick then onClick(self, self:GetChecked() and true or false) end end)
  return cb
end

function UI.CreateDropdown(parent, width, initFn)
  local dd = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
  if UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(dd, width or 120) end
  if UIDropDownMenu_Initialize and initFn then UIDropDownMenu_Initialize(dd, initFn) end
  dd.SetLabel = function(self, text) if UIDropDownMenu_SetText then UIDropDownMenu_SetText(self, text) end end
  return dd
end

function UI.MenuInfo()
  local info = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo() or {}
  return info
end

local copyBox
function UI.ShowCopyBox(title, text)
  if not copyBox then
    copyBox = CreateFrame("Frame", "CasualMinMaxerCopyBox", UIParent, "BackdropTemplate")
    copyBox:SetSize(420, 120)
    copyBox:SetPoint("CENTER")
    copyBox:SetFrameStrata("DIALOG")
    copyBox:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 } })
    copyBox:EnableMouse(true)
    copyBox:SetMovable(true)
    copyBox:RegisterForDrag("LeftButton")
    copyBox:SetScript("OnDragStart", copyBox.StartMoving)
    copyBox:SetScript("OnDragStop", copyBox.StopMovingOrSizing)
    copyBox.title = copyBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    copyBox.title:SetPoint("TOP", 0, -16)
    copyBox.edit = CreateFrame("EditBox", nil, copyBox, "InputBoxTemplate")
    copyBox.edit:SetSize(380, 24)
    copyBox.edit:SetPoint("TOP", 0, -40)
    copyBox.edit:SetAutoFocus(false)
    copyBox.edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() copyBox:Hide() end)
    copyBox.edit:SetScript("OnTextChanged", function(self) if self:GetText() ~= copyBox.text then self:SetText(copyBox.text or "") end end)
    copyBox.hint = copyBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    copyBox.hint:SetPoint("TOP", copyBox.edit, "BOTTOM", 0, -6)
    copyBox.hint:SetText(L["Ctrl-C to copy, Escape to close"])
    local close = UI.CreateButton(copyBox, L["Close"], 80, function() copyBox:Hide() end)
    close:SetPoint("BOTTOM", 0, 14)
    if UISpecialFrames then table.insert(UISpecialFrames, "CasualMinMaxerCopyBox") end
  end
  copyBox.title:SetText(title or "")
  copyBox.text = text or ""
  copyBox.edit:SetText(copyBox.text)
  copyBox:Show()
  copyBox.edit:SetFocus()
  copyBox.edit:HighlightText()
end

---------------------------------------------------------------------------------------------------
-- Frame construction
---------------------------------------------------------------------------------------------------
local frame

local function savePosition()
  if not frame then return end
  local db = UI.DB()
  local _, _, _, x, y = frame:GetPoint()
  db.ui.x, db.ui.y = x, y
end

local function restorePosition()
  local db = UI.DB()
  frame:ClearAllPoints()
  if db.ui.x and db.ui.y then
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.ui.x, db.ui.y)
  else
    frame:SetPoint("CENTER")
  end
  if db.ui.scale then frame:SetScale(db.ui.scale) end
end

local function buildSlotStrip(parent)
  local strip = CreateFrame("Frame", nil, parent)
  strip:SetPoint("TOPLEFT", 14, -32)
  strip:SetSize(UI.STRIP_WIDTH, UI.HEIGHT - 50)
  strip.buttons = {}
  local y = 0
  for _, key in ipairs(UI.SLOT_ORDER) do
    local b = CreateFrame("Button", nil, strip)
    b:SetSize(UI.STRIP_WIDTH, 32)
    b:SetPoint("TOPLEFT", 0, -y)
    b.slot = key
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(28, 28)
    b.icon:SetPoint("LEFT", 2, 0)
    b.icon:SetTexture(UI.SLOT_EMPTY_ICON[key])
    b.name = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.name:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 6, -1)
    b.name:SetText(UI.SlotName(key))
    b.score = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.score:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMRIGHT", 6, 1)
    b.badge = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.badge:SetPoint("RIGHT", -6, 0)
    b.badge:SetTextColor(0.3, 1, 0.3)
    b.highlight = b:CreateTexture(nil, "BACKGROUND")
    b.highlight:SetAllPoints()
    b.highlight:SetColorTexture(1, 1, 1, 0.12)
    b.highlight:Hide()
    b.weak = b:CreateTexture(nil, "BACKGROUND")
    b.weak:SetAllPoints()
    b.weak:SetColorTexture(1, 0.3, 0.2, 0.18)
    b.weak:Hide()
    b:SetScript("OnClick", function(self) UI.SelectSlot(self.slot) end)
    b:SetScript("OnEnter", function(self)
      local sum = UI.state.slotSummary[self.slot]
      if not sum then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(UI.SlotName(self.slot))
      if sum.equippedId then
        local eq = call(CMM.Data, "Item", sum.equippedId)
        GameTooltip:AddDoubleLine(L["Equipped"], eq and eq.name or ("#" .. sum.equippedId), 1, 1, 1, 1, 1, 1)
      end
      GameTooltip:AddDoubleLine(L["Equipped score"], string.format("%.0f", sum.equippedScore or 0), 1, 1, 1, 1, 1, 1)
      GameTooltip:AddDoubleLine(L["Upgrades"], tostring(sum.count or 0), 1, 1, 1, 1, 1, 1)
      if sum.top then
        local name = sum.top.item and sum.top.item.name or ""
        GameTooltip:AddDoubleLine(L["Best"], name .. " " .. UI.FormatGain(sum.top.gain, sum.top.gainPct), 1, 1, 1, 1, 1, 1)
      end
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    strip.buttons[key] = b
    y = y + 33
  end
  return strip
end

local function buildFilterBar(parent)
  local bar = CreateFrame("Frame", nil, parent)
  bar:SetPoint("TOPLEFT", UI.STRIP_WIDTH + 22, -30)
  bar:SetPoint("TOPRIGHT", -14, -30)
  bar:SetHeight(UI.FILTER_HEIGHT)
  local f = UI.CharDB().filters

  -- Row 1: sort, sources, tiers, dungeon
  bar.sort = UI.CreateDropdown(bar, 120, function(_, level)
    for _, s in ipairs(UI.SORTS) do
      local info = UI.MenuInfo()
      info.text = L[s[2]]
      info.checked = (UI.CharDB().filters.sort == s[1])
      info.func = function() UI.CharDB().filters.sort = s[1] UI.UpdateFilterLabels() UI.Refresh() end
      if UIDropDownMenu_AddButton then UIDropDownMenu_AddButton(info, level) end
    end
  end)
  bar.sort:SetPoint("TOPLEFT", -16, 0)

  bar.sources = UI.CreateDropdown(bar, 110, function(_, level)
    for _, code in ipairs(UI.SOURCE_TYPES) do
      local info = UI.MenuInfo()
      info.text = L[UI.SOURCE_NAMES[code]]
      info.isNotRadio = true
      info.keepShownOnClick = true
      info.checked = UI.CharDB().filters.sources[code] and true or false
      info.func = function(_, _, _, checked)
        UI.CharDB().filters.sources[code] = checked and true or false
        UI.Refresh()
      end
      if UIDropDownMenu_AddButton then UIDropDownMenu_AddButton(info, level) end
    end
  end)
  bar.sources:SetPoint("LEFT", bar.sort, "RIGHT", -24, 0)
  bar.sources:SetLabel(L["Sources"])

  bar.tierLabel = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  bar.tierLabel:SetPoint("LEFT", bar.sources, "RIGHT", -8, 2)
  bar.tierLabel:SetText(L["Tier"])
  bar.tiers = {}
  local prev = bar.tierLabel
  for t = 1, 5 do
    local cb = UI.CreateCheck(bar, tostring(t), function(_, checked)
      UI.CharDB().filters.tiers[t] = checked
      UI.Refresh()
    end)
    cb:SetPoint("LEFT", prev, "RIGHT", t == 1 and 4 or 10, t == 1 and -2 or 0)
    cb.label:SetTextColor(UI.TierColor(t))
    bar.tiers[t] = cb
    prev = cb
  end

  bar.dungeon = UI.CreateDropdown(bar, 150, function(_, level)
    local info = UI.MenuInfo()
    info.text = L["No dungeon (upgrades for a slot)"]
    info.checked = (UI.CharDB().filters.dungeon == nil)
    info.func = function() UI.CharDB().filters.dungeon = nil UI.UpdateFilterLabels() UI.Refresh() end
    if UIDropDownMenu_AddButton then UIDropDownMenu_AddButton(info, level) end
    for _, d in ipairs(UI.DungeonList()) do
      local di = UI.MenuInfo()
      di.text = string.format("%s (%d-%d)", d.name, d.min or 0, d.max or 70)
      di.checked = (UI.CharDB().filters.dungeon == d.map)
      di.func = function() UI.CharDB().filters.dungeon = d.map UI.UpdateFilterLabels() UI.Refresh() end
      if UIDropDownMenu_AddButton then UIDropDownMenu_AddButton(di, level) end
    end
  end)
  bar.dungeon:SetPoint("LEFT", prev, "RIGHT", 4, 0)

  -- Row 2: zone, group, armor, lookahead, special, sidegrades
  bar.zone = UI.CreateCheck(bar, L["Current zone only"], function(_, checked)
    UI.CharDB().filters.zone = checked and "current" or nil
    UI.Refresh()
  end)
  bar.zone:SetPoint("TOPLEFT", 4, -30)
  bar.group = UI.CreateCheck(bar, L["Solo only"], function(_, checked)
    UI.CharDB().filters.groupOnly = checked
    UI.Refresh()
  end)
  bar.group:SetPoint("LEFT", bar.zone.label, "RIGHT", 12, 0)
  bar.armor = UI.CreateCheck(bar, L["Best armor type only"], function(_, checked)
    UI.CharDB().filters.armor = checked and "best" or "all"
    UI.Refresh()
  end)
  bar.armor:SetPoint("LEFT", bar.group.label, "RIGHT", 12, 0)
  bar.special = UI.CreateCheck(bar, L["Special effects"], function(_, checked)
    UI.CharDB().filters.special = checked
    UI.Refresh()
  end)
  bar.special:SetPoint("LEFT", bar.armor.label, "RIGHT", 12, 0)
  bar.sidegrades = UI.CreateCheck(bar, L["Sidegrades"], function(_, checked)
    UI.CharDB().filters.sidegrades = checked
    UI.Refresh()
  end)
  bar.sidegrades:SetPoint("LEFT", bar.special.label, "RIGHT", 12, 0)
  bar.lookahead = UI.CreateDropdown(bar, 60, function(_, level)
    for n = 0, 5 do
      local info = UI.MenuInfo()
      info.text = tostring(n)
      info.checked = (UI.CharDB().lookahead == n)
      info.func = function() UI.CharDB().lookahead = n UI.UpdateFilterLabels() UI.Refresh() end
      if UIDropDownMenu_AddButton then UIDropDownMenu_AddButton(info, level) end
    end
  end)
  bar.lookahead:SetPoint("LEFT", bar.sidegrades.label, "RIGHT", 0, -2)
  bar.lookaheadLabel = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  bar.lookaheadLabel:SetPoint("LEFT", bar.lookahead, "RIGHT", -10, 2)
  bar.lookaheadLabel:SetText(L["levels ahead"])

  bar.filters = f
  return bar
end

local function buildList(parent)
  local list = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  list:SetPoint("TOPLEFT", UI.STRIP_WIDTH + 22, -30 - UI.FILTER_HEIGHT - 4)
  list:SetPoint("BOTTOMRIGHT", -30, 14)
  list:SetHeight(UI.LIST_HEIGHT)
  list:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", tile = true, tileSize = 16 })
  list:SetBackdropColor(0, 0, 0, 0.35)
  list:EnableMouseWheel(true)
  list:SetScript("OnMouseWheel", function(_, delta)
    UI.Scroll(-delta * 3)
  end)
  list.rows = {}
  list.details = {}

  local slider = CreateFrame("Slider", nil, parent)
  slider:SetOrientation("VERTICAL")
  slider:SetPoint("TOPLEFT", list, "TOPRIGHT", 4, -8)
  slider:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 4, 8)
  slider:SetWidth(12)
  slider:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
  slider:SetMinMaxValues(1, 1)
  slider:SetValueStep(1)
  slider:SetObeyStepOnDrag(true)
  slider:SetValue(1)
  slider:SetScript("OnValueChanged", function(_, value)
    local v = math.floor(value + 0.5)
    if v ~= UI.state.offset then
      UI.state.offset = v
      UI.Layout()
    end
  end)
  list.slider = slider

  list.status = list:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  list.status:SetPoint("CENTER")
  list.status:SetText("")
  return list
end

function UI.GetFrame()
  if frame then return frame end
  frame = CreateFrame("Frame", "CasualMinMaxerFrame", UIParent, "BackdropTemplate")
  frame:SetSize(UI.WIDTH, UI.HEIGHT)
  frame:SetFrameStrata("HIGH")
  frame:SetToplevel(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() savePosition() end)
  frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 } })
  frame:Hide()

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.title:SetPoint("TOP", 0, -12)
  frame.title:SetText(L["CMM_TITLE"])
  frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.subtitle:SetPoint("TOPLEFT", 16, -16)
  frame.subtitle:SetText("")

  frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  frame.close:SetPoint("TOPRIGHT", -4, -4)
  frame.close:SetScript("OnClick", function() UI.Hide() end)

  frame.options = UI.CreateButton(frame, L["Options"], 70, function() UI.OpenOptions() end)
  frame.options:SetPoint("TOPRIGHT", -34, -8)

  frame.strip = buildSlotStrip(frame)
  frame.filter = buildFilterBar(frame)
  frame.list = buildList(frame)

  if UISpecialFrames then table.insert(UISpecialFrames, "CasualMinMaxerFrame") end
  restorePosition()
  return frame
end

---------------------------------------------------------------------------------------------------
-- Data helpers
---------------------------------------------------------------------------------------------------
function UI.DungeonList()
  local out = {}
  local D = _G.CasualMinMaxer_Data
  if D and D.dungeons then
    for map, d in pairs(D.dungeons) do
      out[#out + 1] = { map = map, name = d.name or tostring(map), min = d.min or 0, max = d.max or 70 }
    end
  end
  table.sort(out, function(a, b)
    if a.min ~= b.min then return a.min < b.min end
    return a.name < b.name
  end)
  return out
end

function UI.UpdateFilterLabels()
  if not frame then return end
  local c = UI.CharDB()
  local f = c.filters
  local bar = frame.filter
  for _, s in ipairs(UI.SORTS) do
    if s[1] == (f.sort or "eff") then bar.sort:SetLabel(L[s[2]]) end
  end
  bar.sources:SetLabel(L["Sources"])
  for t = 1, 5 do bar.tiers[t]:SetChecked(f.tiers[t] and true or false) end
  local dname = L["Slot upgrades"]
  if f.dungeon then
    local d = call(CMM.Data, "Dungeon", f.dungeon)
    dname = d and d.name or tostring(f.dungeon)
  end
  bar.dungeon:SetLabel(dname)
  bar.zone:SetChecked(f.zone == "current")
  bar.group:SetChecked(f.groupOnly and true or false)
  bar.armor:SetChecked(f.armor == "best")
  bar.special:SetChecked(f.special ~= false)
  bar.sidegrades:SetChecked(f.sidegrades and true or false)
  bar.lookahead:SetLabel(tostring(c.lookahead or 2))
end

-- Query every slot once to fill badges / scores and find the weakest slot. Results are cached by Query.
function UI.ComputeSlotSummary(player)
  local summary = {}
  local weakest, weakestGain = nil, 0
  for _, key in ipairs(UI.SLOT_ORDER) do
    local res = call(CMM.Query, "Run", key, player, UI.QueryOpts())
    if res then
      local rows = res.rows or {}
      local top = rows[1]
      summary[key] = { count = #rows, top = top, equippedScore = res.equippedScore, equippedId = res.equippedId }
      local gain = top and top.gain or 0
      if gain > weakestGain then weakest, weakestGain = key, gain end
    end
  end
  UI.state.slotSummary = summary
  UI.state.weakest = weakest
  return summary, weakest
end

function UI.WeakestSlot()
  return UI.state.weakest, UI.state.slotSummary[UI.state.weakest or ""]
end

local function equippedIcon(player, key)
  local eq = player and player.equipped and player.equipped[key]
  local id = type(eq) == "table" and eq[1] or eq
  if not id then return nil end
  if GetItemIcon then
    local icon = GetItemIcon(id)
    if icon then return icon end
  end
  if Item and Item.CreateFromItemID then
    local it = Item:CreateFromItemID(id)
    if it and it.GetItemIcon then
      local ic = it:GetItemIcon()
      if ic then return ic end
    end
  end
  return nil
end

function UI.UpdateStrip(player)
  if not frame then return end
  for key, b in pairs(frame.strip.buttons) do
    local sum = UI.state.slotSummary[key]
    b.icon:SetTexture(equippedIcon(player, key) or UI.SLOT_EMPTY_ICON[key])
    b.score:SetText(sum and sum.equippedScore and string.format("%.0f", sum.equippedScore) or "")
    b.badge:SetText(sum and sum.count and sum.count > 0 and tostring(sum.count) or "")
    if key == UI.state.slot then b.highlight:Show() else b.highlight:Hide() end
    if key == UI.state.weakest then b.weak:Show() else b.weak:Hide() end
  end
end

---------------------------------------------------------------------------------------------------
-- Entry list (rows + headers + expanded detail entries)
---------------------------------------------------------------------------------------------------
local function buildEntries(player)
  local entries = {}
  local f = UI.CharDB().filters
  if f.dungeon then
    local byBoss = call(CMM.Query, "RunDungeon", f.dungeon, player, UI.QueryOpts()) or {}
    local d = call(CMM.Data, "Dungeon", f.dungeon)
    local order = d and d.bosses or {}
    local seen = {}
    local function addBoss(entry)
      seen[entry] = true
      local rows = byBoss[entry]
      if not rows or #rows == 0 then return end
      local npc = call(CMM.Data, "Npc", entry)
      entries[#entries + 1] = { header = true, text = npc and npc.name or ("NPC " .. tostring(entry)), count = #rows }
      for _, row in ipairs(rows) do entries[#entries + 1] = { row = row } end
    end
    for _, entry in ipairs(order) do addBoss(entry) end
    for entry in pairs(byBoss) do if not seen[entry] then addBoss(entry) end end
  else
    local res = call(CMM.Query, "Run", UI.state.slot, player, UI.QueryOpts())
    for _, row in ipairs(res and res.rows or {}) do entries[#entries + 1] = { row = row } end
  end
  -- insert the detail entry after the expanded row
  if UI.state.expanded then
    for i, e in ipairs(entries) do
      if e.row and e.row.id == UI.state.expanded then
        table.insert(entries, i + 1, { detail = true, row = e.row })
        break
      end
    end
  end
  return entries
end

function UI.EntryHeight(e)
  if e.header then return UI.HEADER_HEIGHT end
  if e.detail then
    local Rows = UI.Rows
    local lines = Rows and Rows.DetailLines and Rows.DetailLines(e.row, UI.Player()) or {}
    return 10 + math.max(1, #lines) * UI.DETAIL_LINE + 22
  end
  return UI.ROW_HEIGHT
end

function UI.Scroll(delta)
  local n = #UI.state.entries
  local off = math.max(1, math.min(UI.state.offset + delta, math.max(1, n)))
  if off ~= UI.state.offset then
    UI.state.offset = off
    if frame then frame.list.slider:SetValue(off) end
    UI.Layout()
  end
end

function UI.ToggleExpand(itemId)
  if UI.state.expanded == itemId then UI.state.expanded = nil else UI.state.expanded = itemId end
  UI.state.entries = buildEntries(UI.Player())
  UI.Layout()
end

-- Place recycled widgets for the visible window of entries starting at state.offset.
function UI.Layout()
  if not frame or not frame:IsShown() then return end
  local list = frame.list
  local Rows = UI.Rows
  local entries = UI.state.entries or {}
  local n = #entries
  list.slider:SetMinMaxValues(1, math.max(1, n))
  if UI.state.offset > math.max(1, n) then UI.state.offset = math.max(1, n) end
  for _, w in ipairs(list.rows) do w:Hide() end
  for _, w in ipairs(list.details) do w:Hide() end
  local avail = list:GetHeight() - 8
  local y, ri, di = 4, 0, 0
  local ctx = UI.Ctx(UI.state.slot)
  local player = UI.Player()
  for i = UI.state.offset, n do
    local e = entries[i]
    local h = UI.EntryHeight(e)
    if y + h > avail then break end
    local w
    if e.detail then
      di = di + 1
      w = list.details[di]
      if not w then
        w = Rows and Rows.CreateDetail and Rows.CreateDetail(list) or CreateFrame("Frame", nil, list)
        list.details[di] = w
      end
      w:SetHeight(h)
      if Rows and Rows.FillDetail then Rows.FillDetail(w, e.row, player) end
    else
      ri = ri + 1
      w = list.rows[ri]
      if not w then
        w = Rows and Rows.Create and Rows.Create(list) or CreateFrame("Button", nil, list)
        list.rows[ri] = w
      end
      w:SetHeight(h)
      if e.header then
        if Rows and Rows.FillHeader then Rows.FillHeader(w, e.text, e.count) end
      elseif Rows and Rows.Fill then
        Rows.Fill(w, e.row, ctx, UI.state.expanded == e.row.id)
      end
    end
    w:ClearAllPoints()
    w:SetPoint("TOPLEFT", list, "TOPLEFT", 4, -y)
    w:SetPoint("TOPRIGHT", list, "TOPRIGHT", -4, -y)
    w:Show()
    y = y + h
  end
  if n == 0 then
    list.status:SetText(UI.state.loading and L["Loading data..."] or L["No upgrades found for this slot with the current filters."])
    list.status:Show()
  else
    list.status:Hide()
  end
end

---------------------------------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------------------------------
function UI.SelectSlot(slotKey)
  if slotKey and UI.SLOT_NAMES[slotKey] then
    UI.state.slot = slotKey
    UI.CharDB().lastSlot = slotKey
    UI.state.expanded = nil
    UI.state.offset = 1
  end
  UI.Refresh()
end

function UI.Refresh()
  if not frame or not frame:IsShown() then return end
  if not UI.DataReady() then
    UI.state.loading = true
    UI.state.entries = {}
    frame.subtitle:SetText(L["Loading data..."])
    UI.Layout()
    return
  end
  UI.state.loading = false
  local player = UI.Player()
  local specName = UI.SpecName()
  frame.subtitle:SetText(player and string.format("%s %s %d - %s", player.class or "", specName or "", player.level or 0,
    UI.SlotName(UI.state.slot)) or "")
  UI.UpdateFilterLabels()
  UI.ComputeSlotSummary(player)
  UI.UpdateStrip(player)
  UI.state.entries = buildEntries(player)
  if frame.list.slider then frame.list.slider:SetValue(UI.state.offset) end
  UI.Layout()
end

function UI.Show(slotKey)
  local f = UI.GetFrame()
  if slotKey and UI.SLOT_NAMES[slotKey] then
    UI.state.slot = slotKey
    UI.CharDB().lastSlot = slotKey
  elseif not slotKey then
    UI.state.slot = UI.CharDB().lastSlot or "HEAD"
  end
  UI.state.expanded = nil
  UI.state.offset = 1
  f:Show()
  UI.Refresh()
end

function UI.Hide()
  if frame then frame:Hide() end
end

function UI.Toggle(slotKey)
  if frame and frame:IsShown() and not slotKey then UI.Hide() else UI.Show(slotKey) end
end

function UI.IsShown()
  return frame and frame:IsShown() or false
end

function UI.OpenOptions()
  if UI.Options and UI.Options.Open then UI.Options.Open() end
end

-- Resolve a slot key from user input such as "head", "ring", "mh", "weapon".
function UI.ParseSlot(text)
  if not text or text == "" then return nil end
  text = string.upper(text)
  if UI.SLOT_NAMES[text] then return text end
  local aliases = { RING = "FINGER", RINGS = "FINGER", FINGERS = "FINGER", TRINKETS = "TRINKET", MH = "MAINHAND",
    WEAPON = "MAINHAND", MAIN = "MAINHAND", OH = "OFFHAND", OFF = "OFFHAND", SHIELD = "OFFHAND", BOW = "RANGED",
    GUN = "RANGED", WAND = "RANGED", CLOAK = "BACK", HELM = "HEAD", BELT = "WAIST", BOOTS = "FEET", GLOVES = "HANDS",
    BRACERS = "WRIST", BRACER = "WRIST", PANTS = "LEGS", SHOULDERS = "SHOULDER", RELIC = "RANGED" }
  return aliases[text]
end

---------------------------------------------------------------------------------------------------
-- Ad-hoc item evaluation (tooltips, quest rewards): data-pack record when present, else client stats
---------------------------------------------------------------------------------------------------
UI.EQUIPLOC_TO_INV = {
  INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_BODY = 4, INVTYPE_CHEST = 5, INVTYPE_WAIST = 6,
  INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_FINGER = 11, INVTYPE_TRINKET = 12,
  INVTYPE_WEAPON = 13, INVTYPE_SHIELD = 14, INVTYPE_RANGED = 15, INVTYPE_CLOAK = 16, INVTYPE_2HWEAPON = 17,
  INVTYPE_BAG = 18, INVTYPE_TABARD = 19, INVTYPE_ROBE = 20, INVTYPE_WEAPONMAINHAND = 21, INVTYPE_WEAPONOFFHAND = 22,
  INVTYPE_HOLDABLE = 23, INVTYPE_AMMO = 24, INVTYPE_THROWN = 25, INVTYPE_RANGEDRIGHT = 26, INVTYPE_QUIVER = 27,
  INVTYPE_RELIC = 28,
}
UI.INV_TO_SLOT = {
  [1] = "HEAD", [2] = "NECK", [3] = "SHOULDER", [5] = "CHEST", [20] = "CHEST", [6] = "WAIST", [7] = "LEGS", [8] = "FEET",
  [9] = "WRIST", [10] = "HANDS", [16] = "BACK", [11] = "FINGER", [12] = "TRINKET", [13] = "MAINHAND", [17] = "MAINHAND",
  [21] = "MAINHAND", [22] = "OFFHAND", [14] = "OFFHAND", [23] = "OFFHAND", [15] = "RANGED", [25] = "RANGED",
  [26] = "RANGED", [28] = "RANGED",
}
UI.ITEM_MOD_MAP = {
  ITEM_MOD_STRENGTH_SHORT = "STR", ITEM_MOD_AGILITY_SHORT = "AGI", ITEM_MOD_STAMINA_SHORT = "STA",
  ITEM_MOD_INTELLECT_SHORT = "INT", ITEM_MOD_SPIRIT_SHORT = "SPI", RESISTANCE0_NAME = "ARMOR",
  ITEM_MOD_ATTACK_POWER_SHORT = "AP", ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "RAP", ITEM_MOD_FERAL_ATTACK_POWER_SHORT = "FAP",
  ITEM_MOD_SPELL_POWER_SHORT = "SP", ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "SP", ITEM_MOD_SPELL_HEALING_DONE_SHORT = "HEAL",
  ITEM_MOD_MANA_REGENERATION_SHORT = "MP5", ITEM_MOD_HEALTH_REGENERATION_SHORT = "HP5",
  ITEM_MOD_BLOCK_VALUE_SHORT = "BLOCKV", ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "ARP",
  ITEM_MOD_HIT_RATING_SHORT = "HIT", ITEM_MOD_HIT_MELEE_RATING_SHORT = "HIT", ITEM_MOD_HIT_RANGED_RATING_SHORT = "HIT",
  ITEM_MOD_HIT_SPELL_RATING_SHORT = "SPHIT", ITEM_MOD_CRIT_RATING_SHORT = "CRIT", ITEM_MOD_CRIT_MELEE_RATING_SHORT = "CRIT",
  ITEM_MOD_CRIT_RANGED_RATING_SHORT = "CRIT", ITEM_MOD_CRIT_SPELL_RATING_SHORT = "SPCRIT",
  ITEM_MOD_HASTE_RATING_SHORT = "HASTE", ITEM_MOD_HASTE_MELEE_RATING_SHORT = "HASTE",
  ITEM_MOD_HASTE_RANGED_RATING_SHORT = "HASTE", ITEM_MOD_HASTE_SPELL_RATING_SHORT = "SPHASTE",
  ITEM_MOD_EXPERTISE_RATING_SHORT = "EXP", ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "DEF",
  ITEM_MOD_DODGE_RATING_SHORT = "DODGE", ITEM_MOD_PARRY_RATING_SHORT = "PARRY", ITEM_MOD_BLOCK_RATING_SHORT = "BLOCK",
  ITEM_MOD_RESILIENCE_RATING_SHORT = "RES",
}
local SOCKET_KEYS = { EMPTY_SOCKET_RED = "R", EMPTY_SOCKET_YELLOW = "Y", EMPTY_SOCKET_BLUE = "B", EMPTY_SOCKET_META = "M" }

-- Map a GetItemStats table to §2 keys (prefers the Validate module's mapper when it exists).
function UI.MapStats(raw)
  if not raw then return {}, "" end
  local mapped = call(CMM.Validate, "MapStats", raw)
  local sockets = ""
  for k, v in pairs(raw) do
    local col = SOCKET_KEYS[k]
    if col then sockets = sockets .. string.rep(col, tonumber(v) or 1) end
  end
  if mapped then return mapped, sockets end
  local stats = {}
  for k, v in pairs(raw) do
    local key = UI.ITEM_MOD_MAP[k]
    if key and tonumber(v) and tonumber(v) ~= 0 then stats[key] = (stats[key] or 0) + tonumber(v) end
  end
  return stats, sockets
end

function UI.ItemIdFromLink(link)
  if type(link) == "number" then return link end
  if type(link) ~= "string" then return nil end
  return tonumber(link:match("item:(%d+)"))
end

-- Returns an item record (§4.1 decoded shape) and whether it came from the data pack.
function UI.ItemFromLink(link)
  local id = UI.ItemIdFromLink(link)
  if not id then return nil end
  local ok, item = pcall(function() return call(CMM.Data, "Item", id) end)
  if ok and item then return item, true end
  if not GetItemInfoInstant then return nil end
  local _, _, _, equipLoc, _, cls, sub = GetItemInfoInstant(id)
  local inv = UI.EQUIPLOC_TO_INV[equipLoc or ""]
  if not inv or not UI.INV_TO_SLOT[inv] then return nil end
  local getStats = (CMM.Compat and CMM.Compat.GetItemStats) or (C_Item and C_Item.GetItemStats) or GetItemStats
  local raw = getStats and getStats(type(link) == "string" and link or ("item:" .. id)) or nil
  local stats, sockets = UI.MapStats(raw)
  local name, _, quality, ilvl, req = nil, nil, 2, 1, 1
  if GetItemInfo then name, _, quality, ilvl, req = GetItemInfo(id) end
  return {
    id = id, name = name or ("item " .. id), inv = inv, cls = cls or 4, sub = sub or 0, q = quality or 2,
    ilvl = ilvl or 1, req = req or 1, classmask = 0, flags = 0, stats = stats, sockets = sockets, sbonus = 0,
    phase = 1, src = {},
  }, false
end

function UI.SlotForItem(item)
  local map = (CMM.Constants and CMM.Constants.INV_TO_SLOT) or UI.INV_TO_SLOT
  return map[item.inv] or UI.INV_TO_SLOT[item.inv]
end

-- Score an item record for the current character: score, gain, gainPct, slotKey (nil when not scorable)
function UI.EvaluateItem(item)
  if not item then return nil end
  local slotKey = UI.SlotForItem(item)
  if not slotKey then return nil end
  local player = UI.Player()
  local ctx = UI.Ctx(slotKey)
  local score = call(CMM.Scoring, "ScoreItem", item, ctx)
  if score == nil then return nil end
  local gain, gainPct = call(CMM.Scoring, "Gain", item, slotKey, ctx, player)
  return score, gain or 0, gainPct or 0, slotKey
end

-- Bus wiring: refresh when the character or settings change.
if CMM.On then
  CMM.On("PLAYER_CHANGED", function() if UI.IsShown() then UI.Refresh() end end)
  CMM.On("DATA_LOADED", function() if UI.IsShown() then UI.Refresh() end end)
  CMM.On("WEIGHTS_CHANGED", function() call(CMM.Query, "Invalidate") if UI.IsShown() then UI.Refresh() end end)
  CMM.On("SETTINGS_CHANGED", function() call(CMM.Query, "Invalidate") if UI.IsShown() then UI.Refresh() end end)
end
