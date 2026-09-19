-- TBC combat rating conversion (docs/ARCHITECTURE.md §2).
-- rating per 1 % = base60[key] × f(L)
local _, CMM = ...
local R = CMM.Ratings

R.BASE60 = {
  HIT = 10, SPHIT = 8, CRIT = 14, SPCRIT = 14, HASTE = 10, SPHASTE = 10,
  DEF = 1.5, DODGE = 12, PARRY = 15, BLOCK = 5, RES = 25, EXP = 2.5,
}

function R.LevelFactor(level)
  level = math.max(1, math.min(70, math.floor(tonumber(level) or 70)))
  if level <= 10 then return 2 / 52 end
  if level <= 59 then return (level - 8) / 52 end
  return 82 / (262 - 3 * level)
end

function R.PerPercent(key, level)
  local base = R.BASE60[key]
  if not base then return nil end
  return base * R.LevelFactor(level)
end

function R.ToPercent(key, rating, level)
  local per = R.PerPercent(key, level)
  if not per then return rating end
  return rating / per
end
