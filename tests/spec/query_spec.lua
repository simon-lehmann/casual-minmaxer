local H = require("tests.helpers")

describe("Query", function()
  local CMM, Q, player

  local function ids(rows)
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = r.id end
    return out
  end
  local function has(rows, id) return tContains(ids(rows), id) end
  local function allTiers() return { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true } end
  local function allSources()
    local out = {}
    for _, k in ipairs(CMM.Constants.SOURCE_FILTER_KEYS) do out[k] = true end
    return out
  end
  local function filters(over)
    local f = { sources = allSources(), tiers = allTiers(), armor = "all", special = true, sidegrades = false, sort = "eff" }
    for k, v in pairs(over or {}) do f[k] = v end
    return f
  end

  before_each(function()
    CMM = H.Boot()
    Q = CMM.Query
    H.wow.player.equipped = { [1] = 30100 } -- Old Helm: STA 10 STR 10 -> 14.5
    CMM.Player.Refresh()
    player = CMM.Player.Get()
  end)

  it("returns only upgrades over the equipped item, with row fields filled", function()
    local res = Q.Run("HEAD", player, { filters = filters() })
    assert.equals(30100, res.equippedId)
    assert.is_near(14.5, res.equippedScore, 1e-9)
    assert.is_true(#res.rows > 5)
    for _, r in ipairs(res.rows) do
      assert.is_true(r.gain > 0)
      assert.is_true(r.score > res.equippedScore)
      assert.is_true(r.minutes > 0)
      assert.is_number(r.eff)
      assert.is_number(r.gainPct)
      assert.is_true(r.tier >= 1 and r.tier <= 5)
      assert.is_table(r.obtain)
      assert.is_true(r.lastsUntil >= 63 and r.lastsUntil <= 70)
      assert.is_table(r.item)
    end
    assert.is_false(has(res.rows, 30100))
    -- gated items never appear
    for _, bad in ipairs({ 30003, 30004, 30006, 30007, 30012, 30025, 30026, 30027 }) do
      assert.is_false(has(res.rows, bad), "item " .. bad .. " should be gated")
    end
  end)

  it("hides non-upgrades unless sidegrades are on", function()
    H.wow.player.equipped = { [1] = 30011 } -- Lottery Helm 43.5
    CMM.Player.Refresh()
    player = CMM.Player.Get()
    local res = Q.Run("HEAD", player, { filters = filters() })
    assert.is_true(has(res.rows, 30010)) -- 49.7 > 43.5
    assert.is_false(has(res.rows, 30028)) -- 42.05
    assert.is_false(has(res.rows, 30017)) -- 27.55
    local side = Q.Run("HEAD", player, { filters = filters(), sidegrades = true })
    assert.is_true(has(side.rows, 30028)) -- within 5 %
    assert.is_false(has(side.rows, 30017)) -- far below
    local viaFilter = Q.Run("HEAD", player, { filters = filters({ sidegrades = true }) })
    assert.is_true(has(viaFilter.rows, 30028))
  end)

  it("applies the default filters (tiers 1-3, no world drops)", function()
    local res = Q.Run("HEAD", player, { filters = CMM.Core.CHAR_DEFAULTS.filters })
    assert.is_true(has(res.rows, 30010)) -- tier 3
    assert.is_false(has(res.rows, 30011)) -- tier 4
    assert.is_false(has(res.rows, 30021)) -- W
    assert.is_false(has(res.rows, 30017)) -- tier 5 vendor
  end)

  it("filters by source type and tier", function()
    local res = Q.Run("HEAD", player, { filters = filters({ sources = { Q = true } }) })
    for _, r in ipairs(res.rows) do assert.equals("Q", r.obtain.src.t) end
    assert.is_true(has(res.rows, 30001))
    local t5 = Q.Run("HEAD", player, { filters = filters({ tiers = { [5] = true } }) })
    for _, r in ipairs(t5.rows) do assert.equals(5, r.tier) end
    assert.is_true(has(t5.rows, 30017))
    -- a filtered-out source falls back to the next best source of the same item
    local noVendor = Q.Run("HEAD", player, { filters = filters({ sources = { Q = true, B = true } }) })
    local row
    for _, r in ipairs(noVendor.rows) do if r.id == 30031 then row = r end end
    assert.equals("Q", row.obtain.src.t)
  end)

  it("filters by dungeon, zone and group", function()
    local d = Q.Run("HEAD", player, { filters = filters(), dungeon = 547 })
    assert.is_true(has(d.rows, 30010))
    assert.is_true(has(d.rows, 30015))
    assert.is_true(has(d.rows, 30016))
    assert.is_false(has(d.rows, 30001))
    assert.is_false(has(d.rows, 30013))
    local z = Q.Run("HEAD", player, { filters = filters(), zone = "current" })
    assert.is_true(has(z.rows, 30001))
    assert.is_false(has(z.rows, 30009)) -- Hellfire quest
    local z2 = Q.Run("HEAD", player, { filters = filters(), zone = 3483 })
    assert.is_true(has(z2.rows, 30009))
    assert.is_false(has(z2.rows, 30001))
    local solo = Q.Run("HEAD", player, { filters = filters({ groupOnly = "solo" }) })
    assert.is_true(has(solo.rows, 30001))
    assert.is_false(has(solo.rows, 30010))
    assert.is_false(has(solo.rows, 30005))
  end)

  it("filters armor type, specials and hidden items", function()
    local best = Q.Run("HEAD", player, { filters = filters({ armor = "best" }) })
    assert.is_false(has(best.rows, 30029)) -- leather
    assert.is_false(has(best.rows, 30001)) -- mail at 62
    assert.is_true(has(best.rows, 30010))
    local noSpecial = Q.Run("HEAD", player, { filters = filters({ special = false }) })
    assert.is_false(has(noSpecial.rows, 30023))
    assert.is_true(has(Q.Run("HEAD", player, { filters = filters() }).rows, 30023))
    local hidden = Q.Run("HEAD", player, { filters = filters(), hidden = { [30028] = true } })
    assert.is_false(has(hidden.rows, 30028))
  end)

  it("respects lookahead", function()
    local near = Q.Run("HEAD", player, { filters = filters(), lookahead = 0 })
    assert.is_true(has(near.rows, 30010))
    local far = Q.Run("HEAD", player, { filters = filters(), lookahead = 4 })
    assert.is_true(has(far.rows, 30006)) -- req 66, quest min 66
    assert.is_false(has(near.rows, 30006))
  end)

  it("sorts by efficiency, gain, fastest and value", function()
    local eff = Q.Run("HEAD", player, { filters = filters(), sort = "eff" }).rows
    for i = 2, #eff do assert.is_true(eff[i - 1].eff >= eff[i].eff) end
    local gain = Q.Run("HEAD", player, { filters = filters(), sort = "gain" }).rows
    for i = 2, #gain do assert.is_true(gain[i - 1].gain >= gain[i].gain) end
    local fast = Q.Run("HEAD", player, { filters = filters(), sort = "fast" }).rows
    for i = 2, #fast do assert.is_true(fast[i - 1].minutes <= fast[i].minutes) end
    local value = Q.Run("HEAD", player, { filters = filters(), sort = "value" }).rows
    for i = 2, #value do assert.is_true(value[i - 1].value >= value[i].value) end
    assert.is_near(eff[1].eff * (eff[1].lastsUntil - 62 + 1), eff[1].value, 1e-9)
    assert.is_near(eff[1].gain / (eff[1].minutes / 60), eff[1].eff, 1e-9)
  end)

  it("handles rings, unique-equipped and empty slots", function()
    H.wow.player.equipped = { [11] = 30204, [12] = 30201 }
    CMM.Player.Refresh()
    player = CMM.Player.Get()
    local res = Q.Run("FINGER", player, { filters = filters() })
    assert.equals(30201, res.equippedId)
    assert.is_false(has(res.rows, 30204)) -- unique and already worn
    assert.is_true(has(res.rows, 30203))
    H.wow.player.equipped = {}
    CMM.Player.Refresh()
    local empty = Q.Run("TRINKET", CMM.Player.Get(), { filters = filters() })
    assert.equals(0, empty.equippedScore)
    assert.is_true(has(empty.rows, 30302))
  end)

  it("handles weapon slots with slot-pair logic and dual wield", function()
    H.wow.player.equipped = { [16] = 30401, [17] = 30402 }
    CMM.Player.Refresh()
    player = CMM.Player.Get()
    local mh = Q.Run("MAINHAND", player, { filters = filters() })
    assert.is_true(has(mh.rows, 30403))
    assert.is_true(has(mh.rows, 30404))
    assert.is_true(has(mh.rows, 30408)) -- dagger: DPS 55 beats the old sword despite the fast-speed penalty
    local oh = Q.Run("OFFHAND", player, { filters = filters() })
    assert.is_true(has(oh.rows, 30404)) -- 1H in off hand for a dual wielder
    assert.is_true(has(oh.rows, 30405)) -- shield
    -- non dual wielder: no 1H weapons in the off-hand list
    H.wow.player.class, H.wow.player.classToken = "Paladin", "PALADIN"
    H.wow.player.talents = { { "Holy", 0 }, { "Protection", 0 }, { "Retribution", 40 } }
    CMM.Player.Refresh()
    CMM.Weights.DEFAULTS.PALADIN = { RETRIBUTION = { name = "Retribution", role = "melee", tabIndex = 3,
      phases = { {}, {}, {}, { STR = 1, STA = 0.5, DPS = 5, BLOCKV = 0.2 }, {} } } }
    local pal = CMM.Player.Get()
    local poh = Q.Run("OFFHAND", pal, { filters = filters(), weights = { STR = 1, STA = 0.5, DPS = 5, BLOCKV = 0.2 } })
    assert.is_false(has(poh.rows, 30404))
    assert.is_true(has(poh.rows, 30405))
    CMM.Weights.DEFAULTS.PALADIN = nil
  end)

  it("uses ranged weapons the class can use", function()
    local res = Q.Run("RANGED", player, { filters = filters(), weights = { RDPS = 3, AGI = 1, DPS = 1 } })
    assert.is_true(has(res.rows, 30501))
    assert.is_false(has(res.rows, 30502)) -- wand
    assert.is_false(has(res.rows, 30504)) -- idol
  end)

  it("caches results until invalidated or inputs change", function()
    local a = Q.Run("HEAD", player, { filters = filters() })
    local b = Q.Run("HEAD", player, { filters = filters() })
    assert.equals(a, b)
    Q.Invalidate()
    assert.not_equals(a, Q.Run("HEAD", player, { filters = filters() }))
    local c = Q.Run("HEAD", player, { filters = filters(), sort = "gain" })
    assert.not_equals(b, c)
  end)

  it("reverse-lookup lists wanted items per boss for a dungeon", function()
    local d = Q.RunDungeon(547, player, { filters = filters() })
    assert.is_table(d[17991])
    assert.is_true(has(d[17991], 30010))
    assert.is_true(has(d[17991], 30203) or has(d[17991], 30403) or has(d[17991], 30204))
    assert.is_table(d[17942])
    assert.is_true(has(d[17942], 30601))
    assert.is_true(has(d[0], 30015)) -- trash
    assert.is_true(has(d[0], 30016)) -- chest
    assert.is_nil(d[18678])
  end)

  it("summarizes every slot", function()
    local s = Q.SlotSummary(player, { filters = filters() })
    assert.equals(15, (function() local n = 0 for _ in pairs(s) do n = n + 1 end return n end)())
    assert.is_near(14.5, s.HEAD.equippedScore, 1e-9)
    assert.is_true(s.HEAD.count > 0)
    assert.is_true(s.HEAD.bestGain > 0)
  end)

  it("splits vendor sources by currency in the source filter", function()
    H.wow.player.level = 70
    CMM.Player.Refresh()
    local p70 = CMM.Player.Get()
    local all = Q.Run("HEAD", p70, { filters = filters() })
    assert.is_true(has(all.rows, 30020)) -- E
    assert.is_true(has(all.rows, 30040)) -- H
    assert.is_true(has(all.rows, 30041)) -- A
    assert.is_true(has(all.rows, 30018)) -- F
    local goldOnly = Q.Run("HEAD", p70, { filters = filters({ sources = { V = true } }) })
    assert.is_true(has(goldOnly.rows, 30017))
    assert.is_false(has(goldOnly.rows, 30020))
    assert.is_false(has(goldOnly.rows, 30040))
    assert.is_false(has(goldOnly.rows, 30041))
    assert.is_false(has(goldOnly.rows, 30018))
    local honor = Q.Run("HEAD", p70, { filters = filters({ sources = { H = true } }) })
    assert.same({ 30040, 30044 }, ids(honor.rows)) -- 30045 is a faction twin of 30044 and collapsed
    local defaults = Q.Run("HEAD", p70, { filters = CMM.Core.CHAR_DEFAULTS.filters, phase = 5 })
    assert.is_false(has(defaults.rows, 30041)) -- arena off by default
    assert.is_true(CMM.Core.CHAR_DEFAULTS.filters.sources.E)
    assert.is_true(CMM.Core.CHAR_DEFAULTS.filters.sources.H)
    assert.is_true(CMM.Core.CHAR_DEFAULTS.filters.sources.F)
    assert.is_true(CMM.Core.CHAR_DEFAULTS.filters.sources.W)
  end)

  it("never lists an item without sources (raid loot shipped for equipped scoring)", function()
    H.wow.player.level = 70
    CMM.Player.Refresh()
    local res = Q.Run("HEAD", CMM.Player.Get(), { filters = filters(), lookahead = 5 })
    assert.is_false(has(res.rows, 30042))
    local it = CMM.Data.Item(30042)
    assert.is_not_nil(it)
    assert.same({}, it.src)
  end)

  it("dungeon mode includes dungeon quests whose zone is the hub (qz)", function()
    -- Lost in Action (9738) is a dungeon quest in Coilfang Reservoir (3905), Slave Pens entrance zone is 3521
    local d = Q.Run("BACK", player, { filters = filters(), dungeon = 547 })
    assert.is_true(has(d.rows, 30701))
    assert.equals("Q", d.rows[1].obtain.src.t)
    local other = Q.Run("BACK", player, { filters = filters(), dungeon = 543 })
    assert.is_false(has(other.rows, 30701))
  end)

  it("unlocks plate at 40 with lookahead", function()
    H.wow.player.level = 38
    CMM.Player.Refresh()
    local p38 = CMM.Player.Get()
    local plate = CMM.Data.Item(30017) -- plate, req 58 (level gate) -> use UsableBySlot directly
    assert.is_false(Q.UsableBySlot(plate, "HEAD", p38, { lookahead = 0 }))
    assert.is_true(Q.UsableBySlot(plate, "HEAD", p38, { lookahead = 2 }))
    assert.is_true(Q.UsableBySlot(plate, "HEAD", p38, { level = 40 }))
    assert.is_true(Q.UsableBySlot(CMM.Data.Item(30404), "OFFHAND", p38, {})) -- warriors dual wield from 20
    H.wow.player.level = 15
    CMM.Player.Refresh()
    assert.is_false(Q.UsableBySlot(CMM.Data.Item(30404), "OFFHAND", CMM.Player.Get(), {}))
  end)
end)

describe("Query dedupe", function()
  it("collapses faction twins with the same name, stats and source text", function()
    local CMM = H.Boot()
    local res = CMM.Query.Run("HEAD", CMM.Player.Get(), { filters = { sources = { H = true }, tiers = { [5] = true } } })
    local twins = 0
    for _, r in ipairs(res.rows) do if r.item.name == "Twin Helm" then twins = twins + 1 end end
    assert.equals(1, twins)
    assert.equals(2, #CMM.Query.Dedupe({
      { item = { name = "A", stats = { STA = 1 } }, obtain = { text = "x" } },
      { item = { name = "A", stats = { STA = 1 } }, obtain = { text = "x" } },
      { item = { name = "A", stats = { STA = 2 } }, obtain = { text = "x" } },
    }))
  end)
end)
