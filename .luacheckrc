std = "lua51"
max_line_length = 140
codes = true
ignore = { "212/self", "211/_.*", "213" }
exclude_files = { "CasualMinMaxer/Libs/**", "CasualMinMaxer_Data/**", "tests/fixtures/**" }

globals = { "SlashCmdList", "CasualMinMaxer", "CasualMinMaxerDB", "CasualMinMaxerCharDB", "CasualMinMaxer_Data",
            "SLASH_CASUALMINMAXER1", "SLASH_CASUALMINMAXER2" }

read_globals = {
  -- Lua / WoW additions
  "bit", "strsplit", "strjoin", "strtrim", "wipe", "tinsert", "tremove", "format", "date", "time", "debugstack",
  "geterrorhandler", "hooksecurefunc", "securecall", "tContains", "CopyTable", "GetTime", "strlower", "strupper",
  "floor", "ceil", "max", "min", "abs", "sort", "select", "issecurevariable",
  -- WoW API used by the addon
  "CreateFrame", "UIParent", "GameTooltip", "ItemRefTooltip", "GameFontNormal", "GameFontHighlight",
  "GameFontNormalSmall", "GameFontHighlightSmall", "GameFontDisableSmall", "GameFontNormalLarge",
  "ChatFontNormal", "NumberFontNormal", "CreateFont", "SlashCmdList", "DEFAULT_CHAT_FRAME", "ChatFrame1",
  "GetBuildInfo", "GetLocale", "GetAddOnMetadata", "C_AddOns", "LoadAddOn", "IsAddOnLoaded", "GetAddOnInfo",
  "UnitClass", "UnitLevel", "UnitFactionGroup", "UnitRace", "UnitName", "GetRealmName", "UnitClassBase",
  "GetInventoryItemLink", "GetInventoryItemID", "GetInventorySlotInfo", "GetItemInfo", "GetItemInfoInstant",
  "GetItemStats", "C_Item", "Item", "GetItemIcon", "GetItemQualityColor", "ITEM_QUALITY_COLORS",
  "GetSkillLineInfo", "GetNumSkillLines", "GetTalentTabInfo", "GetNumTalentTabs", "GetActiveTalentGroup",
  "C_QuestLog", "GetQuestLogTitle", "GetNumQuestChoices", "GetQuestItemLink", "GetQuestItemInfo",
  "QuestInfoRewardsFrame", "QuestFrameRewardPanel", "QuestInfoFrame", "QuestInfoItem1", "GetQuestID",
  "GetNumQuestLogRewards", "GetQuestLogRewardInfo", "GetQuestLogChoiceInfo", "QuestLogFrame",
  "GetFactionInfoByID", "GetNumFactions", "GetFactionInfo", "C_Reputation",
  "GetRealZoneText", "GetZoneText", "GetSubZoneText", "C_Map", "GetCurrentMapAreaID", "GetInstanceInfo",
  "PlaySound", "SOUNDKIT", "InterfaceOptions_AddCategory", "InterfaceOptionsFrame_OpenToCategory",
  "Settings", "StaticPopupDialogs", "StaticPopup_Show", "CloseDropDownMenus", "UIDropDownMenu_Initialize",
  "UIDropDownMenu_SetWidth", "UIDropDownMenu_SetText", "UIDropDownMenu_AddButton", "UIDropDownMenu_CreateInfo",
  "ToggleDropDownMenu", "EasyMenu", "GameTooltip_Hide", "GameTooltip_SetDefaultAnchor", "TooltipDataProcessor",
  "Enum", "BackdropTemplateMixin", "UISpecialFrames", "tinsert", "SetItemRef", "HandleModifiedItemClick",
  "IsShiftKeyDown", "IsControlKeyDown", "IsAltKeyDown", "ChatEdit_InsertLink", "ChatEdit_GetActiveWindow",
  "GetCursorPosition", "GetScreenWidth", "GetScreenHeight", "CreateFramePool", "Mixin", "LibStub",
  "TomTom", "Pawn", "PawnGetItemData", "DressUpItemLink", "GetMouseFocus", "ScrollFrame_OnMouseWheel",
  "FauxScrollFrame_Update", "FauxScrollFrame_GetOffset", "FauxScrollFrame_OnVerticalScroll",
  "UIDROPDOWNMENU_MENU_VALUE", "UIDROPDOWNMENU_OPEN_MENU", "RAID_CLASS_COLORS", "CUSTOM_CLASS_COLORS",
  "GetNumClasses", "GetClassInfo", "LOCALIZED_CLASS_NAMES_MALE", "C_Timer", "CreateFromMixins",
  "InCombatLockdown", "UnitAffectingCombat", "GetInventoryItemTexture", "EJ_GetInstanceInfo",
  "ExpansionLevel", "GetExpansionLevel", "WOW_PROJECT_ID", "WOW_PROJECT_BURNING_CRUSADE_CLASSIC",
  "MinimapCluster", "Minimap", "GetContainerNumSlots", "GetContainerItemLink", "C_Container",
  "SetPortraitToTexture", "SetPortraitTexture", "StaticPopup_Hide", "ChatFrame_OnHyperlinkShow",
  "GetQuestLink", "C_TooltipInfo", "ItemLocation", "GetSpecialization", "GetPrimaryTalentTree",
  "GetTalentInfo", "GetNumTalents", "QuestFrame", "QuestRewardScrollChildFrame", "QuestInfoRewardsFrame",
  "SquareButton_SetIcon", "UIParentLoadAddOn", "ReloadUI", "print", "StaticPopupDialogs", "unpack",
  "GameTooltipTextLeft1", "GameTooltipTextLeft2", "CMM_TEST_ENV",
  -- UI additions
  "GetNumQuestLogChoices", "GetQuestLogItemLink", "GetItemIcon", "ShoppingTooltip1", "ShoppingTooltip2",
  "QuestInfo_Display", "InterfaceOptionsFramePanelContainer",
}

files["tests/spec"] = { std = "+busted" }
files["tests/helpers.lua"] = { std = "+busted" }
