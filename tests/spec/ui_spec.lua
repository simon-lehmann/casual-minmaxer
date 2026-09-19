-- UI smoke tests: the UI files load standalone (with fakes for the logic modules) and their
-- entry points run without touching the real client.
local H = require("tests.helpers")
local wow = H.wow

-- Embedded libraries the UI needs (LibDBIcon is skipped: it needs a real Minimap)
local function loadLibs()
  for _, f in ipairs({ "Libs/LibStub/LibStub.lua", "Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua",
    "Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua" }) do
    local chunk = assert(loadfile("CasualMinMaxer/" .. f))
    chunk()
  end
end

-- A tiny fixture in the §4 format, used only when the logic agent's fixture is absent
local function tinyFixture(D)
  D.items[1001] = "Fixture Helm;1;4;2;3;90;60;0;0;STA:20,AGI:15,AP:30;;0;1"
  D.items[1002] = "Fixture Sword;13;2;7;3;95;62;0;16;STA:10,DPS:60.5,SPEED:2.6;;0;1"
  D.src[1001] = "Q5001|B2001:20"
  D.src[1002] = "V12500:0"
  D.quests[5001] = "Fixture Quest;60;62;A;0;3521;0;5000;0;0;1001;"
  D.quests[5000] = "Fixture Prequel;60;61;A;0;3521;0;0;5001;0;;"
  D.npcs[2001] = "Fixture Boss;64;1;547;0"
  D.bosses[2001] = "547;1;0"
  D.dungeons[547] = { name = "The Slave Pens", min = 62, max = 70, zone = 3905, heroic = true,
    bosses = { 2000, 2001 }, t = { 6, 13 } }
  D.zones[3521] = "Zangarmarsh"
  D.zones[3905] = "Coilfang Reservoir"
end

local function fakeItem(id)
  if id == 1001 then
    return { id = 1001, name = "Fixture Helm", inv = 1, cls = 4, sub = 2, q = 3, ilvl = 90, req = 60, classmask = 0,
      flags = 0, stats = { STA = 20, AGI = 15, AP = 30 }, sockets = "", sbonus = 0, phase = 1,
      src = { { t = "Q", id = 5001 }, { t = "B", npc = 2001, pct = 20 } } }
  elseif id == 1002 then
    return { id = 1002, name = "Fixture Sword", inv = 13, cls = 2, sub = 7, q = 3, ilvl = 95, req = 62, classmask = 0,
      flags = 16, stats = { STA = 10, DPS = 60.5, SPEED = 2.6 }, sockets = "", sbonus = 0, phase = 1,
      src = { { t = "V", price = 12500, mode = "0" } } }
  end
  return nil
end

local function fakeRows()
  local helm = fakeItem(1001)
  local sword = fakeItem(1002)
  return {
    { id = 1001, item = helm, score = 80, gain = 25, gainPct = 45, tier = 1, minutes = 20, eff = 75,
      obtain = { tier = 1, minutes = 20, src = helm.src[1], text = "Quest, 2 steps left, Zangarmarsh", group = false,
        zone = 3521, steps = 2 },
      lastsUntil = 68, special = false, set = false },
    { id = 1002, item = sword, score = 120, gain = 10, gainPct = 9, tier = 5, minutes = 5, eff = 120,
      obtain = { tier = 5, minutes = 5, src = sword.src[1], text = "Vendor", group = false },
      lastsUntil = 70, special = true, set = false },
  }
end

