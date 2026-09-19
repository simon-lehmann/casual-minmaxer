local H = require("tests.helpers")

describe("Player", function()
  local CMM
  before_each(function() CMM = H.Boot() end)

  it("snapshots the default character", function()
    local p = CMM.Player.Get()
    assert.equals("WARRIOR", p.class)
    assert.equals(62, p.level)
    assert.equals("Alliance", p.faction)
    assert.equals(CMM.Constants.ALLIANCE_MASK, p.factionMask)
    assert.equals(1, p.raceMask)
    assert.equals(1, p.classMask)
    assert.equals("ARMS", p.spec)
    assert.equals("Zangarmarsh", p.zoneName)
    assert.is_true(p.canDualWield)
    assert.equals(300, p.professions[164])
    assert.is_nil(p.professions[171])
    assert.is_true(p.usable.armor[4])
    assert.is_true(p.usable.weapon[8])
  end)

  it("detects the spec from the talent tab with most points and honors overrides", function()
    H.wow.player.talents = { { "Arms", 5 }, { "Fury", 40 }, { "Protection", 0 } }
    CMM.Weights.DEFAULTS.WARRIOR.FURY = { name = "Fury", role = "melee", tabIndex = 2, phases = { {}, {}, {}, {}, {} } }
    CMM.Player.Refresh()
    assert.equals("FURY", CMM.Player.Get().spec)
    CasualMinMaxerCharDB.specOverride = "ARMS"
    CMM.Player.Refresh()
    assert.equals("ARMS", CMM.Player.Get().spec)
    assert.equals("FURY", CMM.Player.Get().specDetected)
    CMM.Weights.DEFAULTS.WARRIOR.FURY = nil
  end)

  it("falls back to the first known spec when the tab has no weights", function()
    H.wow.player.talents = { { "Arms", 0 }, { "Fury", 0 }, { "Protection", 20 } }
    CMM.Player.Refresh()
    assert.equals("ARMS", CMM.Player.Get().spec)
  end)

  it("supports the 5-return talent signature", function()
    local orig = _G.GetTalentTabInfo
    _G.GetTalentTabInfo = function(i) local t = H.wow.player.talents[i] return i, t[1], "desc", 1, t[2] end
    local tabs = CMM.Compat.TalentTabs()
    assert.equals("Arms", tabs[1].name)
    assert.equals(31, tabs[1].points)
    _G.GetTalentTabInfo = orig
  end)

  it("reads equipped items per slot key", function()
    H.wow.player.equipped = { [1] = 30100, [11] = 30201, [12] = 30202, [16] = 30401, [17] = 30402 }
    CMM.Player.Refresh()
    local p = CMM.Player.Get()
    assert.equals(30100, p.equipped.HEAD)
    assert.same({ 30201, 30202 }, p.equipped.FINGER)
    assert.equals(30401, p.equipped.MAINHAND)
    assert.equals(30402, p.equipped.OFFHAND)
    assert.is_nil(p.equipped.CHEST)
    assert.is_true(CMM.Player.IsEquipped(30202))
    assert.is_false(CMM.Player.IsEquipped(30203))
    assert.equals(30100, CMM.Player.Equipped("HEAD"))
  end)

  it("caches completed quests until invalidated", function()
    assert.is_false(CMM.Player.QuestDone(10015))
    H.wow.player.completedQuests[10015] = true
    assert.is_false(CMM.Player.QuestDone(10015))
    CMM.Player.InvalidateQuests()
    assert.is_true(CMM.Player.QuestDone(10015))
  end)

  it("computes usability for other classes", function()
    H.wow.player.class, H.wow.player.classToken, H.wow.player.classId = "Hunter", "HUNTER", 3
    H.wow.player.level = 30
    H.wow.player.talents = { { "Beast Mastery", 21 }, { "Marksmanship", 0 }, { "Survival", 0 } }
    CMM.Player.Refresh()
    local p = CMM.Player.Get()
    assert.equals("HUNTER", p.class)
    assert.is_true(p.usable.armor[2])
    assert.is_false(p.usable.armor[3]) -- mail only from 40
    assert.is_nil(p.usable.armor[4])
    assert.is_true(p.canDualWield)
    H.wow.player.class, H.wow.player.classToken = "Shaman", "SHAMAN"
    H.wow.player.talents = { { "Elemental", 30 }, { "Enhancement", 0 }, { "Restoration", 0 } }
    CMM.Player.Refresh()
    assert.is_false(CMM.Player.Get().canDualWield)
  end)

  it("maps localized profession names", function()
    H.wow.player.skills = { { "Schneiderei", 250, 300 }, { "Weapon Skills", 0, 0, category = true } }
    CMM.Player.Refresh()
    assert.equals(250, CMM.Player.Get().professions[197])
  end)
end)
