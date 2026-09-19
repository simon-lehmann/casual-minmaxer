-- Random-suffix greens ("of the Bear"): data decoding, scaling, query rows, equipped scoring, filters.
local H = require("tests.helpers")

describe("Random suffix support", function()
  local CMM
  before_each(function() CMM = H.Boot() end)

  describe("Data", function()
    it("decodes the rand field and 13-field records stay compatible", function()
      local item = CMM.Data.Item(30050)
      assert.same({ -7, -5, 100 }, item.rand)
      assert.is_nil(CMM.Data.Item(30010).rand)
    end)

    it("resolves suffix names and scaled stats from RandPropPoints", function()
      assert.equals("of the Bear", CMM.Data.SuffixName(-7))
      assert.equals("of the Falcon", CMM.Data.SuffixName(100))
      assert.is_nil(CMM.Data.Suffix(-999))
      local item = CMM.Data.Item(30050)
      -- ilvl 99, uncommon, chest -> Good group 0 = 46 points: STA 10000 -> 46, STR 6666 -> floor(30.66) = 30
      assert.equals(46, CMM.Data.RandPropPoints(99, 2, 5))
      assert.equals(56, CMM.Data.RandPropPoints(99, 3, 5))
      assert.equals(34, CMM.Data.RandPropPoints(99, 2, 3)) -- shoulder group 1
      assert.equals(0, CMM.Data.RandPropPoints(98, 2, 5))
      assert.same({ STR = 30, STA = 46 }, CMM.Data.SuffixStats(item, -7))
      assert.same({ AGI = 5, INT = 5 }, CMM.Data.SuffixStats(item, 100))
    end)

    it("builds a virtual item with merged stats, name, suffix and link", function()
      local base = CMM.Data.Item(30050)
      local v = CMM.Data.WithSuffix(base, -7)
      assert.equals("Fixture Mail Chest of the Bear", v.name)
      assert.equals(-7, v.suffix)
      assert.equals("item:30050:0:0:0:0:0:-7", v.link)
      assert.same({ ARMOR = 900, STR = 30, STA = 46 }, v.stats)
      assert.same({ STR = 30, STA = 46 }, v.suffixStats)
      assert.is_false(v.rand)
      assert.equals(2, #v.src)
      assert.same({ ARMOR = 900 }, base.stats) -- base untouched
      assert.is_nil(CMM.Data.WithSuffix(base, -999))
    end)

    it("socket bonus from the data pack beats the hand table", function()
      assert.same({ STA = 4 }, CMM.Data.SocketBonus(2860))
      assert.is_nil(CMM.Data.SocketBonus(2861))
      CMM.Weights.SOCKET_BONUS[2860] = { STA = 6 }
      CMM.Weights.SOCKET_BONUS[2861] = { STA = 6 }
      assert.same({ STA = 4 }, CMM.Weights.SocketBonus(2860))
      assert.same({ STA = 6 }, CMM.Weights.SocketBonus(2861))
    end)
  end)

  describe("Obtain", function()
    it("treats the auction house as tier 5 with a short fixed time", function()
      local item = CMM.Data.Item(30050)
      local player = CMM.Player.Get()
      assert.is_true((CMM.Obtain.Gate(item, player, { lookahead = 2 })))
      local o = CMM.Obtain.Evaluate(item, player, { lookahead = 2 })
      assert.equals(5, o.tier)
      assert.equals(CMM.Constants.TIER.auction, o.minutes)
      assert.equals("Auction house", o.text)
      assert.equals("S", o.src.t)
    end)
  end)

  describe("Query", function()
    local function chestRows(sources)
      local filters = { sources = sources, tiers = { true, true, true, true, true }, armor = "all", special = true }
      return CMM.Query.Run("CHEST", CMM.Player.Get(), { filters = filters, lookahead = 2 }).rows
    end

    it("emits one row per base item: the best suffix, with the other upgrades as alternatives", function()
      local rows = chestRows({ S = true, W = true })
      local suffixRows = {}
      for _, r in ipairs(rows) do if r.id == 30050 then suffixRows[#suffixRows + 1] = r end end
      assert.equals(1, #suffixRows)
      local row = suffixRows[1]
      -- Bear (STR 30 STA 46) beats Monkey (AGI 30 STA 46) for Arms test weights; Falcon (0.3 %) is below minChancePct
      assert.equals(-7, row.suffix)
      assert.equals(3.0, row.suffixChance)
      assert.equals("Fixture Mail Chest of the Bear", row.item.name)
      assert.equals("item:30050:0:0:0:0:0:-7", row.link)
      assert.equals("Auction house, of the Bear (3% of drops)", row.obtain.text)
      assert.is_true(row.gain > 0)
      assert.equals(1, #row.alternatives)
      assert.equals(-5, row.alternatives[1].id)
      assert.equals("of the Monkey", row.alternatives[1].name)
      assert.equals(2.5, row.alternatives[1].chance)
      assert.is_true(row.alternatives[1].gain > 0 and row.alternatives[1].gain < row.gain)
      assert.is_truthy(row.alternatives[1].stats.AGI)
      -- the plain base item (armor only) is never listed as such
      for _, r in ipairs(rows) do if r.id == 30050 then assert.is_not_nil(r.suffix) end end
    end)

    it("scales auction minutes by the suffix roll chance", function()
      local T = CMM.Constants.TIER
      assert.equals(1, CMM.Obtain.SuffixFactor(3))
      assert.equals(1, CMM.Obtain.SuffixFactor(10))
      assert.is_near(2, CMM.Obtain.SuffixFactor(1.5), 1e-9)
      assert.equals(T.auctionMaxFactor, CMM.Obtain.SuffixFactor(0.01))
      assert.equals(3, CMM.Obtain.SuffixFactor(nil))
      local rows = chestRows({ S = true, W = true })
      local byId = {}
      for _, r in ipairs(rows) do byId[r.id] = r end
      -- 30050: Bear at 3 % -> 10 min; 30053: Bear at 1 % (3x) vs Monkey at 6 % (1x): best by efficiency is chosen
      assert.is_near(T.auction, byId[30050].minutes, 1e-9)
      assert.is_not_nil(byId[30053])
      if byId[30053].suffix == -7 then
        assert.is_near(T.auction * 3, byId[30053].minutes, 1e-9)
      else
        assert.is_near(T.auction, byId[30053].minutes, 1e-9)
      end
      assert.is_near(byId[30053].gain / (byId[30053].minutes / 60), byId[30053].eff, 1e-6)
      -- a bare-id pool (no chances) parses, counts as unknown chance (factor 3) and is never chance-filtered
      local bare = CMM.Data.Item(30054)
      assert.same({ -7, -5 }, bare.rand)
      assert.same({}, bare.randChance)
      assert.is_not_nil(byId[30054])
      assert.is_nil(byId[30054].suffixChance)
      assert.is_near(T.auction * 3, byId[30054].minutes, 1e-9)
      assert.equals("Auction house, of the Bear", byId[30054].obtain.text)
    end)

    it("drops suffixes below the minimum roll chance and caps auction rows per query", function()
      local rows = chestRows({ S = true, W = true })
      local ah = 0
      for _, r in ipairs(rows) do if r.obtain.src.t == "S" then ah = ah + 1 end end
      assert.equals(4, ah) -- 30050, 30053, 30054 (bare pool), 30055 (shared pool P-65)
      local pooled = CMM.Data.Item(30055)
      assert.same({ -5, -7 }, pooled.rand)
      assert.equals(6.0, pooled.randChance[-5])
      CMM.Core.SetRandomLimit("minChancePct", 2.8)
      rows = chestRows({ S = true, W = true })
      local byId = {}
      for _, r in ipairs(rows) do byId[r.id] = r end
      assert.equals(-7, byId[30050].suffix)
      assert.equals(0, #byId[30050].alternatives) -- Monkey (2.5 %) filtered out
      assert.equals(-5, byId[30053].suffix) -- Bear (1 %) filtered out, Monkey (6 %) stays
      assert.is_not_nil(byId[30054]) -- unknown chance passes
      CMM.Core.SetRandomLimit("maxAuctionRows", 1)
      rows = chestRows({ S = true, W = true })
      ah = 0
      for _, r in ipairs(rows) do if r.obtain.src.t == "S" then ah = ah + 1 end end
      assert.equals(1, ah)
      assert.equals(1, _G.CasualMinMaxerDB.random.maxAuctionRows)
      local summary = CMM.Query.SlotSummary(CMM.Player.Get(), { filters = { sources = { S = true, W = true },
        tiers = { true, true, true, true, true }, armor = "all", special = true }, lookahead = 2 })
      assert.equals(#rows, summary.CHEST.count) -- the slot count reflects the cap
      CMM.Core.SetRandomLimit("maxAuctionRows", 0)
      rows = chestRows({ S = true, W = true })
      for _, r in ipairs(rows) do assert.is_true(r.obtain.src.t ~= "S") end
      -- saved limits survive a settings re-apply and a reset restores the defaults
      CMM.Core.ApplySettings()
      assert.equals(0, CMM.Constants.RANDOM.maxAuctionRows)
      CMM.Core.ResetSavedVariables()
      assert.equals(8, CMM.Constants.RANDOM.maxAuctionRows)
      assert.equals(0.5, CMM.Constants.RANDOM.minChancePct)
    end)

    it("hides suffix rows when the auction house and world drop sources are filtered out", function()
      local rows = chestRows({ S = false, W = false, Q = true, B = true })
      for _, r in ipairs(rows) do assert.is_true(r.id ~= 30050 and r.id ~= 30053 and r.id ~= 30054) end
    end)

    it("keeps only suffixes that beat the equipped item", function()
      H.wow.player.equipped = { [5] = 30050 }
      H.wow.player.equippedLinks = nil
      CMM.Player.Refresh()
      CMM.Query.Invalidate()
      -- equip a Bear version through the link so nothing weaker (Monkey/Falcon) can be an upgrade
      local player = CMM.Player.Get()
      player.equippedLinks = player.equippedLinks or {}
      player.equippedLinks.CHEST = "item:30050:0:0:0:0:0:-7:0"
      local score, id = CMM.Scoring.EquippedScore("CHEST", H.Ctx(CMM, "CHEST"), player)
      assert.equals(30050, id)
      local ctx = H.Ctx(CMM, "CHEST")
      local bear = CMM.Scoring.ScoreItem(CMM.Data.WithSuffix(CMM.Data.Item(30050), -7), ctx)
      assert.is_near(bear, score, 1e-6)
      local filters = { sources = { S = true, W = true }, tiers = { true, true, true, true, true }, armor = "all", special = true }
      local rows = CMM.Query.Run("CHEST", player, { filters = filters, lookahead = 2 }).rows
      for _, r in ipairs(rows) do assert.is_true(r.id ~= 30050, "equipped base item listed again") end
    end)
  end)

  describe("Scoring of equipped items with a suffix", function()
    it("scores base + suffix from the pack when the link carries a known suffix", function()
      local ctx = H.Ctx(CMM, "CHEST")
      assert.equals(-7, CMM.Scoring.SuffixFromLink("item:30050:0:0:0:0:0:-7:12345"))
      assert.equals(0, CMM.Scoring.SuffixFromLink("item:30050"))
      assert.equals(584, CMM.Scoring.SuffixFromLink("|cff1eff00|Hitem:1234:0:0:0:0:0:584:0:62|h[x]|h|r"))
      local s, item = CMM.Scoring.ScoreEquippedId(30050, "CHEST", ctx, "item:30050:0:0:0:0:0:-7:0")
      assert.equals(-7, item.suffix)
      assert.is_near(CMM.Scoring.ScoreItem(CMM.Data.WithSuffix(CMM.Data.Item(30050), -7), ctx), s, 1e-6)
      local plain = CMM.Scoring.ScoreEquippedId(30050, "CHEST", ctx, "item:30050")
      assert.is_true(s > plain)
    end)

    it("falls back to the client's stats for an unknown suffix", function()
      local ctx = H.Ctx(CMM, "CHEST")
      H.wow.itemsByLink = H.wow.itemsByLink or {}
      H.wow.items[30050] = { name = "Fixture Mail Chest", stats = { ITEM_MOD_STAMINA_SHORT = 9 } }
      local s = CMM.Scoring.ScoreEquippedId(30050, "CHEST", ctx, "item:30050:0:0:0:0:0:-999:0")
      assert.is_near(9 * ctx.weights.STA, s, 1e-6)
    end)
  end)

  describe("Core", function()
    it("migrates character filters from version 2 to 3 (S on, W untouched)", function()
      _G.CasualMinMaxerCharDB = { version = 2, filters = { sources = { Q = true, W = false } } }
      CMM.Core.InitSavedVariables()
      local f = _G.CasualMinMaxerCharDB.filters.sources
      assert.is_true(f.S)
      assert.is_false(f.W)
      assert.equals(CMM.Core.CHAR_VERSION, _G.CasualMinMaxerCharDB.version)
      assert.is_true(CMM.Constants.DefaultSourceFilters().S)
      assert.is_true(CMM.Constants.DefaultSourceFilters().W)
      assert.is_false(CMM.Constants.DefaultSourceFilters().A)
    end)
  end)

  describe("Validate", function()
    it("skips random-enchant base items", function()
      local diffs, why = CMM.Validate.CheckItem(30050)
      assert.is_nil(diffs)
      assert.is_truthy(why:find("random enchant", 1, true))
    end)
  end)
end)
