-- LibDataBroker launcher + LibDBIcon minimap button.
local _, CMM = ...
local UI = CMM.UI
local L = CMM.L
local Minimap = {}
UI.Minimap = Minimap

local ICON = "Interface\\Icons\\INV_Misc_EngGizmos_30"
local NAME = "CasualMinMaxer"

local function tooltip(tt)
  if not tt or not tt.AddLine then return end
  tt:AddLine(L["CMM_TITLE"])
  local weakest, sum = UI.WeakestSlot()
  if weakest and sum then
    tt:AddDoubleLine(L["Weakest slot"], UI.SlotName(weakest), 1, 1, 1, 1, 0.82, 0)
    if sum.top then
      local name = sum.top.item and sum.top.item.name or ""
      tt:AddDoubleLine(L["Top upgrade"], name .. " " .. UI.FormatGain(sum.top.gain, sum.top.gainPct), 1, 1, 1, 1, 1, 1)
    end
  else
    tt:AddLine(L["Open the window once to compute your weakest slot."], 0.7, 0.7, 0.7)
  end
  tt:AddLine(" ")
  tt:AddLine(L["Left-click: toggle window. Right-click: options."], 0.6, 0.6, 0.6)
end

function Minimap.CreateDataObject()
  if Minimap.dataObject then return Minimap.dataObject end
  local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
  if not LDB then return nil end
  local spec = {
    type = "launcher",
    label = L["CMM_TITLE"],
    icon = ICON,
    OnClick = function(_, button)
      if button == "RightButton" then UI.OpenOptions() else UI.Toggle() end
    end,
    OnTooltipShow = tooltip,
  }
  local obj = LDB:NewDataObject(NAME, spec)
  if not obj then
    -- already registered (reload of the module): reuse and refresh the callbacks
    obj = LDB:GetDataObjectByName(NAME)
    if obj then for k, v in pairs(spec) do obj[k] = v end end
  end
  Minimap.dataObject = obj
  return obj
end

function Minimap.Register()
  local obj = Minimap.CreateDataObject()
  if not obj then return false end
  local icon = LibStub and LibStub("LibDBIcon-1.0", true)
  if not icon then return false end
  local db = UI.DB()
  if not Minimap.registered then
    icon:Register(NAME, obj, db.minimap)
    Minimap.registered = true
  end
  Minimap.Update()
  return true
end

function Minimap.Update()
  local icon = LibStub and LibStub("LibDBIcon-1.0", true)
  if not icon or not Minimap.registered then return end
  if UI.DB().minimap.hide then icon:Hide(NAME) else icon:Show(NAME) end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_LOGIN")
  Minimap.Register()
end)
