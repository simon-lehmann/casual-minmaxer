-- Casual MinMaxer: addon namespace and module registry.
-- Every file starts with `local ADDON, CMM = ...`; the client passes the addon name and this table.
local ADDON, CMM = ...

CMM.name = ADDON
CMM.version = (GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version")) or "dev"
if CMM.version:find("^@") then CMM.version = "dev" end

-- Modules register themselves here; Core wires them together on PLAYER_LOGIN.
CMM.Constants = CMM.Constants or {}
CMM.Compat = CMM.Compat or {}
CMM.Ratings = CMM.Ratings or {}
CMM.Weights = CMM.Weights or {}
CMM.Specials = CMM.Specials or {}
CMM.Data = CMM.Data or {}
CMM.Player = CMM.Player or {}
CMM.Scoring = CMM.Scoring or {}
CMM.Obtain = CMM.Obtain or {}
CMM.Query = CMM.Query or {}
CMM.Pawn = CMM.Pawn or {}
CMM.Export = CMM.Export or {}
CMM.Validate = CMM.Validate or {}
CMM.UI = CMM.UI or {}

-- Localization table: L["key"] falls back to the key itself.
CMM.L = CMM.L or setmetatable({}, { __index = function(_, k) return k end })

-- Lightweight event bus so logic modules can notify the UI without frame dependencies.
local listeners = {}
function CMM.On(event, fn)
  listeners[event] = listeners[event] or {}
  listeners[event][#listeners[event] + 1] = fn
end
function CMM.Fire(event, ...)
  for _, fn in ipairs(listeners[event] or {}) do fn(...) end
end

function CMM.Print(msg, ...)
  if select("#", ...) > 0 then msg = string.format(msg, ...) end
  (DEFAULT_CHAT_FRAME or { AddMessage = print }):AddMessage("|cff33ccffCasual MinMaxer|r: " .. tostring(msg))
end

function CMM.Debug(msg, ...)
  if CMM.debug then CMM.Print("[debug] " .. msg, ...) end
end

_G.CasualMinMaxer = CMM
