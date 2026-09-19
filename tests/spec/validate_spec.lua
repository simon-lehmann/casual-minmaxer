local H = require("tests.helpers")

describe("Validate", function()
  local CMM, V
  before_each(function()
    CMM = H.Boot()
    V = CMM.Validate
  end)

  it("reports no diffs when the client agrees", function()
    H.wow.items[30010] = { name = "Boss Helm",
      stats = { ITEM_MOD_STAMINA_SHORT = 28, ITEM_MOD_STRENGTH_SHORT = 26, ITEM_MOD_HIT_RATING_SHORT = 10 } }
    local diffs = V.CheckItem(30010)
    assert.same({}, diffs)
  end)

  it("reports pack/client differences in both directions", function()
    H.wow.items[30010] = { name = "Boss Helm",
      stats = { ITEM_MOD_STAMINA_SHORT = 30, ITEM_MOD_STRENGTH_SHORT = 26, ITEM_MOD_CRIT_RATING_SHORT = 5 } }
    local diffs = V.CheckItem(30010)
    local byKey = {}
    for _, d in ipairs(diffs) do byKey[d.key] = d end
    assert.same({ key = "STA", pack = 28, client = 30 }, byKey.STA)
    assert.same({ key = "HIT", pack = 10, client = 0 }, byKey.HIT)
    assert.same({ key = "CRIT", pack = 0, client = 5 }, byKey.CRIT)
    assert.is_nil(byKey.STR)
  end)

  it("skips spell-derived keys unless the tooltip reports them, and accepts AP for pack RAP", function()
    local D = _G.CasualMinMaxer_Data
    D.items[30980] = "AP Helm;1;4;4;3;100;60;0;0;STA:10,AP:24,RAP:24,SP:5;;0;1"
    D.src[30980] = "V1:0"
    CMM.Data.Unload(); CMM.Data.Load()
    H.wow.items[30980] = { name = "AP Helm", stats = { ITEM_MOD_STAMINA_SHORT = 10 } }
    assert.same({}, V.CheckItem(30980)) -- no tooltip: AP/RAP/SP not comparable, nothing reported
    H.wow.tooltipLines[30980] = { "AP Helm", "Equip: Increases attack power by 24.",
      "Equip: Increases damage and healing done by magical spells and effects by up to 7." }
    local diffs = V.CheckItem(30980)
    assert.equals(1, #diffs)
    assert.same({ key = "SP", pack = 5, client = 7, via = "tooltip" }, diffs[1])
  end)

  it("ignores derived weapon stats", function()
    H.wow.items[30403] = { name = "Big 2H",
      stats = { ITEM_MOD_STRENGTH_SHORT = 30, ITEM_MOD_STAMINA_SHORT = 25, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 81 } }
    assert.same({}, V.CheckItem(30403))
  end)

  it("distinguishes unknown items from uncached ones", function()
    local diffs, why = V.CheckItem(1)
    assert.is_nil(diffs)
    assert.equals("not in data pack", why)
    diffs, why = V.CheckItem(30010)
    assert.is_nil(diffs)
    assert.equals("not cached by client", why)
  end)

  it("runs over random items and summarizes", function()
    H.wow.items[30010] = { name = "Boss Helm",
      stats = { ITEM_MOD_STAMINA_SHORT = 28, ITEM_MOD_STRENGTH_SHORT = 26, ITEM_MOD_HIT_RATING_SHORT = 10 } }
    H.wow.items[30011] = { name = "Lottery Helm", stats = { ITEM_MOD_STAMINA_SHORT = 1 } }
    local r = V.Run(3, { ids = { 30010, 30011, 30012 } })
    assert.equals(2, r.checked)
    assert.equals(1, r.ok)
    assert.equals(1, r.pending)
    assert.equals(1, #r.mismatches)
    assert.equals(30011, r.mismatches[1].id)
    assert.equals("Lottery Helm", r.mismatches[1].name)
    assert.matches("2 checked, 1 ok, 1 mismatched, 1 pending", H.wow.chat[#H.wow.chat - 1])
    assert.matches("STA pack=30 client=1", H.wow.chat[#H.wow.chat])
    -- random pick with a deterministic rng
    local seq, i = { 1, 1, 2 }, 0
    local rr = V.Run(2, { rng = function() i = i + 1 return seq[i] end, quiet = true })
    assert.equals(2, rr.checked + rr.pending)
  end)

  it("fails cleanly without a data pack", function()
    H.RemoveData(CMM)
    assert.is_nil(V.Run(5))
    assert.matches("data pack not available", H.wow.chat[#H.wow.chat])
  end)
end)
