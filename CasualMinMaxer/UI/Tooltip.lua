-- Score line on item tooltips: "Casual MinMaxer (Arms): 123 (+12, +8 %)".
local _, CMM = ...
local UI = CMM.UI
local L = CMM.L
local Tooltip = {}
UI.Tooltip = Tooltip

local function tooltipLink(tooltip, data)
  local link
  if tooltip and tooltip.GetItem then
    local _, l = tooltip:GetItem()
    link = l
  end
  if not link and type(data) == "table" then
    if data.hyperlink then link = data.hyperlink
    elseif data.id then link = "item:" .. tostring(data.id) end
  end
  return link
end

-- Build the score line for a link; returns text or nil when the item is not scorable.
function Tooltip.Line(link)
  local item, fromPack = UI.ItemFromLink(link)
  if not item then return nil end
  local score, gain, gainPct = UI.EvaluateItem(item)
  if not score then return nil end
  local spec = UI.SpecName()
  local text
  if gain > 0 then
    text = string.format("%s (%s): %.0f %s", L["CMM_TITLE"], spec, score, UI.FormatGain(gain, gainPct))
  elseif gain == 0 and (not item.stats or next(item.stats) == nil) then
    text = string.format("%s (%s): %s", L["CMM_TITLE"], spec, L["no scored stats"])
  else
    text = string.format("%s (%s): %.0f |cffaaaaaa%s (%+.0f)|r", L["CMM_TITLE"], spec, score, L["not an upgrade"], gain)
  end
  if not fromPack then text = text .. " |cff888888" .. L["(client stats)"] .. "|r" end
  return text, gain
end

local function addLine(tooltip, data)
  if not tooltip or tooltip.cmmDone then return end
  local link = tooltipLink(tooltip, data)
  if not link then return end
  local id = UI.ItemIdFromLink(link)
  if not id then return end
  if not UI.DataReady() then return end
  local text, gain = Tooltip.Line(link)
  if not text then return end
  tooltip.cmmDone = id
  if gain and gain > 0 then
    tooltip:AddLine(text, 0.3, 1, 0.3)
  else
    tooltip:AddLine(text, 0.7, 0.7, 0.7)
  end
  if tooltip.Show then tooltip:Show() end
end

local function clear(tooltip) tooltip.cmmDone = nil end

function Tooltip.Install()
  if Tooltip.installed then return true end
  local hook = CMM.Compat and CMM.Compat.HookItemTooltips
  if hook then
    hook(addLine)
  elseif TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, addLine)
  else
    for _, name in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }) do
      local tt = _G[name]
      if tt and tt.HookScript then tt:HookScript("OnTooltipSetItem", addLine) end
    end
  end
  for _, name in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }) do
    local tt = _G[name]
    if tt and tt.HookScript then tt:HookScript("OnTooltipCleared", clear) end
  end
  Tooltip.installed = true
  return true
end

-- Install now if Compat is already loaded (normal load order); Core may call Install() again later safely.
if CMM.Compat and CMM.Compat.HookItemTooltips then
  Tooltip.Install()
elseif CMM.On then
  CMM.On("DATA_LOADED", Tooltip.Install)
  CMM.On("PLAYER_CHANGED", Tooltip.Install)
end
