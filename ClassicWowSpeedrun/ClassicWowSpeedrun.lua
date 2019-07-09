-- Author      : christophrus
-- Create Date : 7/5/2019 5:24:46 PM

ClassicWowSpeedrunDB = {}
local g_addonLoaded = false
local g_playerLoaded = false
local g_variablesInitialized = false
local g_scrollBarInitialized = false
local g_guid = false
local g_runStarted = false
local g_startDate = false
local g_initialRealTime = false
local g_initialPlayedTime = false
local g_playerInfo = false

local json = LibStub:GetLibrary("LibJSON-1.0", true)
local checksum = LibStub:GetLibrary("LibChecksum-1.0", true)
local base64 = LibStub:GetLibrary("LibBase64-1.0", true)


local function getTime(d)
	local h = math.floor(d / 3600)
	local m = math.floor(d % 3600 / 60)
	local s = math.floor(d % 3600 % 60)

	local formatedTime

	if (h > 0) then
		formatedTime = format("%02d:%02d:%02d", h, m, s)
	else
		formatedTime = format("%02d:%02d", m, s)
	end

	return formatedTime
end

function ClassicWowSpeedrun_OnUpdate()

	local splits = {}
	-- first run
	if (g_addonLoaded and g_playerLoaded and g_variablesInitialized) then
		splits = ClassicWowSpeedrunDB['runs'][g_guid]['splits']
	end

	if (#splits > 0) then	
		g_startDate = splits[1]['realTime']
		ClassicWowSpeedrunScrollFrame:Show()
		if (not g_scrollBarInitialized) then
			local newOffset = #splits - 8 < 0 and 0 or #splits -8
			ClassicWowSpeedrunScrollFrame:SetVerticalScroll(newOffset*36)
			ClassicWowSpeedrunStarted:SetText(date("!%Y-%m-%d %H:%M:%S UTC", g_startDate))
			ClassicWowSpeedrunScrollFrameScrollBar:Hide()
			g_scrollBarInitialized = true
		end
	end

	if (g_startDate and g_initialRealTime and g_initialPlayedTime) then
		local serverTime = GetServerTime()
		local realTime = serverTime - g_startDate
		local playedTime = g_initialPlayedTime + (serverTime - g_initialRealTime)
		ClassicWowSpeedrunRealTimeClock:SetText(getTime(realTime))
		ClassicWowSpeedrunPlayedTimeClock:SetText(getTime(playedTime))
	end
	
end

function ClassicWowSpeedrunScrollBar_Update()
	local splits = ClassicWowSpeedrunDB['runs'][g_guid]['splits']
	local offset = FauxScrollFrame_GetOffset(ClassicWowSpeedrunScrollFrame)
	local startDate = splits[1]['realTime']
	local line
	for line=1,8 do
		local levelVal = line+1+offset
		local currSplit = splits[levelVal]
		local button = "LevelSplitButton"..line
		-- set alternating background colors for split buttons
		local buttonBG = getglobal(button.."Background")

		
		if (line % 2 == 0) then
			if (offset % 2 == 0) then
				buttonBG:SetTexture("Interface\\AddOns\\ClassicWowSpeedrun\\skins\\Background-Even.tga")
			else
				buttonBG:SetTexture("Interface\\AddOns\\ClassicWowSpeedrun\\skins\\Background-Odd.tga")
			end
		else 
			if (offset % 2 == 0) then
				buttonBG:SetTexture("Interface\\AddOns\\ClassicWowSpeedrun\\skins\\Background-Odd.tga")
			else
				buttonBG:SetTexture("Interface\\AddOns\\ClassicWowSpeedrun\\skins\\Background-Even.tga")
			end
		end

		local levelText = getglobal(button.."Level")
		local prevRealText = getglobal(button.."PrevReal")
		local prevPlayedText = getglobal(button.."PrevPlayed")
		local currRealText = getglobal(button.."CurrReal")
		local currPlayedText = getglobal(button.."CurrPlayed")

		local prevRealVal = ""
		local prevPlayedVal = ""
		local currRealVal = ""
		local currPlayedVal = ""

		if (currSplit) then
			local timeDiff = currSplit['realTime'] - startDate
			currRealVal = getTime(timeDiff)
			currPlayedVal = getTime(currSplit['playedTime'])
		end 

		levelText:SetText("Level: " .. levelVal)
		prevRealText:SetText(prevRealVal)
		prevPlayedText:SetText(prevPlayedVal)
		currRealText:SetText(currRealVal)
		currPlayedText:SetText(currPlayedVal)
	end
	FauxScrollFrame_Update(ClassicWowSpeedrunScrollFrame,60,8,36);
end

function ClassicSpeedun_UpdateScrollbar()
	local splits = ClassicWowSpeedrunDB['runs'][g_guid]['splits']
	local newOffset = #splits - 8 < 0 and 0 or #splits - 8
	ClassicWowSpeedrunScrollBar_Update()
	ClassicWowSpeedrunScrollFrame:SetVerticalScroll(newOffset*36)
end

local function concatOptions(t, template)
	local ret = ""
	local template = template or "%s, "
	for k, v in pairs(t) do
		if (v == true) then
			ret=ret..template:format(k)
		end
	end
	ret, _ = ret:gsub(", $", "")
	return ret
end

function ClassicWowSpeedrun_HandlePlayed(playedTime, timePlayedThisLevel, level)
	
	local run = ClassicWowSpeedrunDB['runs'][g_guid]
	local options = run["options"]
	local splits = run['splits']

	if (#splits > 0 and not g_runStarted) then
		g_runStarted = true
		ClassicWowSpeedrun:Show()
	end

	if (playedTime < 30 and not g_runStarted) then
		ClassicWowSpeedrunNewCharDetected:Show()
	end 

	if (g_runStarted) then
		-- set split frame header texts
		ClassicWowSpeedrunSubTitle:SetText(format("%s - %s", options["preset"], options["difficulty"]))
		local optionsLabel = concatOptions(options)
		if (optionsLabel) then
			ClassicWowSpeedrunSubSubTitle:SetText(format("(%s)", optionsLabel))
		end
		local level = #splits + 1  --UnitLevel("player")
		local realTime = GetServerTime()

		if (not g_initialPlayedTime and not g_initialRealTime) then
			g_initialRealTime = GetServerTime()
			g_initialPlayedTime = playedTime
		end

		if (splits[level] == nil) then
			splits[level] = {
				['level'] = level,
				['realTime'] = realTime,
				['playedTime'] = playedTime
			}
		end
		ClassicSpeedun_UpdateScrollbar()
	end
end

function ClassicWowSpeedrun_OnLoad(self)

	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("ADDON_LOADED")
	self:RegisterEvent("TIME_PLAYED_MSG")

end


function ClassicWowSpeedrun_OnEvent(self, event, arg1, arg2, arg3, arg4)

	if ((event == "ADDON_LOADED") and (arg1 == "ClassicWowSpeedrun")) then
		self:UnregisterEvent("ADDON_LOADED")
		g_addonLoaded = true
	end

	if (event == "PLAYER_ENTERING_WORLD") then
		g_playerLoaded = true
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
		if g_addonLoaded and g_playerLoaded then
			ClassicWowSpeedrun_InitializeVariables()
		end
	end

	if (event == "TIME_PLAYED_MSG") then
		ClassicWowSpeedrun_HandlePlayed(arg1, arg2)
	end
end

function ClassicWowSpeedrun_InitializeVariables()
	
	g_guid = UnitGUID("player")
	g_realmName = GetRealmName()
	g_faction = UnitFactionGroup("player")
	_, g_name = UnitName("player")
	_, g_race = UnitRace("player")
	_, g_class = UnitClass("player")


	if (ClassicWowSpeedrunDB['runs'] == nil) then
		ClassicWowSpeedrunDB['runs'] = {}
	end

	if ( ClassicWowSpeedrunDB['runs'][g_guid] == nil) then

		ClassicWowSpeedrunDB['runs'][g_guid] = {}

		ClassicWowSpeedrunDB['runs'][g_guid]["realmName"] = g_realmName
		ClassicWowSpeedrunDB['runs'][g_guid]["name"] = g_name
		ClassicWowSpeedrunDB['runs'][g_guid]["faction"] = g_faction
		ClassicWowSpeedrunDB['runs'][g_guid]["race"] = g_race
		ClassicWowSpeedrunDB['runs'][g_guid]["class"] = g_class


	end

	if (ClassicWowSpeedrunDB['runs'][g_guid]['options'] == nil) then
		ClassicWowSpeedrunDB['runs'][g_guid]['options'] = {}
	end

	if (ClassicWowSpeedrunDB['runs'][g_guid]['optionsFullfilled'] == nil) then
		ClassicWowSpeedrunDB['runs'][g_guid]['optionsFullfilled'] = {
			['noAH'] = true,
			['noParty'] = true,
			['noMail'] = true,
			['noTrade'] = true,
		}
	end

	if (ClassicWowSpeedrunDB['runs'][g_guid]['splits'] == nil) then
		ClassicWowSpeedrunDB['runs'][g_guid]['splits'] = {}
	end

	RequestTimePlayed()
	g_variablesInitialized = true
end

function Button2_OnClick()
	ClassicWowSpeedrunDB = {}
	C_UI.Reload()
end

function Button3_OnClick()
	EditBox1:SetText(ClassicWowSpeedrun_EncodeJson(ClassicWowSpeedrunDB))
	EditBox1:SetFocus()
	EditBox1:HighlightText()
end
function Button1_OnClick()
	ClassicWowSpeedrunDB = {}
	C_UI.Reload()
end

base64Text = ""
function ClassicWowSpeedrunExportButton_OnClick()
	local jsonText = json:encode(ClassicWowSpeedrunDB)
	base64Text = base64:encode(jsonText)
	ClassicWowSpeedrunExportFrame:Show()
	ClassicWowSpeedrunExportEditBox:SetText(base64Text)
	ClassicWowSpeedrunExportEditBox:HighlightText()
	ClassicWowSpeedrunExportEditBox:SetCursorPosition(0)
end

function ClassicWowSpeedrunExportFrameCloseButton_OnClick()
	ClassicWowSpeedrunExportFrame:Hide()
end

function ClassicWowSpeedrunExportEditBox_OnCursorChanged()
	ClassicWowSpeedrunExportEditBox:SetCursorPosition(0)
	ClassicWowSpeedrunExportEditBox:HighlightText()
end

function ClassicWowSpeedrunExportEditBox_OnKeyUp()
	ClassicWowSpeedrunExportEditBox:SetText(base64Text)
	ClassicWowSpeedrunExportEditBox:HighlightText()
	ClassicWowSpeedrunExportEditBox:SetCursorPosition(0)
end

function ClassicWowSpeedrunExportEditBox_OnKeyDown(self, key)
	if (key == "ESCAPE") then
		ClassicWowSpeedrunExportFrame:Hide()
	end
end

function ClassicWowSpeedrunNotStartRunButton_OnClick()
	ClassicWowSpeedrunNewCharDetected:Hide()
end

function ClassicWowSpeedrunStartRunButton_OnClick()

	-- write selected options
	local options = ClassicWowSpeedrunDB['runs'][g_guid]['options']
	
	local subSubLabel = ""

	if (CustomDifficulty:GetChecked()) then
		options["noAh"] = OptionNoAH:GetChecked()
		options["noParty"] = OptionNoParty:GetChecked()
		options["noMail"] = OptionNoMail:GetChecked()
		options["noTrade"] = OptionNoTrade:GetChecked()
		options["difficulty"] = "custom difficulty"
	else
		options["difficulty"] = "any%"
	end

	if (OptionTargetFirstTo60:GetChecked()) then
		options["preset"] = "World #1 to 60"
	else
		options["preset"] = format("Target LvL %s", TargetLevelLabel:GetText())
	end

	if (InCinematic()) then
		StopCinematic()
	end

	ClassicWowSpeedrunNewCharDetected:Hide()
	g_runStarted = true
	RequestTimePlayed()
	ClassicWowSpeedrun:Show()
end

function ClassicWowSpeedrunNewCharDetected_OnShow()
	if (InCinematic()) then
		MouseOverrideCinematicDisable(true)
	end
	ClassicWowSpeedrunLevelSlider:SetObeyStepOnDrag(true)
end

function ClassicWowSpeedrunLevelSlider_OnValueChanged(self, value, userInput)
	TargetLevelLabel:SetText(value)
end

function CustomDifficulty_OnClick()
	CustomDifficulty:SetChecked(true)
	OptionAnyPercent:SetChecked(false)
	LabelNoAH:Show()
	OptionNoAH:Show()
	LabelNoParty:Show()
	OptionNoParty:Show()
	LabelNoMail:Show()
	OptionNoMail:Show()
	LabelNoTrade:Show()
	OptionNoTrade:Show()
end

function OptionAnyPercent_OnClick()
	CustomDifficulty:SetChecked(false)
	OptionAnyPercent:SetChecked(true)
	LabelNoAH:Hide()
	OptionNoAH:Hide()
	LabelNoParty:Hide()
	OptionNoParty:Hide()
	LabelNoMail:Hide()
	OptionNoMail:Hide()
	LabelNoTrade:Hide()
	OptionNoTrade:Hide()
end

function OptionTargetCustom_OnClick()
	OptionTargetCustom:SetChecked(true)
	OptionTargetFirstTo60:SetChecked(false)
	ClassicWowSpeedrunLevelSlider:Show()
	TargetLevelLabel:Show()
end

function OptionTargetFirstTo60_OnClick()
	OptionTargetCustom:SetChecked(false)
	OptionTargetFirstTo60:SetChecked(true)
	ClassicWowSpeedrunLevelSlider:Hide()
	TargetLevelLabel:Hide()
end
