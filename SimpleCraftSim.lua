local frame = CreateFrame("Frame")
local CHECKBOX_TOP_OFFSET = -6
local CHECKBOX_SIZE = 24
local LABEL_OFFSET_X = 0
local LABEL_TEXT = (GetLocale() == "zhCN" or GetLocale() == "zhTW") and "解锁" or "Unlock"
local BAG_UPDATE_EVENTS = {
    "BAG_UPDATE",
    "BAG_UPDATE_DELAYED",
    "BANKFRAME_OPENED",
    "BANKFRAME_CLOSED",
    "PLAYERBANKSLOTS_CHANGED",
}

local unlockCheckbox
local unlockLabel
local isElvUISkinned = false
local isUnlockEnabled = false
local originalGetCraftingReagentCount
local originalGetReagentQuantityInPossession
local originalAccumulateReagentsInPossession
local flyoutButtonOverridesInstalled = false
local originalFlyoutItemButtonUpdateState
local originalFlyoutCurrencyButtonUpdateState
local flyoutButtonStateCache = setmetatable({}, { __mode = "k" })

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

    SafeCallMethod(schematicForm, "UpdateAllSlots")
    SafeCallMethod(schematicForm, "OnAllocationsChanged")
    SafeCallMethod(schematicForm, "UpdateReagentSlots")
    SafeCallMethod(schematicForm, "UpdateOutputIcon")
    SafeCallMethod(schematicForm, "UpdateOutputItem")
    SafeCallMethod(schematicForm, "UpdateResultData")
    SafeCallMethod(schematicForm, "UpdateDetailsStats")
    SafeCallMethod(schematicForm, "UpdateCreateButton")
    SafeCallMethod(schematicForm, "Layout")

    local craftingPage = GetCraftingPage()
    if craftingPage and craftingPage.OnEvent then
        pcall(craftingPage.OnEvent, craftingPage, "BAG_UPDATE")
    end
end

local function GetCraftingReagentCountOverride()
    return 9999
end

local function GetReagentQuantityInPossessionOverride()
    return 9999
end

local function AccumulateReagentsInPossessionOverride()
    return 9999
end

local function SetUnlockCountOverridesEnabled(enabled)
    local itemUtil = _G.ItemUtil
    if type(itemUtil) == "table" and type(itemUtil.GetCraftingReagentCount) == "function" and not originalGetCraftingReagentCount then
        originalGetCraftingReagentCount = itemUtil.GetCraftingReagentCount
    end

    local professionsUtil = _G.ProfessionsUtil
    if type(professionsUtil) == "table" and type(professionsUtil.GetReagentQuantityInPossession) == "function" and not originalGetReagentQuantityInPossession then
        originalGetReagentQuantityInPossession = professionsUtil.GetReagentQuantityInPossession
    end
    if type(professionsUtil) == "table" and type(professionsUtil.AccumulateReagentsInPossession) == "function" and not originalAccumulateReagentsInPossession then
        originalAccumulateReagentsInPossession = professionsUtil.AccumulateReagentsInPossession
    end

    if type(itemUtil) == "table" and originalGetCraftingReagentCount then
        itemUtil.GetCraftingReagentCount = enabled and GetCraftingReagentCountOverride or originalGetCraftingReagentCount
    end
    if type(professionsUtil) == "table" and originalGetReagentQuantityInPossession then
        professionsUtil.GetReagentQuantityInPossession = enabled and GetReagentQuantityInPossessionOverride or originalGetReagentQuantityInPossession
    end
    if type(professionsUtil) == "table" and originalAccumulateReagentsInPossession then
        professionsUtil.AccumulateReagentsInPossession = enabled and AccumulateReagentsInPossessionOverride or originalAccumulateReagentsInPossession
    end
end

local function IsFlyoutElementUnlocked(elementData, behavior)
    if not isUnlockEnabled or not elementData or not behavior then
        return false
    end

    local reagent = elementData.reagent
    local transaction = behavior.GetTransaction and behavior:GetTransaction() or nil
    if not reagent or not transaction then
        return false
    end

    if transaction.HasAllocatedReagent and transaction:HasAllocatedReagent(reagent) then
        return false
    end
    if transaction.AreDependentReagentsAllocated and not transaction:AreDependentReagentsAllocated(reagent) then
        return false
    end

    local recraftAllocation = transaction.GetRecraftAllocation and transaction:GetRecraftAllocation() or nil
    if recraftAllocation and C_TradeSkillUI and C_TradeSkillUI.IsRecraftReagentValid and not C_TradeSkillUI.IsRecraftReagentValid(recraftAllocation, reagent) then
        return false
    end

    return true
end

