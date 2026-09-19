local H = require("tests.helpers")

describe("Pawn", function()
  local CMM
  before_each(function() CMM = H.LoadAddon() end)

  it("imports a Pawn v1 string and converts ratings per point to per percent", function()
    local str = '( Pawn: v1: "Arms Leveling": Strength=1, Stamina=0.5, CritRating=0.8, HitRating=1.2, Dps=4.5, ArmorPenetration=0.1 )'
    local w, name = CMM.Pawn.Import(str, 62)
    assert.equals("Arms Leveling", name)
    assert.equals(1, w.STR)
    assert.equals(0.5, w.STA)
    assert.is_near(0.8 * CMM.Ratings.PerPercent("CRIT", 62), w.CRIT, 1e-9)
    assert.is_near(1.2 * CMM.Ratings.PerPercent("HIT", 62), w.HIT, 1e-9)
    assert.equals(4.5, w.DPS)
    assert.equals(0.1, w.ARP)
  end)

  it("maps caster names and merges duplicates", function()
    local str = '( Pawn: v1: "Heal": Healing=1, SpellDamage=0.3, SpellPower=0.2, Mp5=2.5, Intellect=0.4, '
      .. 'SpellCritRating=0.5, FireSpellDamage=0.1 )'
    local w = CMM.Pawn.Import(str, 70)
    assert.equals(1, w.HEAL)
    assert.is_near(0.5, w.SP, 1e-9)
    assert.equals(2.5, w.MP5)
    assert.is_near(0.5 * CMM.Ratings.PerPercent("SPCRIT", 70), w.SPCRIT, 1e-9)
    assert.equals(0.1, w.SPFIRE)
  end)

  it("rejects malformed strings", function()
    assert.is_nil(CMM.Pawn.Import("hello"))
    assert.is_nil(CMM.Pawn.Import('( Pawn: v1: "x": Unknown=1 )'))
    assert.is_nil(CMM.Pawn.Import(42))
    local w, why = CMM.Pawn.Import('( Pawn: v1: "x" )')
    assert.is_nil(w)
    assert.is_string(why)
  end)

  it("round-trips through export", function()
    local orig = { STR = 1, STA = 0.45, CRIT = 14, HIT = 12, DPS = 5, SP = 0 }
    local str = CMM.Pawn.Export(orig, "Test", 62)
    assert.matches('^%( Pawn: v1: "Test": ', str)
    assert.matches("Strength=1", str)
    assert.is_false(str:find("SpellDamage") ~= nil) -- zero weights are dropped
    local back = CMM.Pawn.Import(str, 62)
    assert.is_near(1, back.STR, 1e-6)
    assert.is_near(0.45, back.STA, 1e-6)
    assert.is_near(14, back.CRIT, 1e-2)
    assert.is_near(12, back.HIT, 1e-2)
    assert.is_near(5, back.DPS, 1e-6)
  end)
end)
