-- Obtainability: hard gates, tiers, expected minutes, chain progress and longevity
-- (docs/ARCHITECTURE.md §6.4, §6.5, §6.6).
local _, CMM = ...
local O = CMM.Obtain
local C = CMM.Constants
local Data = CMM.Data
local Player = CMM.Player

local band = bit and bit.band or function(a, b)
  local r, p = 0, 1
  while a > 0 and b > 0 do
    if a % 2 == 1 and b % 2 == 1 then r = r + p end
    a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2
  end
  return r
end

local function tier()
  local base = C.TIER
  local over = _G.CasualMinMaxerDB and _G.CasualMinMaxerDB.constants
  if not over then return base end
  local t = {}
  for k, v in pairs(base) do t[k] = over[k] or v end
  return t
end
O.Constants = tier

local function hasFlag(item, flag)
  return Data.HasFlag(item, flag)
end

-- Remaining quests in the chain ending at questId (quests not yet completed, walking `prev`).
function O.ChainRemaining(questId, player) -- luacheck: ignore 212/player
  local steps, first = 0, questId
  local seen = {}
  local cur = questId
  while cur and cur ~= 0 and not seen[cur] do
    seen[cur] = true
    local q = Data.Quest(cur)
    if not q then break end
    if not Player.QuestDone(cur) then
      steps = steps + 1
      first = cur
    else
      break -- everything before a completed quest is done too
    end
    cur = math.abs(q.prev or 0)
  end
  return steps, first
end

local function questUsable(q, player, opts)
  if not q then return false, "unknown quest" end
  if q.type == C.QUEST_RAID then return false, "raid" end
  if q.races ~= 0 and band(q.races, player.raceMask) == 0 then return false, "race" end
  if q.classes ~= 0 and band(q.classes, player.classMask) == 0 then return false, "class" end
  if Player.QuestDone(q.id) then return false, "done" end
  if q.minLevel > player.level + (opts.lookahead or 0) then return false, "level" end
  return true
end

local function dungeonUsable(map, player, opts)
  local d = Data.Dungeon(map)
  if not d then return true end
  if (d.min or 0) > player.level + (opts.lookahead or 0) then return false, "dungeon level" end
  return true
end

local function npcUsable(npc, player)
  if not npc then return true end
  if npc.level > player.level + 3 then return false, "content level" end
  return true
end

-- Is one source usable by this character (gates 1-7 applied per source)?
function O.SourceUsable(src, player, opts)
  local t = src.t
  if t == "Q" then
    return questUsable(Data.Quest(src.quest), player, opts)
  elseif t == "B" then
    local boss = Data.Boss(src.npc)
    if boss and boss.heroic and player.level < 70 then return false, "heroic" end
    local ok, why = npcUsable(Data.Npc(src.npc), player)
    if not ok then return false, why end
    if boss then return dungeonUsable(boss.map, player, opts) end
    return true
  elseif t == "R" or t == "N" then
    return npcUsable(Data.Npc(src.npc), player)
  elseif t == "T" then
    return dungeonUsable(src.map, player, opts)
  elseif t == "G" then
    local obj = Data.Object(src.object)
    if obj and Data.Dungeon(obj.map) then return dungeonUsable(obj.map, player, opts) end
    return true
  elseif t == "V" or t == "K" or t == "W" then
    -- reputation is not a gate (§6.4): rep vendors get a time penalty per missing rank instead
    return true
  end
  return false, "unknown source"
end

-- Hard gates (§6.4). opts = { lookahead=, phase= }
function O.Gate(item, player, opts)
  opts = opts or {}
  if item.classmask ~= 0 and band(item.classmask, player.classMask) == 0 then return false, "class" end
  if hasFlag(item, C.FLAG_ALLIANCE) and player.faction ~= "Alliance" then return false, "faction" end
  if hasFlag(item, C.FLAG_HORDE) and player.faction ~= "Horde" then return false, "faction" end
  if hasFlag(item, C.FLAG_PROFESSION) then
    local okProf = false
    for _, src in ipairs(item.src) do
      if src.t == "K" then
        local own = player.professions and player.professions[src.skillLine]
        if own and own >= (src.skill or 0) then okProf = true end
      end
    end
    if not okProf then return false, "profession" end
  end
  if item.cls == 4 then
    if not C.CanUseArmor(player.class, item.sub, player.level + (opts.lookahead or 0)) then return false, "armor" end
  elseif item.cls == 2 then
    if not C.CanUseWeapon(player.class, item.sub) then return false, "weapon" end
  end
  if item.req > player.level + (opts.lookahead or 0) then return false, "level" end
  if item.phase > (opts.phase or 5) then return false, "phase" end
  if hasFlag(item, C.FLAG_HEROIC) and player.level < 70 then return false, "heroic" end
  local usable, lastReason = false, "no source"
  for _, src in ipairs(item.src) do
    local ok, why = O.SourceUsable(src, player, opts)
    if ok then usable = true break end
    lastReason = why or lastReason
  end
  if not usable then return false, lastReason end
  return true
end

