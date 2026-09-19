-- Hand-assigned stat equivalents for proc / on-use / chance-on-hit items (design doc: ~100 most relevant).
-- CMM.Specials.TABLE[itemId] = { AP = 90 } etc. Values are added to the item's stats before scoring.
local _, CMM = ...
local S = CMM.Specials
S.TABLE = S.TABLE or {}
function S.Get(itemId)
  return S.TABLE[itemId]
end
