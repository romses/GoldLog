-- GoldLog - Gold and Currency Tracking Addon
local ADDON_NAME = "gold_log"
local GoldLog = {}

-- LibDataBroker support
local LDB = LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true)
local dataObject

-- Initialize saved variables
GoldLogDB = GoldLogDB or {}
GoldLogDB.characters = GoldLogDB.characters or {}

-- Local variables
local frame
local currencyFrame
local isVisible = false
local sessionStartTime = 0
local sessionStartCurrencies = {}
local collapsedSections = {}

-- UI Appearance Constants
local FRAME_BG_COLOR_R = 0
local FRAME_BG_COLOR_G = 0
local FRAME_BG_COLOR_B = 0
local FRAME_BG_ALPHA = 1
local ROW_BG_COLOR_R = 0.2
local ROW_BG_COLOR_G = 0.2
local ROW_BG_COLOR_B = 0.2
local ROW_BG_ALPHA = 0.6

-- Helper function to get current date string
local function GetDateString()
    return date("%Y-%m-%d")
end

-- Helper function to get week string (year-week)
local function GetWeekString()
    return date("%Y-W%W")
end

-- Helper function to get month string (year-month)
local function GetMonthString()
    return date("%Y-%m")
end

-- Get player's current gold
local function GetCurrentGold()
    return GetMoney()
end

-- Currency expansion mapping
local currencyExpansions = {
    -- The War Within (11.x)
    [3089] = "The War Within", -- Restored Coffer Key
    [2915] = "The War Within", -- Valorstones
    [3056] = "The War Within", -- Kej
    [2914] = "The War Within", -- Weathered Harbinger Crest
    [2917] = "The War Within", -- Carved Harbinger Crest
    [2916] = "The War Within", -- Runed Harbinger Crest
    [2918] = "The War Within", -- Gilded Harbinger Crest
    [3028] = "The War Within", -- Resonance Crystals
    
    -- Dragonflight (10.x)
    [2806] = "Dragonflight", -- Whelpling's Awakened Crest
    [2807] = "Dragonflight", -- Drake's Awakened Crest
    [2809] = "Dragonflight", -- Wyrm's Awakened Crest
    [2812] = "Dragonflight", -- Aspect's Awakened Crest
    [2245] = "Dragonflight", -- Flightstones
    [2594] = "Dragonflight", -- Paracausal Flakes
    [2708] = "Dragonflight", -- Drake's Dreaming Crest
    
    -- Shadowlands (9.x)
    [1906] = "Shadowlands", -- Soul Ash
    [1977] = "Shadowlands", -- Stygian Ember
    [1828] = "Shadowlands", -- Reservoir Anima
    [1885] = "Shadowlands", -- Grateful Offering
    [1979] = "Shadowlands", -- Cyphers of the First Ones
    [1904] = "Shadowlands", -- Tower Knowledge
    [1816] = "Shadowlands", -- Sinstone Fragments
    
    -- Battle for Azeroth (8.x)
    [1560] = "Battle for Azeroth", -- War Resources
    [1553] = "Battle for Azeroth", -- Azerite
    [1721] = "Battle for Azeroth", -- Prismatic Manapearl
    [1755] = "Battle for Azeroth", -- Coalescing Visions
    [1803] = "Battle for Azeroth", -- Echoes of Ny'alotha
    
    -- Legion (7.x)
    [1220] = "Legion", -- Order Resources
    [1226] = "Legion", -- Nethershard
    [1342] = "Legion", -- Legionfall War Supplies
    [1508] = "Legion", -- Veiled Argunite
    
    -- PvP
    [1602] = "PvP", -- Conquest
    [1792] = "PvP", -- Honor
    
    -- Timeless Dungeons
    [2009] = "Remix", -- Bronze
    [2123] = "Remix", -- Residual Memories
}

-- Get all current currencies
local function GetAllCurrencies()
    local currencies = {}
    
    -- Add Gold as currency ID 0
    local goldAmount = GetMoney()
    if goldAmount > 0 then
        currencies[0] = {
            name = "Gold",
            quantity = goldAmount,
            iconFileID = 133784
        }
    end
    
    -- First pass: expand all headers
    local numCurrencies = C_CurrencyInfo.GetCurrencyListSize()
    for i = 1, numCurrencies do
        local currencyInfo = C_CurrencyInfo.GetCurrencyListInfo(i)
        if currencyInfo and currencyInfo.isHeader and not currencyInfo.isHeaderExpanded then
            C_CurrencyInfo.ExpandCurrencyList(i, true)
        end
    end
    
    -- Refresh the count after expanding
    numCurrencies = C_CurrencyInfo.GetCurrencyListSize()
    
    -- Second pass: collect all currencies
    for i = 1, numCurrencies do
        local currencyInfo = C_CurrencyInfo.GetCurrencyListInfo(i)
        if currencyInfo and not currencyInfo.isHeader then
            local currencyData = C_CurrencyInfo.GetCurrencyInfo(currencyInfo.idKeyPath or currencyInfo.currencyID)
            if currencyData and currencyData.quantity and currencyData.quantity > 0 then
                currencies[currencyData.currencyID] = {
                    name = currencyData.name,
                    quantity = currencyData.quantity,
                    iconFileID = currencyData.iconFileID
                }
            end
        end
    end
    
    return currencies
