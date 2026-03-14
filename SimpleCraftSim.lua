local ADDON_NAME = ...

local frame = CreateFrame("Frame")
local REAGENT_COUNT_OVERRIDE = 999
local BUTTON_SIZE = 24
local BUTTON_Y_OFFSET = -6
local BUTTON_TEXT_OFFSET_X = 4
local BUTTON_TEXT_OFFSET_Y = 1
local RETRY_DELAY = 0.1

local defaults = {
    enabled = false,
}

local db
local originalGetCraftingReagentCount
local unlockButton
local locale = GetLocale()
local buttonLabel = (locale == "zhCN" or locale == "zhTW") and "解锁" or "Unlock"

local function CopyDefaults(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            target[key] = target[key] or {}
            CopyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function GetDB()
    if not db then
        SimpleCraftSimDB = SimpleCraftSimDB or {}
        CopyDefaults(SimpleCraftSimDB, defaults)
        db = SimpleCraftSimDB
    end

    return db
end

local function GetCraftingPage()
    local professionsFrame = _G.ProfessionsFrame
    return professionsFrame and professionsFrame.CraftingPage or nil
end

local function GetSchematicForm()
    local craftingPage = GetCraftingPage()
    return craftingPage and craftingPage.SchematicForm or nil
end

local function GetTrackRecipeCheckbox()
    local schematicForm = GetSchematicForm()
    return schematicForm and schematicForm.TrackRecipeCheckbox or nil
end

local function SafeCallMethod(object, methodName, ...)
    local method = object and object[methodName]
    if method then
        pcall(method, object, ...)
    end
end

local function RefreshCraftingForm()
    local schematicForm = GetSchematicForm()
    if not schematicForm or not schematicForm:IsShown() then
        return
    end

    SafeCallMethod(schematicForm, "UpdateReagentSlots")
    SafeCallMethod(schematicForm, "UpdateOutputIcon")
    SafeCallMethod(schematicForm, "UpdateResultData")
    SafeCallMethod(schematicForm, "UpdateCreateButton")

    local event = _G.ProfessionsRecipeSchematicFormMixin
        and _G.ProfessionsRecipeSchematicFormMixin.Event
        and _G.ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified
    if event then
        SafeCallMethod(schematicForm, "TriggerEvent", event)
    end
end

local function ApplyOverride()
    local currentDB = GetDB()
    local itemUtil = _G.ItemUtil
    if type(itemUtil) ~= "table" then
        return
    end

    if type(itemUtil.GetCraftingReagentCount) == "function" and not originalGetCraftingReagentCount then
        originalGetCraftingReagentCount = itemUtil.GetCraftingReagentCount
    end

    if currentDB.enabled then
        itemUtil.GetCraftingReagentCount = function()
            return REAGENT_COUNT_OVERRIDE
        end
    elseif originalGetCraftingReagentCount then
        itemUtil.GetCraftingReagentCount = originalGetCraftingReagentCount
    end
end

local function UpdateButtonState()
    if not unlockButton then
        return
    end

    unlockButton:SetChecked(GetDB().enabled)
end

local function ApplyElvUISkin(trackCheckbox)
    if not unlockButton then
        return
    end

    local E = _G.ElvUI and unpack(_G.ElvUI)
    if not E or not E.private or not E.private.skins or not E.private.skins.blizzard or not E.private.skins.blizzard.tradeskill then
        return
    end

    local S = E.GetModule and E:GetModule("Skins", true)
    if not S or not S.HandleCheckBox then
        return
    end

    if not unlockButton.IsSkinned then
        S:HandleCheckBox(unlockButton)
    end

    local size = trackCheckbox and trackCheckbox:GetWidth() or BUTTON_SIZE
    if size <= 0 then
        size = BUTTON_SIZE
    end
    unlockButton:SetSize(size, size)
end

local function ApplyButtonTextStyle(trackCheckbox)
    local buttonText = _G[unlockButton:GetName() .. "Text"]
    local trackText = _G[trackCheckbox:GetName() .. "Text"]
    if not buttonText or not trackText then
        return
    end

    buttonText:ClearAllPoints()
    buttonText:SetPoint("LEFT", unlockButton, "RIGHT", BUTTON_TEXT_OFFSET_X, BUTTON_TEXT_OFFSET_Y)
    buttonText:SetFontObject(trackText:GetFontObject())
    buttonText:SetTextColor(trackText:GetTextColor())
end

local function StyleButtonLikeTrackCheckbox(trackCheckbox)
    unlockButton:ClearAllPoints()
    unlockButton:SetPoint("TOPLEFT", trackCheckbox, "BOTTOMLEFT", 0, BUTTON_Y_OFFSET)
    unlockButton:SetScale(trackCheckbox:GetScale())

    local size = trackCheckbox:GetWidth()
    if size and size > 0 then
        unlockButton:SetSize(size, size)
    else
        unlockButton:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    end

    ApplyButtonTextStyle(trackCheckbox)
    ApplyElvUISkin(trackCheckbox)
end

local function CreateUnlockButton(parent)
    if not unlockButton then
        unlockButton = CreateFrame("CheckButton", "SimpleCraftSimUnlockButton", parent, "UICheckButtonTemplate")
        unlockButton:SetHitRectInsets(0, 0, 0, 0)

        local text = _G[unlockButton:GetName() .. "Text"]
        if text then
            text:SetText(buttonLabel)
        end

        unlockButton:SetScript("OnClick", function(self)
            local db = GetDB()
            db.enabled = not not self:GetChecked()
            ApplyOverride()
            RefreshCraftingForm()
        end)
    end
end

local function EnsureButton()
    local schematicForm = GetSchematicForm()
    local trackCheckbox = schematicForm and schematicForm.TrackRecipeCheckbox
    if not schematicForm or not trackCheckbox then
        return
    end

    CreateUnlockButton(schematicForm)
    StyleButtonLikeTrackCheckbox(trackCheckbox)
    UpdateButtonState()
    unlockButton:Show()
end

local function ScheduleEnsureButton(delay)
    C_Timer.After(delay or 0, EnsureButton)
end

local function HookProfessionsFrame()
    local schematicForm = GetSchematicForm()
    local trackCheckbox = schematicForm and schematicForm.TrackRecipeCheckbox
    if not schematicForm or schematicForm.SimpleCraftSimHooked then
        return
    end

    schematicForm.SimpleCraftSimHooked = true

    if schematicForm.HookScript then
        schematicForm:HookScript("OnShow", EnsureButton)
    end

    if schematicForm.Init then
        hooksecurefunc(schematicForm, "Init", function()
            ScheduleEnsureButton()
        end)
    end

    if trackCheckbox and trackCheckbox.HookScript then
        trackCheckbox:HookScript("OnShow", EnsureButton)
        trackCheckbox:HookScript("OnSizeChanged", EnsureButton)
    end

    EnsureButton()
    ScheduleEnsureButton(RETRY_DELAY)
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            GetDB()
        elseif arg1 == "Blizzard_Professions" then
            ScheduleEnsureButton()
            C_Timer.After(0, HookProfessionsFrame)
        elseif arg1 == "ElvUI" then
            ScheduleEnsureButton()
        end
    elseif event == "PLAYER_LOGIN" then
        ApplyOverride()
        C_Timer.After(0, HookProfessionsFrame)
    end
end)
