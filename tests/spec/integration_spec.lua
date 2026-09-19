-- Integration: REAL logic modules + REAL UI modules together, with the fixture data pack and the real one.
-- No fakes: every cross-module path the UI takes runs against the modules the client would load.
local H = require("tests.helpers")
local wow = H.wow

local function loadLibs()
  for _, f in ipairs({ "Libs/LibStub/LibStub.lua", "Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua",
    "Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua" }) do
    local chunk = assert(loadfile("CasualMinMaxer/" .. f))
    chunk()
  end
end

local function allFilters(cdb)
  for _, k in ipairs({ "Q", "K", "V", "B", "G", "R", "N", "T", "W" }) do cdb.filters.sources[k] = true end
  for t = 1, 5 do cdb.filters.tiers[t] = true end
end

local function rowById(entries, id)
  for _, e in ipairs(entries) do
    if e.row and not e.detail and e.row.id == id then return e.row end
  end
  return nil
end

local function boot(player)
  loadLibs()
  wow.anonFrames = {}
  -- fresh tooltip frame so only this boot's hooks are attached to it
  _G.GameTooltip = CreateFrame("GameTooltip", "GameTooltip")
  local CMM = H.Boot({ ui = true, realWeights = true, player = player })
  wow.optionsPanels = {}
  wow.FireEvent("PLAYER_LOGIN")
  return CMM
end

