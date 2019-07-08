-- Author      : christophrus
-- Create Date : 7/5/2019 5:24:46 PM

ClassicWowSpeedrunDB = {}
local g_addonLoaded = false
local g_playerLoaded = false
local g_variablesInitialized = false
local g_firstRun = true
local g_scrollBarInitialized = false
local g_guid = false
local g_startDate = false
local g_initialRealTime = false
local g_initialPlayedTime = false

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
		splits = ClassicWowSpeedrunDB[g_guid]['splits']
		if (g_firstRun) then
			RequestTimePlayed()
			g_firstRun = false
		end
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
	local splits = ClassicWowSpeedrunDB[g_guid]['splits']
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
	local splits = ClassicWowSpeedrunDB[g_guid]['splits']
	local newOffset = #splits - 8 < 0 and 0 or #splits - 8
	ClassicWowSpeedrunScrollBar_Update()
	ClassicWowSpeedrunScrollFrame:SetVerticalScroll(newOffset*36)
end

function ClassicWowSpeedrun_HandlePlayed(playedTime, timePlayedThisLevel, level)
	local splits = ClassicWowSpeedrunDB[g_guid]['splits']
	local level = #splits + 1  --UnitLevel("player")
	local realTime = level > 1 and GetServerTime() or GetServerTime()-playedTime

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
	if (ClassicWowSpeedrunDB[g_guid] == nil) then
		ClassicWowSpeedrunDB[g_guid] = {}
	end

	if (ClassicWowSpeedrunDB[g_guid]['splits'] == nil) then
		ClassicWowSpeedrunDB[g_guid]['splits'] = {}
	end

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
