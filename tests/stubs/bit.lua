-- Pure-Lua bit library compatible with WoW's `bit` (LuaBitOp subset) for Lua 5.1 without a C module.
local M = {}
local function tobit(x) x = x % 4294967296 return x end
function M.band(a, b, ...)
  a, b = tobit(a), tobit(b)
  local r, p = 0, 1
  for _ = 0, 31 do
    local ra, rb = a % 2, b % 2
    if ra == 1 and rb == 1 then r = r + p end
    a, b, p = (a - ra) / 2, (b - rb) / 2, p * 2
  end
  if select("#", ...) > 0 then return M.band(r, ...) end
  return r
end
function M.bor(a, b, ...)
  a, b = tobit(a), tobit(b)
  local r, p = 0, 1
  for _ = 0, 31 do
    local ra, rb = a % 2, b % 2
    if ra == 1 or rb == 1 then r = r + p end
    a, b, p = (a - ra) / 2, (b - rb) / 2, p * 2
  end
  if select("#", ...) > 0 then return M.bor(r, ...) end
  return r
end
function M.bxor(a, b)
  a, b = tobit(a), tobit(b)
  local r, p = 0, 1
  for _ = 0, 31 do
    local ra, rb = a % 2, b % 2
    if ra ~= rb then r = r + p end
    a, b, p = (a - ra) / 2, (b - rb) / 2, p * 2
  end
  return r
end
function M.lshift(a, n) return tobit(a * 2 ^ n) end
function M.rshift(a, n) return math.floor(tobit(a) / 2 ^ n) end
function M.bnot(a) return 4294967295 - tobit(a) end
return M
