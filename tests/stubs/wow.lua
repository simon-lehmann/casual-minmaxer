-- Minimal WoW API stub so the logic modules load and run under busted.
-- Only what the logic modules (Constants..Export, Core's SavedVariables handling) touch.
-- UI modules are not loaded in tests unless a spec sets CMM_TEST_ENV.ui = true.
local M = {}
_G.CMM_TEST_ENV = { ui = false }

-- Lua additions WoW provides
_G.bit = _G.bit or require("tests.stubs.bit")
_G.strsplit = function(delim, s, pieces)
  local out, n = {}, 0
  local pattern = "([^" .. delim:gsub("%W", "%%%0") .. "]*)"
  for piece in (s .. delim):gmatch(pattern .. delim:gsub("%W", "%%%0")) do
    n = n + 1
    out[n] = piece
    if pieces and n == pieces - 1 then break end
  end
  if pieces and n == pieces - 1 then
    local rest = s
    for i = 1, n do rest = rest:sub(#out[i] + 2) end
    out[n + 1] = rest
  end
  return unpack(out)
end
_G.strjoin = function(delim, ...) return table.concat({ ... }, delim) end
_G.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.tinsert, _G.tremove = table.insert, table.remove
_G.format = string.format
_G.strlower, _G.strupper = string.lower, string.upper
_G.floor, _G.ceil, _G.max, _G.min, _G.abs = math.floor, math.ceil, math.max, math.min, math.abs
_G.sort = table.sort
_G.tContains = function(t, v) for _, x in pairs(t) do if x == v then return true end end return false end
_G.CopyTable = function(t) local c = {} for k, v in pairs(t) do c[k] = type(v) == "table" and CopyTable(v) or v end return c end
_G.GetTime = function() return os.clock() end
_G.debugstack = function() return "" end
_G.geterrorhandler = function() return function(e) error(e) end end
_G.hooksecurefunc = function(tbl, name, fn)
  if type(tbl) == "string" then fn, name, tbl = name, tbl, _G end
  local orig = tbl[name]
  tbl[name] = function(...) local r = { orig(...) } fn(...) return unpack(r) end
end
_G.date = os.date
_G.time = os.time

-- Client identity
M.build = { version = "2.5.5", build = "60000", date = "Sep 1 2026", interface = 20505 }
_G.GetBuildInfo = function() return M.build.version, M.build.build, M.build.date, M.build.interface end
_G.GetLocale = function() return "enUS" end
_G.WOW_PROJECT_ID = 5
_G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 5
_G.GetAddOnMetadata = function(_, field) return field == "Version" and "test" or nil end

-- Character state: tests mutate M.player then call CMM.Player.Refresh()
M.player = {
  class = "Warrior", classToken = "WARRIOR", classId = 1, level = 62, faction = "Alliance",
  race = "Human", raceToken = "Human", name = "Tester", realm = "Test",
  talents = { { "Arms", 31 }, { "Fury", 12 }, { "Protection", 0 } },
  skills = { { "Blacksmithing", 300, 375, category = false }, { "Mining", 300, 375 } },
  equipped = {},        -- [invSlotId] = itemId
  completedQuests = {}, -- [questId] = true
  zone = "Zangarmarsh",
  factions = {},        -- [factionId] = standingId (4 neutral .. 8 exalted)
}
_G.UnitClass = function() return M.player.class, M.player.classToken, M.player.classId end
_G.UnitLevel = function() return M.player.level end
_G.UnitFactionGroup = function() return M.player.faction, M.player.faction end
_G.UnitRace = function() return M.player.race, M.player.raceToken end
_G.UnitName = function() return M.player.name end
_G.GetRealmName = function() return M.player.realm end
_G.GetNumTalentTabs = function() return #M.player.talents end
_G.GetTalentTabInfo = function(i) local t = M.player.talents[i] return t[1], nil, t[2] end
_G.GetNumSkillLines = function() return #M.player.skills end
_G.GetSkillLineInfo = function(i)
  local s = M.player.skills[i]
  -- name, isHeader, isExpanded, skillRank, numTempPoints, skillModifier, skillMaxRank
  return s[1], s.category or false, true, s[2], 0, 0, s[3]
end
_G.GetInventoryItemID = function(_, slotId) return M.player.equipped[slotId] end
_G.GetInventoryItemLink = function(_, slotId)
  local id = M.player.equipped[slotId]
  return id and ("|cffffffff|Hitem:" .. id .. "::::::::62:::::|h[item" .. id .. "]|h|r") or nil
end
local INV_SLOTS = { HeadSlot = 1, NeckSlot = 2, ShoulderSlot = 3, ShirtSlot = 4, ChestSlot = 5, WaistSlot = 6,
  LegsSlot = 7, FeetSlot = 8, WristSlot = 9, HandsSlot = 10, Finger0Slot = 11, Finger1Slot = 12,
  Trinket0Slot = 13, Trinket1Slot = 14, BackSlot = 15, MainHandSlot = 16, SecondaryHandSlot = 17,
  RangedSlot = 18, TabardSlot = 19 }
_G.GetInventorySlotInfo = function(name) return INV_SLOTS[name] end
_G.C_QuestLog = { IsQuestFlaggedCompleted = function(id) return M.player.completedQuests[id] == true end }
_G.GetRealZoneText = function() return M.player.zone end
_G.GetZoneText = _G.GetRealZoneText
_G.C_Map = {
  GetAreaInfo = function(areaId) return M.areaNames and M.areaNames[areaId] or nil end,
  GetBestMapForUnit = function() return nil end,
}
_G.GetFactionInfoByID = function(id)
  local st = M.player.factions[id]
  if not st then return nil end
  return "Faction" .. id, "", st, 0, 0, 0
end
_G.IsSpellKnown = function() return false end

-- Items: tests register fake client item info in M.items[id] = { name=, quality=, ilvl=, link=, stats={} }
M.items = {}
_G.GetItemInfo = function(id)
  id = tonumber(id) or tonumber(tostring(id):match("item:(%d+)"))
  local it = M.items[id]
  if not it then return nil end
  return it.name, it.link or ("|Hitem:" .. id .. "|h[" .. it.name .. "]|h"), it.quality or 2, it.ilvl or 1, it.req or 1
end
_G.GetItemInfoInstant = function(id)
  id = tonumber(id) or tonumber(tostring(id):match("item:(%d+)"))
  if not M.items[id] then return nil end
  return id, "Armor", "Cloth", "INVTYPE_HEAD", 134400, 4, 1
end
_G.GetItemStats = function(link)
  local id = tonumber(tostring(link):match("item:(%d+)"))
  local it = M.items[id]
  return it and it.stats and CopyTable(it.stats) or nil
end
_G.C_Item = { GetItemStats = _G.GetItemStats, GetItemInfo = _G.GetItemInfo }
_G.Item = {
  CreateFromItemID = function(id)
    return {
      ContinueOnItemLoad = function(_, cb) cb() end,
      IsItemEmpty = function() return M.items[id] == nil end,
      GetItemName = function() return M.items[id] and M.items[id].name end,
      GetItemLink = function() return M.items[id] and ("|Hitem:" .. id .. "|h[" .. M.items[id].name .. "]|h") end,
      GetItemIcon = function() return 134400 end,
      GetItemQuality = function() return M.items[id] and M.items[id].quality or 2 end,
    }
  end,
}
_G.ITEM_QUALITY_COLORS = {}
for q = 0, 6 do _G.ITEM_QUALITY_COLORS[q] = { r = 1, g = 1, b = 1, hex = "|cffffffff" } end
_G.GetItemQualityColor = function() return 1, 1, 1, "|cffffffff" end

-- Addon loading: the data addon is provided by tests through M.dataLoader (a function that fills CasualMinMaxer_Data)
M.dataLoader = nil
M.loadedAddons = {}
_G.IsAddOnLoaded = function(name) return M.loadedAddons[name] == true end
_G.LoadAddOn = function(name)
  if name == "CasualMinMaxer_Data" and M.dataLoader then
    M.dataLoader()
    M.loadedAddons[name] = true
    return true
  end
  return false, "MISSING"
end
_G.C_AddOns = { LoadAddOn = _G.LoadAddOn, IsAddOnLoaded = _G.IsAddOnLoaded, GetAddOnMetadata = _G.GetAddOnMetadata }

-- Frames: enough for Core to register events without UI
local Frame = {}
Frame.__index = Frame
function Frame:RegisterEvent(e) self.events[e] = true end
function Frame:UnregisterEvent(e) self.events[e] = nil end
function Frame:UnregisterAllEvents() self.events = {} end
function Frame:SetScript(h, fn) self.scripts[h] = fn end
function Frame:GetScript(h) return self.scripts[h] end
function Frame:HookScript(h, fn) local o = self.scripts[h] self.scripts[h] = function(...) if o then o(...) end fn(...) end end
function Frame:Hide() self.shown = false end
function Frame:Show() self.shown = true end
function Frame:IsShown() return self.shown end
function Frame:IsVisible() return self.shown end
function Frame:SetSize() end
function Frame:SetPoint() end
function Frame:ClearAllPoints() end
function Frame:SetParent() end
function Frame:GetName() return self.name end
function Frame:SetMovable() end
function Frame:EnableMouse() end
function Frame:RegisterForDrag() end
function Frame:SetClampedToScreen() end
function Frame:SetFrameStrata() end
function Frame:SetScale() end
function Frame:GetScale() return 1 end
function Frame:SetAlpha() end
function Frame:SetWidth() end
function Frame:SetHeight() end
function Frame:GetWidth() return 100 end
function Frame:GetHeight() return 20 end
function Frame:SetBackdrop() end
function Frame:SetBackdropColor() end
function Frame:SetBackdropBorderColor() end
function Frame:CreateTexture() return setmetatable({ scripts = {}, events = {} }, Frame) end
function Frame:CreateFontString() local f = setmetatable({ scripts = {}, events = {}, text = "" }, Frame) return f end
function Frame:SetText(t) self.text = t end
function Frame:GetText() return self.text end
function Frame:SetTexture() end
function Frame:SetTexCoord() end
function Frame:SetVertexColor() end
function Frame:SetTextColor() end
function Frame:SetJustifyH() end
function Frame:SetFontObject() end
function Frame:SetFont() end
function Frame:SetAllPoints() end
function Frame:SetNormalTexture() end
function Frame:SetHighlightTexture() end
function Frame:SetPushedTexture() end
function Frame:GetParent() return self.parent end
function Frame:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function Frame:SetID(i) self.id = i end
function Frame:GetID() return self.id end
function Frame:SetChecked(c) self.checked = c end
function Frame:GetChecked() return self.checked end
function Frame:Enable() end
function Frame:Disable() end
function Frame:SetResizable() end
function Frame:SetMinResize() end
function Frame:SetResizeBounds() end
function Frame:SetUserPlaced() end
function Frame:StartMoving() end
function Frame:StopMovingOrSizing() end
function Frame:SetScrollChild() end
function Frame:SetVerticalScroll() end
function Frame:EnableMouseWheel() end
function Frame:SetToplevel() end
function Frame:SetTitle() end
function Frame:SetHyperlinksEnabled() end
function Frame:RegisterForClicks() end
function Frame:SetAttribute() end
function Frame:SetMinMaxValues() end
function Frame:SetValue(v) self.value = v end
function Frame:GetValue() return self.value end
function Frame:SetValueStep() end
function Frame:SetObeyStepOnDrag() end
function Frame:SetOrientation() end
function Frame:SetAutoFocus() end
function Frame:SetMaxLetters() end
function Frame:SetCursorPosition() end
function Frame:HighlightText() end
function Frame:ClearFocus() end
function Frame:SetMultiLine() end
function Frame:SetTextInsets() end
function Frame:SetSpacing() end
function Frame:SetWordWrap() end
function Frame:SetNonSpaceWrap() end
function Frame:SetMaxLines() end
function Frame:SetDrawLayer() end
function Frame:SetBlendMode() end
function Frame:SetDesaturated() end
function Frame:SetGradient() end
function Frame:SetColorTexture() end
function Frame:SetShown(s) self.shown = s end
function Frame:AddLine() end
function Frame:SetOwner() end
function Frame:SetHyperlink() end
function Frame:NumLines() return 0 end
function Frame:ClearLines() end
function Frame:AddDoubleLine() end
function Frame:GetItem() return nil end
function Frame:SetItemByID() end
function Frame:SetInventoryItem() end
function Frame:SetQuestItem() end
function Frame:SetQuestLogItem() end
function Frame:Raise() end

M.frames = {}
_G.CreateFrame = function(_, name, parent)
  local f = setmetatable({ name = name, parent = parent, scripts = {}, events = {}, shown = true }, Frame)
  if name then _G[name] = f; M.frames[name] = f end
  return f
end
_G.UIParent = CreateFrame("Frame", "UIParent")
_G.GameTooltip = CreateFrame("GameTooltip", "GameTooltip")
_G.ItemRefTooltip = CreateFrame("GameTooltip", "ItemRefTooltip")
_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) M.chat = M.chat or {}; M.chat[#M.chat + 1] = msg end }
_G.SlashCmdList = {}
_G.C_Timer = { After = function(_, fn) fn() end, NewTicker = function() return { Cancel = function() end } end }
_G.UISpecialFrames = {}
_G.StaticPopupDialogs = {}
_G.StaticPopup_Show = function() end
_G.InCombatLockdown = function() return false end
_G.PlaySound = function() end
_G.SOUNDKIT = {}
_G.RAID_CLASS_COLORS = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1, colorStr = "ffffffff" } end })
_G.print = function(...) M.chat = M.chat or {}; M.chat[#M.chat + 1] = table.concat({ ... }, " ") end

-- Fire an event to every frame that registered it
function M.FireEvent(event, ...)
  for _, f in pairs(M.frames) do
    if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
  end
  for _, f in ipairs(M.anonFrames or {}) do
    if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
  end
end
local realCreateFrame = _G.CreateFrame
_G.CreateFrame = function(kind, name, parent, template)
  local f = realCreateFrame(kind, name, parent, template)
  if not name then M.anonFrames = M.anonFrames or {}; M.anonFrames[#M.anonFrames + 1] = f end
  return f
end

function M.Reset()
  M.items = {}
  M.player.equipped = {}
  M.player.completedQuests = {}
  M.player.factions = {}
  M.chat = {}
  M.loadedAddons = {}
  _G.CasualMinMaxerDB = nil
  _G.CasualMinMaxerCharDB = nil
  _G.CasualMinMaxer_Data = nil
end

return M
