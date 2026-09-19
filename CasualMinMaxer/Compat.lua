-- Client API differences between 2.5.x builds are isolated here. Logic modules call only these wrappers.
local _, CMM = ...
local Compat = CMM.Compat

function Compat.Build()
  local version, build, _, interface = GetBuildInfo()
  return { version = version, build = build, interface = interface }
end

function Compat.GetItemStats(link)
  if C_Item and C_Item.GetItemStats then return C_Item.GetItemStats(link) end
  if GetItemStats then return GetItemStats(link) end
  return nil
end

function Compat.GetItemInfo(id)
  if C_Item and C_Item.GetItemInfo then return C_Item.GetItemInfo(id) end
  return GetItemInfo(id)
end

function Compat.LoadAddOn(name)
  if C_AddOns and C_AddOns.LoadAddOn then return C_AddOns.LoadAddOn(name) end
  if LoadAddOn then return LoadAddOn(name) end
  return false, "MISSING"
end

function Compat.IsAddOnLoaded(name)
  if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) end
  if IsAddOnLoaded then return IsAddOnLoaded(name) end
  return false
end

function Compat.GetAddOnMetadata(name, field)
  if C_AddOns and C_AddOns.GetAddOnMetadata then return C_AddOns.GetAddOnMetadata(name, field) end
  if GetAddOnMetadata then return GetAddOnMetadata(name, field) end
  return nil
end

function Compat.IsQuestCompleted(questId)
  if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then return C_QuestLog.IsQuestFlaggedCompleted(questId) == true end
  return false
end

-- Talent tabs: returns array of { name = , points = } in tab order.
function Compat.TalentTabs()
  local out = {}
  local n = (GetNumTalentTabs and GetNumTalentTabs()) or 0
  for i = 1, n do
    local a, b, c, _, e = GetTalentTabInfo(i)
    local name, points
    if type(a) == "string" then
      -- (name, texture, pointsSpent, ...)
      name, points = a, tonumber(c) or 0
    else
      -- (id, name, description, icon, pointsSpent, ...)
      name, points = b, tonumber(e) or 0
    end
    out[i] = { name = name, points = points }
  end
  return out
end

-- Professions: { [skillLineId] = rank } from the skill frame, matched by (localized) skill name.
function Compat.Professions()
  local out = {}
  local n = (GetNumSkillLines and GetNumSkillLines()) or 0
  local byName = CMM.Constants.SKILL_LINE_BY_NAME
  for i = 1, n do
    local name, isHeader, _, rank = GetSkillLineInfo(i)
    if name and not isHeader then
      local id = byName[name]
      if id then out[id] = tonumber(rank) or 0 end
    end
  end
  return out
end

-- Standing id (4 neutral .. 8 exalted) for a faction id, nil if unknown to the client.
function Compat.FactionStanding(factionId)
  if C_Reputation and C_Reputation.GetFactionDataByID then
    local d = C_Reputation.GetFactionDataByID(factionId)
    return d and d.reaction or nil
  end
  if GetFactionInfoByID then
    local name, _, standing = GetFactionInfoByID(factionId)
    if name then return standing end
  end
  return nil
end

function Compat.AreaName(areaId)
  if C_Map and C_Map.GetAreaInfo then
    local ok, name = pcall(C_Map.GetAreaInfo, areaId)
    if ok and name and name ~= "" then return name end
  end
  return nil
end

function Compat.ZoneName()
  return (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or ""
end

function Compat.InventoryItemID(slotId)
  if GetInventoryItemID then return GetInventoryItemID("player", slotId) end
  local link = GetInventoryItemLink and GetInventoryItemLink("player", slotId)
  return link and tonumber(link:match("item:(%d+)")) or nil
end

-- Item tooltip hook usable on both the modern (TooltipDataProcessor) and legacy (OnTooltipSetItem) clients.
-- fn(tooltip, itemId, link)
function Compat.HookItemTooltips(fn)
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
      local id = data and data.id
      local link
      if tooltip.GetItem then local _, l = tooltip:GetItem() link = l end
      if not id and link then id = tonumber(link:match("item:(%d+)")) end
      if id then fn(tooltip, id, link) end
    end)
    return "processor"
  end
  local function handler(tooltip)
    if not tooltip.GetItem then return end
    local _, link = tooltip:GetItem()
    local id = link and tonumber(link:match("item:(%d+)"))
    if id then fn(tooltip, id, link) end
  end
  for _, name in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }) do
    local tt = _G[name]
    if tt and tt.HookScript then tt:HookScript("OnTooltipSetItem", handler) end
  end
  return "hookscript"
end

-- Base64 (RFC 4648) for export strings.
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_REV = {}
for i = 1, #B64 do B64_REV[B64:sub(i, i)] = i - 1 end

function Compat.Base64Encode(s)
  local out = {}
  for i = 1, #s, 3 do
    local a, b, c = s:byte(i, i + 2)
    local n = a * 65536 + (b or 0) * 256 + (c or 0)
    local c1 = math.floor(n / 262144) % 64
    local c2 = math.floor(n / 4096) % 64
    local c3 = math.floor(n / 64) % 64
    local c4 = n % 64
    out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
      .. (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
  end
  return table.concat(out)
end

function Compat.Base64Decode(s)
  if type(s) ~= "string" then return nil end
  s = s:gsub("%s", "")
  if s == "" then return "" end
  if s:find("[^%w%+/=]") or #s % 4 ~= 0 then return nil end
  local out = {}
  for i = 1, #s, 4 do
    local chunk = s:sub(i, i + 3)
    local vals, pad = {}, 0
    for j = 1, 4 do
      local ch = chunk:sub(j, j)
      if ch == "=" or ch == "" then vals[j] = 0; pad = pad + 1 else
        local v = B64_REV[ch]
        if not v then return nil end
        vals[j] = v
      end
    end
    local n = vals[1] * 262144 + vals[2] * 4096 + vals[3] * 64 + vals[4]
    local a = math.floor(n / 65536) % 256
    local b = math.floor(n / 256) % 256
    local c = n % 256
    out[#out + 1] = string.char(a)
    if pad < 2 then out[#out + 1] = string.char(b) end
    if pad < 1 then out[#out + 1] = string.char(c) end
  end
  return table.concat(out)
end

-- Async item info: calls fn(id, name, link, quality, icon) once the client has the item cached.
function Compat.OnItemLoad(id, fn)
  if Item and Item.CreateFromItemID then
    local item = Item:CreateFromItemID(id)
    if item:IsItemEmpty() then
      fn(id, nil)
      return
    end
    item:ContinueOnItemLoad(function()
      fn(id, item:GetItemName(), item:GetItemLink(), item:GetItemQuality(), item:GetItemIcon())
    end)
    return
  end
  local name, link, quality, _, _, _, _, _, _, icon = Compat.GetItemInfo(id)
  fn(id, name, link, quality, icon)
end
