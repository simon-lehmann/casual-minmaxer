-- End-to-end believability checks against the REAL generated data pack (CasualMinMaxer_Data/).
-- Design doc M1 done-criterion: "a level 62 character gets a believable top 10 for every slot".
local H = require("tests.helpers")
local wow = H.wow

local function tocFiles()
  local files = {}
  for line in io.lines("CasualMinMaxer_Data/CasualMinMaxer_Data.toc") do
    line = line:gsub("\r", "")
    if line:match("%.lua$") then files[#files + 1] = line end
  end
  return files
end

local function useRealData()
  wow.dataLoader = function()
    _G.CasualMinMaxer_Data = nil
    for _, f in ipairs(tocFiles()) do
      local chunk, err = loadfile("CasualMinMaxer_Data/" .. f)
      assert(chunk, err)
      chunk()
    end
  end
end

local SLOTS = { "HEAD", "NECK", "SHOULDER", "BACK", "CHEST", "WRIST", "HANDS", "WAIST", "LEGS", "FEET",
  "FINGER", "TRINKET", "MAINHAND", "OFFHAND", "RANGED" }

local function setup(playerFields)
  local CMM = H.LoadAddon()
  useRealData()
  for k, v in pairs(playerFields) do wow.player[k] = v end
  wow.FireEvent("PLAYER_LOGIN")
  assert.is_true(CMM.Core.EnsureData())
  CMM.Player.Refresh()
  return CMM
end

local function runAll(CMM, opts)
  local player = CMM.Player.Get()
  local out = {}
  for _, slot in ipairs(SLOTS) do
    local res = CMM.Query.Run(slot, player, opts)
    out[slot] = res
  end
  return out
end

local function defaultOpts()
  return { filters = { sources = nil, tiers = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true },
    armor = "all", special = true, sidegrades = false }, sort = "eff", lookahead = 2, showSpecial = true }
end

