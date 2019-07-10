-- Author      : christophrus
-- Create Date : 7/5/2019 5:24:46 PM

ClassicWowSpeedrunDB = {}
local g_addonLoaded = false
local g_playerLoaded = false
local g_variablesInitialized = false
local g_scrollBarInitialized = false
local g_guid = false
local g_runStarted = false
local g_runEnded = false
local g_reloaded = true
local g_startDate = false
local g_initialRealTime = false
local g_initialPlayedTime = false
local g_currentLevel = nil
local g_realmName = nil
local g_faction = nil
local g_name = nil
local g_race = nil
local g_class = nil
local g_sex = 1
local g_targetLevel = nil
g_privateBest = nil

local json = LibStub:GetLibrary("LibJSON-1.0", true)
local checksum = LibStub:GetLibrary("LibChecksum-1.0", true)
local base64 = LibStub:GetLibrary("LibBase64-1.0", true)


local function formatTime(d)
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

local function formatPBTime(d)

	local sign
	if (d == 0) then
		sign = "" 
	elseif (d < 0) then
		sign = "-"
	else 
		sign = "+"
	end

	d = math.abs(d)

	local h = math.floor(d / 3600)
	local m = math.floor(d % 3600 / 60)
	local s = math.floor(d % 3600 % 60)

	if (h == 0 and m == 0 and s < 10) then
		return format("%s%01d", sign, s)
	elseif (h == 0 and m == 0 and s < 60) then
		return format("%s%02d", sign, s)
	elseif (h == 0 and m < 10) then
		return format("%s%01d:%02d", sign, m, s)
	elseif (h == 0 and m < 60) then
		return format("%s%02d:%02d", sign, m, s)
	elseif (h < 10) then
		return format("%s%01d:%02d:%02d", sign, h, m, s)
	else
		return format("%s%02d:%02d:%02d", sign, h, m, s)
	end

end