local function installFakes(CMM)
  CMM.Player.Get = function()
    return { class = "WARRIOR", classId = 1, level = 62, faction = "Alliance", race = "Human", spec = "ARMS",
      professions = { [164] = 300 }, equipped = { HEAD = 900 }, zoneName = "Zangarmarsh", canDualWield = true }
  end
  CMM.Player.QuestDone = function(id) return id == 5000 end
  CMM.Core = CMM.Core or {}
  CMM.Core.EnsureData = function() return true end
  CMM.Core.ActiveWeights = function() return { STR = 1, STA = 0.5, AGI = 0.6, AP = 0.5, DPS = 5 } end
  CMM.Data.Item = fakeItem
  CMM.Data.Dungeon = function(map) return _G.CasualMinMaxer_Data and _G.CasualMinMaxer_Data.dungeons[map] end
  CMM.Data.Npc = function(entry)
    return entry == 2001 and { name = "Fixture Boss", level = 64, rank = 1, map = 547, respawnMin = 0 } or nil
  end
  CMM.Data.Boss = function(entry) return entry == 2001 and { map = 547, index = 1, heroic = 0 } or nil end
  CMM.Data.Quest = function(id)
    if id == 5001 then return { title = "Fixture Quest", minLevel = 60, questLevel = 62, zone = 3521, prev = 5000 } end
    if id == 5000 then return { title = "Fixture Prequel", minLevel = 60, questLevel = 61, zone = 3521, prev = 0 } end
    return nil
  end
  CMM.Data.Object = function() return nil end
  CMM.Data.ZoneName = function(id) return _G.CasualMinMaxer_Data and _G.CasualMinMaxer_Data.zones[id] end
  CMM.Data.Load = function() return true end
  CMM.Query.Run = function(slotKey)
    if slotKey == "HEAD" then return { rows = fakeRows(), equippedScore = 55, equippedId = 900 } end
    if slotKey == "MAINHAND" then return { rows = { fakeRows()[2] }, equippedScore = 110, equippedId = 901 } end
    return { rows = {}, equippedScore = 0 }
  end
  CMM.Query.RunDungeon = function() return { [2001] = { fakeRows()[1] } } end
  CMM.Query.Invalidate = function() CMM._invalidated = (CMM._invalidated or 0) + 1 end
  CMM.Scoring.ScoreItem = function(item) return (item.stats.STA or 0) * 0.5 + (item.stats.AP or 0) * 0.5 end
  CMM.Scoring.Gain = function(item) return item.id == 1001 and 25 or -3, item.id == 1001 and 45 or -2 end
  CMM.Weights.Specs = function() return { { key = "ARMS", name = "Arms", role = "melee", tabIndex = 1 } } end
  CMM.Weights.Get = function() return { STR = 1, STA = 0.5, AGI = 0.6, AP = 0.5, DPS = 5, CRIT = 12 } end
  CMM.Pawn.Import = function(str) if str:find("Pawn") then return { STR = 1, STA = 0.7 }, "Test" end return nil end
  CMM.Pawn.Export = function() return "( Pawn: v1: \"CMM\": Strength=1 )" end
  CMM.Export.String = function() return "djEuLi4=" end
  CMM.Compat.HookItemTooltips = function(fn) CMM._tooltipHook = fn end
end