end

-- Get expansion for currency
local function GetCurrencyExpansion(currencyID)
    -- Gold gets its own category at the top
    if currencyID == 0 then
        return "Gold"
    end
    return currencyExpansions[currencyID] or "Andere"
end

-- Group currencies by expansion
local function GroupCurrenciesByExpansion(currencies)
    local grouped = {}
    
    for currencyID, data in pairs(currencies) do
        local expansion = GetCurrencyExpansion(currencyID)
        if not grouped[expansion] then
            grouped[expansion] = {}
        end
        table.insert(grouped[expansion], {id = currencyID, data = data})
    end
    
    -- Sort within each group
    for expansion, currList in pairs(grouped) do
        table.sort(currList, function(a, b) 
            return math.abs(a.data.change) > math.abs(b.data.change) 
        end)
    end
    
    return grouped
end

-- Format number with separators
local function FormatNumber(num)
    if not num then return "0" end
    local formatted = tostring(math.abs(num))
    formatted = formatted:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if formatted:sub(1, 1) == "," then
        formatted = formatted:sub(2)
    end
    if num < 0 then
        formatted = "-" .. formatted
    end
    return formatted
end

-- Format copper to gold string
local function FormatGold(copper)
    if not copper or copper == 0 then
        return "0g 0s 0c"
    end
    
    local isNegative = copper < 0
    copper = math.abs(copper)
    
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local bronze = copper % 100
    
    local result = ""
    if gold > 0 then
        -- Format gold with thousand separators
        local goldStr = tostring(gold)
        goldStr = goldStr:reverse():gsub("(%d%d%d)", "%1."):reverse()
        if goldStr:sub(1, 1) == "." then
            goldStr = goldStr:sub(2)
        end
        result = result .. goldStr .. "g "
    end
    if silver > 0 or gold > 0 then
        result = result .. silver .. "s "
    end
    result = result .. bronze .. "c"
    
    if isNegative then
        result = "-" .. result
    end
    
    return result
end

-- Initialize database structure
local function InitializeDB()
    if not GoldLogDB.characters then
        GoldLogDB.characters = {}
    end
    
    local playerName = UnitName("player") .. "-" .. GetRealmName()
    
    if not GoldLogDB.characters[playerName] then
        GoldLogDB.characters[playerName] = {
            dailyData = {},
            currencies = {},
            currencyData = {}
        }
        
        -- For new characters, initialize with current currency values as baseline
        local currentCurrencies = GetAllCurrencies()
        for currencyID, data in pairs(currentCurrencies) do
            GoldLogDB.characters[playerName].currencies[currencyID] = data.quantity
            GoldLogDB.characters[playerName].currencyData[currencyID] = {
                name = data.name,
                iconFileID = data.iconFileID
            }
        end
    end
    
    -- Ensure currency fields exist for existing characters
    if not GoldLogDB.characters[playerName].currencies then
        GoldLogDB.characters[playerName].currencies = {}
    end
    if not GoldLogDB.characters[playerName].currencyData then
        GoldLogDB.characters[playerName].currencyData = {}
    end
    
    return playerName
end

-- Update daily data
local function UpdateDailyData(playerName, currencyChanges)
    local dateStr = GetDateString()
    local weekStr = GetWeekString()
    local monthStr = GetMonthString()
    
    local charData = GoldLogDB.characters[playerName]
    
    -- Initialize daily entry if needed
    if not charData.dailyData[dateStr] then
        charData.dailyData[dateStr] = {
            week = weekStr,
            month = monthStr,
            currencies = {}
        }
    end
    
    -- Update currency changes
    if currencyChanges then
        if not charData.dailyData[dateStr].currencies then
            charData.dailyData[dateStr].currencies = {}
        end
        for currencyID, change in pairs(currencyChanges) do
            if not charData.dailyData[dateStr].currencies[currencyID] then
                charData.dailyData[dateStr].currencies[currencyID] = 0
            end
            charData.dailyData[dateStr].currencies[currencyID] = charData.dailyData[dateStr].currencies[currencyID] + change
        end
    end
end

