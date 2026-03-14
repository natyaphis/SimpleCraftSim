local ADDON_NAME = ...

local frame = CreateFrame("Frame")
local REAGENT_COUNT_OVERRIDE = 999
local CHECKBOX_TOP_OFFSET = -6
local CHECKBOX_SIZE = 24
local LABEL_OFFSET_X = 0
local LABEL_TEXT = (GetLocale() == "zhCN" or GetLocale() == "zhTW") and "解锁" or "Unlock"

local defaults = {
    enabled = false,
}

local db
local originalGetCraftingReagentCount
local unlockCheckbox
local unlockLabel
local isElvUISkinned = false

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

local function GetTrackRecipeCheckbox()
    local schematicForm = GetSchematicForm()
    return schematicForm and schematicForm.TrackRecipeCheckbox or nil
end

local function UpdateControlState()
    if unlockCheckbox then
        unlockCheckbox:SetChecked(GetDB().enabled)
    end
end

local function ApplyElvUISkin()
    if isElvUISkinned or not unlockCheckbox then
        return
    end

    local E = _G.ElvUI and unpack(_G.ElvUI)
    if not E or not E.private or not E.private.skins or not E.private.skins.blizzard or not E.private.skins.blizzard.tradeskill then
        return
    end

    local S = E.GetModule and E:GetModule("Skins", true)
    if not S then
        return
    end

    if S.HandleCheckBox then
        S:HandleCheckBox(unlockCheckbox)
        unlockCheckbox:SetSize(CHECKBOX_SIZE, CHECKBOX_SIZE)
    end

    isElvUISkinned = true
end

local function CreateControls(parent)
    if unlockCheckbox then
        return
    end

    unlockCheckbox = CreateFrame("CheckButton", "SimpleCraftSimUnlockCheckbox", parent, "UICheckButtonTemplate")
    unlockCheckbox:SetSize(CHECKBOX_SIZE, CHECKBOX_SIZE)
    unlockCheckbox:SetHitRectInsets(0, 0, 0, 0)

    unlockLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    unlockLabel:SetPoint("LEFT", unlockCheckbox, "RIGHT", LABEL_OFFSET_X, 0)
    unlockLabel:SetJustifyH("LEFT")
    unlockLabel:SetText(LABEL_TEXT)

    local checkboxText = _G[unlockCheckbox:GetName() .. "Text"]
    if checkboxText then
        checkboxText:SetText("")
        checkboxText:Hide()
    end

    unlockCheckbox:SetScript("OnClick", function(self)
        local currentDB = GetDB()
        currentDB.enabled = not not self:GetChecked()
        ApplyOverride()
        RefreshCraftingForm()
    end)

    ApplyElvUISkin()
end

local function EnsureControls()
    local schematicForm = GetSchematicForm()
    local trackCheckbox = GetTrackRecipeCheckbox()
    if not schematicForm or not trackCheckbox then
        return
    end

    CreateControls(schematicForm)

    unlockCheckbox:ClearAllPoints()
    unlockCheckbox:SetPoint("TOPLEFT", trackCheckbox, "BOTTOMLEFT", 0, CHECKBOX_TOP_OFFSET)
    unlockCheckbox:SetSize(CHECKBOX_SIZE, CHECKBOX_SIZE)
    unlockCheckbox:Show()

    unlockLabel:ClearAllPoints()
    unlockLabel:SetPoint("LEFT", unlockCheckbox, "RIGHT", LABEL_OFFSET_X, 0)
    unlockLabel:Show()

    UpdateControlState()
    ApplyElvUISkin()
end

local function HookProfessionsFrame()
    local schematicForm = GetSchematicForm()
    if not schematicForm or schematicForm.SimpleCraftSimHooked then
        return
    end

    schematicForm.SimpleCraftSimHooked = true

    if schematicForm.HookScript then
        schematicForm:HookScript("OnShow", EnsureControls)
    end

    if schematicForm.Init then
        hooksecurefunc(schematicForm, "Init", function()
            C_Timer.After(0, EnsureControls)
        end)
    end

    EnsureControls()
    C_Timer.After(0.1, EnsureControls)
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            GetDB()
        elseif arg1 == "Blizzard_Professions" then
            C_Timer.After(0, HookProfessionsFrame)
        elseif arg1 == "ElvUI" then
            isElvUISkinned = false
            C_Timer.After(0, EnsureControls)
        end
    elseif event == "PLAYER_LOGIN" then
        ApplyOverride()
        C_Timer.After(0, HookProfessionsFrame)
    end
end)