function ClassicWowSpeedrun_OnUpdate()

	local splits = {}
	-- first run
	if (g_addonLoaded and g_playerLoaded and g_variablesInitialized) then
		splits = ClassicWowSpeedrunDB['runs'][g_guid]['splits']
	end

	if (not g_runEnded and g_currentLevel >= g_targetLevel) then
		print("run ended")
		g_runEnded = true
	end

	if (not g_runEnded) then
		if (#splits > 0) then	
			g_startDate = splits[1]['realTime']
			ClassicWowSpeedrunScrollFrame:Show()
			if (not g_scrollBarInitialized) then
				local newOffset = #splits - 7 < 0 and 0 or #splits - 7
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
			ClassicWowSpeedrunRealTimeClock:SetText(formatTime(realTime))
			ClassicWowSpeedrunPlayedTimeClock:SetText(formatTime(playedTime))

			-- set the color of the main clock based on time to next segment
			if (g_privateBest) then
				local startDatePB = g_privateBest['splits'][1]['realTime']
				local nextPBSegment = g_privateBest['splits'][g_currentLevel+1]
				local realTimeToNextSegment = nextPBSegment['realTime'] - startDatePB - realTime
				if (realTimeToNextSegment > 30) then
					ClassicWowSpeedrunRealTimeClock:SetTextColor(0,192,0, 1) -- green
				elseif (realTimeToNextSegment >= 0) then
					ClassicWowSpeedrunRealTimeClock:SetTextColor(255,209,0,1)  -- yellow
				else
					ClassicWowSpeedrunRealTimeClock:SetTextColor(255,0,0,1) -- red
				end
					
			end

		end
	end
	
end

function ClassicWowSpeedrunScrollBar_Update()
	local splits = ClassicWowSpeedrunDB['runs'][g_guid]['splits']

	local splitsPB = nil
	if (g_privateBest) then
		splitsPB = g_privateBest['splits']
	end

	local offset = FauxScrollFrame_GetOffset(ClassicWowSpeedrunScrollFrame)
	local startDate = splits[1]['realTime']

	local startDatePB = nil
	if (splitsPB) then
		startDatePB = splitsPB[1]['realTime']
	end

	local line
	for line=1,7 do
		local levelVal = line+1+offset
		local currSplit = splits[levelVal]
		local currPBSplit = nil
		if (splitsPB) then
			currPBSplit = splitsPB[levelVal]
		end
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
			currRealVal = formatTime(timeDiff)
			currPlayedVal = formatTime(currSplit['playedTime'])

			if (currPBSplit) then
				local realPBDiff = timeDiff - (currPBSplit['realTime'] - startDatePB) 
				local playedPBDiff = currSplit['playedTime'] - currPBSplit['playedTime']

				if (realPBDiff == 0) then
					prevRealText:SetTextColor(255,209,0,1)  -- yellow
				elseif (realPBDiff < 0) then
					prevRealText:SetTextColor(0,192,0, 1) -- green
				else
					prevRealText:SetTextColor(255,0,0,1) -- red
				end

				if (playedPBDiff == 0) then
					prevPlayedText:SetTextColor(255,209,0,1)  -- yellow
				elseif (playedPBDiff < 0) then
					prevPlayedText:SetTextColor(0,192,0, 1) -- green
				else
					prevPlayedText:SetTextColor(255,0,0,1) -- red
				end

				prevRealVal = formatPBTime(realPBDiff)
				prevPlayedVal = formatPBTime(playedPBDiff)
			end
		end 

		levelText:SetText("Level: " .. levelVal)
		prevRealText:SetText(prevRealVal)
		prevPlayedText:SetText(prevPlayedVal)
		currRealText:SetText(currRealVal)
		currPlayedText:SetText(currPlayedVal)
	end
	FauxScrollFrame_Update(ClassicWowSpeedrunScrollFrame,59,7,36);
end

function ClassicSpeedun_UpdateScrollbar()
	print("update scrollbar")
	local splits = ClassicWowSpeedrunDB['runs'][g_guid]['splits']
	local newOffset = #splits - 7 < 0 and 0 or #splits - 7
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

local function findPrivateBest(targetLevel)

	targetLevel = tonumber(targetLevel)

	local runs = ClassicWowSpeedrunDB['runs']
	local fastestTime = 99999999999
	local fastestGuid = nil

	for guid,run in pairs(runs) do
		if (run["splits"][targetLevel]) then
			local timediff = run["splits"][targetLevel]["realTime"] - run["splits"][targetLevel]["realTime"]
			if (timediff < fastestTime) then
				fastestTime = timediff
				fastestGuid = guid
			end
		end	
	end

	return fastestGuid

end

function ClassicWowSpeedrun_HandlePlayed(playedTime, timePlayedThisLevel, level)
	
	local run = ClassicWowSpeedrunDB['runs'][g_guid]
	local options = run["options"]
	local splits = run['splits']
	g_currentLevel = #splits + 1  --UnitLevel("player")

	g_targetLevel = options['targetLevel']

	if (#splits > 0) then
		if (not g_runStarted) then
			g_runStarted = true
			ClassicWowSpeedrun:Show()
		end
		if (g_reloaded and g_currentLevel >= g_targetLevel) then
			-- we only reach this point when someone /reload after a finished run
			g_runEnded = true
			g_startDate = splits[1]['realTime']
			local realTime = splits[g_targetLevel]['realTime'] - g_startDate
			local playedTime = splits[g_targetLevel]['playedTime']
			ClassicWowSpeedrunScrollFrameScrollBar:Hide()
			ClassicWowSpeedrunStarted:SetText(date("!%Y-%m-%d %H:%M:%S UTC", g_startDate))
			ClassicWowSpeedrunRealTimeClock:SetText(formatTime(realTime))
			ClassicWowSpeedrunPlayedTimeClock:SetText(formatTime(playedTime))
		end
	end

	if (playedTime < 30 and not g_runStarted) then
		ClassicWowSpeedrunNewCharDetected:Show()
		g_reloaded = false
	end

	print(g_targetLevel)
	print(g_currentLevel)

	print(g_runEnded)

	-- intialize also when run ended because someone could /reload after a run
	if (g_runStarted or g_runEnded) then
		print("inside")
		-- set split frame header texts
		ClassicWowSpeedrunSubTitle:SetText(format("%s - %s", options["preset"], options["difficulty"]))
		local optionsLabel = concatOptions(options)
		if (optionsLabel ~= "") then
			ClassicWowSpeedrunSubSubTitle:SetText(format("(%s)", optionsLabel))
		end

		local privateBestGuid = findPrivateBest(g_targetLevel)
		g_privateBest = ClassicWowSpeedrunDB['runs'][privateBestGuid]

		if (g_privateBest) then
			ClassicWowSpeedtunPBLabel:Show()
			ClassicWowSpeedrunPBDate:Show()
			ClassicWowSpeedrunPBDate:SetText(date("%Y-%m-%d",g_privateBest["splits"][10]["realTime"]))
		end

		local gender = g_sex == 2 and "Male" or "Female"
		local classIcon = format("Interface\\CharacterFrame\\TemporaryPortrait-%s-%s", gender, g_race)
		ClassicWowSpeedrunClassIcon:SetTexture(classIcon)

		local realTime = GetServerTime()

		if (not g_initialPlayedTime and not g_initialRealTime) then
			g_initialRealTime = GetServerTime()
			g_initialPlayedTime = playedTime
		end

		if (splits[g_currentLevel] == nil) then
			splits[g_currentLevel] = {
				['level'] = g_currentLevel,
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
	g_name = UnitName("player")
	g_sex = UnitSex("player")
	g_currentLevel = UnitLevel("player")
	_, g_race = UnitRace("player")
	_, g_class = UnitClass("player")


	if (ClassicWowSpeedrunDB['runs'] == nil) then
		ClassicWowSpeedrunDB['runs'] = {}
	end

	if ( ClassicWowSpeedrunDB['runs'][g_guid] == nil) then

		ClassicWowSpeedrunDB['runs'][g_guid] = {}

		local version, build = GetBuildInfo()

		ClassicWowSpeedrunDB['runs'][g_guid]["wowVersion"] = format("%s (%s)", version, build)
		ClassicWowSpeedrunDB['runs'][g_guid]["realmName"] = g_realmName
		ClassicWowSpeedrunDB['runs'][g_guid]["name"] = g_name
		ClassicWowSpeedrunDB['runs'][g_guid]["faction"] = g_faction
		ClassicWowSpeedrunDB['runs'][g_guid]["race"] = g_race
		ClassicWowSpeedrunDB['runs'][g_guid]["class"] = g_class
		ClassicWowSpeedrunDB['runs'][g_guid]["g_sex"] = g_sex


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
		g_targetLevel = 60
		options["preset"] = "World #1 to 60"
	else
		g_targetLevel = tonumber(TargetLevelLabel:GetText())
		options["preset"] = format("Target LvL %s", g_targetLevel)
	end

	options['targetLevel'] = g_targetLevel


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