local function UpdateFlyoutButtonState(button, count, elementData, behavior)
    if button and elementData and behavior then
        flyoutButtonStateCache[button] = {
            behavior = behavior,
            elementData = elementData,
        }
    end

    local cachedState = button and flyoutButtonStateCache[button] or nil
    elementData = elementData or (cachedState and cachedState.elementData) or nil
    behavior = behavior or (cachedState and cachedState.behavior) or nil

    local valid = behavior and behavior.IsElementValid and behavior:IsElementValid(elementData)
    if not valid then
        return
    end

    if IsFlyoutElementUnlocked(elementData, behavior) then
        button.enabled = true
        if button.DesaturateHierarchy then
            button:DesaturateHierarchy(0)
        end
        if button.GetNormalTexture and button:GetNormalTexture() then
            SetItemButtonTextureVertexColor(button, 1, 1, 1)
            SetItemButtonNormalTextureVertexColor(button, 1, 1, 1)
        end
    end
end

local function EnsureFlyoutButtonOverrides()
    if flyoutButtonOverridesInstalled then
        return
    end

    local function InstallOverride(mixin, originalRefName)
        if not mixin or type(mixin.UpdateState) ~= "function" then
            return
        end

        if originalRefName == "item" then
            originalFlyoutItemButtonUpdateState = mixin.UpdateState
        else
            originalFlyoutCurrencyButtonUpdateState = mixin.UpdateState
        end

        mixin.UpdateState = function(button, count, elementData, behavior)
            local original = originalRefName == "item" and originalFlyoutItemButtonUpdateState or originalFlyoutCurrencyButtonUpdateState
            original(button, count, elementData, behavior)
            UpdateFlyoutButtonState(button, count, elementData, behavior)
        end
    end

    InstallOverride(_G.ProfessionsFlyoutItemButtonMixin, "item")
    InstallOverride(_G.ProfessionsFlyoutCurrencyButtonMixin, "currency")
    flyoutButtonOverridesInstalled = true
end

local function SanitizeTransaction(transaction)
    if not transaction then
        return false
    end

    local changed = false
    local beforeCount

    if transaction.CreateCraftingReagentInfoTbl then
        local ok, tbl = pcall(transaction.CreateCraftingReagentInfoTbl, transaction)
        if ok and tbl then
            beforeCount = #tbl
        end
    end

    SafeCallMethod(transaction, "SanitizeOptionalAllocations")
    SafeCallMethod(transaction, "SanitizeAllocations")
    SafeCallMethod(transaction, "SanitizeTargetAllocations")

    local recipeSchematic = transaction.GetRecipeSchematic and transaction:GetRecipeSchematic() or nil
    if recipeSchematic and transaction.HasAnyAllocations and transaction.ClearAllocations and transaction.EnumerateAllocations then
        local useCharacterInventoryOnly = transaction.ShouldUseCharacterInventoryOnly and transaction:ShouldUseCharacterInventoryOnly() or false

        for slotIndex, reagentSlotSchematic in ipairs(recipeSchematic.reagentSlotSchematics or {}) do
            if transaction:HasAnyAllocations(slotIndex) then
                local requiredQuantity = reagentSlotSchematic.quantityRequired or 0
                local allocatedOwnedQuantity = 0
                local invalidSlot = false

                for _, allocation in transaction:EnumerateAllocations(slotIndex) do
                    local reagent = allocation and allocation.reagent
                    if not reagent then
                        invalidSlot = true
                        break
                    end

                    local professionsUtil = _G.ProfessionsUtil
                    local ownedQuantity = professionsUtil and professionsUtil.GetReagentQuantityInPossession and professionsUtil.GetReagentQuantityInPossession(reagent, useCharacterInventoryOnly) or 0
                    local reagentRequiredQuantity = reagentSlotSchematic.GetQuantityRequired and reagentSlotSchematic:GetQuantityRequired(reagent) or requiredQuantity
                    if ownedQuantity < reagentRequiredQuantity then
                        invalidSlot = true
                        break
                    end

                    allocatedOwnedQuantity = allocatedOwnedQuantity + ownedQuantity
                end

                if not invalidSlot and requiredQuantity > 0 and allocatedOwnedQuantity < requiredQuantity then
                    invalidSlot = true
                end

                if invalidSlot then
                    pcall(transaction.ClearAllocations, transaction, slotIndex)
                    changed = true
                end
            end
        end
    end

    if beforeCount and transaction.CreateCraftingReagentInfoTbl then
        local ok, tbl = pcall(transaction.CreateCraftingReagentInfoTbl, transaction)
        if ok and tbl then
            changed = changed or beforeCount ~= #tbl
        end
    end

    return changed
end