describe("real data pack", function()
  it("loads and decodes every item without error, within the memory budget", function()
    local CMM = setup({ level = 62, class = "Warrior", classToken = "WARRIOR", classId = 1 })
    local D = _G.CasualMinMaxer_Data
    assert.equals(D.meta.items, (function() local n = 0 for _ in pairs(D.items) do n = n + 1 end return n end)())
    collectgarbage("collect")
    local before = collectgarbage("count")
    local bad = {}
    for id in pairs(D.items) do
      local it = CMM.Data.Item(id)
      if not it or not CMM.Constants.INV_TO_SLOT[it.inv] then bad[#bad + 1] = id end
      for key in pairs(it.stats) do
        if not CMM.Constants.STAT_SET[key] then bad[#bad + 1] = id .. ":" .. key end
      end
    end
    collectgarbage("collect")
    local usedMB = (collectgarbage("count") - before) / 1024
    assert.same({}, bad)
    assert.is_true(usedMB < 14, "decoded data uses " .. usedMB .. " MB")
  end)

  it("gives a level 62 Arms warrior a believable upgrade list in every slot", function()
    local CMM = setup({ level = 62, class = "Warrior", classToken = "WARRIOR", classId = 1,
      faction = "Alliance", race = "Human", raceToken = "Human",
      talents = { { "Arms", 40 }, { "Fury", 13 }, { "Protection", 0 } }, zone = "Hellfire Peninsula" })
    local results = runAll(CMM, defaultOpts())
    local needGuaranteed = { HEAD = true, CHEST = true, LEGS = true, MAINHAND = true }
    for _, slot in ipairs(SLOTS) do
      local rows = results[slot].rows
      assert.is_true(#rows >= 10, slot .. " has only " .. #rows .. " upgrades for an empty slot")
      local sawGuaranteed = false
      -- currency vendors (badges / honor / arena) cost hours: never in the top 5.
      -- Gold vendors and auction-house suffix greens may lead an empty slot (a 30 g weapon or a
      -- "of the Bear" green is a legit quick upgrade), so guaranteed quest / own-profession items are
      -- only required within the top 15.
      for i = 1, math.min(5, #rows) do
        local src = rows[i].obtain.src
        local mode = src.t == "V" and src.mode or nil
        assert.is_true(mode ~= "E" and mode ~= "H" and mode ~= "A",
          slot .. " top 5 contains a currency vendor item: " .. rows[i].item.name)
      end
      -- ignoring auction-house suffix rows, a guaranteed item must sit within the top 10
      local seen = 0
      for _, row in ipairs(rows) do
        if not row.suffix then
          seen = seen + 1
          if row.tier <= 2 then sawGuaranteed = true end
          if seen >= 10 then break end
        end
      end
      if needGuaranteed[slot] then
        assert.is_true(sawGuaranteed, slot .. " top 10 (without auction-house rows) has no guaranteed (tier 1/2) item")
      end
      for _, row in ipairs(rows) do
        assert.is_true(#row.item.src > 0, "source-less item listed: " .. row.item.name)
      end
      local prev = math.huge
      for i, row in ipairs(rows) do
        assert.is_true(row.gain > 0, slot .. " row " .. i .. " is not an upgrade")
        assert.is_true(row.tier >= 1 and row.tier <= 5, slot .. " tier out of range")
        assert.is_true(row.minutes >= 0, slot .. " negative minutes")
        assert.is_true(row.item.req <= 64, slot .. " item above level + lookahead: " .. row.item.name)
        assert.is_true(row.eff <= prev + 1e-6, slot .. " not sorted by efficiency at row " .. i)
        prev = row.eff
        assert.is_string(row.obtain.text)
        assert.is_true(#row.obtain.text > 0, slot .. " empty obtain text for " .. row.item.name)
      end
      -- a warrior never gets cloth/leather-only caster gear ranked at the top
      local top = rows[1].item
      if top.cls == 4 and (slot == "CHEST" or slot == "LEGS" or slot == "HEAD") then
        assert.is_true(top.sub >= 3, slot .. " top item is " .. top.name .. " (subclass " .. top.sub .. ")")
      end
    end
    -- weapons: a two-hander must appear in MAINHAND, and no wand / bow in MAINHAND
    local sawTwoHand = false
    for _, row in ipairs(results.MAINHAND.rows) do
      assert.is_true(row.item.inv == 13 or row.item.inv == 17 or row.item.inv == 21, "bad inv in MAINHAND: " .. row.item.name)
      if row.item.inv == 17 then sawTwoHand = true end
    end
    assert.is_true(sawTwoHand)
    for _, row in ipairs(results.RANGED.rows) do
      assert.is_true(row.item.sub == 2 or row.item.sub == 3 or row.item.sub == 16 or row.item.sub == 18,
        "warrior ranged slot got " .. row.item.name)
    end
  end)

  it("respects gates for a Horde character: no Alliance quests, no Alliance-only items", function()
    local CMM = setup({ level = 62, class = "Shaman", classToken = "SHAMAN", classId = 7,
      faction = "Horde", race = "Orc", raceToken = "Orc",
      talents = { { "Elemental", 10 }, { "Enhancement", 43 }, { "Restoration", 0 } }, zone = "Zangarmarsh" })
    local results = runAll(CMM, defaultOpts())
    local D = _G.CasualMinMaxer_Data
    for _, slot in ipairs(SLOTS) do
      for _, row in ipairs(results[slot].rows) do
        assert.is_true(bit.band(row.item.flags, 64) == 0, "Alliance-only item for Horde: " .. row.item.name)
        if row.obtain.src.t == "Q" then
          local q = CMM.Data.Quest(row.obtain.src.quest)
          assert.is_not_nil(q)
          assert.is_true(q.races ~= "A", "Alliance quest " .. q.title .. " for Horde: " .. row.item.name)
        end
      end
      assert.is_true(#results[slot].rows >= 5, slot .. " has only " .. #results[slot].rows .. " rows")
    end
    assert.is_not_nil(D)
  end)

  it("marks completed quests as gone and shortens chains", function()
    local CMM = setup({ level = 62, class = "Priest", classToken = "PRIEST", classId = 5,
      faction = "Alliance", race = "Human", raceToken = "Human",
      talents = { { "Discipline", 0 }, { "Holy", 10 }, { "Shadow", 43 } }, zone = "Zangarmarsh" })
    local player = CMM.Player.Get()
    -- Lost in Action (9738) rewards Cenarion Ring of Casting (25541); chain prev = 9876
    local ok = CMM.Obtain.Gate(CMM.Data.Item(25541), player, defaultOpts())
    assert.is_true(ok)
    local steps = CMM.Obtain.ChainRemaining(9738, player)
    assert.is_true(steps >= 2, "chain should have at least 2 steps, got " .. tostring(steps))
    wow.player.completedQuests[9876] = true
    CMM.Player.Refresh()
    player = CMM.Player.Get()
    assert.equals(1, CMM.Obtain.ChainRemaining(9738, player))
    wow.player.completedQuests[9738] = true
    CMM.Player.Refresh()
    player = CMM.Player.Get()
    local gated = CMM.Obtain.Gate(CMM.Data.Item(25541), player, defaultOpts())
    assert.is_false(gated)
  end)

  it("dungeon reverse lookup lists wanted items per boss for The Slave Pens", function()
    local CMM = setup({ level = 63, class = "Druid", classToken = "DRUID", classId = 11,
      faction = "Horde", race = "Tauren", raceToken = "Tauren",
      talents = { { "Balance", 0 }, { "Feral", 0 }, { "Restoration", 54 } }, zone = "Zangarmarsh" })
    local player = CMM.Player.Get()
    local byBoss = CMM.Query.RunDungeon(547, player, defaultOpts())
    local total = 0
    for _, entry in ipairs(CMM.Data.Dungeon(547).bosses) do
      local rows = byBoss[entry]
      assert.is_not_nil(rows, "no rows for boss " .. entry)
      total = total + #rows
      for _, row in ipairs(rows) do
        assert.is_true(row.gain > 0)
      end
    end
    assert.is_true(total >= 3, "expected some wanted items in Slave Pens, got " .. total)
    -- Coilfang Hammer of Renewal (24378, Rokmar 20 %) is a healer main hand and should be wanted by an empty-handed resto druid
    local found = false
    for _, row in ipairs(byBoss[17991] or {}) do if row.id == 24378 then found = true end end
    assert.is_true(found, "Coilfang Hammer of Renewal missing from Rokmar's list")
  end)

  it("a level 70 character sees heroic-only items, a level 62 does not", function()
    local CMM = setup({ level = 70, class = "Rogue", classToken = "ROGUE", classId = 4,
      faction = "Alliance", race = "Gnome", raceToken = "Gnome",
      talents = { { "Assassination", 20 }, { "Combat", 41 }, { "Subtlety", 0 } }, zone = "Shattrath City" })
    local results = runAll(CMM, defaultOpts())
    local heroic = 0
    for _, slot in ipairs(SLOTS) do
      for _, row in ipairs(results[slot].rows) do
        if bit.band(row.item.flags, 32) ~= 0 then heroic = heroic + 1 end
      end
    end
    assert.is_true(heroic > 0, "no heroic items at 70")
    wow.player.level = 62
    CMM.Player.Refresh()
    CMM.Query.Invalidate()
    results = runAll(CMM, defaultOpts())
    for _, slot in ipairs(SLOTS) do
      for _, row in ipairs(results[slot].rows) do
        assert.is_true(bit.band(row.item.flags, 32) == 0, "heroic-only item at 62: " .. row.item.name)
      end
    end
  end)

  it("upgrades only: an item that is already equipped or worse never shows", function()
    local CMM = setup({ level = 62, class = "Warrior", classToken = "WARRIOR", classId = 1,
      faction = "Alliance", race = "Human", raceToken = "Human",
      talents = { { "Arms", 40 }, { "Fury", 13 }, { "Protection", 0 } }, zone = "Zangarmarsh" })
    local opts = defaultOpts()
    local player = CMM.Player.Get()
    local first = CMM.Query.Run("HEAD", player, opts)
    assert.is_true(#first.rows > 0)
    local best
    for _, r in ipairs(first.rows) do if not r.suffix then best = r break end end
    assert.is_not_nil(best)
    -- equip the best non-suffix head item (the stub's inventory links carry no suffix id)
    wow.player.equipped[1] = best.id
    CMM.Player.Refresh()
    CMM.Query.Invalidate()
    local second = CMM.Query.Run("HEAD", CMM.Player.Get(), opts)
    for _, row in ipairs(second.rows) do
      assert.is_true(row.id ~= best.id, "equipped item listed as upgrade")
      assert.is_true(row.score > best.score, "non-upgrade listed: " .. row.item.name)
    end
    assert.is_true(#second.rows < #first.rows)
  end)

  it("runs a full slot sweep quickly enough for one frame budget", function()
    local CMM = setup({ level = 45, class = "Mage", classToken = "MAGE", classId = 8,
      faction = "Horde", race = "Undead", raceToken = "Scourge",
      talents = { { "Arcane", 0 }, { "Fire", 36 }, { "Frost", 0 } }, zone = "Tanaris" })
    local t0 = os.clock()
    runAll(CMM, defaultOpts())
    local dt = os.clock() - t0
    assert.is_true(dt < 3, "15-slot sweep took " .. dt .. " s (cold, all decoding included)")
  end)

  it("lists auction-house random-suffix greens with real stats for a level 62 Arms warrior", function()
    local CMM = setup({ level = 62, class = "Warrior", classToken = "WARRIOR", classId = 1,
      faction = "Alliance", race = "Human", raceToken = "Human",
      talents = { { "Arms", 40 }, { "Fury", 13 }, { "Protection", 0 } }, zone = "Zangarmarsh" })
    local results = runAll(CMM, defaultOpts())
    local ahRows, perBase = 0, {}
    for _, slot in ipairs({ "CHEST", "LEGS" }) do
      for _, row in ipairs(results[slot].rows) do
        if row.suffix then
          local hasS = false
          for _, src in ipairs(row.item.src) do if src.t == "S" then hasS = true end end
          if hasS then
            ahRows = ahRows + 1
            assert.is_truthy(row.obtain.text:find("^Auction house, "), row.obtain.text)
            assert.is_true(row.suffixChance == nil or row.suffixChance >= CMM.Constants.RANDOM.minChancePct)
          end
          assert.is_truthy(row.item.name:find(" of ", 1, true), row.item.name)
          assert.is_truthy(next(row.item.suffixStats), "empty suffix stats: " .. row.item.name)
          assert.is_truthy(row.link and row.link:match("^item:%d+:0:0:0:0:0:%-?%d+$"))
          perBase[row.id] = (perBase[row.id] or 0) + 1
          assert.equals(1, perBase[row.id], "more than one row for " .. row.item.name)
          assert.is_table(row.alternatives)
          assert.is_true(#row.alternatives <= CMM.Query.MAX_ALTERNATIVES)
        end
      end
      local ahInSlot = 0
      for _, row in ipairs(results[slot].rows) do if row.obtain.src.t == "S" then ahInSlot = ahInSlot + 1 end end
      assert.is_true(ahInSlot <= CMM.Constants.RANDOM.maxAuctionRows, slot .. " has " .. ahInSlot .. " auction rows")
      assert.is_true(#results[slot].rows < 600, slot .. " has " .. #results[slot].rows .. " rows for an empty slot")
    end
    assert.is_true(ahRows >= 5, "expected auction-house rows, got " .. ahRows)
    -- an equipped green "of the Bear" is scored from base + suffix
    local anyBase
    for _, row in ipairs(results.CHEST.rows) do if row.suffix and row.suffix < 0 then anyBase = row break end end
    assert.is_not_nil(anyBase)
    local ctx = { level = 62, weights = CMM.Core.ActiveWeights(), class = "WARRIOR", spec = "ARMS", slotKey = "CHEST" }
    local withSuffix = CMM.Scoring.ScoreEquippedId(anyBase.id, "CHEST", ctx, anyBase.link .. ":0")
    local plain = CMM.Scoring.ScoreEquippedId(anyBase.id, "CHEST", ctx, "item:" .. anyBase.id)
    assert.is_true(withSuffix > plain)
  end)
end)
