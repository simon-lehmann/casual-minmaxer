-- Default stat weights per class / spec / level phase, default gems and socket bonuses.
-- API is fixed by docs/ARCHITECTURE.md §5; the content tables are hand-authored.
local _, CMM = ...
local W = CMM.Weights

W.PHASES = { { 1, 19 }, { 20, 39 }, { 40, 57 }, { 58, 69 }, { 70, 70 } }

-- W.DEFAULTS[classToken][specKey] = { name = "Arms", role = "melee"|"tank"|"caster"|"healer"|"ranged",
--   tabIndex = 1, phases = { [1] = {STA=..}, [2] = {...}, [3] = {...}, [4] = {...}, [5] = {...} } }
W.DEFAULTS = W.DEFAULTS or {}

-- placeholder content: replaced by the weights author. Keep the API below unchanged.
W.DEFAULTS.WARRIOR = W.DEFAULTS.WARRIOR or {
  ARMS = { name = "Arms", role = "melee", tabIndex = 1, phases = {
    { STR = 1, AGI = 0.6, STA = 0.7, AP = 0.5, CRIT = 12, HIT = 10, DPS = 4, SPEEDPREF = 1, ARMOR = 0.02 },
    { STR = 1, AGI = 0.6, STA = 0.6, AP = 0.5, CRIT = 12, HIT = 10, DPS = 4, SPEEDPREF = 1, ARMOR = 0.02 },
    { STR = 1, AGI = 0.6, STA = 0.5, AP = 0.5, CRIT = 12, HIT = 10, DPS = 4.5, SPEEDPREF = 1, ARMOR = 0.02 },
    { STR = 1, AGI = 0.6, STA = 0.45, AP = 0.5, CRIT = 14, HIT = 12, DPS = 5, SPEEDPREF = 1, ARMOR = 0.01, EXP = 16 },
    { STR = 1, AGI = 0.6, STA = 0.3, AP = 0.5, CRIT = 16, HIT = 16, DPS = 5.5, SPEEDPREF = 1, ARMOR = 0.01, EXP = 20, ARP = 0.1 },
  } },
}

function W.Specs(classToken)
  local out = {}
  for key, spec in pairs(W.DEFAULTS[classToken] or {}) do out[#out + 1] = { key = key, name = spec.name, role = spec.role, tabIndex = spec.tabIndex } end
  table.sort(out, function(a, b) return (a.tabIndex or 0) < (b.tabIndex or 0) end)
  return out
end

function W.PhaseIndex(level)
  for i, p in ipairs(W.PHASES) do
    if level >= p[1] and level <= p[2] then return i end
  end
  return #W.PHASES
end

-- Blend the weights of the phase containing `level` with the next phase over the last 3 levels
-- before the boundary, so a level 57 character already leans toward 58-69 weights.
local BLEND = 3
function W.Get(classToken, specKey, level)
  local spec = W.DEFAULTS[classToken] and W.DEFAULTS[classToken][specKey]
  if not spec then return {} end
  local i = W.PhaseIndex(level)
  local cur, nxt = spec.phases[i], spec.phases[i + 1]
  local out = {}
  for k, v in pairs(cur) do out[k] = v end
  if nxt then
    local boundary = W.PHASES[i][2] + 1
    local d = boundary - level -- 1..BLEND
    if d <= BLEND then
      local t = (BLEND - d + 1) / (BLEND + 1) -- level 57 (d=1) -> 0.75 toward next
      for k, v in pairs(nxt) do out[k] = (out[k] or 0) * (1 - t) + v * t end
      for k, v in pairs(cur) do if nxt[k] == nil then out[k] = v * (1 - t) end end
    end
  end
  return out
end

-- Default gem stats by socket color for the spec's role. Uncommon gems below 70, rare gems at 70.
W.GEMS = W.GEMS or {}
function W.DefaultGem(classToken, specKey, level, color)
  local spec = W.DEFAULTS[classToken] and W.DEFAULTS[classToken][specKey]
  local role = spec and spec.role or "melee"
  local tier = level >= 70 and "rare" or "uncommon"
  local byRole = W.GEMS[role] or W.GEMS.melee or {}
  local byTier = byRole[tier] or {}
  return byTier[color] or {}
end

-- Socket bonus enchantment id -> stats table (hand table; unknown ids return nil and the bonus is estimated)
W.SOCKET_BONUS = W.SOCKET_BONUS or {}
function W.SocketBonus(enchantId)
  return W.SOCKET_BONUS[enchantId]
end