-- Calculate earnings for different periods
local function CalculateEarnings(playerName)
    local charData = GoldLogDB.characters[playerName]
    if not charData then
        return {}, {}, {}, {}, {}
    end
    
    local dateStr = GetDateString()
    local weekStr = GetWeekString()
    local monthStr = GetMonthString()
    
    local sessionCurrencies = {}
    local todayCurrencies = {}
    local weekCurrencies = {}
    local monthCurrencies = {}
    
    -- Get all current currencies (including Gold as ID 0)
    local currentCurrencies = GetAllCurrencies()
    
    -- Initialize sessionStartCurrencies if empty (happens on first call after login)
    local needsInit = true
    for _ in pairs(sessionStartCurrencies) do
        needsInit = false
        break
    end
    if needsInit then
        for currencyID, data in pairs(currentCurrencies) do
            sessionStartCurrencies[currencyID] = data.quantity
        end
    end
    
    -- Calculate session earnings for all currencies (including Gold)
    for currencyID, data in pairs(currentCurrencies) do
        local startAmount = sessionStartCurrencies[currencyID] or 0
        sessionCurrencies[currencyID] = {
            name = data.name,
            change = data.quantity - startAmount,
            iconFileID = data.iconFileID
        }
    end
    
    -- Calculate today, week and month earnings from daily data
    for date, data in pairs(charData.dailyData) do
        if date == dateStr then
            if data.currencies then
                for currencyID, change in pairs(data.currencies) do
                    todayCurrencies[currencyID] = (todayCurrencies[currencyID] or 0) + change
                end
            end
        end
        if data.week == weekStr then
            if data.currencies then
                for currencyID, change in pairs(data.currencies) do
                    weekCurrencies[currencyID] = (weekCurrencies[currencyID] or 0) + change
                end
            end
        end
        if data.month == monthStr then
            if data.currencies then
                for currencyID, change in pairs(data.currencies) do
                    monthCurrencies[currencyID] = (monthCurrencies[currencyID] or 0) + change
                end
            end
        end
    end
    
    -- Add current session to today/week/month
    for currencyID, data in pairs(sessionCurrencies) do
        todayCurrencies[currencyID] = (todayCurrencies[currencyID] or 0) + data.change
        weekCurrencies[currencyID] = (weekCurrencies[currencyID] or 0) + data.change
        monthCurrencies[currencyID] = (monthCurrencies[currencyID] or 0) + data.change
    end
    
    -- Include all current currencies
    for currencyID, data in pairs(currentCurrencies) do
        if not todayCurrencies[currencyID] then
            todayCurrencies[currencyID] = 0
        end
        if not weekCurrencies[currencyID] then
            weekCurrencies[currencyID] = 0
        end
        if not monthCurrencies[currencyID] then
            monthCurrencies[currencyID] = 0
        end
    end
    
    -- Convert to formatted objects
    local todayCurrenciesFormatted = {}
    for currencyID, change in pairs(todayCurrencies) do
        local currInfo = currentCurrencies[currencyID] or charData.currencyData[currencyID]
        todayCurrenciesFormatted[currencyID] = {
            name = currInfo and currInfo.name or ("Currency " .. currencyID),
            change = change,
            iconFileID = currInfo and currInfo.iconFileID or 134400
        }
    end
    
    local weekCurrenciesFormatted = {}
    for currencyID, change in pairs(weekCurrencies) do
        local currInfo = currentCurrencies[currencyID] or charData.currencyData[currencyID]
        weekCurrenciesFormatted[currencyID] = {
            name = currInfo and currInfo.name or ("Currency " .. currencyID),
            change = change,
            iconFileID = currInfo and currInfo.iconFileID or 134400
        }
    end
    
    local monthCurrenciesFormatted = {}
    for currencyID, change in pairs(monthCurrencies) do
        local currInfo = currentCurrencies[currencyID] or charData.currencyData[currencyID]
        monthCurrenciesFormatted[currencyID] = {
            name = currInfo and currInfo.name or ("Currency " .. currencyID),
            change = change,
            iconFileID = currInfo and currInfo.iconFileID or 134400
        }
    end
    
    return sessionCurrencies, todayCurrenciesFormatted, weekCurrenciesFormatted, monthCurrenciesFormatted, currentCurrencies
end

-- Create the display frame
local function CreateDisplayFrame()
    frame = CreateFrame("Frame", "GoldLogFrame", UIParent, "BackdropTemplate")
    frame:SetSize(1100, 450)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    
    -- Backdrop
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(FRAME_BG_COLOR_R, FRAME_BG_COLOR_G, FRAME_BG_COLOR_B, FRAME_BG_ALPHA)
    
    -- Make it movable
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("Gold Log")
    
    -- Currency section separator
    local currencySeparator = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    currencySeparator:SetPoint("TOPLEFT", 20, -45)
    currencySeparator:SetText("|cffFFD700Einnahmen:|r")
    
    -- Table headers
    local headerBg = frame:CreateTexture(nil, "BACKGROUND")
    headerBg:SetPoint("TOPLEFT", 20, -63)
    headerBg:SetSize(1050, 20)
    headerBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    
    local nameHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameHeader:SetPoint("TOPLEFT", 25, -65)
    nameHeader:SetText("|cffFFFFFFName|r")
    
    local sessionHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sessionHeader:SetPoint("TOPLEFT", 520, -65)
    sessionHeader:SetText("|cffFFFFFFSession|r")
    
    local todayHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    todayHeader:SetPoint("TOPLEFT", 700, -65)
    todayHeader:SetText("|cffFFFFFFHeute|r")
    
    local weekHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    weekHeader:SetPoint("TOPLEFT", 860, -65)
    weekHeader:SetText("|cffFFFFFFWoche|r")
    
    local monthHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    monthHeader:SetPoint("TOPLEFT", 1000, -65)
    monthHeader:SetText("|cffFFFFFFMonat|r")
    
    -- Currency scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 20, -85)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 15)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(1050, 1)
    scrollFrame:SetScrollChild(scrollChild)
    
    frame.currencyScrollFrame = scrollFrame
    frame.currencyScrollChild = scrollChild
    frame.currencyLines = {}
    
    -- Close button
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        frame:Hide()
        isVisible = false
    end)
    
    -- Make frame closable with ESC key
    table.insert(UISpecialFrames, "GoldLogFrame")
    
    frame:Hide()
