local _, CMM = ...
-- English is the fallback: L[key] returns key. Only keys whose display text differs from the key go here.
-- Locales load before Init.lua in the .toc, so create the fallback table here if needed.
CMM.L = CMM.L or setmetatable({}, { __index = function(_, k) return k end })
local L = CMM.L
L["CMM_TITLE"] = "Casual MinMaxer"