describe("UI modules", function()
  local CMM
  before_each(function()
    loadLibs()
    wow.anonFrames = {} -- drop event frames registered by module copies from earlier tests
    if io.open("tests/fixtures/data.lua") then H.LoadFixtureData() else H.UseData(tinyFixture) end
    CMM = H.LoadAddon({ ui = true, skipMissing = true })
    installFakes(CMM)
    -- Compat normally loads before the UI; re-run the tooltip install now that the fake hook exists
    CMM.UI.Tooltip.installed = nil
    CMM.UI.Tooltip.Install()
    wow.dataLoader()
    _G.CasualMinMaxerDB = nil
    _G.CasualMinMaxerCharDB = nil
    wow.optionsPanels = {}
  end)

  it("exposes the contract entry points", function()
    for _, fn in ipairs({ "Toggle", "Show", "Hide", "Refresh", "OpenOptions" }) do
      assert.is_function(CMM.UI[fn], fn)
    end
  end)

  it("shows the window, fills the slot strip and rows without error", function()
    CMM.UI.Show("HEAD")
    assert.is_true(CMM.UI.IsShown())
    assert.equals("HEAD", CMM.UI.state.slot)
    assert.equals(2, #CMM.UI.state.entries)
    assert.equals(2, CMM.UI.state.slotSummary.HEAD.count)
    assert.equals("HEAD", CMM.UI.state.weakest)
    local list = _G.CasualMinMaxerFrame.list
    assert.is_true(list.rows[1]:IsShown())
    assert.equals("Fixture Helm", list.rows[1].name:GetText())
    assert.is_true(list.rows[1].gain:GetText():find("+25", 1, true) ~= nil)
    assert.equals("Quest, 2 steps left, Zangarmarsh", list.rows[1].source:GetText())
    assert.equals("2 steps left", list.rows[1].detail:GetText())
    assert.equals("until 68", list.rows[1].lasts:GetText())
    assert.is_true(list.rows[2].badges:GetText():find("special", 1, true) ~= nil)
  end)

  it("toggles and remembers the last slot", function()
    CMM.UI.Toggle("MAINHAND")
    assert.is_true(CMM.UI.IsShown())
    assert.equals("MAINHAND", _G.CasualMinMaxerCharDB.lastSlot)
    CMM.UI.Toggle()
    assert.is_false(CMM.UI.IsShown())
    CMM.UI.Toggle()
    assert.is_true(CMM.UI.IsShown())
    assert.equals("MAINHAND", CMM.UI.state.slot)
    CMM.UI.Hide()
    assert.is_false(CMM.UI.IsShown())
  end)

  it("expands a row into a detail panel with the quest chain", function()
    CMM.UI.Show("HEAD")
    CMM.UI.ToggleExpand(1001)
    assert.equals(3, #CMM.UI.state.entries)
    assert.is_true(CMM.UI.state.entries[2].detail)
    local lines = CMM.UI.Rows.DetailLines(CMM.UI.state.entries[1].row, CMM.Player.Get())
    assert.is_true(lines[1].text:find("Quest chain", 1, true) ~= nil)
    assert.is_true(lines[1].text:find("Zangarmarsh", 1, true) ~= nil)
    assert.is_true(lines[2].text:find("Fixture Prequel", 1, true) ~= nil)
    assert.is_true(lines[3].text:find("Fixture Quest", 1, true) ~= nil)
    assert.is_true(lines[4].text:find("Fixture Boss", 1, true) ~= nil) -- "Also:" line
    local detail = _G.CasualMinMaxerFrame.list.details[1]
    assert.is_true(detail:IsShown())
    CMM.UI.ToggleExpand(1001)
    assert.equals(2, #CMM.UI.state.entries)
  end)

  it("renders dungeon mode grouped by boss", function()
    CMM.UI.Show("HEAD")
    _G.CasualMinMaxerCharDB.filters.dungeon = 547
    CMM.UI.Refresh()
    assert.is_true(CMM.UI.state.entries[1].header)
    assert.equals("Fixture Boss", CMM.UI.state.entries[1].text)
    assert.equals(1001, CMM.UI.state.entries[2].row.id)
    local list = _G.CasualMinMaxerFrame.list
    assert.is_true(list.rows[1].header:IsShown())
  end)

  it("filter controls persist to CharDB and refresh", function()
    CMM.UI.Show("HEAD")
    local bar = _G.CasualMinMaxerFrame.filter
    bar.tiers[4]:SetChecked(true)
    bar.tiers[4]:GetScript("OnClick")(bar.tiers[4])
    assert.is_true(_G.CasualMinMaxerCharDB.filters.tiers[4])
    bar.zone:SetChecked(true)
    bar.zone:GetScript("OnClick")(bar.zone)
    assert.equals("current", _G.CasualMinMaxerCharDB.filters.zone)
    local buttons = wow.OpenDropdown(bar.sort)
    assert.equals(4, #buttons)
    buttons[2].func()
    assert.equals("gain", _G.CasualMinMaxerCharDB.filters.sort)
    local dbuttons = wow.OpenDropdown(bar.dungeon)
    assert.is_true(#dbuttons >= 2)
    dbuttons[2].func()
    assert.equals(547, _G.CasualMinMaxerCharDB.filters.dungeon)
    dbuttons[1].func()
    assert.is_nil(_G.CasualMinMaxerCharDB.filters.dungeon)
    local opts = CMM.UI.QueryOpts()
    assert.equals("gain", opts.sort)
    assert.equals("current", opts.zone)
    assert.equals(2, opts.lookahead)
  end)

  it("row clicks: shift links, ctrl dresses, right-click menu, hide item", function()
    CMM.UI.Show("HEAD")
    local row = _G.CasualMinMaxerFrame.list.rows[1]
    wow.shift = true
    row:GetScript("OnClick")(row, "LeftButton")
    assert.is_truthy(wow.lastChatLink)
    wow.shift = false
    wow.ctrl = true
    row:GetScript("OnClick")(row, "LeftButton")
    assert.is_truthy(wow.lastDressUp)
    wow.ctrl = false
    row:GetScript("OnClick")(row, "RightButton")
    assert.is_true(#wow.menuButtons >= 3)
    wow.menuButtons[2].func() -- hide this item
    assert.is_true(_G.CasualMinMaxerCharDB.hidden[1001])
    assert.is_true((CMM._invalidated or 0) >= 1)
    row:GetScript("OnEnter")(row)
    row:GetScript("OnLeave")(row)
  end)

  it("slot parsing accepts aliases", function()
    assert.equals("HEAD", CMM.UI.ParseSlot("head"))
    assert.equals("FINGER", CMM.UI.ParseSlot("ring"))
    assert.equals("MAINHAND", CMM.UI.ParseSlot("mh"))
    assert.equals("OFFHAND", CMM.UI.ParseSlot("shield"))
    assert.is_nil(CMM.UI.ParseSlot("hat"))
  end)

  it("evaluates ad-hoc items from client stats", function()
    wow.items[777] = { name = "Client Helm", quality = 2, ilvl = 50, req = 45,
      stats = { ITEM_MOD_STAMINA_SHORT = 10, ITEM_MOD_ATTACK_POWER_SHORT = 20, EMPTY_SOCKET_RED = 1 } }
    local item, fromPack = CMM.UI.ItemFromLink("|Hitem:777::::::::62:::::|h[Client Helm]|h")
    assert.is_false(fromPack)
    assert.equals(10, item.stats.STA)
    assert.equals(20, item.stats.AP)
    assert.equals("R", item.sockets)
    local score = CMM.UI.EvaluateItem(item)
    assert.equals(15, score)
    local packItem, fromPack2 = CMM.UI.ItemFromLink("item:1001")
    assert.is_true(fromPack2)
    assert.equals("Fixture Helm", packItem.name)
  end)

  it("tooltip hook registers and adds a score line", function()
    assert.is_function(CMM._tooltipHook)
    local tt = CreateFrame("GameTooltip", "TestTooltip")
    local added = {}
    tt.AddLine = function(_, text) added[#added + 1] = text end
    tt.GetItem = function() return "Fixture Helm", "item:1001" end
    CMM._tooltipHook(tt)
    assert.equals(1, #added)
    assert.is_true(added[1]:find("Arms", 1, true) ~= nil)
    assert.is_true(added[1]:find("+25", 1, true) ~= nil)
    CMM._tooltipHook(tt) -- same item: no duplicate
    assert.equals(1, #added)
    tt.cmmDone = nil
    tt.GetItem = function() return "Fixture Sword", "item:1002" end
    CMM._tooltipHook(tt)
    assert.equals(2, #added)
    assert.is_true(added[2]:find("not an upgrade", 1, true) ~= nil)
  end)

  it("quest advisor marks the best reward", function()
    wow.questChoices = { "item:1002", "item:1001" }
    for i = 1, 2 do
      _G.QuestInfoRewardsFrame.RewardButtons[i] = CreateFrame("Button", "QuestInfoRewardsFrameQuestInfoItem" .. i)
    end
    wow.FireEvent("QUEST_COMPLETE")
    local results = CMM.UI.QuestAdvisor.lastResults
    assert.equals(2, #results)
    assert.equals(2, results[1].index) -- the helm (choice 2) wins
    assert.equals(25, results[1].gain)
    wow.FireEvent("QUEST_FINISHED")
    wow.questChoices = {}
  end)

  it("options panel registers, refreshes sliders and applies changes", function()
    wow.FireEvent("PLAYER_LOGIN")
    assert.equals(1, #wow.optionsPanels)
    local panel = wow.optionsPanels[#wow.optionsPanels]
    CMM.UI.Options.Refresh()
    assert.is_true(#panel.sliders >= 5)
    local first = panel.sliders[1]
    assert.equals("STR", first.key)
    first:GetScript("OnValueChanged")(first, 0.8)
    assert.equals(0.8, _G.CasualMinMaxerCharDB.weights.ARMS.STR)
    CMM.UI.Options.ResetWeights()
    assert.is_nil(_G.CasualMinMaxerCharDB.weights.ARMS)
    assert.is_true(CMM.UI.Options.ImportPawn("( Pawn: v1: \"x\": Strength=1, Stamina=0.7 )"))
    assert.equals(0.7, _G.CasualMinMaxerCharDB.weights.ARMS.STA)
    assert.is_false(CMM.UI.Options.ImportPawn("garbage"))
    CMM.UI.Options.SetPhase(3)
    assert.equals(3, _G.CasualMinMaxerDB.phase)
    CMM.UI.Options.SetConstant("minutesPerQuest", 12)
    assert.equals(12, _G.CasualMinMaxerDB.constants.minutesPerQuest)
    CMM.UI.Options.ExportPawn()
    assert.is_true(_G.CasualMinMaxerCopyBox:IsShown())
    assert.equals("( Pawn: v1: \"CMM\": Strength=1 )", _G.CasualMinMaxerCopyBox.edit:GetText())
    CMM.UI.Options.ExportCharacter()
    assert.equals("djEuLi4=", _G.CasualMinMaxerCopyBox.edit:GetText())
    CMM.UI.OpenOptions()
  end)

  it("creates the LibDataBroker launcher", function()
    local obj = CMM.UI.Minimap.CreateDataObject()
    assert.is_truthy(obj)
    assert.equals("launcher", obj.type)
    local LDB = LibStub("LibDataBroker-1.1")
    assert.equals(obj, LDB:GetDataObjectByName("CasualMinMaxer"))
    local tt = { lines = {},
      AddLine = function(self, t) self.lines[#self.lines + 1] = t end,
      AddDoubleLine = function(self, a, b) self.lines[#self.lines + 1] = a .. " " .. b end }
    obj.OnTooltipShow(tt)
    assert.is_true(#tt.lines >= 3)
    CMM.UI.Show("HEAD")
    tt.lines = {}
    obj.OnTooltipShow(tt)
    assert.is_true(tt.lines[2]:find("Head", 1, true) ~= nil)
    obj.OnClick(nil, "LeftButton")
    assert.is_false(CMM.UI.IsShown())
    -- registration without LibDBIcon loaded is a no-op, not an error
    assert.is_false(CMM.UI.Minimap.Register())
  end)

  it("bus events refresh an open window", function()
    CMM.UI.Show("HEAD")
    local before = CMM._invalidated or 0
    CMM.Fire("WEIGHTS_CHANGED")
    assert.equals(before + 1, CMM._invalidated)
    CMM.Fire("PLAYER_CHANGED")
    assert.is_true(CMM.UI.IsShown())
  end)

  it("shows a loading state when the data addon is not ready", function()
    CMM.Core.EnsureData = function() return false end
    CMM.UI.Show("HEAD")
    assert.is_true(CMM.UI.state.loading)
    assert.equals(0, #CMM.UI.state.entries)
    assert.is_true(_G.CasualMinMaxerFrame.list.status:IsShown())
  end)
end)
