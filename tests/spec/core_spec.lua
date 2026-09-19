local H = require("tests.helpers")

describe("Core", function()
  local CMM
  before_each(function() CMM = H.LoadAddon() end)

  it("creates SavedVariables with defaults", function()
    assert.is_nil(CasualMinMaxerDB)
    CMM.Core.InitSavedVariables()
    assert.equals(1, CasualMinMaxerDB.version)
    assert.equals(5, CasualMinMaxerDB.phase)
    assert.is_false(CasualMinMaxerDB.minimap.hide)
    assert.equals(2, CasualMinMaxerCharDB.lookahead)
    assert.is_true(CasualMinMaxerCharDB.filters.tiers[3])
    assert.is_false(CasualMinMaxerCharDB.filters.tiers[4])
    assert.is_false(CasualMinMaxerCharDB.filters.sources.W)
    assert.equals("eff", CasualMinMaxerCharDB.filters.sort)
    assert.same({}, CasualMinMaxerCharDB.hidden)
    assert.equals(CasualMinMaxerDB, CMM.db)
  end)

  it("keeps existing values and fills missing ones", function()
    _G.CasualMinMaxerDB = { version = 1, phase = 2, ui = { scale = 1.5 } }
    _G.CasualMinMaxerCharDB = { version = 1, lookahead = 4, filters = { sort = "gain" }, hidden = { [5] = true } }
    CMM.Core.InitSavedVariables()
    assert.equals(2, CasualMinMaxerDB.phase)
    assert.equals(1.5, CasualMinMaxerDB.ui.scale)
    assert.equals(760, CasualMinMaxerDB.ui.w)
    assert.equals(4, CasualMinMaxerCharDB.lookahead)
    assert.equals("gain", CasualMinMaxerCharDB.filters.sort)
    assert.is_true(CasualMinMaxerCharDB.filters.tiers[1])
    assert.is_true(CasualMinMaxerCharDB.hidden[5])
  end)

  it("runs migrations in order", function()
    CMM.Core.DB_VERSION = 3
    CMM.Core.DB_DEFAULTS.version = 3
    local log = {}
    CMM.Core.DB_MIGRATIONS[1] = function(db) log[#log + 1] = 1; db.a = 1 end
    CMM.Core.DB_MIGRATIONS[2] = function(db) log[#log + 1] = 2; db.b = db.a + 1 end
    _G.CasualMinMaxerDB = { version = 1 }
    CMM.Core.InitSavedVariables()
    assert.same({ 1, 2 }, log)
    assert.equals(3, CasualMinMaxerDB.version)
    assert.equals(2, CasualMinMaxerDB.b)
    -- unversioned (very old) data runs from 0
    _G.CasualMinMaxerDB = {}
    CMM.Core.InitSavedVariables()
    assert.equals(3, CasualMinMaxerDB.version)
  end)

  it("migrates version-1 character filters to the split vendor keys", function()
    CMM = H.LoadAddon() -- resets the saved variables; set the legacy table afterwards
    _G.CasualMinMaxerCharDB = { version = 1, filters = { sources = { Q = true, V = false, B = true, W = false },
      tiers = { [1] = true } } }
    CMM.Core.InitSavedVariables()
    local f = _G.CasualMinMaxerCharDB.filters.sources
    assert.equals(CMM.Core.CHAR_VERSION, _G.CasualMinMaxerCharDB.version)
    assert.is_false(f.V)
    assert.is_false(f.E) -- follows the old vendor choice
    assert.is_false(f.H)
    assert.is_false(f.F)
    assert.is_false(f.A)
    assert.is_true(f.Q)
    assert.is_true(f.K) -- missing keys get the default
    _G.CasualMinMaxerCharDB = { version = 1, filters = { sources = { V = true } } }
    CMM.Core.InitSavedVariables()
    f = _G.CasualMinMaxerCharDB.filters.sources
    assert.is_true(f.E and f.H and f.F)
    assert.is_false(f.A)
  end)

  it("resets settings", function()
    CMM = H.Boot()
    CasualMinMaxerDB.phase = 1
    CasualMinMaxerCharDB.hidden[1] = true
    CMM.Core.ResetSavedVariables()
    assert.equals(5, CasualMinMaxerDB.phase)
    assert.same({}, CasualMinMaxerCharDB.hidden)
  end)

  it("overlays custom weights on the defaults", function()
    CMM = H.Boot()
    local w = CMM.Core.ActiveWeights()
    assert.equals(1, w.STR)
    CMM.Core.SetCustomWeights("ARMS", { STR = 2, HASTE = 3 })
    w = CMM.Core.ActiveWeights()
    assert.equals(2, w.STR)
    assert.equals(3, w.HASTE)
    assert.equals(0.45, w.STA)
    assert.equals(0.45, CMM.Core.ActiveWeightsAt(65).STA)
    CMM.Core.SetCustomWeights("ARMS", nil)
    assert.equals(1, CMM.Core.ActiveWeights().STR)
  end)

  it("fires WEIGHTS_CHANGED and PLAYER_CHANGED and invalidates the cache", function()
    CMM = H.Boot()
    local fired = {}
    CMM.On("WEIGHTS_CHANGED", function(spec) fired.weights = spec end)
    CMM.On("PLAYER_CHANGED", function(reason) fired.player = reason end)
    CMM.On("SETTINGS_CHANGED", function() fired.settings = true end)
    local a = CMM.Query.Run("HEAD", CMM.Player.Get())
    CMM.Core.SetCustomWeights("ARMS", { STR = 2 })
    assert.equals("ARMS", fired.weights)
    assert.not_equals(a, CMM.Query.Run("HEAD", CMM.Player.Get()))
    H.wow.player.level = 63
    H.wow.FireEvent("PLAYER_LEVEL_UP", 63)
    assert.equals("PLAYER_LEVEL_UP", fired.player)
    assert.equals(63, CMM.Player.Get().level)
    H.wow.player.completedQuests[10015] = true
    H.wow.FireEvent("QUEST_TURNED_IN", 10015)
    assert.is_true(CMM.Player.QuestDone(10015))
    assert.is_true(CMM.Core.SetPhase(3))
    assert.is_true(fired.settings)
    assert.equals(3, CasualMinMaxerDB.phase)
    assert.is_false(CMM.Core.SetPhase(9))
  end)

  it("initializes on PLAYER_LOGIN", function()
    local fired = {}
    CMM.On("PLAYER_LOGIN", function() fired.login = true end)
    H.LoadFixtureData()
    H.wow.FireEvent("PLAYER_LOGIN")
    assert.is_true(fired.login)
    assert.is_table(CasualMinMaxerDB)
    assert.equals("WARRIOR", CMM.Player.Get().class)
  end)

  it("dispatches slash commands", function()
    CMM = H.Boot()
    local calls = {}
    CMM.UI = { Toggle = function() calls.toggle = true end, Show = function(slot) calls.show = slot end,
      OpenOptions = function() calls.options = true end, Refresh = function() calls.refresh = true end }
    local slash = SlashCmdList["CASUALMINMAXER"]
    assert.equals("/cmm", SLASH_CASUALMINMAXER1)
    slash("")
    assert.is_true(calls.toggle)
    slash("head")
    assert.equals("HEAD", calls.show)
    slash("  Ring ")
    assert.equals("FINGER", calls.show)
    slash("options")
    assert.is_true(calls.options)
    slash("phase 2")
    assert.equals(2, CasualMinMaxerDB.phase)
    slash("spec fury")
    assert.is_nil(CasualMinMaxerCharDB.specOverride) -- unknown spec for the placeholder table
    slash("spec arms")
    assert.equals("ARMS", CasualMinMaxerCharDB.specOverride)
    slash("spec auto")
    assert.is_nil(CasualMinMaxerCharDB.specOverride)
    slash("hide 30010")
    assert.is_true(CasualMinMaxerCharDB.hidden[30010])
    assert.is_true(calls.refresh)
    slash("unhide")
    assert.same({}, CasualMinMaxerCharDB.hidden)
    slash("debug")
    assert.is_true(CMM.debug)
    slash("debug")
    slash("export")
    local last = H.wow.chat[#H.wow.chat]
    assert.matches("export string", last)
    slash("validate 3")
    assert.matches("validate:", H.wow.chat[#H.wow.chat])
    slash("reset")
    assert.equals(5, CasualMinMaxerDB.phase)
    slash("bogus")
    assert.matches("unknown command", H.wow.chat[#H.wow.chat])
    slash("help")
    assert.matches("/cmm", H.wow.chat[#H.wow.chat])
  end)

  it("reports a missing UI without erroring", function()
    CMM = H.Boot()
    CMM.UI = {}
    SlashCmdList["CASUALMINMAXER"]("")
    assert.matches("UI not loaded", H.wow.chat[#H.wow.chat])
  end)

  it("EnsureData loads the data addon or explains the failure", function()
    CMM = H.Boot()
    assert.is_true(CMM.Core.EnsureData())
    H.RemoveData(CMM)
    assert.is_false(CMM.Core.EnsureData())
    assert.matches("CasualMinMaxer_Data", H.wow.chat[#H.wow.chat])
  end)
end)