local function SanitizeVisibleReagentAllocations()
    local schematicForm = GetSchematicForm()
    if not schematicForm or not schematicForm:IsVisible() then
        return
    end

    local transaction = schematicForm.GetTransaction and schematicForm:GetTransaction() or nil
    SanitizeTransaction(transaction)

    if schematicForm.QualityDialog and schematicForm.QualityDialog.IsShown and schematicForm.QualityDialog:IsShown() then
        local qd = schematicForm.QualityDialog
        local slotIndex = qd.GetSlotIndex and qd:GetSlotIndex() or nil
        if slotIndex and transaction and transaction.GetAllocationsCopy and qd.ReinitAllocations then
            local allocationsCopy = transaction:GetAllocationsCopy(slotIndex)
            qd:ReinitAllocations(allocationsCopy)
        end
    end

    RefreshCraftingForm()
end

local function RefreshVisibleFlyouts()
    for button, buttonState in pairs(flyoutButtonStateCache) do
        UpdateFlyoutButtonState(button, nil, buttonState.elementData, buttonState.behavior)
    end
end

local function SetCraftingPageBagUpdatesSuspended(suspended)
    local craftingPage = GetCraftingPage()
    if not craftingPage or type(craftingPage.IsEventRegistered) ~= "function" then
        return
    end

    craftingPage.simpleCraftSimSuspendedBagEvents = craftingPage.simpleCraftSimSuspendedBagEvents or {}

    for _, eventName in ipairs(BAG_UPDATE_EVENTS) do
        if suspended then
            if craftingPage:IsEventRegistered(eventName) then
                craftingPage.simpleCraftSimSuspendedBagEvents[eventName] = true
                pcall(craftingPage.UnregisterEvent, craftingPage, eventName)
            end
        elseif craftingPage.simpleCraftSimSuspendedBagEvents[eventName] then
            craftingPage.simpleCraftSimSuspendedBagEvents[eventName] = nil
            if type(craftingPage.RegisterEvent) == "function" and not craftingPage:IsEventRegistered(eventName) then
                pcall(craftingPage.RegisterEvent, craftingPage, eventName)
            end
        end
    end
end

local function SetUnlockEnabled(enabled, shouldRefresh)
    local normalizedEnabled = not not enabled
    local wasEnabled = isUnlockEnabled

    if isUnlockEnabled == normalizedEnabled then
        if unlockCheckbox then
            unlockCheckbox:SetChecked(normalizedEnabled)
        end
        return
    end

    isUnlockEnabled = normalizedEnabled
    SetUnlockCountOverridesEnabled(normalizedEnabled)
    SetCraftingPageBagUpdatesSuspended(normalizedEnabled)

    if unlockCheckbox then
        unlockCheckbox:SetChecked(normalizedEnabled)
    end

    RefreshVisibleFlyouts()

    if wasEnabled and not normalizedEnabled then
        SanitizeVisibleReagentAllocations()
    elseif shouldRefresh then
        RefreshCraftingForm()
        C_Timer.After(0, RefreshCraftingForm)
        C_Timer.After(0.05, RefreshCraftingForm)
    end
end

local function GetTrackRecipeCheckbox()
    local schematicForm = GetSchematicForm()
    return schematicForm and schematicForm.TrackRecipeCheckbox or nil
end

local function UpdateControlState()
    if unlockCheckbox then
        unlockCheckbox:SetChecked(isUnlockEnabled)
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

    unlockCheckbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    unlockCheckbox:SetSize(CHECKBOX_SIZE, CHECKBOX_SIZE)
    unlockCheckbox:SetHitRectInsets(0, 0, 0, 0)

    unlockLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    unlockLabel:SetPoint("LEFT", unlockCheckbox, "RIGHT", LABEL_OFFSET_X, 0)
    unlockLabel:SetJustifyH("LEFT")
    unlockLabel:SetText(LABEL_TEXT)

    local checkboxName = unlockCheckbox.GetName and unlockCheckbox:GetName()
    local checkboxText = unlockCheckbox.Text or (checkboxName and _G[checkboxName .. "Text"]) or nil
    if checkboxText then
        checkboxText:SetText("")
        checkboxText:Hide()
    end

    unlockCheckbox:SetScript("OnClick", function(self)
        SetUnlockEnabled(self:GetChecked(), true)
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
        schematicForm:HookScript("OnHide", function()
            SetUnlockEnabled(false, false)
        end)
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
        if arg1 == "Blizzard_Professions" or arg1 == "Blizzard_ProfessionsTemplates" then
            EnsureFlyoutButtonOverrides()
            C_Timer.After(0, HookProfessionsFrame)
        elseif arg1 == "ElvUI" then
            isElvUISkinned = false
            C_Timer.After(0, EnsureControls)
        end
    elseif event == "PLAYER_LOGIN" then
        EnsureFlyoutButtonOverrides()
        C_Timer.After(0, HookProfessionsFrame)
    end
end)