end

-- Update display
local function UpdateDisplay()
    if not frame or not frame:IsVisible() then
        return
    end
    
    local playerName = UnitName("player") .. "-" .. GetRealmName()
    local sessionCurrencies, todayCurrencies, weekCurrencies, monthCurrencies, currentCurrencies = CalculateEarnings(playerName)
    
    -- Update currency display
    -- Clear existing lines and buttons
    for _, element in ipairs(frame.currencyLines) do
        if element.Hide then
            element:Hide()
        end
    end
    
    local yOffset = -5
    local lineNum = 1
    
    -- Group currencies by expansion (Gold will be in its own group at the top)
    local groupedCurrencies = GroupCurrenciesByExpansion(todayCurrencies)
    
    -- Expansion display order (Gold first)
    local expansionOrder = {
        "Gold",
        "The War Within",
        "Dragonflight",
        "Shadowlands",
        "Battle for Azeroth",
        "Legion",
        "PvP",
        "Remix",
        "Andere"
    }
    
    -- Display grouped currencies
    for _, expansion in ipairs(expansionOrder) do
        -- Get all currencies for this expansion from all time periods
        local allExpCurrencies = {}
        
        -- Collect unique currency IDs from all periods
        for currencyID, data in pairs(sessionCurrencies) do
            if GetCurrencyExpansion(currencyID) == expansion then
                allExpCurrencies[currencyID] = true
            end
        end
        for currencyID, data in pairs(todayCurrencies) do
            if GetCurrencyExpansion(currencyID) == expansion then
                allExpCurrencies[currencyID] = true
            end
        end
        for currencyID, data in pairs(weekCurrencies) do
            if GetCurrencyExpansion(currencyID) == expansion then
                allExpCurrencies[currencyID] = true
            end
        end
        for currencyID, data in pairs(monthCurrencies) do
            if GetCurrencyExpansion(currencyID) == expansion then
                allExpCurrencies[currencyID] = true
            end
        end
        
        local hasAny = false
        for _ in pairs(allExpCurrencies) do
            hasAny = true
            break
        end
        
        if hasAny then
            -- Create or reuse header button
            if not frame.currencyLines[lineNum] or not frame.currencyLines[lineNum].SetText then
                local headerBtn = CreateFrame("Button", nil, frame.currencyScrollChild)
                headerBtn:SetSize(1050, 20)
                
                local headerText = headerBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                headerText:SetPoint("LEFT", 15, 0)
                headerBtn.text = headerText
                
                local arrow = headerBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                arrow:SetPoint("LEFT", headerText, "LEFT", -15, 0)
                headerBtn.arrow = arrow
                
                headerBtn:SetScript("OnClick", function(self)
                    local exp = self.expansion
                    collapsedSections[exp] = not collapsedSections[exp]
                    UpdateDisplay()
                end)
                
                headerBtn:SetScript("OnEnter", function(self)
                    self.text:SetTextColor(1, 1, 0.5)
                end)
                
                headerBtn:SetScript("OnLeave", function(self)
                    self.text:SetTextColor(1, 0.82, 0)
                end)
                
                frame.currencyLines[lineNum] = headerBtn
            end
            
            local headerBtn = frame.currencyLines[lineNum]
            headerBtn:SetPoint("TOPLEFT", frame.currencyScrollChild, "TOPLEFT", 0, yOffset)
            headerBtn.expansion = expansion
            
            -- Count total currencies for expansion
            local totalItems = 0
            for _ in pairs(allExpCurrencies) do
                totalItems = totalItems + 1
            end
            
            local isCollapsed = collapsedSections[expansion]
            
            headerBtn.arrow:SetText(isCollapsed and "|cffFFFFFF+|r" or "|cffFFFFFF-|r")
            headerBtn.text:SetText("|cffFFD700" .. expansion .. "|r |cff888888(" .. totalItems .. ")|r")
            headerBtn:Show()
            
            yOffset = yOffset - 25
            lineNum = lineNum + 1
            
            -- Display currencies if not collapsed
            if not isCollapsed then
                -- Sort currencies by biggest change
                local sortedCurrencies = {}
                for currencyID in pairs(allExpCurrencies) do
                    local sessionData = sessionCurrencies[currencyID]
                    local todayData = todayCurrencies[currencyID]
                    
                    -- Calculate total change magnitude for sorting
                    local maxChange = 0
                    if sessionData then maxChange = math.max(maxChange, math.abs(sessionData.change)) end
                    if todayData then maxChange = math.max(maxChange, math.abs(todayData.change)) end
                    if weekCurrencies[currencyID] and weekCurrencies[currencyID].change then 
                        maxChange = math.max(maxChange, math.abs(weekCurrencies[currencyID].change)) 
                    end
                    if monthCurrencies[currencyID] and monthCurrencies[currencyID].change then 
                        maxChange = math.max(maxChange, math.abs(monthCurrencies[currencyID].change)) 
                    end
                    
                    local name = (sessionData and sessionData.name) or (todayData and todayData.name) or ("Currency " .. currencyID)
                    -- Try to get icon from multiple sources
                    local currInfo = currentCurrencies[currencyID]
                    local iconFileID = (currInfo and currInfo.iconFileID) or (sessionData and sessionData.iconFileID) or (todayData and todayData.iconFileID) or 134400
                    
                    table.insert(sortedCurrencies, {
                        id = currencyID,
                        name = name,
                        iconFileID = iconFileID,
                        maxChange = maxChange
                    })
                end
                
                table.sort(sortedCurrencies, function(a, b) 
                    return a.maxChange > b.maxChange
                end)
                
                -- Display each currency row
                for _, currEntry in ipairs(sortedCurrencies) do
                    local currencyID = currEntry.id
                    
                    -- Create row frame if needed
                    if not frame.currencyLines[lineNum] or frame.currencyLines[lineNum].SetText then
                        local rowFrame = CreateFrame("Frame", nil, frame.currencyScrollChild)
                        rowFrame:SetSize(1050, 18)
                        
                        -- Background for alternating rows
                        local bg = rowFrame:CreateTexture(nil, "BACKGROUND")
                        bg:SetAllPoints(rowFrame)
                        rowFrame.bg = bg
                        
                        -- Currency name
                        local nameText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                        nameText:SetPoint("LEFT", 20, 0)
                        nameText:SetWidth(460)
                        nameText:SetJustifyH("LEFT")
                        rowFrame.nameText = nameText
                        
                        -- Session value
                        local sessionText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                        sessionText:SetPoint("LEFT", 500, 0)
                        sessionText:SetWidth(150)
                        sessionText:SetJustifyH("LEFT")
                        rowFrame.sessionText = sessionText
                        
                        -- Today value
                        local todayText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                        todayText:SetPoint("LEFT", 660, 0)
                        todayText:SetWidth(150)
                        todayText:SetJustifyH("LEFT")
                        rowFrame.todayText = todayText
                        
                        -- Week value
                        local weekText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                        weekText:SetPoint("LEFT", 820, 0)
                        weekText:SetWidth(150)
                        weekText:SetJustifyH("LEFT")
                        rowFrame.weekText = weekText
                        
                        -- Month value
                        local monthText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                        monthText:SetPoint("LEFT", 960, 0)
                        monthText:SetWidth(150)
                        monthText:SetJustifyH("LEFT")
                        rowFrame.monthText = monthText
                        
                        frame.currencyLines[lineNum] = rowFrame
                    end
                    
                    local rowFrame = frame.currencyLines[lineNum]
                    rowFrame:SetPoint("TOPLEFT", frame.currencyScrollChild, "TOPLEFT", 0, yOffset)
                    
                    -- Set alternating row background color
                    if lineNum % 2 == 0 then
                        rowFrame.bg:SetColorTexture(ROW_BG_COLOR_R, ROW_BG_COLOR_G, ROW_BG_COLOR_B, ROW_BG_ALPHA)
                    else
                        rowFrame.bg:SetColorTexture(0, 0, 0, 0)
                    end
                    
                    -- Set currency name with icon
                    rowFrame.nameText:SetText("|T" .. currEntry.iconFileID .. ":16:16:0:0|t " .. currEntry.name)
                    
                    -- Helper function to format currency value
                    local function FormatCurrencyValue(value, currencyID)
                        if not value or value == 0 then
                            return "|cff666666-|r"
                        end
                        local color = value >= 0 and "|cff00ff00" or "|cffff0000"
                        local prefix = value > 0 and "+" or ""
                        -- Format Gold differently (convert copper to gold)
                        if currencyID == 0 then
                            return color .. FormatGold(value) .. "|r"
                        else
                            return color .. prefix .. FormatNumber(value) .. "|r"
                        end
                    end
                    
                    -- Session
                    local sessionVal = sessionCurrencies[currencyID] and sessionCurrencies[currencyID].change or 0
                    rowFrame.sessionText:SetText(FormatCurrencyValue(sessionVal, currencyID))
                    
                    -- Today
                    local todayVal = todayCurrencies[currencyID] and todayCurrencies[currencyID].change or 0
                    rowFrame.todayText:SetText(FormatCurrencyValue(todayVal, currencyID))
                    
                    -- Week
                    local weekVal = weekCurrencies[currencyID] and weekCurrencies[currencyID].change or 0
                    rowFrame.weekText:SetText(FormatCurrencyValue(weekVal, currencyID))
                    
                    -- Month
                    local monthVal = monthCurrencies[currencyID] and monthCurrencies[currencyID].change or 0
                    rowFrame.monthText:SetText(FormatCurrencyValue(monthVal, currencyID))
                    
                    rowFrame:Show()
                    
                    yOffset = yOffset - 18
                    lineNum = lineNum + 1
                end
                
                -- Add spacing after group
                yOffset = yOffset - 5
            end
        end
    end
    
    -- Update scroll child height
    frame.currencyScrollChild:SetHeight(math.max(1, math.abs(yOffset) + 20))
