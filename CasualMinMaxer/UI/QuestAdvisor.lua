-- Quest reward advisor: marks the best-scoring choice reward on the quest turn-in frame and the quest log.
local _, CMM = ...
local UI = CMM.UI
local L = CMM.L
local Advisor = {}
UI.QuestAdvisor = Advisor

local overlays = {}

local function overlayFor(button)
  local o = overlays[button]
  if o then return o end
  o = CreateFrame("Frame", nil, button)
  o:SetAllPoints()
  o:SetFrameLevel((button.GetFrameLevel and button:GetFrameLevel() or 1) + 5)
  o.border = o:CreateTexture(nil, "OVERLAY")
  o.border:SetPoint("TOPLEFT", -2, 2)
  o.border:SetPoint("BOTTOMRIGHT", 2, -2)
  o.border:SetColorTexture(0.2, 1, 0.2, 0.35)
  o.text = o:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  o.text:SetPoint("BOTTOMRIGHT", -4, 2)
  o.text:SetTextColor(0.3, 1, 0.3)
  o:Hide()
  overlays[button] = o
  return o
end

function Advisor.ClearMarks()
  for _, o in pairs(overlays) do o:Hide() end
end

-- Reward buttons of the shared QuestInfo frame, found defensively across client builds.
local function rewardButton(i)
  local rf = _G.QuestInfoRewardsFrame
  if rf and rf.RewardButtons and rf.RewardButtons[i] then return rf.RewardButtons[i] end
  return _G["QuestInfoRewardsFrameQuestInfoItem" .. i] or _G["QuestInfoItem" .. i]
end

-- Choice links either from the turn-in frame (questFrame) or the quest log (questLog)
local function choiceLinks(questLog)
  local links = {}
  if questLog then
    local n = GetNumQuestLogChoices and GetNumQuestLogChoices() or 0
    for i = 1, n do links[i] = GetQuestLogItemLink and GetQuestLogItemLink("choice", i) or nil end
  else
    local n = GetNumQuestChoices and GetNumQuestChoices() or 0
    for i = 1, n do links[i] = GetQuestItemLink and GetQuestItemLink("choice", i) or nil end
  end
  return links
end

-- Score every choice; returns { {index=, gain=, gainPct=, score=, item=} ... } sorted by gain desc
function Advisor.Evaluate(links)
  local results = {}
  for i, link in pairs(links) do
    if link then
      local item = UI.ItemFromLink(link)
      local score, gain, gainPct = UI.EvaluateItem(item)
      if score then results[#results + 1] = { index = i, gain = gain, gainPct = gainPct, score = score, item = item } end
    end
  end
  table.sort(results, function(a, b) return a.gain > b.gain end)
  return results
end

function Advisor.Mark(questLog)
  Advisor.ClearMarks()
  if not UI.DataReady() then return end
  local links = choiceLinks(questLog)
  if next(links) == nil then return end
  local results = Advisor.Evaluate(links)
  local best = results[1]
  if not best then return end
  -- when the quest log is shown, reward buttons are the same shared frames; only mark the best upgrade
  for _, r in ipairs(results) do
    local btn = rewardButton(r.index)
    if btn then
      local o = overlayFor(btn)
      if r == best and r.gain > 0 then
        o.border:Show()
        o.text:SetText(UI.FormatGain(r.gain, r.gainPct))
        o:Show()
      elseif r.gain > 0 then
        o.border:Hide()
        o.text:SetText(UI.FormatGain(r.gain, r.gainPct))
        o:Show()
      else
        o:Hide()
      end
    end
  end
  Advisor.lastResults = results
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("QUEST_COMPLETE")
frame:RegisterEvent("QUEST_ITEM_UPDATE")
frame:RegisterEvent("QUEST_FINISHED")
frame:SetScript("OnEvent", function(_, event)
  if event == "QUEST_FINISHED" then
    Advisor.ClearMarks()
  elseif event == "QUEST_COMPLETE" then
    Advisor.Mark(false)
  elseif event == "QUEST_ITEM_UPDATE" then
    local qf = _G.QuestFrameRewardPanel
    if qf and qf.IsShown and qf:IsShown() then Advisor.Mark(false) end
  end
end)

-- Quest log detail: the shared QuestInfo_Display sets QuestInfoFrame.questLog when showing a log entry
if hooksecurefunc and _G.QuestInfo_Display then
  hooksecurefunc("QuestInfo_Display", function()
    local qi = _G.QuestInfoFrame
    if qi and qi.questLog then
      Advisor.Mark(true)
    end
  end)
end

-- Chat summary for /cmm quest (Core may call this)
function Advisor.Print()
  local results = Advisor.lastResults or {}
  if #results == 0 then CMM.Print(L["No quest rewards evaluated yet."]) return end
  for _, r in ipairs(results) do
    CMM.Print("%s %s", r.item and r.item.name or ("item " .. r.index), UI.FormatGain(r.gain, r.gainPct))
  end
end
