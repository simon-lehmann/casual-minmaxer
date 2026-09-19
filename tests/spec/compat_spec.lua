local H = require("tests.helpers")

describe("Compat", function()
  local CMM
  before_each(function() CMM = H.Boot() end)

  it("parses Equip: tooltip lines into canonical stats", function()
    local P = CMM.Compat.ParseEquipLine
    assert.same({ AP = 58 }, P("Equip: Increases attack power by 58."))
    assert.same({ SP = 36 }, P("Equip: Increases damage and healing done by magical spells and effects by up to 36."))
    assert.same({ HEAL = 106, SP = 36 },
      P("Equip: Increases healing done by up to 106 and damage done by up to 36 for all magical spells and effects."))
    assert.same({ MP5 = 8 }, P("Equip: Restores 8 mana per 5 sec."))
    assert.same({ SPHIT = 10 }, P("Equip: Increases your spell hit rating by 10."))
    assert.same({ CRIT = 14 }, P("Equip: Improves critical strike rating by 14."))
    assert.same({ RAP = 22 }, P("Equip: Increases ranged attack power by 22."))
    assert.same({ BLOCKV = 20 }, P("Equip: Increases the block value of your shield by 20."))
    assert.same({ FAP = 40 }, P("Equip: Increases attack power by 40 in Cat, Bear, Dire Bear, and Moonkin forms only."))
    assert.same({ SPSHADOW = 20 }, P("Equip: Increases damage done by Shadow spells and effects by up to 20."))
    assert.is_nil(P("Equip: Chance on hit to do something exciting."))
    assert.is_nil(P("Use: Restores 200 mana."))
    assert.is_nil(P("Erhöht die Angriffskraft um 58."))
    assert.is_nil(P(nil))
  end)

  it("scans a link's tooltip and merges stats the client does not report", function()
    local link = "item:12345"
    H.wow.items[12345] = { name = "Scan Helm", stats = { ITEM_MOD_STAMINA_SHORT = 20, ITEM_MOD_CRIT_RATING_SHORT = 14 } }
    H.wow.tooltipLines[link] = { "Scan Helm", "Head", "Equip: Increases attack power by 58.",
      "Equip: Restores 8 mana per 5 sec.", "Equip: Improves critical strike rating by 99." }
    local scanned = CMM.Compat.ScanEquipStats(link)
    assert.same({ AP = 58, MP5 = 8, CRIT = 99 }, scanned)
    local stats = CMM.Compat.ItemStatsFromClient(link)
    assert.equals(20, stats.STA)
    assert.equals(14, stats.CRIT) -- GetItemStats wins over the tooltip for reported keys
    assert.equals(58, stats.AP)
    assert.equals(8, stats.MP5)
    assert.is_nil(CMM.Compat.ItemStatsFromClient("item:1"))
    assert.same({}, CMM.Compat.ScanEquipStats(nil))
  end)

  it("maps localized profession names to skill lines", function()
    H.wow.player.skills = { { "Herrería", 300, 375 }, { "Кожевничество", 1, 75 }, { "Alchimie", 250, 300 }, { "裁缝", 40, 75 } }
    local prof = CMM.Compat.Professions()
    assert.equals(300, prof[164])
    assert.equals(1, prof[165])
    assert.equals(250, prof[171])
    assert.equals(40, prof[197])
  end)
end)
