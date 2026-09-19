-- Result rows (recycled), boss header rows and the expandable detail panel.
local _, CMM = ...
local UI = CMM.UI
local L = CMM.L
local Rows = {}
UI.Rows = Rows

local call = UI.Call
local SKILL_NAMES = {
  [171] = "Alchemy", [164] = "Blacksmithing", [333] = "Enchanting", [202] = "Engineering",
  [165] = "Leatherworking", [197] = "Tailoring", [755] = "Jewelcrafting", [185] = "Cooking", [129] = "First Aid",
}
local RANK_NAMES = { [0] = "Normal", [1] = "Elite", [2] = "Rare", [3] = "Boss", [4] = "Rare elite" }
local REP_NAMES = { [4] = "Neutral", [5] = "Friendly", [6] = "Honored", [7] = "Revered", [8] = "Exalted" }
local MAP_NAMES = { [0] = "Eastern Kingdoms", [1] = "Kalimdor", [530] = "Outland" }

---------------------------------------------------------------------------------------------------
-- Text helpers
---------------------------------------------------------------------------------------------------
local function itemName(row)
  return (row.item and row.item.name) or ("item " .. tostring(row.id))
end

local function itemLink(id)
  if GetItemInfo then
    local _, link = GetItemInfo(id)
    if link then return link end
  end
  return "item:" .. tostring(id)
end

local function mapName(map)
  if not map then return "" end
  if MAP_NAMES[map] then return L[MAP_NAMES[map]] end
  local d = call(CMM.Data, "Dungeon", map)
  return d and d.name or ("map " .. tostring(map))
end

local function zoneName(areaId)
  if not areaId or areaId == 0 then return nil end
  return call(CMM.Data, "ZoneName", areaId) or tostring(areaId)
end

-- One-line summary for the row's extra column (drop %, chain length, price ...)
function Rows.SourceDetail(row)
  local o = row.obtain
  local s = o and o.src
  if not s then return "" end
  local t = s.t
  if t == "Q" then
    local steps = s.steps or o.steps
    if steps then return string.format(L["%d steps left"], steps) end
    return L["Quest"]
  elseif t == "B" or t == "R" or t == "N" or t == "T" or t == "G" or t == "W" then
    return s.pct and string.format("%.0f%%", s.pct) or ""
  elseif t == "V" then
    if s.mode == "E" then return L["tokens"] end
    return UI.FormatMoney(s.price)
  elseif t == "K" then
    return string.format("%s %d", L[SKILL_NAMES[s.skillLine] or "Profession"], s.skill or 0)
  end
  return ""
end

-- Walk the quest chain backwards through `prev` and return the quests first -> last.
function Rows.QuestChain(questId)
  local chain, seen = {}, {}
  local id = questId
  while id and id ~= 0 and not seen[id] do
    seen[id] = true
    local q = call(CMM.Data, "Quest", id)
    if not q then break end
    table.insert(chain, 1, { id = id, quest = q })
    local prev = tonumber(q.prev) or 0
    id = math.abs(prev)
  end
  return chain
end