local function fmtPct(p)
  if p >= 10 then return string.format("%d%%", math.floor(p + 0.5)) end
  return string.format("%.1f%%", p)
end

local function fmtMoney(copper)
  local g = math.floor(copper / 10000)
  local s = math.floor(copper / 100) % 100
  if g > 0 then return string.format("%dg %ds", g, s) end
  local c = copper % 100
  if s > 0 then return string.format("%ds %dc", s, c) end
  return string.format("%dc", c)
end
O.FormatMoney = fmtMoney

local function zoneMatches(areaId, player)
  if not areaId or areaId == 0 then return true end
  local name = Data.ZoneName(areaId)
  return name ~= nil and name == player.zoneName
end

-- Evaluate one source -> { tier, minutes, text, group, zone, src, map, boss }
function O.EvaluateSource(src, player, opts) -- luacheck: ignore 212/opts
  local T = tier()
  local t = src.t
  if t == "Q" then
    local q = Data.Quest(src.quest)
    local steps = O.ChainRemaining(q.id, player)
    if steps < 1 then steps = 1 end
    local minutes = steps * T.minutesPerQuest
    local zoneName = Data.ZoneName(q.zone)
    local travel = not zoneMatches(q.zone, player)
    if C.QUEST_GROUP_TYPES[q.type] then
      local kind = q.type == C.QUEST_DUNGEON and "Dungeon quest" or (q.type == C.QUEST_HEROIC and "Heroic quest" or "Group quest")
      local text = kind
      if steps > 1 then text = text .. string.format(", %d steps left", steps) end
      if zoneName then text = text .. ", " .. zoneName end
      return { tier = 2, minutes = T.groupOverhead + minutes, text = text, group = true, zone = q.zone, src = src,
        quest = q, steps = steps }
    end
    if travel then minutes = minutes + T.travel end
    local text = steps > 1 and string.format("Quest, %d steps left", steps) or "Quest"
    if zoneName then text = text .. ", " .. zoneName end
    return { tier = 1, minutes = minutes, text = text, group = false, zone = q.zone, src = src, quest = q, steps = steps }
  elseif t == "B" or t == "G" then
    local pct = math.max(src.pct or 0, 0.01)
    local map, label, index
    if t == "B" then
      local boss = Data.Boss(src.npc)
      local npc = Data.Npc(src.npc)
      map = boss and boss.map or (npc and npc.map)
      index = boss and boss.index or 0
      local d = map and Data.Dungeon(map)
      local n = d and #d.bosses or 0
      label = n > 0 and string.format("Boss %d of %d", index + 1, n) or (npc and npc.name or "Boss")
      if boss and boss.heroic then label = "Heroic " .. label:sub(1, 1):lower() .. label:sub(2) end
    else
      local obj = Data.Object(src.object)
      map = obj and obj.map
      label = "Chest"
      index = 0
    end
    local d = map and Data.Dungeon(map)
    local reach = (d and d.t and d.t[index + 1]) or (6 + 7 * index)
    local minutes = (T.groupOverhead + reach) / (pct / 100)
    local text = string.format("%s, %s", label, fmtPct(pct))
    if d then text = text .. ", " .. d.name end
    local tr = pct >= T.lotteryBelowPct and 3 or 4
    return { tier = tr, minutes = minutes, text = text, group = d ~= nil, zone = d and d.zone or nil, src = src, map = map, boss = src.npc }
  elseif t == "R" then
    local npc = Data.Npc(src.npc)
    local pct = math.max(src.pct or 0, 0.01)
    local respawn = math.max(npc and npc.respawnMin or 0, T.rareMinutes)
    local text = string.format("Rare spawn, %s", fmtPct(pct))
    if npc then text = text .. ", " .. npc.name end
    return { tier = 4, minutes = respawn / (pct / 100), text = text, group = (npc and npc.rank == 4), src = src, npc = npc }
  elseif t == "N" then
    local npc = Data.Npc(src.npc)
    local pct = math.max(src.pct or 0, 0.01)
    local text = string.format("Mob drop, %s", fmtPct(pct))
    if npc then text = text .. ", " .. npc.name end
    return { tier = 4, minutes = T.namedMinutes / (pct / 100), text = text, group = (npc and npc.rank == 1), src = src, npc = npc }
  elseif t == "T" then
    local pct = math.max(src.pct or 0, 0.01)
    local d = Data.Dungeon(src.map)
    local text = string.format("Trash, %s", fmtPct(pct))
    if d then text = text .. ", " .. d.name end
    return { tier = 4, minutes = T.trashRun / (pct / 100), text = text, group = true, zone = d and d.zone, src = src, map = src.map }
  elseif t == "W" then
    local pct = math.max(src.pct or 0, 0.01)
    return { tier = 4, minutes = T.namedMinutes / (pct / 100), text = string.format("World drop, %s", fmtPct(pct)),
      group = false, src = src }
  elseif t == "V" then
    local price = (src.price or 0) > 0 and (", " .. fmtMoney(src.price)) or ""
    if src.mode == "E" then
      return { tier = 5, minutes = T.badgeGrind, text = "Badge vendor" .. price, group = false, src = src }
    elseif src.mode == "H" then
      return { tier = 5, minutes = T.honorGrind, text = "Honor / PvP vendor" .. price, group = false, src = src }
    elseif src.mode == "A" then
      return { tier = 5, minutes = T.arenaGrind, text = "Arena vendor" .. price, group = false, src = src }
    elseif src.mode == "F" then
      local rank = src.rank or 4
      local rankName = C.REP_RANK_NAMES[rank] or ("rank " .. tostring(rank))
      -- client standingId 4 neutral .. 8 exalted; item rank 4 friendly .. 7 exalted -> need standing >= rank + 1
      local standing = (src.faction and CMM.Compat.FactionStanding(src.faction)) or C.REP_STANDING_NEUTRAL
      local missing = math.max(0, (rank + 1) - standing)
      if missing == 0 then
        return { tier = 5, minutes = T.vendorWalk, text = "Reputation vendor, " .. rankName .. price, group = false, src = src }
      end
      local text = string.format("Reputation vendor, %s (%d rank%s to go)%s", rankName, missing, missing == 1 and "" or "s", price)
      return { tier = 5, minutes = T.repPerRank * missing, text = text, group = false, src = src, repMissing = missing }
    end
    return { tier = 5, minutes = T.vendorWalk, text = "Vendor" .. price, group = false, src = src }
  elseif t == "K" then
    local prof = C.SKILL_LINES[src.skillLine] or ("skill " .. tostring(src.skillLine))
    local own = player.professions[src.skillLine]
    local text = string.format("Crafted, %s %d", prof, src.skill)
    if own and own >= src.skill then
      return { tier = 1, minutes = T.craftOwn, text = text, group = false, src = src, own = true }
    end
    return { tier = 5, minutes = T.craftOther, text = text, group = false, src = src, own = false }
  end
  return nil
