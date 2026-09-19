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

function Compat.InventoryItemLink(slotId)
  return GetInventoryItemLink and GetInventoryItemLink("player", slotId) or nil
end

-- "Equip:" tooltip lines -> canonical stats for what GetItemStats does not report on the Classic client
-- (attack power, spell damage / healing, mp5, block value, feral AP, and ratings phrased as text).
local EQUIP_PATTERNS = {
  { "^Increases attack power by (%d+) in Cat, Bear", "FAP" },
  { "^Increases attack power by (%d+)", "AP" },
  { "^Increases ranged attack power by (%d+)", "RAP" },
  { "^Increases damage and healing done by magical spells and effects by up to (%d+)", "SP" },
  { "^Increases healing done by up to (%d+) and damage done by up to (%d+)", "HEAL", "SP" },
  { "^Increases healing done by up to (%d+)", "HEAL" },
  { "^Increases healing done by magical spells and effects by up to (%d+)", "HEAL" },
  { "^Increases damage done by (%a+) spells and effects by up to (%d+)", "SCHOOL" },
  { "^Restores (%d+) mana per 5 sec", "MP5" },
  { "^Restores (%d+) health per 5 sec", "HP5" },
  { "^Increases the block value of your shield by (%d+)", "BLOCKV" },
  { "^Increases your spell hit rating by (%d+)", "SPHIT" },
  { "^Improves spell hit rating by (%d+)", "SPHIT" },
  { "^Increases your hit rating by (%d+)", "HIT" },
  { "^Improves hit rating by (%d+)", "HIT" },
  { "^Improves spell critical strike rating by (%d+)", "SPCRIT" },
  { "^Increases your spell critical strike rating by (%d+)", "SPCRIT" },
  { "^Improves critical strike rating by (%d+)", "CRIT" },
  { "^Increases your critical strike rating by (%d+)", "CRIT" },
  { "^Improves spell haste rating by (%d+)", "SPHASTE" },
  { "^Improves haste rating by (%d+)", "HASTE" },
  { "^Increases your expertise rating by (%d+)", "EXP" },
  { "^Increases defense rating by (%d+)", "DEF" },
  { "^Increases your dodge rating by (%d+)", "DODGE" },
  { "^Increases your parry rating by (%d+)", "PARRY" },
  { "^Increases your shield block rating by (%d+)", "BLOCK" },
  { "^Improves your resilience rating by (%d+)", "RES" },
  { "^Increases your armor penetration rating by (%d+)", "ARP" },
  { "^Your attacks ignore (%d+) of your opponent's armor", "ARP" },
}
local SCHOOL_KEYS = { Fire = "SPFIRE", Frost = "SPFROST", Shadow = "SPSHADOW", Nature = "SPNATURE",
  Arcane = "SPARCANE", Holy = "SPHOLY" }

-- Parse one tooltip line ("Equip: ...") into stats; returns nil when it is not a recognised equip effect.
function Compat.ParseEquipLine(text)
  if type(text) ~= "string" then return nil end
  local body = text:match("^Equip:%s*(.*)$")
  if not body then return nil end
  for _, pat in ipairs(EQUIP_PATTERNS) do
    local a, b = body:match(pat[1])
    if a then
      if pat[2] == "SCHOOL" then
        local key = SCHOOL_KEYS[a]
        if key then return { [key] = tonumber(b) } end
        return nil
      end
      local out = { [pat[2]] = tonumber(a) }
      if pat[3] and b then out[pat[3]] = tonumber(b) end
      return out
    end
  end
  return nil
end

local scanTip
-- Stats from the "Equip:" lines of an item link's tooltip. Returns {} when nothing is recognised.
function Compat.ScanEquipStats(link)
  local out = {}
  if not link or not CreateFrame then return out end
  if not scanTip then
    scanTip = CreateFrame("GameTooltip", "CasualMinMaxerScanTip", UIParent, "GameTooltipTemplate")
    if scanTip.SetOwner then scanTip:SetOwner(UIParent, "ANCHOR_NONE") end
  end
  if scanTip.ClearLines then scanTip:ClearLines() end
  if not scanTip.SetHyperlink then return out end
  local ok = pcall(scanTip.SetHyperlink, scanTip, link)
  if not ok then return out end
  local n = scanTip.NumLines and scanTip:NumLines() or 0
  for i = 1, n do
    local fs = _G["CasualMinMaxerScanTipTextLeft" .. i]
    local text = fs and fs.GetText and fs:GetText()
    local parsed = Compat.ParseEquipLine(text)
    if parsed then
      for k, v in pairs(parsed) do out[k] = (out[k] or 0) + v end
    end
  end
  return out
end

-- Canonical stats for an item link: GetItemStats (mapped) plus tooltip-scanned equip effects for the
-- keys the client does not report. Returns nil when the client has no data at all.
local SCAN_KEYS = { AP = true, RAP = true, FAP = true, SP = true, HEAL = true, MP5 = true, HP5 = true, BLOCKV = true,
  SPFIRE = true, SPFROST = true, SPSHADOW = true, SPNATURE = true, SPARCANE = true, SPHOLY = true, ARP = true }
Compat.SCAN_KEYS = SCAN_KEYS
function Compat.ItemStatsFromClient(link)
  local mods = Compat.GetItemStats(link)
  if not mods then return nil end
  local stats = CMM.Scoring.FromItemStats(mods)
  local scanned = Compat.ScanEquipStats(link)
  for k, v in pairs(scanned) do
    if stats[k] == nil and (SCAN_KEYS[k] or CMM.Constants.RATING_KEYS[k]) then stats[k] = v end
  end
  return stats, scanned
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