describe("integration: real logic + real UI (fixture data)", function()
  local CMM

  before_each(function()
    CMM = boot()
    allFilters(_G.CasualMinMaxerCharDB)
  end)

  it("login wires Core, shows the window and renders real Query rows", function()
    assert.equals(62, CMM.Player.Get().level)
    assert.equals("ARMS", CMM.Player.Get().spec)
    CMM.UI.Show("HEAD")
    assert.is_true(CMM.UI.IsShown())
    local res = CMM.Query.Run("HEAD", CMM.Player.Get(), CMM.UI.QueryOpts())
    assert.is_true(#res.rows > 5)
    local rendered = 0
    for _, e in ipairs(CMM.UI.state.entries) do if e.row and not e.detail then rendered = rendered + 1 end end
    assert.equals(#res.rows, rendered)
    assert.equals(res.rows[1].id, CMM.UI.state.entries[1].row.id)
    local list = _G.CasualMinMaxerFrame.list
    assert.is_true(list.rows[1]:IsShown())
    assert.equals(res.rows[1].item.name, list.rows[1].name:GetText())
    assert.is_true(list.rows[1].gain:GetText():find("+", 1, true) ~= nil)
    assert.equals(res.rows[1].obtain.text, list.rows[1].source:GetText())
    -- slot strip summaries come from Query.SlotSummary-equivalent runs for all 15 slots
    local n = 0
    for _ in pairs(CMM.UI.state.slotSummary) do n = n + 1 end
    assert.equals(15, n)
    assert.is_not_nil(CMM.UI.state.weakest)
    assert.is_true(_G.CasualMinMaxerFrame.strip.buttons.HEAD.badge:GetText() ~= "")
  end)

  it("slot summary in the strip matches Query.SlotSummary", function()
    CMM.UI.Show("HEAD")
    local sum = CMM.Query.SlotSummary(CMM.Player.Get(), CMM.UI.QueryOpts())
    for key, s in pairs(sum) do
      local ui = CMM.UI.state.slotSummary[key]
      assert.is_not_nil(ui, key)
      assert.equals(s.count, ui.count, key)
    end
  end)

  it("detail lines render every source kind from real Obtain/Data records", function()
    CMM.UI.Show("HEAD")
    local player = CMM.Player.Get()
    local entries = CMM.UI.state.entries
    local function lines(id)
      local row = rowById(entries, id)
      assert.is_not_nil(row, "row " .. id .. " missing")
      local out = CMM.UI.Rows.DetailLines(row, player)
      local texts = {}
      for i, l in ipairs(out) do texts[i] = l.text end
      return table.concat(texts, "\n"), row
    end
    -- quest chain (Chain A1 -> A2 -> A3, none completed)
    local text, row = lines(30001)
    assert.is_true(text:find("Quest chain", 1, true) ~= nil, text)
    assert.is_true(text:find("Zangarmarsh", 1, true) ~= nil, text)
    assert.is_true(text:find("Chain A1", 1, true) ~= nil, text)
    assert.is_true(text:find("Chain A3", 1, true) ~= nil, text)
    assert.equals("3 steps left", CMM.UI.Rows.SourceDetail(row))
    assert.equals(3, row.obtain.steps)
    -- boss
    text = lines(30010)
    assert.is_true(text:find("The Slave Pens", 1, true) ~= nil, text)
    assert.is_true(text:find("Boss 2 of 3: Rokmar the Crackler", 1, true) ~= nil, text)
    -- reputation vendor: rank 6 = Revered per §4.2
    text = lines(30018)
    assert.is_true(text:find("Vendor", 1, true) ~= nil, text)
    assert.is_true(text:find("Revered", 1, true) ~= nil, text)
    -- crafted by the player's own profession (skill too low -> still shows "you have 300")
    text = lines(30019)
    assert.is_true(text:find("Blacksmithing 340", 1, true) ~= nil, text)
    assert.is_true(text:find("you have 300", 1, true) ~= nil, text)
    -- rare spawn and chest and world drop
    assert.is_true(lines(30013):find("Rare spawn", 1, true) ~= nil)
    assert.is_true(lines(30016):find("Coilfang Chest", 1, true) ~= nil)
    assert.is_true(lines(30021):find("World drop", 1, true) ~= nil)
    -- report string uses real version / data meta
    assert.is_true(CMM.UI.Rows.ReportString(row, player):find("item 30001 Chain Helm", 1, true) ~= nil)
  end)

  it("expands a row and hides an item through the context menu", function()
    CMM.UI.Show("HEAD")
    local first = CMM.UI.state.entries[1].row
    CMM.UI.ToggleExpand(first.id)
    assert.is_true(CMM.UI.state.entries[2].detail)
    assert.equals(first.id, CMM.UI.state.entries[2].row.id)
    local widget = _G.CasualMinMaxerFrame.list.rows[1]
    widget:GetScript("OnClick")(widget, "RightButton")
    assert.is_true(#wow.menuButtons >= 3)
    wow.menuButtons[2].func() -- Hide this item
    assert.is_true(_G.CasualMinMaxerCharDB.hidden[first.id])
    assert.is_nil(rowById(CMM.UI.state.entries, first.id))
    local res = CMM.Query.Run("HEAD", CMM.Player.Get(), CMM.UI.QueryOpts())
    for _, r in ipairs(res.rows) do assert.is_true(r.id ~= first.id) end
  end)

  it("dungeon mode groups real RunDungeon results under boss headers in encounter order", function()
    _G.CasualMinMaxerCharDB.filters.dungeon = 547
    CMM.UI.Show("HEAD")
    local headers = {}
    local rows = 0
    for _, e in ipairs(CMM.UI.state.entries) do
      if e.header then headers[#headers + 1] = e.text elseif e.row then rows = rows + 1 end
    end
    assert.is_true(#headers >= 2, "expected boss headers, got " .. #headers)
    assert.equals("Mennu the Betrayer", headers[1])
    assert.equals("Rokmar the Crackler", headers[2])
    assert.is_true(rows > 3)
    local byBoss = CMM.Query.RunDungeon(547, CMM.Player.Get(), CMM.UI.QueryOpts())
    local expected = 0
    for _, list in pairs(byBoss) do expected = expected + #list end
    assert.equals(expected, rows)
    assert.is_true((_G.CasualMinMaxerFrame.filter.dungeon.ddText or ""):find("Slave Pens", 1, true) ~= nil)
  end)

  it("filter changes re-run the real query", function()
    CMM.UI.Show("HEAD")
    local before = #CMM.UI.state.entries
    local bar = _G.CasualMinMaxerFrame.filter
    for t = 3, 5 do
      bar.tiers[t]:SetChecked(false)
      bar.tiers[t]:GetScript("OnClick")(bar.tiers[t])
    end
    assert.is_false(_G.CasualMinMaxerCharDB.filters.tiers[3])
    local after = #CMM.UI.state.entries
    assert.is_true(after < before)
    for _, e in ipairs(CMM.UI.state.entries) do
      if e.row then assert.is_true(e.row.tier <= 2, e.row.item.name .. " tier " .. e.row.tier) end
    end
    -- sort dropdown
    local buttons = wow.OpenDropdown(bar.sort)
    buttons[2].func()
    assert.equals("gain", _G.CasualMinMaxerCharDB.filters.sort)
    local prev = math.huge
    for _, e in ipairs(CMM.UI.state.entries) do
      if e.row then assert.is_true(e.row.gain <= prev + 1e-9) prev = e.row.gain end
    end
  end)

  it("tooltip hook installed through Compat adds a real score line", function()
    local handler = _G.GameTooltip:GetScript("OnTooltipSetItem")
    assert.is_function(handler)
    local added = {}
    _G.GameTooltip.AddLine = function(_, text) added[#added + 1] = text end
    _G.GameTooltip.GetItem = function() return "Chain Helm", "|Hitem:30001::::::::62:::::|h[Chain Helm]|h" end
    _G.GameTooltip.cmmDone = nil
    handler(_G.GameTooltip)
    assert.equals(1, #added)
    local ctx = CMM.UI.Ctx("HEAD")
    local score = CMM.Scoring.ScoreItem(CMM.Data.Item(30001), ctx)
    assert.is_true(added[1]:find(string.format("%.0f", score), 1, true) ~= nil, added[1])
    assert.is_true(added[1]:find("Arms", 1, true) ~= nil, added[1])
    assert.is_true(added[1]:find("+", 1, true) ~= nil, added[1])
    -- equipped-or-worse item: "not an upgrade"
    _G.GameTooltip.cmmDone = nil
    _G.GameTooltip.GetItem = function() return "Cloth Hood", "item:30002" end
    handler(_G.GameTooltip)
    assert.equals(2, #added)
    assert.is_true(added[2]:find("not an upgrade", 1, true) ~= nil or added[2]:find("no scored stats", 1, true) ~= nil, added[2])
  end)

  it("quest advisor marks the best real reward with the real gain", function()
    wow.questChoices = { "item:30002", "item:30001" }
    for i = 1, 2 do
      _G.QuestInfoRewardsFrame.RewardButtons[i] = CreateFrame("Button", "QuestInfoRewardsFrameQuestInfoItem" .. i)
    end
    wow.FireEvent("QUEST_COMPLETE")
    local results = CMM.UI.QuestAdvisor.lastResults
    assert.equals(2, #results)
    assert.equals(2, results[1].index)
    local gain = CMM.Scoring.Gain(CMM.Data.Item(30001), "HEAD", CMM.UI.Ctx("HEAD"), CMM.Player.Get())
    assert.is_near(gain, results[1].gain, 1e-9)
    assert.is_true(results[1].gain > 0)
    wow.FireEvent("QUEST_FINISHED")
    wow.questChoices = {}
  end)

  it("random-suffix limit sliders write DB.random and change the auction rows", function()
    assert.equals(1, #wow.optionsPanels)
    local panel = wow.optionsPanels[1]
    CMM.UI.Options.Refresh()
    assert.equals(8, panel.maxAuctionRows:GetValue())
    assert.is_near(0.5, panel.minChancePct:GetValue(), 1e-9)
    local cdb = _G.CasualMinMaxerCharDB
    cdb.filters.sources.S, cdb.filters.sources.W = true, true
    cdb.filters.tiers = { true, true, true, true, true }
    CMM.Query.Invalidate()
    local function auctionRows()
      local n, ids = 0, {}
      for _, r in ipairs(CMM.Query.Run("CHEST", CMM.Player.Get(), CMM.UI.QueryOpts()).rows) do
        if r.obtain.src.t == "S" then n = n + 1; ids[r.id] = r end
      end
      return n, ids
    end
    local n, ids = auctionRows()
    assert.equals(4, n)
    assert.equals(-7, ids[30050].suffix)
    panel.minChancePct:GetScript("OnValueChanged")(panel.minChancePct, 5)
    assert.equals(5, _G.CasualMinMaxerDB.random.minChancePct)
    assert.equals(5, CMM.Constants.RANDOM.minChancePct)
    n, ids = auctionRows()
    assert.equals(3, n)
    assert.is_nil(ids[30050]) -- every suffix of 30050 rolls below 5 %
    assert.equals(-5, ids[30053].suffix) -- only the 6 % Monkey survives
    assert.is_not_nil(ids[30054]) -- unknown chance passes
    panel.maxAuctionRows:GetScript("OnValueChanged")(panel.maxAuctionRows, 0)
    assert.equals(0, _G.CasualMinMaxerDB.random.maxAuctionRows)
    n = auctionRows()
    assert.equals(0, n)
    CMM.UI.Show("CHEST")
    for _, e in ipairs(CMM.UI.state.entries) do
      if e.row then assert.is_true(e.row.obtain.src.t ~= "S") end
    end
    CMM.Core.ResetSavedVariables()
    assert.equals(8, CMM.Constants.RANDOM.maxAuctionRows)
  end)

  it("options sliders reflect the real active weights and changes flow back into queries", function()
    assert.equals(1, #wow.optionsPanels)
    local panel = wow.optionsPanels[1]
    CMM.UI.Options.Refresh()
    local active = CMM.Core.ActiveWeights()
    assert.is_true(#panel.sliders >= 5)
    local strSlider
    for _, s in ipairs(panel.sliders) do
      if s.key == "STR" then strSlider = s end
      if s:IsShown() then assert.is_near(active[s.key] or 0, s:GetValue(), 1e-9, s.key) end
    end
    assert.is_not_nil(strSlider)
    CMM.UI.Show("HEAD")
    local before = CMM.Query.Run("HEAD", CMM.Player.Get(), CMM.UI.QueryOpts()).rows[1]
    strSlider:GetScript("OnValueChanged")(strSlider, 5)
    assert.equals(5, _G.CasualMinMaxerCharDB.weights.ARMS.STR)
    assert.equals(5, CMM.Core.ActiveWeights().STR)
    local after = CMM.Query.Run("HEAD", CMM.Player.Get(), CMM.UI.QueryOpts()).rows[1]
    assert.is_true(after.score > before.score)
    assert.equals(after.id, CMM.UI.state.entries[1].row.id) -- window refreshed on WEIGHTS_CHANGED
    CMM.UI.Options.ResetWeights()
    assert.is_nil(_G.CasualMinMaxerCharDB.weights.ARMS)
    assert.is_near(active.STR, CMM.Core.ActiveWeights().STR, 1e-9)
  end)

  it("Pawn import and export go through the real Pawn module", function()
    assert.is_true(CMM.UI.Options.ImportPawn('( Pawn: v1: "Test": Strength=1, Stamina=0.7, CritRating=0.5 )'))
    local w = _G.CasualMinMaxerCharDB.weights.ARMS
    assert.equals(0.7, w.STA)
    assert.is_near(0.5 * CMM.Ratings.PerPercent("CRIT", 62), w.CRIT, 1e-9)
    assert.equals(0.7, CMM.Core.ActiveWeights().STA)
    CMM.UI.Options.ExportPawn()
    local str = _G.CasualMinMaxerCopyBox.edit:GetText()
    assert.is_true(str:find("Pawn: v1", 1, true) ~= nil, str)
    local back = CMM.Pawn.Import(str, 62)
    assert.is_near(0.7, back.STA, 1e-6)
    assert.is_false(CMM.UI.Options.ImportPawn("garbage"))
  end)

  it("character export string round-trips through Export", function()
    CMM.UI.Options.ExportCharacter()
    local str = _G.CasualMinMaxerCopyBox.edit:GetText()
    assert.equals(CMM.Export.String(CMM.Player.Get(), CMM.Core.ActiveWeights()), str)
    local parsed = CMM.Export.Parse(str)
    assert.equals("WARRIOR", parsed.class)
    assert.equals(62, parsed.level)
  end)

  it("minimap data object reports the weakest slot after a window computation", function()
    local obj = CMM.UI.Minimap.CreateDataObject()
    assert.is_truthy(obj)
    CMM.UI.Show("HEAD")
    local tt = { lines = {}, AddLine = function(self, t) self.lines[#self.lines + 1] = t end,
      AddDoubleLine = function(self, a, b) self.lines[#self.lines + 1] = a .. " " .. b end }
    obj.OnTooltipShow(tt)
    local weakest = CMM.UI.state.weakest
    assert.is_true(tt.lines[2]:find(CMM.UI.SlotName(weakest), 1, true) ~= nil, tt.lines[2])
    assert.is_true(tt.lines[3]:find("+", 1, true) ~= nil, tt.lines[3])
  end)

  it("slash commands drive the UI", function()
    local slash = SlashCmdList["CASUALMINMAXER"]
    slash("head")
    assert.is_true(CMM.UI.IsShown())
    assert.equals("HEAD", CMM.UI.state.slot)
    slash("ring")
    assert.equals("FINGER", CMM.UI.state.slot)
    slash("")
    assert.is_false(CMM.UI.IsShown())
    slash("options")
    slash("spec protection")
    assert.equals("PROTECTION", _G.CasualMinMaxerCharDB.specOverride)
    assert.equals("PROTECTION", CMM.Player.Get().spec)
    assert.equals("Protection", CMM.UI.SpecName())
    slash("spec auto")
    assert.equals("ARMS", CMM.Player.Get().spec)
    slash("hide 30001")
    assert.is_true(_G.CasualMinMaxerCharDB.hidden[30001])
    slash("unhide")
    assert.is_nil(_G.CasualMinMaxerCharDB.hidden[30001])
  end)

  it("PLAYER_LEVEL_UP refreshes the player and the open window", function()
    CMM.UI.Show("HEAD")
    assert.is_nil(rowById(CMM.UI.state.entries, 30006)) -- High Level Helm needs 66, lookahead 2
    wow.player.level = 64
    wow.FireEvent("PLAYER_LEVEL_UP", 64)
    assert.equals(64, CMM.Player.Get().level)
    assert.is_not_nil(rowById(CMM.UI.state.entries, 30006))
    assert.is_true(_G.CasualMinMaxerFrame.subtitle:GetText():find("64", 1, true) ~= nil)
  end)

  it("spec override through the options panel refreshes the snapshot and the weights", function()
    CMM.UI.Show("MAINHAND")
    CMM.UI.Options.SetSpecOverride("FURY")
    assert.equals("FURY", CMM.Player.Get().spec)
    assert.is_true(CMM.Player.Get().canDualWield)
    assert.is_true((CMM.Core.ActiveWeights().DPS_OH or 0) > 0)
    local res = CMM.Query.Run("OFFHAND", CMM.Player.Get(), CMM.UI.QueryOpts())
    local sawOneHand = false
    for _, r in ipairs(res.rows) do if r.item.inv == 13 then sawOneHand = true end end
    assert.is_true(sawOneHand)
  end)

  it("missing data addon shows the loading state without errors", function()
    CMM.UI.Show("HEAD")
    H.RemoveData(CMM)
    CMM.UI.Refresh()
    assert.is_true(CMM.UI.state.loading)
    assert.equals(0, #CMM.UI.state.entries)
    assert.equals("Loading data...", _G.CasualMinMaxerFrame.subtitle:GetText())
    -- tooltip and advisor stay silent
    local added = {}
    _G.GameTooltip.AddLine = function(_, text) added[#added + 1] = text end
    _G.GameTooltip.GetItem = function() return "Chain Helm", "item:30001" end
    _G.GameTooltip.cmmDone = nil
    _G.GameTooltip:GetScript("OnTooltipSetItem")(_G.GameTooltip)
    assert.equals(0, #added)
  end)
end)

describe("integration: real UI over the real data pack", function()
  local function tocFiles()
    local files = {}
    for line in io.lines("CasualMinMaxer_Data/CasualMinMaxer_Data.toc") do
      line = line:gsub("\r", "")
      if line:match("%.lua$") then files[#files + 1] = line end
    end
    return files
  end

  it("renders every slot for a level 62 Arms warrior and details the first 20 rows", function()
    loadLibs()
    wow.anonFrames = {}
    local CMM = H.LoadAddon({ ui = true })
    wow.dataLoader = function()
      _G.CasualMinMaxer_Data = nil
      for _, f in ipairs(tocFiles()) do assert(loadfile("CasualMinMaxer_Data/" .. f))() end
    end
    H.ResetPlayer()
    wow.player.talents = { { "Arms", 40 }, { "Fury", 13 }, { "Protection", 0 } }
    wow.player.zone = "Hellfire Peninsula"
    wow.optionsPanels = {}
    wow.FireEvent("PLAYER_LOGIN")
    allFilters(_G.CasualMinMaxerCharDB)
    local player = CMM.Player.Get()
    for _, slot in ipairs(CMM.Constants.SLOT_KEYS) do
      CMM.UI.Show(slot)
      assert.equals(slot, CMM.UI.state.slot)
      local n = 0
      for i, e in ipairs(CMM.UI.state.entries) do
        if e.row then
          n = n + 1
          if n <= 20 then
            local lines = CMM.UI.Rows.DetailLines(e.row, player)
            assert.is_true(#lines >= 1, slot .. " row " .. i)
            assert.is_string(CMM.UI.Rows.SourceDetail(e.row))
            assert.is_string(CMM.UI.Rows.ReportString(e.row, player))
          end
        end
      end
      assert.is_true(n >= 10, slot .. " rendered only " .. n .. " rows")
      assert.is_true(_G.CasualMinMaxerFrame.list.rows[1]:IsShown())
    end
    CMM.UI.ToggleExpand(CMM.UI.state.entries[1].row.id)
    assert.is_true(CMM.UI.state.entries[2].detail)
    -- dungeon mode on a real dungeon
    _G.CasualMinMaxerCharDB.filters.dungeon = 547
    CMM.UI.Refresh()
    local headers = 0
    for _, e in ipairs(CMM.UI.state.entries) do if e.header then headers = headers + 1 end end
    assert.is_true(headers >= 1)
  end)

  it("renders auction-house suffix rows with the suffix name and stats in the detail panel", function()
    local CMM = H.Boot({ ui = true, realWeights = true })
    local c = _G.CasualMinMaxerCharDB
    c.filters.sources.S = true
    c.filters.sources.W = true
    for t = 1, 5 do c.filters.tiers[t] = true end
    CMM.UI.Show("CHEST")
    local found
    for _, e in ipairs(CMM.UI.state.entries) do
      if e.row and e.row.suffix and e.row.id == 30050 then found = e.row break end
    end
    assert.is_not_nil(found, "no suffix row rendered for the fixture green")
    assert.equals("Fixture Mail Chest of the Bear", found.item.name)
    local lines = CMM.UI.Rows.DetailLines(found, CMM.Player.Get())
    local joined = {}
    for _, l in ipairs(lines) do joined[#joined + 1] = l.text end
    joined = table.concat(joined, "\n")
    assert.is_truthy(joined:find("of the Bear: +30 STR, +46 STA", 1, true), joined)
    assert.is_truthy(joined:find("Auction house", 1, true), joined)
  end)
end)