end

-- Best obtain record among usable (and, if opts.sourceFilter is given, allowed) sources.
-- opts.sourceFilter(src, eval) -> bool lets Query apply source/dungeon/zone/group filters.
function O.Evaluate(item, player, opts)
  opts = opts or {}
  local best
  for _, src in ipairs(item.src) do
    if O.SourceUsable(src, player, opts) then
      local e = O.EvaluateSource(src, player, opts)
      if e and (not opts.sourceFilter or opts.sourceFilter(src, e)) then
        if not best or e.minutes < best.minutes or (e.minutes == best.minutes and e.tier < best.tier) then best = e end
      end
    end
  end
  return best
end

-- Guaranteed sources (tier 1/2) usable by the character at level L, ignoring the current level.
local function guaranteedAt(item, player, L)
  for _, src in ipairs(item.src) do
    if src.t == "Q" then
      local q = Data.Quest(src.quest)
      if q and q.type ~= C.QUEST_RAID and not Player.QuestDone(q.id) and q.minLevel <= L
        and (q.races == 0 or band(q.races, player.raceMask) ~= 0)
        and (q.classes == 0 or band(q.classes, player.classMask) ~= 0) then
        return true
      end
    elseif src.t == "K" then
      local own = player.professions[src.skillLine]
      if own and own >= src.skill then return true end
    end
  end
  return false
end

-- Cache of the best guaranteed score per (slotKey, level) for one query context.
-- ctx.weightsAt(L) returns the weights for level L.
local function bestGuaranteed(slotKey, ctx, player, L)
  ctx.guaranteedCache = ctx.guaranteedCache or {}
  local key = slotKey .. ":" .. L
  local cached = ctx.guaranteedCache[key]
  if cached then return cached end
  local best = 0
  local lctx = { level = L, weights = ctx.weightsAt and ctx.weightsAt(L) or ctx.weights, class = ctx.class, spec = ctx.spec,
    slotKey = slotKey }
  for _, id in ipairs(Data.ItemsForSlot(slotKey)) do
    local it = Data.Item(id)
    if it and it.req <= L and it.phase <= (ctx.phase or 5)
      and (it.classmask == 0 or band(it.classmask, player.classMask) ~= 0)
      and ((it.cls == 4 and C.CanUseArmor(player.class, it.sub, L)) or (it.cls == 2 and C.CanUseWeapon(player.class, it.sub)))
      and (not CMM.Query.UsableBySlot or CMM.Query.UsableBySlot(it, slotKey, player, { level = L }))
      and guaranteedAt(it, player, L) then
      local s = CMM.Scoring.ScoreItem(it, lctx)
      if s > best then best = s end
    end
  end
  ctx.guaranteedCache[key] = best
  return best
end

-- Lowest level above the character's where a guaranteed item for the slot beats this item; 70 if none.
function O.LastsUntil(item, slotKey, ctx, player)
  for L = player.level + 1, 70 do
    local lctx = { level = L, weights = ctx.weightsAt and ctx.weightsAt(L) or ctx.weights, class = ctx.class, spec = ctx.spec,
      slotKey = slotKey }
    local own = CMM.Scoring.ScoreItem(item, lctx)
    if bestGuaranteed(slotKey, ctx, player, L) > own then return L end
  end
  return 70
end