-- Lines for the detail panel: { text, color? }
function Rows.DetailLines(row, player)
  local lines = {}
  local function add(text, r, g, b) lines[#lines + 1] = { text = text, r = r, g = g, b = b } end
  local o = row.obtain or {}
  local s = o.src
  if not s then
    add(L["No source information."])
    return lines
  end
  local t = s.t
  if t == "Q" then
    local chain = Rows.QuestChain(s.quest)
    local q = call(CMM.Data, "Quest", s.quest)
    local zone = q and zoneName(q.zone)
    add(string.format("%s%s", L["Quest chain"], zone and (" - " .. zone) or ""), 1, 0.82, 0)
    if #chain == 0 and q then chain = { { id = s.quest, quest = q } } end
    for _, step in ipairs(chain) do
      local done = call(CMM.Player, "QuestDone", step.id)
      local qq = step.quest
      local mark = done and "|cff33ff33+|r" or "|cffffffff-|r"
      local text = string.format("%s %s (%d)", mark, qq.title or ("quest " .. step.id), qq.questLevel or qq.minLevel or 0)
      if done then add(text, 0.6, 0.6, 0.6) else add(text, 1, 1, 1) end
    end
  elseif t == "B" then
    local boss = call(CMM.Data, "Boss", s.npc)
    local npc = call(CMM.Data, "Npc", s.npc)
    local d = boss and call(CMM.Data, "Dungeon", boss.map)
    local total = d and d.bosses and #d.bosses or 0
    local heroic = boss and boss.heroic == 1 and (" (" .. L["Heroic"] .. ")") or ""
    add(string.format("%s%s", d and d.name or L["Dungeon"], heroic), 1, 0.82, 0)
    add(string.format(L["Boss %d of %d: %s - %.1f%% drop"], (boss and boss.index or 0) + 1, total,
      npc and npc.name or "?", s.pct or 0), 1, 1, 1)
    if d and d.zone then add(L["Entrance"] .. ": " .. (zoneName(d.zone) or ""), 0.8, 0.8, 0.8) end
  elseif t == "R" or t == "N" then
    local npc = call(CMM.Data, "Npc", s.npc)
    add(t == "R" and L["Rare spawn"] or L["Named mob"], 1, 0.82, 0)
    if npc then
      add(string.format("%s (%d, %s) - %.1f%% drop", npc.name or "?", npc.level or 0,
        L[RANK_NAMES[npc.rank or 0] or "Normal"], s.pct or 0), 1, 1, 1)
      local respawn = npc.respawnMin and npc.respawnMin > 0
        and string.format(", %s %s", L["respawn"], UI.FormatMinutes(npc.respawnMin)) or ""
      add(mapName(npc.map) .. respawn, 0.8, 0.8, 0.8)
    end
  elseif t == "T" then
    add(L["Dungeon trash"], 1, 0.82, 0)
    add(string.format("%s - %.1f%% %s", mapName(s.map), s.pct or 0, L["per mob"]), 1, 1, 1)
  elseif t == "G" then
    local obj = call(CMM.Data, "Object", s.object)
    add(L["Chest"], 1, 0.82, 0)
    add(string.format("%s - %s - %.1f%%", obj and obj.name or "?", obj and mapName(obj.map) or "", s.pct or 0), 1, 1, 1)
  elseif t == "V" then
    add(L["Vendor"], 1, 0.82, 0)
    if s.mode == "E" then
      add(L["Sold for badges, honor or tokens"], 1, 1, 1)
    elseif s.faction then
      local fname = GetFactionInfoByID and select(1, GetFactionInfoByID(s.faction)) or ("faction " .. tostring(s.faction))
      add(string.format("%s: %s %s", fname or "?", L["requires"], L[REP_NAMES[s.rank or 4] or "Neutral"]), 1, 1, 1)
      add(UI.FormatMoney(s.price), 1, 1, 1)
    else
      add(UI.FormatMoney(s.price), 1, 1, 1)
    end
  elseif t == "K" then
    add(L["Crafted"], 1, 0.82, 0)
    local mine = player and player.professions and player.professions[s.skillLine]
    add(string.format("%s %d%s", L[SKILL_NAMES[s.skillLine] or "Profession"], s.skill or 0,
      mine and string.format(" (%s %d)", L["you have"], mine) or ""), 1, 1, 1)
  elseif t == "W" then
    add(L["World drop (BoE)"], 1, 0.82, 0)
    add(string.format("%.2f%% %s", s.pct or 0, L["per mob, or buy it on the auction house"]), 1, 1, 1)
  end
  -- other sources, one line
  local item = row.item
  if item and item.src and #item.src > 1 then
    local parts = {}
    for _, src in ipairs(item.src) do
      if src ~= s then
        if src.t == "Q" then
          local q = call(CMM.Data, "Quest", src.quest)
          parts[#parts + 1] = L["Quest"] .. " " .. (q and q.title or tostring(src.quest))
        elseif src.t == "B" or src.t == "R" or src.t == "N" then
          local npc = call(CMM.Data, "Npc", src.npc)
          parts[#parts + 1] = string.format("%s %.0f%%", npc and npc.name or ("NPC " .. tostring(src.npc)), src.pct or 0)
        elseif src.t == "V" then
          parts[#parts + 1] = L["Vendor"]
        elseif src.t == "K" then
          parts[#parts + 1] = L[SKILL_NAMES[src.skillLine] or "Crafted"]
        elseif src.t == "T" then
          parts[#parts + 1] = L["Dungeon trash"]
        elseif src.t == "G" then
          parts[#parts + 1] = L["Chest"]
        elseif src.t == "W" then
          parts[#parts + 1] = L["World drop (BoE)"]
        end
      end
      if #parts >= 4 then break end
    end
    if #parts > 0 then add(L["Also"] .. ": " .. table.concat(parts, ", "), 0.7, 0.7, 0.7) end
  end
  if row.minutes then add(string.format("%s: %s", L["Expected time"], UI.FormatMinutes(row.minutes)), 0.7, 0.7, 0.7) end
  return lines
end

-- Find the uiMapID whose localized name equals the zone's name, to place a TomTom waypoint at the zone centre.
local CONTINENTS = { 1414, 1415, 1945 } -- Kalimdor, Eastern Kingdoms, Outland
local function uiMapForZone(areaId)
  if not (C_Map and C_Map.GetMapChildrenInfo and areaId) then return nil end
  local name = call(CMM.Data, "ZoneName", areaId)
  if not name then return nil end
  for _, cont in ipairs(CONTINENTS) do
    local children = C_Map.GetMapChildrenInfo(cont, nil, true)
    for _, info in ipairs(children or {}) do
      if info.name == name then return info.mapID end
    end
  end
  return nil
end

function Rows.SourceZone(row)
  local o = row.obtain
  if o and o.zone and o.zone ~= 0 then return o.zone end
  local s = o and o.src
  if not s then return nil end
  if s.t == "Q" then
    local q = call(CMM.Data, "Quest", s.quest)
    return q and q.zone ~= 0 and q.zone or nil
  elseif s.t == "B" then
    local boss = call(CMM.Data, "Boss", s.npc)
    local d = boss and call(CMM.Data, "Dungeon", boss.map)
    return d and d.zone or nil
  elseif s.t == "T" then
    local d = call(CMM.Data, "Dungeon", s.map)
    return d and d.zone or nil
  end
  return nil
end

function Rows.AddWaypoint(row)
  local zone = Rows.SourceZone(row)
  local name = zone and (call(CMM.Data, "ZoneName", zone) or tostring(zone))
  if not zone then
    CMM.Print(L["No zone known for this source."])
    return false
  end
  if TomTom and TomTom.AddWaypoint then
    local uiMap = uiMapForZone(zone)
    if uiMap then
      TomTom:AddWaypoint(uiMap, 0.5, 0.5, { title = itemName(row) .. " - " .. name, persistent = false })
      return true
    end
  end
  CMM.Print(L["Head to"] .. " " .. name)
  return false
end

function Rows.ReportString(row, player)
  local o = row.obtain or {}
  local D = _G.CasualMinMaxer_Data
  return string.format("CMM %s | data %s | item %d %s | %s | %s %s L%d",
    tostring(CMM.version), D and D.meta and tostring(D.meta.version) or "?", row.id or 0, itemName(row),
    o.text or "?", player and player.class or "?", player and player.spec or "?", player and player.level or 0)
end

---------------------------------------------------------------------------------------------------
-- Row widget
---------------------------------------------------------------------------------------------------
local function onEnter(self)
  if not self.row then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  if GameTooltip.SetItemByID then
    GameTooltip:SetItemByID(self.row.id)
  else
    GameTooltip:SetHyperlink("item:" .. self.row.id)
  end
  GameTooltip:Show()
end

local function onLeave() GameTooltip:Hide() end

local menuFrame
local function showMenu(self)
  local row, player = self.row, UI.Player()
  if not row then return end
  menuFrame = menuFrame or CreateFrame("Frame", "CasualMinMaxerRowMenu", UIParent, "UIDropDownMenuTemplate")
  local items = {
    { text = itemName(row), isTitle = true, notCheckable = true },
    { text = L["Hide this item"], notCheckable = true, func = function()
      UI.CharDB().hidden[row.id] = true
      call(CMM.Query, "Invalidate")
      UI.Refresh()
    end },
    { text = L["Copy 'report wrong data' string"], notCheckable = true, func = function()
      UI.ShowCopyBox(L["Report wrong data"], Rows.ReportString(row, player))
    end },
    { text = L["Link to chat"], notCheckable = true, func = function()
      if ChatEdit_InsertLink then ChatEdit_InsertLink(itemLink(row.id)) end
    end },
    { text = L["Cancel"], notCheckable = true, func = function() end },
  }
  if EasyMenu then
    EasyMenu(items, menuFrame, "cursor", 0, 0, "MENU")
  elseif UIDropDownMenu_Initialize and ToggleDropDownMenu then
    UIDropDownMenu_Initialize(menuFrame, function(_, level)
      for _, it in ipairs(items) do
        local info = UI.MenuInfo()
        for k, v in pairs(it) do info[k] = v end
        UIDropDownMenu_AddButton(info, level)
      end
    end, "MENU")
    ToggleDropDownMenu(1, nil, menuFrame, "cursor", 0, 0)
  end
end

local function onClick(self, button)
  local row = self.row
  if not row then return end
  if button == "RightButton" then
    showMenu(self)
    return
  end
  if IsShiftKeyDown and IsShiftKeyDown() then
    if ChatEdit_InsertLink then ChatEdit_InsertLink(itemLink(row.id)) end
    return
  end
  if IsControlKeyDown and IsControlKeyDown() then
    if DressUpItemLink then DressUpItemLink(itemLink(row.id)) end
    return
  end
  UI.ToggleExpand(row.id)
end

function Rows.Create(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(UI.ROW_HEIGHT)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.bg:SetColorTexture(1, 1, 1, 0.04)
  b.hl = b:CreateTexture(nil, "HIGHLIGHT")
  b.hl:SetAllPoints()
  b.hl:SetColorTexture(1, 1, 1, 0.08)
  b.tier = b:CreateTexture(nil, "ARTWORK")
  b.tier:SetSize(4, UI.ROW_HEIGHT - 4)
  b.tier:SetPoint("LEFT", 0, 0)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(28, 28)
  b.icon:SetPoint("LEFT", 8, 0)
  b.name = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  b.name:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 6, -1)
  b.name:SetWidth(250)
  b.name:SetJustifyH("LEFT")
  b.name:SetWordWrap(false)
  b.badges = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.badges:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMRIGHT", 6, 1)
  b.badges:SetWidth(250)
  b.badges:SetJustifyH("LEFT")
  b.gain = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  b.gain:SetPoint("LEFT", b.icon, "RIGHT", 262, 0)
  b.gain:SetWidth(100)
  b.gain:SetJustifyH("RIGHT")
  b.source = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.source:SetPoint("TOPLEFT", b.gain, "TOPRIGHT", 10, 0)
  b.source:SetPoint("RIGHT", b, "RIGHT", -70, 0)
  b.source:SetJustifyH("LEFT")
  b.source:SetWordWrap(false)
  b.detail = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  b.detail:SetPoint("BOTTOMLEFT", b.gain, "BOTTOMRIGHT", 10, 0)
  b.detail:SetPoint("RIGHT", b, "RIGHT", -70, 0)
  b.detail:SetJustifyH("LEFT")
  b.lasts = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.lasts:SetPoint("RIGHT", -6, 0)
  b.lasts:SetWidth(62)
  b.lasts:SetJustifyH("RIGHT")
  b.header = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  b.header:SetPoint("LEFT", 8, 0)
  b.header:Hide()
  b:SetScript("OnEnter", onEnter)
  b:SetScript("OnLeave", onLeave)
  b:SetScript("OnClick", onClick)
  return b
end

local function setIcon(b, id)
  b.icon:SetTexture(134400) -- INV_Misc_QuestionMark
  if GetItemIcon then
    local icon = GetItemIcon(id)
    if icon then b.icon:SetTexture(icon) return end
  end
  if Item and Item.CreateFromItemID then
    local it = Item:CreateFromItemID(id)
    if it and it.ContinueOnItemLoad then
      it:ContinueOnItemLoad(function()
        if b.row and b.row.id == id then
          local icon = it.GetItemIcon and it:GetItemIcon()
          if icon then b.icon:SetTexture(icon) end
          local name = it.GetItemName and it:GetItemName()
          if name then b.name:SetText(name) end
        end
      end)
    end
  end
end

function Rows.Fill(b, row, ctx, expanded)
  b.row = row
  b.header:Hide()
  for _, w in ipairs({ b.icon, b.name, b.badges, b.gain, b.source, b.detail, b.lasts, b.tier }) do w:Show() end
  b.bg:SetColorTexture(1, 1, 1, expanded and 0.10 or 0.04)
  local item = row.item or {}
  b.name:SetText(itemName(row))
  b.name:SetTextColor(UI.QualityColor(item.q))
  setIcon(b, row.id)
  b.gain:SetText(UI.FormatGain(row.gain, row.gainPct))
  local o = row.obtain or {}
  b.source:SetText(o.text or "")
  b.detail:SetText(Rows.SourceDetail(row))
  b.tier:SetColorTexture(UI.TierColor(row.tier or o.tier))
  local badges = {}
  if row.special then badges[#badges + 1] = "|cffff99ff" .. L["special"] .. "|r" end
  if row.set then badges[#badges + 1] = "|cffffff99" .. L["set"] .. "|r" end
  if item.flags and bit and bit.band(item.flags, 32) ~= 0 then badges[#badges + 1] = "|cffff9966" .. L["heroic"] .. "|r" end
  if o.group then badges[#badges + 1] = "|cff99ccff" .. L["group"] .. "|r" end
  if item.req and ctx and ctx.level and item.req > ctx.level then
    badges[#badges + 1] = string.format("|cffcccccc%s %d|r", L["lvl"], item.req)
  end
  b.badges:SetText(table.concat(badges, " "))
  if row.lastsUntil and row.lastsUntil < 70 then
    b.lasts:SetText(string.format(L["until %d"], row.lastsUntil))
  elseif row.lastsUntil then
    b.lasts:SetText(L["until 70"])
  else
    b.lasts:SetText("")
  end
end

function Rows.FillHeader(b, text, count)
  b.row = nil
  for _, w in ipairs({ b.icon, b.name, b.badges, b.gain, b.source, b.detail, b.lasts, b.tier }) do w:Hide() end
  b.bg:SetColorTexture(1, 0.82, 0, 0.10)
  b.header:SetText(string.format("%s  |cffaaaaaa(%d)|r", text or "", count or 0))
  b.header:Show()
end

---------------------------------------------------------------------------------------------------
-- Detail panel (one per expanded row, recycled)
---------------------------------------------------------------------------------------------------
function Rows.CreateDetail(parent)
  local f = CreateFrame("Frame", nil, parent)
  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetAllPoints()
  f.bg:SetColorTexture(0, 0, 0, 0.25)
  f.lines = {}
  f.waypoint = UI.CreateButton(f, L["Waypoint"], 80, function(self) if self.row then Rows.AddWaypoint(self.row) end end)
  f.waypoint:SetPoint("BOTTOMRIGHT", -6, 4)
  f.report = UI.CreateButton(f, L["Report"], 70, function(self)
    if self.row then UI.ShowCopyBox(L["Report wrong data"], Rows.ReportString(self.row, UI.Player())) end
  end)
  f.report:SetPoint("RIGHT", f.waypoint, "LEFT", -4, 0)
  f.hide = UI.CreateButton(f, L["Hide"], 60, function(self)
    if self.row then
      UI.CharDB().hidden[self.row.id] = true
      call(CMM.Query, "Invalidate")
      UI.Refresh()
    end
  end)
  f.hide:SetPoint("RIGHT", f.report, "LEFT", -4, 0)
  return f
end

function Rows.FillDetail(f, row, player)
  f.row = row
  f.waypoint.row, f.report.row, f.hide.row = row, row, row
  local lines = Rows.DetailLines(row, player)
  for i, l in ipairs(lines) do
    local fs = f.lines[i]
    if not fs then
      fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      fs:SetPoint("TOPLEFT", 44, -6 - (i - 1) * UI.DETAIL_LINE)
      fs:SetPoint("RIGHT", -230, 0)
      fs:SetJustifyH("LEFT")
      fs:SetWordWrap(false)
      f.lines[i] = fs
    end
    fs:SetText(l.text)
    fs:SetTextColor(l.r or 1, l.g or 1, l.b or 1)
    fs:Show()
  end
  for i = #lines + 1, #f.lines do f.lines[i]:Hide() end
  local zone = Rows.SourceZone(row)
  if zone then f.waypoint:Show() else f.waypoint:Hide() end
end
