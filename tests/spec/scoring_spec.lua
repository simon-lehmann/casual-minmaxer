local H = require("tests.helpers")

describe("Scoring", function()
  local CMM, S
  before_each(function()
    CMM = H.Boot()
    S = CMM.Scoring
  end)

  describe("ScoreStats", function()
    it("sums weighted flat stats", function()
      assert.equals(35, S.ScoreStats({ STR = 20, STA = 30 }, { STR = 1, STA = 0.5 }, 62))
    end)
    it("converts ratings to percent at the given level", function()
      -- 14 crit rating = 1 % at 60, 22.08 at 70
      assert.is_near(12, S.ScoreStats({ CRIT = 14 }, { CRIT = 12 }, 60), 1e-9)
      assert.is_near(12 * 14 / 22.077, S.ScoreStats({ CRIT = 14 }, { CRIT = 12 }, 70), 0.01)
    end)
    it("ignores unknown weights and SPEED", function()
      assert.equals(0, S.ScoreStats({ SPEED = 2.6, FOO = 5 }, { SPEED = 100, FOO = 1 }, 62))
      assert.equals(0, S.ScoreStats(nil, { STR = 1 }, 62))
    end)
  end)

  describe("ScoreItem", function()
    it("matches a hand calculation for an armor piece", function()
      local ctx = H.Ctx(CMM, "HEAD")
      -- weights at 62 (Arms phase 4): STA .45, STR 1, HIT 12 per %
      local hitPct = 10 / CMM.Ratings.PerPercent("HIT", 62)
      local expected = 28 * 0.45 + 26 * 1 + 12 * hitPct
      assert.is_near(expected, S.ScoreItem(CMM.Data.Item(30010), ctx), 1e-6)
    end)

    it("adds specials and gems, and estimates unknown socket bonuses", function()
      local ctx = H.Ctx(CMM, "HEAD")
      local plain = S.ScoreItem(CMM.Data.Item(30024), ctx) -- STA 20 STR 20
      local special = S.ScoreItem(CMM.Data.Item(30023), ctx)
      assert.is_near(plain + 40 * 0.5, special, 1e-6)
      -- no gem table: sockets add nothing and no bonus
      assert.is_near(plain, S.ScoreItem(CMM.Data.Item(30022), ctx), 1e-6)
      -- with default gems: each socket adds the gem score; unknown bonus id -> 3 × best primary weight
      CMM.Weights.GEMS = { melee = { uncommon = { R = { STR = 6 }, Y = { STR = 3, CRIT = 3 }, B = { STA = 6 } } } }
      local socketed = S.ScoreItem(CMM.Data.Item(30022), ctx)
      local gems = 6 + (3 + ctx.weights.CRIT * (3 / CMM.Ratings.PerPercent("CRIT", 62)))
      assert.is_near(plain + gems + 3 * 1, socketed, 1e-6)
      -- known bonus id
      CMM.Weights.SOCKET_BONUS[2859] = { STA = 4 }
      assert.is_near(plain + gems + 4 * 0.45, S.ScoreItem(CMM.Data.Item(30022), ctx), 1e-6)
      -- a socket color without a useful gem forfeits the bonus
      CMM.Weights.GEMS.melee.uncommon.Y = {}
      assert.is_near(plain + 6, S.ScoreItem(CMM.Data.Item(30022), ctx), 1e-6)
      CMM.Weights.GEMS = {}
      CMM.Weights.SOCKET_BONUS = {}
    end)

    it("uses rare gems at 70 and ignores meta sockets", function()
      CMM.Weights.GEMS = { melee = { uncommon = { R = { STR = 6 } }, rare = { R = { STR = 8 } } } }
      local item = { id = 1, stats = {}, sockets = "MR", sbonus = 0, flags = 0 }
      assert.is_near(6, S.ScoreItem(item, H.Ctx(CMM, "HEAD", { weights = { STR = 1 } })), 1e-9)
      assert.is_near(8, S.ScoreItem(item, H.Ctx(CMM, "HEAD", { weights = { STR = 1 }, level = 70 })), 1e-9)
      CMM.Weights.GEMS = {}
    end)

    it("scores weapon DPS with the speed preference and off-hand weights", function()
      local ctx = H.Ctx(CMM, "MAINHAND", { weights = { DPS = 5, SPEEDPREF = 1, STR = 1, DPS_OH = 2, SPEEDPREF_OH = -1 } })
      local big = CMM.Data.Item(30403) -- DPS 80 speed 3.5 STR 30 STA 25
      assert.is_near(80 * 5 + 1 * (3.5 - 2.4) * 5 * 2 + 30, S.ScoreItem(big, ctx), 1e-6)
      local ohctx = H.Ctx(CMM, "OFFHAND", { weights = ctx.weights })
      local oh = CMM.Data.Item(30402) -- DPS 38 speed 1.8
      assert.is_near(38 * 2 + (-1) * (1.8 - 2.4) * 2 * 2, S.ScoreItem(oh, ohctx), 1e-6)
      -- casters: DPS weight 0 -> weapons score by stats only
      local caster = H.Ctx(CMM, "MAINHAND", { weights = { SP = 1, INT = 0.5 } })
      assert.equals(0, S.ScoreItem(big, caster))
      -- ranged uses RDPS
      local rctx = H.Ctx(CMM, "RANGED", { weights = { RDPS = 3, AGI = 1, DPS = 100 } })
      assert.is_near(70 * 3 + 10, S.ScoreItem(CMM.Data.Item(30501), rctx), 1e-6)
      assert.is_near(100 * 100, S.ScoreItem(CMM.Data.Item(30502), H.Ctx(CMM, "RANGED", { weights = { DPS = 100 } })), 1e-6)
    end)
  end)

  describe("equipped and gain", function()
    it("uses the weaker ring as the baseline", function()
      H.wow.player.equipped = { [11] = 30201, [12] = 30202 }
      CMM.Player.Refresh()
      local ctx = H.Ctx(CMM, "FINGER")
      local score, id = S.EquippedScore("FINGER", ctx, CMM.Player.Get())
      assert.equals(30202, id)
      assert.is_near(5 + 5 * 0.45, score, 1e-6)
      local gain, pct = S.Gain(CMM.Data.Item(30203), "FINGER", ctx, CMM.Player.Get())
      assert.is_near((20 + 20 * 0.45) - (5 + 5 * 0.45), gain, 1e-6)
      assert.is_true(pct > 100)
    end)

    it("treats an empty second ring slot as zero", function()
      H.wow.player.equipped = { [11] = 30201 }
      CMM.Player.Refresh()
      local score = S.EquippedScore("FINGER", H.Ctx(CMM, "FINGER"), CMM.Player.Get())
      assert.equals(0, score)
    end)

    it("compares a two-hander against main hand plus off hand", function()
      H.wow.player.equipped = { [16] = 30401, [17] = 30402 }
      CMM.Player.Refresh()
      local ctx = H.Ctx(CMM, "MAINHAND", { weights = { DPS = 5, DPS_OH = 2, STR = 1 } })
      local p = CMM.Player.Get()
      local mh = 40 * 5 + 5
      local oh = 38 * 2
      local gain = S.Gain(CMM.Data.Item(30403), "MAINHAND", ctx, p)
      assert.is_near((80 * 5 + 30) - (mh + oh), gain, 1e-6)
      -- a one-hander only competes with the main hand
      local gain1h = S.Gain(CMM.Data.Item(30404), "MAINHAND", ctx, p)
      assert.is_near((60 * 5 + 15) - mh, gain1h, 1e-6)
      -- an off-hand candidate competes with the off hand
      local gainOH = S.Gain(CMM.Data.Item(30404), "OFFHAND", H.Ctx(CMM, "OFFHAND", { weights = ctx.weights }), p)
      assert.is_near((60 * 2 + 15) - oh, gainOH, 1e-6)
    end)

    it("compares a one-hander against a two-hander minus the best off-hand", function()
      H.wow.player.equipped = { [16] = 30407 }
      CMM.Player.Refresh()
      local ctx = H.Ctx(CMM, "MAINHAND", { weights = { DPS = 5, DPS_OH = 2, STR = 1 }, bestOffhand = 100 })
      local p = CMM.Player.Get()
      local twoH = 60 * 5 + 15
      local gain = S.Gain(CMM.Data.Item(30404), "MAINHAND", ctx, p)
      assert.is_near((60 * 5 + 15) - (twoH - 100), gain, 1e-6)
      -- off-hand candidate while a 2H is equipped
      local ohctx = H.Ctx(CMM, "OFFHAND", { weights = ctx.weights, bestMainhand1H = 200 })
      local gainOH = S.Gain(CMM.Data.Item(30402), "OFFHAND", ohctx, p)
      assert.is_near(38 * 2 - (twoH - 200), gainOH, 1e-6)
      -- floor at 0 when the best 1H already beats the 2H
      local ctx2 = H.Ctx(CMM, "MAINHAND", { weights = ctx.weights, bestOffhand = 10000 })
      assert.is_near(60 * 5 + 15, S.Gain(CMM.Data.Item(30404), "MAINHAND", ctx2, p), 1e-6)
    end)

    it("reports 100 % gain over an empty slot", function()
      local gain, pct = S.Gain(CMM.Data.Item(30010), "HEAD", H.Ctx(CMM, "HEAD"), CMM.Player.Get())
      assert.is_true(gain > 0)
      assert.equals(100, pct)
    end)

    it("falls back to the client's item stats for equipped items outside the data pack", function()
      H.wow.player.equipped = { [1] = 99999 }
      H.wow.items[99999] = { name = "Client Helm",
        stats = { ITEM_MOD_STAMINA_SHORT = 10, ITEM_MOD_STRENGTH_SHORT = 10, ITEM_MOD_CRIT_RATING_SHORT = 14 } }
      CMM.Player.Refresh()
      local ctx = H.Ctx(CMM, "HEAD")
      local score = S.EquippedScore("HEAD", ctx, CMM.Player.Get())
      assert.is_near(10 * 0.45 + 10 + 14 * 14 / CMM.Ratings.PerPercent("CRIT", 62), score, 1e-6)
      H.wow.player.equipped = { [1] = 88888 } -- unknown everywhere
      CMM.Player.Refresh()
      assert.equals(0, S.EquippedScore("HEAD", ctx, CMM.Player.Get()))
    end)

    it("scores equipped items through their full link (random suffix) and tooltip equip lines", function()
      -- the stub returns suffix stats only for the exact link (GetItemStats sees the link, not the bare id)
      H.wow.player.equipped = { [1] = 77777 }
      local link = "|cffffffff|Hitem:77777::::::::62:::::|h[item77777]|h|r"
      H.wow.items[77777] = { name = "Suffix Helm", stats = { ITEM_MOD_STAMINA_SHORT = 10 } }
      H.wow.itemsByLink = H.wow.itemsByLink or {}
      H.wow.itemsByLink[link] = { ITEM_MOD_STAMINA_SHORT = 10, ITEM_MOD_STRENGTH_SHORT = 12 }
      H.wow.tooltipLines[link] = { "Suffix Helm", "Equip: Increases attack power by 24." }
      CMM.Player.Refresh()
      local p = CMM.Player.Get()
      assert.equals(link, p.equippedLinks.HEAD)
      local ctx = H.Ctx(CMM, "HEAD")
      local score = S.EquippedScore("HEAD", ctx, p)
      assert.is_near(10 * 0.45 + 12 + 24 * 0.5, score, 1e-6)
    end)

    it("prefers pack stats for equipped raid items shipped without sources", function()
      H.wow.player.equipped = { [1] = 30042 }
      H.wow.items[30042] = { name = "Raid Helm Sourceless", stats = { ITEM_MOD_STAMINA_SHORT = 1 } }
      CMM.Player.Refresh()
      local ctx = H.Ctx(CMM, "HEAD")
      local score = S.EquippedScore("HEAD", ctx, CMM.Player.Get())
      assert.is_near(70 * 0.45 + 70, score, 1e-6)
    end)

    it("maps ITEM_MOD keys", function()
      local st = S.FromItemStats({ ITEM_MOD_SPELL_HEALING_DONE_SHORT = 100, ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 35,
        ITEM_MOD_MANA_REGENERATION_SHORT = 5, RESISTANCE0_NAME = 300, ITEM_MOD_HIT_RATING_SHORT = 0, UNKNOWN = 3 })
      assert.same({ HEAL = 100, SP = 35, MP5 = 5, ARMOR = 300 }, st)
    end)
  end)
end)