end

-- Toggle frame visibility
local function ToggleFrame()
    if not frame then
        CreateDisplayFrame()
    end
    
    if frame:IsVisible() then
        frame:Hide()
        isVisible = false
    else
        frame:Show()
        isVisible = true
        UpdateDisplay()
    end
end

-- Create LibDataBroker object
local function CreateDataBroker()
    if not LDB then
        print("|cffff0000GoldLog:|r LibDataBroker nicht gefunden. Installiere Bazooka oder ein anderes LDB-Display-Addon.")
        return
    end
    
    dataObject = LDB:NewDataObject("GoldLog", {
        type = "data source",
        text = "Gold Log",
        icon = "Interface\\Icons\\INV_Misc_Coin_01",
        label = "Gold Log",
        
        OnClick = function(clickedframe, button)
            if button == "LeftButton" then
                ToggleFrame()
            elseif button == "RightButton" then
                -- Reset all data
                local playerName = UnitName("player") .. "-" .. GetRealmName()
                if GoldLogDB.characters and GoldLogDB.characters[playerName] then
                    GoldLogDB.characters[playerName].dailyData = {}
                    GoldLogDB.characters[playerName].currencies = {}
                    GoldLogDB.characters[playerName].currencyData = {}
                    sessionStartCurrencies = {}
                    print("|cff00ff00GoldLog:|r Alle Daten zurückgesetzt!")
                    UpdateDisplay()
                end
            end
        end,
        
        OnTooltipShow = function(tooltip)
            tooltip:SetText("|cff00ff00Gold Log|r", 1, 1, 1)
            tooltip:AddLine(" ")
            
            local playerName = UnitName("player") .. "-" .. GetRealmName()
            if not GoldLogDB.characters or not GoldLogDB.characters[playerName] then
                tooltip:AddLine("Keine Daten verfügbar")
                tooltip:Show()
                return
            end
            
            local sessionCurrencies, todayCurrencies, weekCurrencies, monthCurrencies = CalculateEarnings(playerName)
            
            -- Show Gold first
            local goldSession = sessionCurrencies[0]
            local goldToday = todayCurrencies[0]
            local goldWeek = weekCurrencies[0]
            local goldMonth = monthCurrencies[0]
            
            if goldSession then
                local sessionColor = goldSession.change >= 0 and "|cff00ff00" or "|cffff0000"
                tooltip:AddDoubleLine("Session:", sessionColor .. FormatGold(goldSession.change) .. "|r")
            end
            
            if goldToday then
                local todayColor = goldToday.change >= 0 and "|cff00ff00" or "|cffff0000"
                tooltip:AddDoubleLine("Heute:", todayColor .. FormatGold(goldToday.change) .. "|r")
            end
            
            if goldWeek then
                local weekColor = goldWeek.change >= 0 and "|cff00ff00" or "|cffff0000"
                tooltip:AddDoubleLine("Diese Woche:", weekColor .. FormatGold(goldWeek.change) .. "|r")
            end
            
            if goldMonth then
                local monthColor = goldMonth.change >= 0 and "|cff00ff00" or "|cffff0000"
                tooltip:AddDoubleLine("Dieser Monat:", monthColor .. FormatGold(goldMonth.change) .. "|r")
            end
            
            -- Top 5 currencies with changes (excluding Gold)
            local sortedCurrencies = {}
            for currencyID, data in pairs(todayCurrencies) do
                if currencyID ~= 0 then
                    table.insert(sortedCurrencies, data)
                end
            end
            table.sort(sortedCurrencies, function(a, b) return math.abs(a.change) > math.abs(b.change) end)
            
            if #sortedCurrencies > 0 then
                tooltip:AddLine(" ")
                tooltip:AddLine("|cffFFD700Währungen:|r")
                for i = 1, math.min(5, #sortedCurrencies) do
                    local data = sortedCurrencies[i]
                    local color = data.change >= 0 and "|cff00ff00" or "|cffff0000"
                    local changeText = (data.change >= 0 and "+" or "") .. FormatNumber(data.change)
                    tooltip:AddDoubleLine(data.name, color .. changeText .. "|r")
                end
                if #sortedCurrencies > 5 then
                    tooltip:AddLine("|cff888888... und " .. (#sortedCurrencies - 5) .. " weitere|r")
                end
            end
            
            tooltip:AddLine(" ")
            tooltip:AddLine("|cffFFFFFFLinksklick:|r Fenster öffnen", 0.8, 0.8, 0.8)
            tooltip:AddLine("|cffFFFFFFRechtsklick:|r Alle Daten zurücksetzen", 0.8, 0.8, 0.8)
            
            tooltip:Show()
        end,
    })
end

-- Update DataBroker text
local function UpdateDataBrokerText()
    if not dataObject then return end
    
    local playerName = UnitName("player") .. "-" .. GetRealmName()
    if not GoldLogDB.characters or not GoldLogDB.characters[playerName] then
        dataObject.text = "Gold Log"
        return
    end
    
    local sessionCurrencies = CalculateEarnings(playerName)
    local goldData = sessionCurrencies[0]
    if goldData then
        local color = goldData.change >= 0 and "|cff00ff00" or "|cffff0000"
        dataObject.text = "Gold: " .. color .. FormatGold(goldData.change) .. "|r"
    else
        dataObject.text = "Gold Log"
    end
end

-- Event handler
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
eventFrame:RegisterEvent("PLAYER_LOGOUT")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        -- Initialize database
        local playerName = InitializeDB()
        -- Create DataBroker object
        CreateDataBroker()
        print("|cff00ff00GoldLog|r geladen. Benutze /goldlog oder /gl zum Anzeigen.")
        if LDB then
            print("|cff00ff00GoldLog:|r LibDataBroker gefunden - Bazooka-Integration aktiv.")
        end
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Ensure database is initialized
        if not GoldLogDB.characters then
            GoldLogDB.characters = {}
        end
        
        local playerName = UnitName("player") .. "-" .. GetRealmName()
        
        -- Initialize character data if needed
        if not GoldLogDB.characters[playerName] then
            GoldLogDB.characters[playerName] = {
                dailyData = {},
                currencies = {},
                currencyData = {}
            }
        end
        
        local charData = GoldLogDB.characters[playerName]
        
        -- Initialize session start time
        sessionStartTime = time()
        
        -- Initialize session currencies (including Gold as ID 0)
        local allCurrencies = GetAllCurrencies()
        sessionStartCurrencies = {}
        for currencyID, data in pairs(allCurrencies) do
            sessionStartCurrencies[currencyID] = data.quantity
        end
        
        -- Also initialize charData currencies if not already done
        if not charData.currencies then
            charData.currencies = {}
        end
        for currencyID, data in pairs(allCurrencies) do
            if not charData.currencies[currencyID] then
                charData.currencies[currencyID] = data.quantity
            end
        end
        
    elseif event == "PLAYER_MONEY" or event == "CURRENCY_DISPLAY_UPDATE" then
        -- Track all currency changes (including Gold)
        if not GoldLogDB.characters then
            return
        end
        
        local playerName = UnitName("player") .. "-" .. GetRealmName()
        local charData = GoldLogDB.characters[playerName]
        
        if not charData then
            return
        end
        
        local currentCurrencies = GetAllCurrencies()
        local currencyChanges = {}
        local hasChanges = false
        
        -- Check for changes in all currencies (including Gold as ID 0)
        for currencyID, data in pairs(currentCurrencies) do
            local lastAmount = charData.currencies[currencyID] or 0
            local change = data.quantity - lastAmount
            if change ~= 0 then
                currencyChanges[currencyID] = change
                hasChanges = true
                
                -- Store currency info
                charData.currencyData[currencyID] = {
                    name = data.name,
                    iconFileID = data.iconFileID
                }
            end
        end
        
        -- Update stored values
        for currencyID, data in pairs(currentCurrencies) do
            charData.currencies[currencyID] = data.quantity
        end
        
        if hasChanges then
            UpdateDailyData(playerName, currencyChanges)
            UpdateDataBrokerText()
        end
        
        UpdateDisplay()
        
    elseif event == "PLAYER_LOGOUT" then
        -- All currency values are already saved in charData.currencies
        -- No additional action needed
    end
end)

-- Slash commands
SLASH_GOLDLOG1 = "/goldlog"
SLASH_GOLDLOG2 = "/gl"
SlashCmdList["GOLDLOG"] = function(msg)
    msg = string.lower(msg or "")
    
    if msg == "reset" then
        local playerName = UnitName("player") .. "-" .. GetRealmName()
        GoldLogDB.characters[playerName].dailyData = {}
        GoldLogDB.characters[playerName].currencies = {}
        GoldLogDB.characters[playerName].currencyData = {}
        sessionStartCurrencies = {}
        print("|cff00ff00GoldLog:|r Daten zurückgesetzt.")
        UpdateDisplay()
        print("|cff00ff00GoldLog:|r Daten zurückgesetzt.")
        UpdateDisplay()
    elseif msg == "reload" or msg == "fix" then
        -- Manually create data broker if missing
        if not dataObject and LDB then
            CreateDataBroker()
            print("|cff00ff00GoldLog:|r DataBroker erstellt.")
        elseif not LDB then
            print("|cffff0000GoldLog:|r LibDataBroker nicht verfügbar.")
        else
            print("|cff00ff00GoldLog:|r DataBroker existiert bereits.")
        end
        -- Ensure frame exists
        if not frame then
            CreateDisplayFrame()
            print("|cff00ff00GoldLog:|r Hauptfenster erstellt.")
        end
    elseif msg == "status" or msg == "debug" or msg == "info" then
        print("|cff00ff00=== GoldLog Status ===|r")
        print("Version: 1.0.0")
        print("Spieler: " .. UnitName("player") .. "-" .. GetRealmName())
        
        local playerName = UnitName("player") .. "-" .. GetRealmName()
        local sessionCurrencies, todayCurrencies, weekCurrencies, monthCurrencies, currentCurrencies = CalculateEarnings(playerName)
        
        -- Show Gold
        local goldSession = sessionCurrencies[0]
        local goldToday = todayCurrencies[0]
        local goldWeek = weekCurrencies[0]
        local goldMonth = monthCurrencies[0]
        
        print("Aktuelles Gold: " .. FormatGold(GetMoney()))
        if goldSession then
            print("|cff00ff00Session:|r " .. FormatGold(goldSession.change))
        end
        if goldToday then
            print("|cff00ff00Heute:|r " .. FormatGold(goldToday.change))
        end
        if goldWeek then
            print("|cff00ff00Diese Woche:|r " .. FormatGold(goldWeek.change))
        end
        if goldMonth then
            print("|cff00ff00Dieser Monat:|r " .. FormatGold(goldMonth.change))
        end
        
        -- Show currency counts
        local sessionCount = 0
        for currencyID in pairs(sessionCurrencies) do 
            if currencyID ~= 0 then sessionCount = sessionCount + 1 end
        end
        local todayCount = 0
        for currencyID in pairs(todayCurrencies) do 
            if currencyID ~= 0 then todayCount = todayCount + 1 end
        end
        
        print("|cff00ff00Währungen (Session):|r " .. sessionCount)
        print("|cff00ff00Währungen (Heute):|r " .. todayCount)
        
        -- Show all current currencies
        local currCount = 0
        for currencyID in pairs(currentCurrencies) do 
            if currencyID ~= 0 then currCount = currCount + 1 end
        end
        print("|cff00ff00Aktuell besessene Währungen:|r " .. currCount)
        
        if currCount > 0 then
            print("|cff888888Liste:|r")
            for currencyID, data in pairs(currentCurrencies) do
                if currencyID ~= 0 then
                    print("  - " .. data.name .. ": " .. data.quantity)
                end
            end
        end
        
        if LDB then
            print("|cff00ff00LibDataBroker:|r Gefunden")
            if dataObject then
                print("|cff00ff00DataBroker Plugin:|r Aktiv")
            else
                print("|cffff0000DataBroker Plugin:|r Nicht erstellt!")
            end
        else
            print("|cffff0000LibDataBroker:|r Nicht gefunden - Bazooka installieren!")
        end
        
        if frame then
            print("|cff00ff00Hauptfenster:|r " .. (frame:IsVisible() and "Sichtbar" or "Versteckt"))
        else
            print("|cffff0000Hauptfenster:|r Nicht erstellt!")
        end
        
        local charData = GoldLogDB.characters[playerName]
        if charData then
            local dayCount = 0
            for _ in pairs(charData.dailyData) do
                dayCount = dayCount + 1
            end
            print("Gespeicherte Tage: " .. dayCount)
        end
        
    elseif msg == "help" then
        print("|cff00ff00GoldLog Befehle:|r")
        print("/goldlog oder /gl - Zeigt/versteckt das Gold-Fenster")
        print("/goldlog status - Zeigt Addon-Status und aktuelle Statistiken")
        print("/goldlog reload - Erstellt Minimap-Button und Fenster neu")
        print("/goldlog reset - Setzt alle Daten zurück")
        print("/goldlog help - Zeigt diese Hilfe")
    else
        ToggleFrame()
    end
end

-- Update display periodically if visible
local updateTimer = 0
eventFrame:SetScript("OnUpdate", function(self, elapsed)
    updateTimer = updateTimer + elapsed
    if updateTimer >= 1 then
        updateTimer = 0
        if isVisible then
            UpdateDisplay()
        end
    end
end)
