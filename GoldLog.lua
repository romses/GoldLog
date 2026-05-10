-- GoldLog - Gold and Currency Tracking Addon
local ADDON_NAME = "GoldLog"
local GoldLog = {}

-- Get localization table
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME, true) or {}

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
local activeTab = "balance" -- "balance", "income", "expense"

-- Transaction context tracking
local transactionContext = {
    currentContext = nil,  -- Current open frame/context
    lastGold = 0,          -- Last known gold amount
    contextTimeout = 0,    -- Timeout to clear context
    pendingAmount = 0      -- Amount waiting for categorization
}

-- Transaction categories
local CATEGORY = {
    MERCHANT_BUY = "MERCHANT_BUY",
    MERCHANT_SELL = "MERCHANT_SELL",
    REPAIR = "REPAIR",
    MAIL_SEND = "MAIL_SEND",
    MAIL_RECEIVE = "MAIL_RECEIVE",
    TRADE = "TRADE",
    QUEST = "QUEST",
    LOOT = "LOOT",
    AUCTION_BUY = "AUCTION_BUY",
    AUCTION_SELL = "AUCTION_SELL",
    GUILD_BANK = "GUILD_BANK",
    OTHER = "OTHER"
}

-- Forward declarations
local UpdateDisplay

-- UI Appearance Constants (Classic WoW Style)
local FRAME_BG_COLOR_R = 0.1
local FRAME_BG_COLOR_G = 0.05
local FRAME_BG_COLOR_B = 0
local FRAME_BG_ALPHA = 0.9
local ROW_BG_COLOR_R = 0.18
local ROW_BG_COLOR_G = 0.12
local ROW_BG_COLOR_B = 0.06
local ROW_BG_ALPHA = 0.5
local HEADER_BG_COLOR_R = 0.25
local HEADER_BG_COLOR_G = 0.16
local HEADER_BG_COLOR_B = 0.0
local HEADER_BG_ALPHA = 0.9

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

-- Helper function to get day of month (1-31)
local function GetDayOfMonth()
    return tonumber(date("%d"))
end

-- Helper function to get day of week (1-7, Monday=1)
local function GetDayOfWeek()
    local day = tonumber(date("%w"))
    -- Convert Sunday (0) to 7, rest stays same but shift by -1
    if day == 0 then
        return 7
    else
        return day
    end
end

-- Helper function to get date of last Wednesday (start of current week)
local function GetLastWednesday()
    local dayOfWeek = GetDayOfWeek()
    -- Wednesday is 3 (Monday=1, Tuesday=2, Wednesday=3...)
    -- Calculate days to subtract to get to last/current Wednesday
    local daysToWednesday = (dayOfWeek - 3 + 7) % 7
    
    -- Get current time and subtract days
    local now = time()
    local secondsPerDay = 86400
    local wednesdayTime = now - (daysToWednesday * secondsPerDay)
    
    return date("%Y-%m-%d", wednesdayTime)
end

-- Get player's current gold
local function GetCurrentGold()
    return GetMoney()
end

-- Currency expansion mapping
local currencyExpansions = {
    -- Midnight (12.x)
    -- Add Midnight currency IDs here as they become available

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

-- Helper: Add thousand separators to number
local function AddThousandSeparators(num, separator)
    separator = separator or ","
    local formatted = tostring(num):reverse():gsub("(%d%d%d)", "%1" .. separator):reverse()
    if formatted:sub(1, 1) == separator then
        formatted = formatted:sub(2)
    end
    return formatted
end

-- Format number with separators
local function FormatNumber(num)
    if not num then return "0" end
    local sign = num < 0 and "-" or ""
    return sign .. AddThousandSeparators(math.abs(num), ",")
end

-- Format copper to gold string
local function FormatGold(copper)
    if not copper or copper == 0 then
        return "0g 0s 0c"
    end
    
    local sign = copper < 0 and "-" or ""
    copper = math.abs(copper)
    
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local bronze = copper % 100
    
    local result = ""
    if gold > 0 then
        result = AddThousandSeparators(gold, ".") .. "g "
    end
    if silver > 0 or gold > 0 then
        result = result .. silver .. "s "
    end
    result = result .. bronze .. "c"
    
    return sign .. result
end

-- Set transaction context
local function SetTransactionContext(context)
    transactionContext.currentContext = context
    transactionContext.contextTimeout = GetTime() + 2 -- 2 second timeout
    transactionContext.lastGold = GetMoney()
end

-- Clear transaction context
local function ClearTransactionContext()
    transactionContext.currentContext = nil
    transactionContext.contextTimeout = 0
end

-- Context to category mapping
local CONTEXT_CATEGORY_MAP = {
    MERCHANT = function(amount) return amount > 0 and CATEGORY.MERCHANT_SELL or CATEGORY.MERCHANT_BUY end,
    REPAIR = function() return CATEGORY.REPAIR end,
    MAIL = function(amount) return amount > 0 and CATEGORY.MAIL_RECEIVE or CATEGORY.MAIL_SEND end,
    TRADE = function() return CATEGORY.TRADE end,
    QUEST = function() return CATEGORY.QUEST end,
    LOOT = function() return CATEGORY.LOOT end,
    AUCTION = function(amount) return amount > 0 and CATEGORY.AUCTION_SELL or CATEGORY.AUCTION_BUY end,
    GUILD_BANK = function() return CATEGORY.GUILD_BANK end,
}

-- Get current transaction category based on context
local function GetTransactionCategory(amount)
    -- Check if context is still valid
    if transactionContext.contextTimeout > 0 and GetTime() > transactionContext.contextTimeout then
        ClearTransactionContext()
    end
    
    local context = transactionContext.currentContext
    if context and CONTEXT_CATEGORY_MAP[context] then
        return CONTEXT_CATEGORY_MAP[context](amount)
    end
    
    return CATEGORY.OTHER
end

-- Add transaction to history
local function AddTransaction(playerName, amount, category, details)
    local charData = GoldLogDB.characters[playerName]
    if not charData or not charData.transactions then
        return
    end
    
    local transaction = {
        timestamp = time(),
        amount = amount,
        category = category,
        details = details or ""
    }
    
    table.insert(charData.transactions, transaction)
    
    -- Keep only last 1000 transactions
    while #charData.transactions > 1000 do
        table.remove(charData.transactions, 1)
    end
end

-- Helper: Create bucket structure
local function CreateBucketStructure()
    return {
        date = nil,
        income = {},
        expense = {},
        incomeByCategory = {},
        expenseByCategory = {}
    }
end

-- Initialize database structure
local function InitializeDB()
    if not GoldLogDB.characters then
        GoldLogDB.characters = {}
    end
    
    local playerName = UnitName("player") .. "-" .. GetRealmName()
    
    if not GoldLogDB.characters[playerName] then
        GoldLogDB.characters[playerName] = {
            weekTotal = {},     -- Wochentotal (Reset jeden Mittwoch)
            lastWeeklyReset = GetLastWednesday(), -- Datum des letzten Mittwoch-Resets
            todayBucket = {},   -- Bucket für den heutigen Tag
            lastDayDate = GetDateString(), -- Datum des letzten Tages
            monthTotal = {},    -- Monatstotal (Reset am 1. des Monats)
            lastMonthlyReset = GetMonthString(), -- Monat des letzten Resets (YYYY-MM)
            currencies = {},    -- Aktuelle Währungsstände
            currencyData = {},  -- Währungsinformationen (Name, Icon)
            transactions = {},  -- Transaction history (limited to last 1000)
            sessionStart = {},  -- Session start currencies (persistent across reloads)
            sessionStartTime = 0 -- Session start timestamp
        }
        
        -- Initialize week total bucket
        GoldLogDB.characters[playerName].weekTotal = CreateBucketStructure()
        
        -- Initialize today bucket
        GoldLogDB.characters[playerName].todayBucket = CreateBucketStructure()
        
        -- Initialize month total bucket
        GoldLogDB.characters[playerName].monthTotal = CreateBucketStructure()
        
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
    
    -- Migrate old data structure to new one
    if GoldLogDB.characters[playerName].dailyData then
        -- Clear old structure
        GoldLogDB.characters[playerName].dailyData = nil
    end
    
    -- Ensure all fields exist for existing characters
    -- Migrate from old weekDays structure to new weekTotal
    if GoldLogDB.characters[playerName].weekDays then
        -- Clear old structure and create new one
        GoldLogDB.characters[playerName].weekDays = nil
        GoldLogDB.characters[playerName].weekTotal = CreateBucketStructure()
        GoldLogDB.characters[playerName].lastWeeklyReset = GetLastWednesday()
    end
    
    if not GoldLogDB.characters[playerName].weekTotal then
        GoldLogDB.characters[playerName].weekTotal = CreateBucketStructure()
        GoldLogDB.characters[playerName].lastWeeklyReset = GetLastWednesday()
    else
        -- Ensure byCategory fields exist
        local bucket = GoldLogDB.characters[playerName].weekTotal
        bucket.incomeByCategory = bucket.incomeByCategory or {}
        bucket.expenseByCategory = bucket.expenseByCategory or {}
    end
    
    if not GoldLogDB.characters[playerName].lastWeeklyReset then
        GoldLogDB.characters[playerName].lastWeeklyReset = GetLastWednesday()
    end
    
    -- Migrate from old monthDays structure to new todayBucket
    if GoldLogDB.characters[playerName].monthDays then
        -- Clear old structure and create new one
        GoldLogDB.characters[playerName].monthDays = nil
        GoldLogDB.characters[playerName].todayBucket = CreateBucketStructure()
        GoldLogDB.characters[playerName].lastDayDate = GetDateString()
    end
    
    if not GoldLogDB.characters[playerName].todayBucket then
        GoldLogDB.characters[playerName].todayBucket = CreateBucketStructure()
        GoldLogDB.characters[playerName].lastDayDate = GetDateString()
    else
        -- Ensure byCategory fields exist
        local bucket = GoldLogDB.characters[playerName].todayBucket
        bucket.incomeByCategory = bucket.incomeByCategory or {}
        bucket.expenseByCategory = bucket.expenseByCategory or {}
    end
    
    if not GoldLogDB.characters[playerName].lastDayDate then
        GoldLogDB.characters[playerName].lastDayDate = GetDateString()
    end
    
    if not GoldLogDB.characters[playerName].monthTotal then
        GoldLogDB.characters[playerName].monthTotal = CreateBucketStructure()
        GoldLogDB.characters[playerName].lastMonthlyReset = GetMonthString()
    else
        -- Ensure byCategory fields exist
        local bucket = GoldLogDB.characters[playerName].monthTotal
        bucket.incomeByCategory = bucket.incomeByCategory or {}
        bucket.expenseByCategory = bucket.expenseByCategory or {}
    end
    
    if not GoldLogDB.characters[playerName].lastMonthlyReset then
        GoldLogDB.characters[playerName].lastMonthlyReset = GetMonthString()
    end
    
    if not GoldLogDB.characters[playerName].transactions then
        GoldLogDB.characters[playerName].transactions = {}
    end
    
    if not GoldLogDB.characters[playerName].currencies then
        GoldLogDB.characters[playerName].currencies = {}
    end
    if not GoldLogDB.characters[playerName].currencyData then
        GoldLogDB.characters[playerName].currencyData = {}
    end
    
    -- Check if we need to reset buckets based on date/time changes
    local charData = GoldLogDB.characters[playerName]
    local currentDate = GetDateString()
    local currentMonth = GetMonthString()
    local currentWednesday = GetLastWednesday()
    
    -- Reset daily bucket if date changed
    if charData.lastDayDate ~= currentDate then
        charData.todayBucket = CreateBucketStructure()
        charData.lastDayDate = currentDate
    end
    
    -- Reset weekly bucket if week changed (Wednesday)
    if charData.lastWeeklyReset ~= currentWednesday then
        charData.weekTotal = CreateBucketStructure()
        charData.lastWeeklyReset = currentWednesday
    end
    
    -- Reset monthly bucket if month changed
    if charData.lastMonthlyReset ~= currentMonth then
        charData.monthTotal = CreateBucketStructure()
        charData.lastMonthlyReset = currentMonth
    end
    
    return playerName
end

-- Helper: Update a single bucket
local function UpdateBucket(bucket, currencyID, change, category)
    if change > 0 then
        bucket.income[currencyID] = (bucket.income[currencyID] or 0) + change
        if currencyID == 0 and category then
            if not bucket.incomeByCategory[currencyID] then
                bucket.incomeByCategory[currencyID] = {}
            end
            bucket.incomeByCategory[currencyID][category] = (bucket.incomeByCategory[currencyID][category] or 0) + change
        end
    elseif change < 0 then
        local absChange = math.abs(change)
        bucket.expense[currencyID] = (bucket.expense[currencyID] or 0) + absChange
        if currencyID == 0 and category then
            if not bucket.expenseByCategory[currencyID] then
                bucket.expenseByCategory[currencyID] = {}
            end
            bucket.expenseByCategory[currencyID][category] = (bucket.expenseByCategory[currencyID][category] or 0) + absChange
        end
    end
end

-- Update bucket data with automatic rollover
local function UpdateBucketData(playerName, currencyChanges)
    if not currencyChanges then return end
    
    local charData = GoldLogDB.characters[playerName]
    local dateStr = GetDateString()
    local monthStr = GetMonthString()
    
    -- Check if we need to reset weekly stats (every Wednesday)
    local lastWednesday = GetLastWednesday()
    if charData.lastWeeklyReset ~= lastWednesday then
        -- New week started, reset weekly bucket
        charData.weekTotal = CreateBucketStructure()
        charData.lastWeeklyReset = lastWednesday
    end
    
    -- Check if we need to reset daily stats (every day)
    if charData.lastDayDate ~= dateStr then
        -- New day started, reset today bucket
        charData.todayBucket = CreateBucketStructure()
        charData.lastDayDate = dateStr
    end
    
    -- Check if we need to reset monthly stats (every month)
    if charData.lastMonthlyReset ~= monthStr then
        -- New month started, reset monthly bucket
        charData.monthTotal = CreateBucketStructure()
        charData.lastMonthlyReset = monthStr
    end
    
    local weekBucket = charData.weekTotal
    local todayBucket = charData.todayBucket
    local monthTotalBucket = charData.monthTotal
    
    -- Update all buckets
    for currencyID, change in pairs(currencyChanges) do
        local category = currencyID == 0 and GetTransactionCategory(change) or nil
        
        if currencyID == 0 and category then
            AddTransaction(playerName, change, category, nil)
        end
        
        UpdateBucket(todayBucket, currencyID, change, category)
        UpdateBucket(weekBucket, currencyID, change, category)
        UpdateBucket(monthTotalBucket, currencyID, change, category)
    end
end

-- Get localized category name
local function GetCategoryName(category)
    local key = "CATEGORY_" .. category
    return L[key] or category
end

-- Helper: Sum currency data into target
local function SumCurrencyData(target, source)
    for currencyID, data in pairs(source) do
        if not target[currencyID] then
            target[currencyID] = {
                name = data.name,
                change = 0,
                iconFileID = data.iconFileID
            }
        end
        target[currencyID].change = target[currencyID].change + data.change
    end
end

-- Helper: Format currency data with fallback
local function FormatCurrencyData(currencies, getFallback, isExpense)
    local formatted = {}
    for currencyID, value in pairs(currencies) do
        local currInfo = getFallback(currencyID)
        formatted[currencyID] = {
            name = currInfo and currInfo.name or ("Currency " .. currencyID),
            change = isExpense and -value or value,
            iconFileID = currInfo and currInfo.iconFileID or 134400
        }
    end
    return formatted
end

-- Calculate earnings for a single character
local function CalculateEarningsForCharacter(charData, playerName)
    if not charData then
        return {}, {}, {}, {}, {}
    end
    
    local sessionCurrencies = {}
    local todayCurrencies = {}
    local weekCurrencies = {}
    local monthCurrencies = {}
    
    -- Get all current currencies (including Gold as ID 0) - only for current player
    local currentCurrencies = {}
    local currentPlayer = UnitName("player") .. "-" .. GetRealmName()
    if playerName == currentPlayer then
        currentCurrencies = GetAllCurrencies()
    end
    
    -- Load session start from saved data (persistent across reloads)
    if not charData.sessionStart then
        charData.sessionStart = {}
    end
    
    -- Calculate session earnings for all currencies (including Gold)
    for currencyID, data in pairs(currentCurrencies) do
        local startAmount = charData.sessionStart[currencyID] or data.quantity
        sessionCurrencies[currencyID] = {
            name = data.name,
            change = data.quantity - startAmount,
            iconFileID = data.iconFileID
        }
    end
    
    -- Separate income/expense tracking
    local todayIncome = {}
    local todayExpense = {}
    local weekIncome = {}
    local weekExpense = {}
    local monthIncome = {}
    local monthExpense = {}
    
    -- Ensure new structure exists for this character (migration for old data)
    if not charData.todayBucket then
        charData.todayBucket = CreateBucketStructure()
        charData.lastDayDate = GetDateString()
    end
    if not charData.weekTotal then
        charData.weekTotal = CreateBucketStructure()
        charData.lastWeeklyReset = GetLastWednesday()
    end
    if not charData.monthTotal then
        charData.monthTotal = CreateBucketStructure()
        charData.lastMonthlyReset = GetMonthString()
    end
    
    -- Migrate old structures if they exist
    if charData.weekDays then
        charData.weekDays = nil
    end
    if charData.monthDays then
        charData.monthDays = nil
    end
    
    -- Check if we need to reset buckets based on date/time changes
    local currentDate = GetDateString()
    local currentMonth = GetMonthString()
    local currentWednesday = GetLastWednesday()
    
    if charData.lastDayDate ~= currentDate then
        charData.todayBucket = CreateBucketStructure()
        charData.lastDayDate = currentDate
    end
    
    if charData.lastWeeklyReset ~= currentWednesday then
        charData.weekTotal = CreateBucketStructure()
        charData.lastWeeklyReset = currentWednesday
    end
    
    if charData.lastMonthlyReset ~= currentMonth then
        charData.monthTotal = CreateBucketStructure()
        charData.lastMonthlyReset = currentMonth
    end
    
    -- Calculate today from today bucket
    local todayBucket = charData.todayBucket
    
    for currencyID, income in pairs(todayBucket.income) do
        todayCurrencies[currencyID] = (todayCurrencies[currencyID] or 0) + income
        todayIncome[currencyID] = (todayIncome[currencyID] or 0) + income
    end
    for currencyID, expense in pairs(todayBucket.expense) do
        todayCurrencies[currencyID] = (todayCurrencies[currencyID] or 0) - expense
        todayExpense[currencyID] = (todayExpense[currencyID] or 0) + expense
    end
    
    -- Calculate week from weekly total bucket
    local weekBucket = charData.weekTotal
    for currencyID, income in pairs(weekBucket.income) do
        weekCurrencies[currencyID] = (weekCurrencies[currencyID] or 0) + income
        weekIncome[currencyID] = (weekIncome[currencyID] or 0) + income
    end
    for currencyID, expense in pairs(weekBucket.expense) do
        weekCurrencies[currencyID] = (weekCurrencies[currencyID] or 0) - expense
        weekExpense[currencyID] = (weekExpense[currencyID] or 0) + expense
    end
    
    -- Calculate month from monthly total bucket
    local monthBucket = charData.monthTotal
    
    for currencyID, income in pairs(monthBucket.income) do
        monthCurrencies[currencyID] = (monthCurrencies[currencyID] or 0) + income
        monthIncome[currencyID] = (monthIncome[currencyID] or 0) + income
    end
    for currencyID, expense in pairs(monthBucket.expense) do
        monthCurrencies[currencyID] = (monthCurrencies[currencyID] or 0) - expense
        monthExpense[currencyID] = (monthExpense[currencyID] or 0) + expense
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
    
    -- Helper function to get currency info with fallback
    local function GetCurrencyInfoWithFallback(currencyID)
        local currInfo = currentCurrencies[currencyID] or charData.currencyData[currencyID]
        
        -- If not found in cached data, try to get it from game API
        if not currInfo and currencyID ~= 0 then
            local apiInfo = C_CurrencyInfo.GetCurrencyInfo(currencyID)
            if apiInfo and apiInfo.name then
                currInfo = {
                    name = apiInfo.name,
                    iconFileID = apiInfo.iconFileID or 134400
                }
                -- Cache it for future use
                charData.currencyData[currencyID] = currInfo
            end
        end
        
        return currInfo
    end
    
    -- Convert to formatted objects using helper
    local todayCurrenciesFormatted = FormatCurrencyData(todayCurrencies, GetCurrencyInfoWithFallback, false)
    local todayIncomeFormatted = FormatCurrencyData(todayIncome, GetCurrencyInfoWithFallback, false)
    local todayExpenseFormatted = FormatCurrencyData(todayExpense, GetCurrencyInfoWithFallback, true)
    
    local weekCurrenciesFormatted = FormatCurrencyData(weekCurrencies, GetCurrencyInfoWithFallback, false)
    local weekIncomeFormatted = FormatCurrencyData(weekIncome, GetCurrencyInfoWithFallback, false)
    local weekExpenseFormatted = FormatCurrencyData(weekExpense, GetCurrencyInfoWithFallback, true)
    
    local monthCurrenciesFormatted = FormatCurrencyData(monthCurrencies, GetCurrencyInfoWithFallback, false)
    local monthIncomeFormatted = FormatCurrencyData(monthIncome, GetCurrencyInfoWithFallback, false)
    local monthExpenseFormatted = FormatCurrencyData(monthExpense, GetCurrencyInfoWithFallback, true)
    
    -- Create income-only and expense-only versions for session (calculated from balance)
    local sessionIncome = {}
    local sessionExpense = {}
    for currencyID, data in pairs(sessionCurrencies) do
        if data.change > 0 then
            sessionIncome[currencyID] = data
        elseif data.change < 0 then
            sessionExpense[currencyID] = data
        end
    end
    
    return sessionCurrencies, todayCurrenciesFormatted, weekCurrenciesFormatted, monthCurrenciesFormatted, currentCurrencies,
           sessionIncome, sessionExpense, todayIncomeFormatted, todayExpenseFormatted, weekIncomeFormatted, weekExpenseFormatted, monthIncomeFormatted, monthExpenseFormatted
end

-- Calculate earnings for all characters combined
local function CalculateEarningsAllCharacters()
    local totalSessionCurrencies = {}
    local totalTodayCurrencies = {}
    local totalWeekCurrencies = {}
    local totalMonthCurrencies = {}
    local totalSessionIncome = {}
    local totalSessionExpense = {}
    local totalTodayIncome = {}
    local totalTodayExpense = {}
    local totalWeekIncome = {}
    local totalWeekExpense = {}
    local totalMonthIncome = {}
    local totalMonthExpense = {}
    
    -- Iterate through all characters
    for charName, charData in pairs(GoldLogDB.characters) do
        local sessionCurrencies, todayCurrencies, weekCurrencies, monthCurrencies, currentCurrencies,
              sessionIncome, sessionExpense, todayIncome, todayExpense, weekIncome, weekExpense, monthIncome, monthExpense = 
              CalculateEarningsForCharacter(charData, charName)
        
        -- Sum up all data using helper function
        SumCurrencyData(totalSessionCurrencies, sessionCurrencies)
        SumCurrencyData(totalTodayCurrencies, todayCurrencies)
        SumCurrencyData(totalWeekCurrencies, weekCurrencies)
        SumCurrencyData(totalMonthCurrencies, monthCurrencies)
        SumCurrencyData(totalSessionIncome, sessionIncome)
        SumCurrencyData(totalSessionExpense, sessionExpense)
        SumCurrencyData(totalTodayIncome, todayIncome)
        SumCurrencyData(totalTodayExpense, todayExpense)
        SumCurrencyData(totalWeekIncome, weekIncome)
        SumCurrencyData(totalWeekExpense, weekExpense)
        SumCurrencyData(totalMonthIncome, monthIncome)
        SumCurrencyData(totalMonthExpense, monthExpense)
    end
    
    -- Get current currencies for the active player (for display purposes)
    local currentCurrencies = GetAllCurrencies()
    
    return totalSessionCurrencies, totalTodayCurrencies, totalWeekCurrencies, totalMonthCurrencies, currentCurrencies,
           totalSessionIncome, totalSessionExpense, totalTodayIncome, totalTodayExpense, 
           totalWeekIncome, totalWeekExpense, totalMonthIncome, totalMonthExpense
end

-- Wrapper function for backward compatibility (returns data for current player only)
local function CalculateEarnings(playerName)
    local charData = GoldLogDB.characters[playerName]
    return CalculateEarningsForCharacter(charData, playerName)
end

-- Create the display frame
local function CreateDisplayFrame()
    frame = CreateFrame("Frame", "GoldLogFrame", UIParent, "BackdropTemplate")
    frame:SetSize(1100, 450)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    
    -- Backdrop (Classic WoW style)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
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
    
    -- Title (Classic gold color)
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetTextColor(1, 0.82, 0) -- Classic WoW gold
    title:SetText(L["ADDON_NAME"])
    
    -- Tab buttons (Classic WoW style)
    local function CreateTabButton(text, tabValue, xOffset)
        local tab = CreateFrame("Button", nil, frame, "BackdropTemplate")
        tab:SetSize(120, 28)
        tab:SetPoint("TOPLEFT", 20 + xOffset, -42)
        
        tab:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        tab:SetBackdropColor(0.18, 0.12, 0.06, 1)
        tab:SetBackdropBorderColor(0.5, 0.4, 0.2, 1)
        
        local tabText = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tabText:SetPoint("CENTER")
        tabText:SetTextColor(0.9, 0.8, 0.5)
        tabText:SetText(text)
        tab.text = tabText
        
        tab:SetScript("OnClick", function()
            activeTab = tabValue
            UpdateDisplay()
        end)
        
        tab:SetScript("OnEnter", function(self)
            if activeTab ~= tabValue then
                self:SetBackdropColor(0.25, 0.18, 0.10, 1)
                self.text:SetTextColor(1, 0.82, 0)
            end
        end)
        
        tab:SetScript("OnLeave", function(self)
            if activeTab ~= tabValue then
                self:SetBackdropColor(0.18, 0.12, 0.06, 1)
                self.text:SetTextColor(0.9, 0.8, 0.5)
            end
        end)
        
        return tab
    end
    
    -- Create tabs using configuration
    local tabConfigs = {
        {key = "TAB_BALANCE", value = "balance", offset = 0, name = "balanceTab"},
        {key = "TAB_INCOME", value = "income", offset = 130, name = "incomeTab"},
        {key = "TAB_EXPENSE", value = "expense", offset = 260, name = "expenseTab"}
    }
    
    for _, config in ipairs(tabConfigs) do
        frame[config.name] = CreateTabButton(L[config.key], config.value, config.offset)
    end
    
    -- Currency section separator
    local currencySeparator = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    currencySeparator:SetPoint("TOPLEFT", 20, -75)
    currencySeparator:SetText("|cffFFD700" .. L["CURRENCIES"] .. ":|r")
    frame.currencySeparator = currencySeparator
    
    -- Table headers (Classic WoW style)
    local headerBg = frame:CreateTexture(nil, "BACKGROUND")
    headerBg:SetPoint("TOPLEFT", 20, -93)
    headerBg:SetSize(1050, 22)
    headerBg:SetColorTexture(HEADER_BG_COLOR_R, HEADER_BG_COLOR_G, HEADER_BG_COLOR_B, HEADER_BG_ALPHA)
    
    -- Header border
    local headerBorder = frame:CreateTexture(nil, "BORDER")
    headerBorder:SetPoint("TOPLEFT", 20, -93)
    headerBorder:SetSize(1050, 1)
    headerBorder:SetColorTexture(0.5, 0.4, 0.2, 1)
    
    local headerBorderBottom = frame:CreateTexture(nil, "BORDER")
    headerBorderBottom:SetPoint("TOPLEFT", 20, -115)
    headerBorderBottom:SetSize(1050, 1)
    headerBorderBottom:SetColorTexture(0.5, 0.4, 0.2, 1)
    
    local nameHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameHeader:SetPoint("TOPLEFT", 25, -96)
    nameHeader:SetTextColor(1, 0.82, 0) -- Gold
    nameHeader:SetText(L["HEADER_NAME"])
    
    local sessionHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sessionHeader:SetPoint("TOPLEFT", 520, -96)
    sessionHeader:SetTextColor(1, 0.82, 0)
    sessionHeader:SetText(L["HEADER_SESSION"])
    
    local todayHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    todayHeader:SetPoint("TOPLEFT", 700, -96)
    todayHeader:SetTextColor(1, 0.82, 0)
    todayHeader:SetText(L["HEADER_TODAY"])
    
    local weekHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    weekHeader:SetPoint("TOPLEFT", 860, -96)
    weekHeader:SetTextColor(1, 0.82, 0)
    weekHeader:SetText(L["HEADER_WEEK"])
    
    local monthHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    monthHeader:SetPoint("TOPLEFT", 1000, -96)
    monthHeader:SetTextColor(1, 0.82, 0)
    monthHeader:SetText(L["HEADER_MONTH"])
    
    -- Currency scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 20, -118)
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

-- Helper: Get icon for currency from multiple sources
local function GetCurrencyIcon(currencyID, currentCurrencies, displayData)
    -- Try current currencies first
    if currentCurrencies[currencyID] and currentCurrencies[currencyID].iconFileID then
        return currentCurrencies[currencyID].iconFileID
    end
    
    -- Try display data sources
    for _, data in ipairs(displayData) do
        if data[currencyID] and data[currencyID].iconFileID and data[currencyID].iconFileID ~= 134400 then
            return data[currencyID].iconFileID
        end
    end
    
    -- Check all characters' cached data
    for charName, charData in pairs(GoldLogDB.characters) do
        if charData.currencyData and charData.currencyData[currencyID] and charData.currencyData[currencyID].iconFileID then
            return charData.currencyData[currencyID].iconFileID
        end
    end
    
    -- Last resort: API call or fallback
    if currencyID == 0 then
        return 133784 -- Gold icon
    else
        local apiInfo = C_CurrencyInfo.GetCurrencyInfo(currencyID)
        if apiInfo and apiInfo.iconFileID then
            return apiInfo.iconFileID
        end
    end
    
    return 134400 -- Fallback icon
end

-- Update display
UpdateDisplay = function()
    if not frame or not frame:IsVisible() then
        return
    end
    
    -- Update tab button appearance using loop
    local tabs = {
        {frame = frame.balanceTab, value = "balance"},
        {frame = frame.incomeTab, value = "income"},
        {frame = frame.expenseTab, value = "expense"}
    }
    
    for _, tab in ipairs(tabs) do
        if tab.frame then
            if activeTab == tab.value then
                tab.frame:SetBackdropColor(0.35, 0.25, 0.12, 1)
                tab.frame:SetBackdropBorderColor(1, 0.82, 0, 1)
                tab.frame.text:SetTextColor(1, 0.82, 0)
            else
                tab.frame:SetBackdropColor(0.18, 0.12, 0.06, 1)
                tab.frame:SetBackdropBorderColor(0.5, 0.4, 0.2, 1)
                tab.frame.text:SetTextColor(0.9, 0.8, 0.5)
            end
        end
    end
    
    -- Update separator text based on active tab
    if frame.currencySeparator then
        if activeTab == "balance" then
            frame.currencySeparator:SetText("|cffFFD700" .. L["CURRENCIES_BALANCE"] .. ":|r")
        elseif activeTab == "income" then
            frame.currencySeparator:SetText("|cff00FF00" .. L["CURRENCIES_INCOME"] .. ":|r")
        elseif activeTab == "expense" then
            frame.currencySeparator:SetText("|cffFF0000" .. L["CURRENCIES_EXPENSE"] .. ":|r")
        end
    end
    
    -- Use combined data from all characters
    local sessionCurrencies, todayCurrencies, weekCurrencies, monthCurrencies, currentCurrencies,
          sessionIncome, sessionExpense, todayIncome, todayExpense, weekIncome, weekExpense, monthIncome, monthExpense = CalculateEarningsAllCharacters()
    
    -- Select the correct data set based on active tab
    local displaySession, displayToday, displayWeek, displayMonth
    if activeTab == "income" then
        displaySession = sessionIncome
        displayToday = todayIncome
        displayWeek = weekIncome
        displayMonth = monthIncome
    elseif activeTab == "expense" then
        displaySession = sessionExpense
        displayToday = todayExpense
        displayWeek = weekExpense
        displayMonth = monthExpense
    else -- balance
        displaySession = sessionCurrencies
        displayToday = todayCurrencies
        displayWeek = weekCurrencies
        displayMonth = monthCurrencies
    end
    
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
    local groupedCurrencies = GroupCurrenciesByExpansion(displayToday)
    
    -- Expansion display order (Gold first)
    local expansionOrder = {
        "Gold",
        "Midnight",
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
        for currencyID, data in pairs(displaySession) do
            if GetCurrencyExpansion(currencyID) == expansion then
                -- In balance tab, only show if there's a change
                if activeTab ~= "balance" or (data.change and data.change ~= 0) then
                    allExpCurrencies[currencyID] = true
                end
            end
        end
        for currencyID, data in pairs(displayToday) do
            if GetCurrencyExpansion(currencyID) == expansion then
                -- In balance tab, only show if there's a change
                if activeTab ~= "balance" or (data.change and data.change ~= 0) then
                    allExpCurrencies[currencyID] = true
                end
            end
        end
        for currencyID, data in pairs(displayWeek) do
            if GetCurrencyExpansion(currencyID) == expansion then
                -- In balance tab, only show if there's a change
                if activeTab ~= "balance" or (data.change and data.change ~= 0) then
                    allExpCurrencies[currencyID] = true
                end
            end
        end
        for currencyID, data in pairs(displayMonth) do
            if GetCurrencyExpansion(currencyID) == expansion then
                -- In balance tab, only show if there's a change
                if activeTab ~= "balance" or (data.change and data.change ~= 0) then
                    allExpCurrencies[currencyID] = true
                end
            end
        end
        
        local hasAny = false
        for _ in pairs(allExpCurrencies) do
            hasAny = true
            break
        end
        
        if hasAny then
            -- Create or reuse header button
            if not frame.currencyLines[lineNum] or not frame.currencyLines[lineNum].text then
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
                    local sessionData = displaySession[currencyID]
                    local todayData = displayToday[currencyID]
                    
                    -- Calculate total change magnitude for sorting
                    local maxChange = 0
                    if sessionData then maxChange = math.max(maxChange, math.abs(sessionData.change)) end
                    if todayData then maxChange = math.max(maxChange, math.abs(todayData.change)) end
                    if displayWeek[currencyID] and displayWeek[currencyID].change then 
                        maxChange = math.max(maxChange, math.abs(displayWeek[currencyID].change)) 
                    end
                    if displayMonth[currencyID] and displayMonth[currencyID].change then 
                        maxChange = math.max(maxChange, math.abs(displayMonth[currencyID].change)) 
                    end
                    
                    -- Try to get name from all available sources
                    local name = (sessionData and sessionData.name) or 
                                 (todayData and todayData.name) or 
                                 (displayWeek[currencyID] and displayWeek[currencyID].name) or
                                 (displayMonth[currencyID] and displayMonth[currencyID].name)
                    
                    -- If still not found, try to get from API directly
                    if not name or name:match("^Currency %d+$") then
                        if currencyID == 0 then
                            name = "Gold"
                        else
                            local apiInfo = C_CurrencyInfo.GetCurrencyInfo(currencyID)
                            if apiInfo and apiInfo.name then
                                name = apiInfo.name
                            else
                                name = "Currency " .. currencyID
                            end
                        end
                    end
                    
                    -- Try to get icon from multiple sources using helper
                    local iconFileID = GetCurrencyIcon(currencyID, currentCurrencies, {
                        displaySession, displayToday, displayWeek, displayMonth
                    })
                    
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
                    if not frame.currencyLines[lineNum] or not frame.currencyLines[lineNum].nameText then
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
                    rowFrame.nameText:SetText("|T" .. currEntry.iconFileID .. ":16:16:0:0:64:64:4:60:4:60|t " .. currEntry.name)
                    
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
                    local sessionVal = displaySession[currencyID] and displaySession[currencyID].change or 0
                    rowFrame.sessionText:SetText(FormatCurrencyValue(sessionVal, currencyID))
                    
                    -- Today
                    local todayVal = displayToday[currencyID] and displayToday[currencyID].change or 0
                    rowFrame.todayText:SetText(FormatCurrencyValue(todayVal, currencyID))
                    
                    -- Week
                    local weekVal = displayWeek[currencyID] and displayWeek[currencyID].change or 0
                    rowFrame.weekText:SetText(FormatCurrencyValue(weekVal, currencyID))
                    
                    -- Month
                    local monthVal = displayMonth[currencyID] and displayMonth[currencyID].change or 0
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
        print("|cffff0000GoldLog:|r " .. L["LDB_NOT_FOUND"])
        return
    end
    
    dataObject = LDB:NewDataObject("GoldLog", {
        type = "data source",
        text = L["ADDON_NAME"],
        icon = "Interface\\Icons\\INV_Misc_Coin_01",
        label = L["ADDON_NAME"],
        
        OnClick = function(clickedframe, button)
            if button == "LeftButton" then
                ToggleFrame()
            elseif button == "RightButton" then
                -- Reset session only with confirmation
                StaticPopupDialogs["GOLDLOG_SESSION_RESET"] = {
                    text = L["SESSION_RESET_CONFIRM"],
                    button1 = YES,
                    button2 = NO,
                    OnAccept = function()
                        local playerName = UnitName("player") .. "-" .. GetRealmName()
                        if GoldLogDB.characters and GoldLogDB.characters[playerName] then
                            -- Reset session start to current values
                            local currentCurrencies = GetAllCurrencies()
                            local charData = GoldLogDB.characters[playerName]
                            if not charData.sessionStart then
                                charData.sessionStart = {}
                            end
                            for currencyID, data in pairs(currentCurrencies) do
                                charData.sessionStart[currencyID] = data.quantity
                            end
                            charData.sessionStartTime = time()
                            print("|cff00ff00GoldLog:|r " .. L["SESSION_RESET"])
                            UpdateDisplay()
                        end
                    end,
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = true,
                    preferredIndex = 3,
                }
                StaticPopup_Show("GOLDLOG_SESSION_RESET")
            end
        end,
        
        OnTooltipShow = function(tooltip)
            tooltip:SetText("|cff00ff00" .. L["ADDON_NAME"] .. "|r", 1, 1, 1)
            tooltip:AddLine(" ")
            
            if not GoldLogDB.characters or not next(GoldLogDB.characters) then
                tooltip:AddLine(L["NO_DATA"])
                tooltip:Show()
                return
            end
            
            local sessionCurrencies, todayCurrencies, weekCurrencies, monthCurrencies = CalculateEarningsAllCharacters()
            
            -- Show Gold first
            local goldSession = sessionCurrencies[0]
            local goldToday = todayCurrencies[0]
            local goldWeek = weekCurrencies[0]
            local goldMonth = monthCurrencies[0]
            
            if goldSession then
                local sessionColor = goldSession.change >= 0 and "|cff00ff00" or "|cffff0000"
                tooltip:AddDoubleLine(L["SESSION"] .. ":", sessionColor .. FormatGold(goldSession.change) .. "|r")
            end
            
            if goldToday then
                local todayColor = goldToday.change >= 0 and "|cff00ff00" or "|cffff0000"
                tooltip:AddDoubleLine(L["TODAY"] .. ":", todayColor .. FormatGold(goldToday.change) .. "|r")
            end
            
            if goldWeek then
                local weekColor = goldWeek.change >= 0 and "|cff00ff00" or "|cffff0000"
                tooltip:AddDoubleLine(L["THIS_WEEK"] .. ":", weekColor .. FormatGold(goldWeek.change) .. "|r")
            end
            
            if goldMonth then
                local monthColor = goldMonth.change >= 0 and "|cff00ff00" or "|cffff0000"
                tooltip:AddDoubleLine(L["THIS_MONTH"] .. ":", monthColor .. FormatGold(goldMonth.change) .. "|r")
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
                tooltip:AddLine("|cffFFD700" .. L["CURRENCIES"] .. ":|r")
                for i = 1, math.min(5, #sortedCurrencies) do
                    local data = sortedCurrencies[i]
                    local color = data.change >= 0 and "|cff00ff00" or "|cffff0000"
                    local changeText = (data.change >= 0 and "+" or "") .. FormatNumber(data.change)
                    tooltip:AddDoubleLine(data.name, color .. changeText .. "|r")
                end
                if #sortedCurrencies > 5 then
                    tooltip:AddLine(string.format("|cff888888" .. L["AND_MORE"] .. "|r", #sortedCurrencies - 5))
                end
            end
            
            tooltip:AddLine(" ")
            tooltip:AddLine("|cffFFFFFF" .. L["TOOLTIP_LEFT_CLICK"] .. ":|r " .. L["TOOLTIP_OPEN_WINDOW"], 0.8, 0.8, 0.8)
            tooltip:AddLine("|cffFFFFFF" .. L["TOOLTIP_RIGHT_CLICK"] .. ":|r " .. L["TOOLTIP_RESET_DATA"], 0.8, 0.8, 0.8)
            
            tooltip:Show()
        end,
    })
end

-- Update DataBroker text
local function UpdateDataBrokerText()
    if not dataObject then return end
    
    if not GoldLogDB.characters or not next(GoldLogDB.characters) then
        dataObject.text = L["ADDON_NAME"]
        return
    end
    
    local sessionCurrencies = CalculateEarningsAllCharacters()
    local goldData = sessionCurrencies[0]
    if goldData then
        local color = goldData.change >= 0 and "|cff00ff00" or "|cffff0000"
        dataObject.text = L["GOLD"] .. ": " .. color .. FormatGold(goldData.change) .. "|r"
    else
        dataObject.text = L["ADDON_NAME"]
    end
end

-- Event handler
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
eventFrame:RegisterEvent("PLAYER_LOGOUT")

-- Transaction context events
eventFrame:RegisterEvent("MERCHANT_SHOW")
eventFrame:RegisterEvent("MERCHANT_CLOSED")
eventFrame:RegisterEvent("MAIL_SHOW")
eventFrame:RegisterEvent("MAIL_CLOSED")
eventFrame:RegisterEvent("MAIL_SEND_SUCCESS")
eventFrame:RegisterEvent("TRADE_SHOW")
eventFrame:RegisterEvent("TRADE_CLOSED")
eventFrame:RegisterEvent("QUEST_TURNED_IN")
eventFrame:RegisterEvent("QUEST_COMPLETE")
eventFrame:RegisterEvent("LOOT_OPENED")
eventFrame:RegisterEvent("LOOT_CLOSED")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
eventFrame:RegisterEvent("GUILDBANKFRAME_OPENED")
eventFrame:RegisterEvent("GUILDBANKFRAME_CLOSED")

eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        -- Initialize database
        local playerName = InitializeDB()
        -- Create DataBroker object
        CreateDataBroker()
        print("|cff00ff00GoldLog|r " .. L["LOADED"])
        if LDB then
            print("|cff00ff00GoldLog:|r " .. L["LDB_FOUND"])
        end
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isLogin = arg1
        local isReload = arg2
        
        -- Ensure database is initialized
        if not GoldLogDB.characters then
            GoldLogDB.characters = {}
        end
        
        local playerName = UnitName("player") .. "-" .. GetRealmName()
        
        -- Initialize player name if needed
        playerName = InitializeDB()
        
        local charData = GoldLogDB.characters[playerName]
        local allCurrencies = GetAllCurrencies()
        
        -- Only reset session on actual login, not on reload or zone change
        if isLogin then
            -- Initialize session currencies (including Gold as ID 0)
            if not charData.sessionStart then
                charData.sessionStart = {}
            end
            for currencyID, data in pairs(allCurrencies) do
                charData.sessionStart[currencyID] = data.quantity
            end
            charData.sessionStartTime = time()
        else
            -- On reload, ensure sessionStart is initialized if it doesn't exist
            if not charData.sessionStart or next(charData.sessionStart) == nil then
                charData.sessionStart = {}
                for currencyID, data in pairs(allCurrencies) do
                    charData.sessionStart[currencyID] = data.quantity
                end
                charData.sessionStartTime = time()
            end
        end
        
        -- Also initialize charData currencies if not already done
        if not charData.currencies then
            charData.currencies = {}
        end
        if not charData.currencyData then
            charData.currencyData = {}
        end
        for currencyID, data in pairs(allCurrencies) do
            if not charData.currencies[currencyID] then
                charData.currencies[currencyID] = data.quantity
            end
            -- Always update currency icon data
            charData.currencyData[currencyID] = {
                name = data.name,
                iconFileID = data.iconFileID
            }
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
            UpdateBucketData(playerName, currencyChanges)
            UpdateDataBrokerText()
        end
        
        UpdateDisplay()
        
    elseif event == "PLAYER_LOGOUT" then
        -- All currency values are already saved in charData.currencies
        -- No additional action needed
        
    -- Transaction context events
    elseif event == "MERCHANT_SHOW" then
        SetTransactionContext("MERCHANT")
    elseif event == "MERCHANT_CLOSED" then
        ClearTransactionContext()
    elseif event == "MAIL_SHOW" then
        SetTransactionContext("MAIL")
    elseif event == "MAIL_CLOSED" then
        ClearTransactionContext()
    elseif event == "MAIL_SEND_SUCCESS" then
        SetTransactionContext("MAIL")
    elseif event == "TRADE_SHOW" then
        SetTransactionContext("TRADE")
    elseif event == "TRADE_CLOSED" then
        ClearTransactionContext()
    elseif event == "QUEST_TURNED_IN" or event == "QUEST_COMPLETE" then
        SetTransactionContext("QUEST")
    elseif event == "LOOT_OPENED" then
        SetTransactionContext("LOOT")
    elseif event == "LOOT_CLOSED" then
        ClearTransactionContext()
    elseif event == "AUCTION_HOUSE_SHOW" then
        SetTransactionContext("AUCTION")
    elseif event == "AUCTION_HOUSE_CLOSED" then
        ClearTransactionContext()
    elseif event == "GUILDBANKFRAME_OPENED" then
        SetTransactionContext("GUILD_BANK")
    elseif event == "GUILDBANKFRAME_CLOSED" then
        ClearTransactionContext()
    end
end)

-- Slash commands
SLASH_GOLDLOG1 = "/goldlog"
SLASH_GOLDLOG2 = "/gl"
SlashCmdList["GOLDLOG"] = function(msg)
    msg = string.lower(msg or "")
    
    if msg == "reset" then
        local playerName = UnitName("player") .. "-" .. GetRealmName()
        local charData = GoldLogDB.characters[playerName]
        
        -- Reset all buckets
        charData.todayBucket = CreateBucketStructure()
        charData.lastDayDate = GetDateString()
        charData.weekTotal = CreateBucketStructure()
        charData.lastWeeklyReset = GetLastWednesday()
        charData.monthTotal = CreateBucketStructure()
        charData.lastMonthlyReset = GetMonthString()
        charData.currencies = {}
        charData.currencyData = {}
        charData.sessionStart = {}
        charData.sessionStartTime = 0
        
        print("|cff00ff00GoldLog:|r " .. L["RESET_CONFIRM"])
        UpdateDisplay()
    elseif msg == "reload" or msg == "fix" then
        -- Manually create data broker if missing
        if not dataObject and LDB then
            CreateDataBroker()
            print("|cff00ff00GoldLog:|r " .. L["DB_CREATED"])
        elseif not LDB then
            print("|cffff0000GoldLog:|r " .. L["DB_NOT_AVAILABLE"])
        else
            print("|cff00ff00GoldLog:|r " .. L["DB_EXISTS"])
        end
        -- Ensure frame exists
        if not frame then
            CreateDisplayFrame()
            print("|cff00ff00GoldLog:|r " .. L["FRAME_CREATED"])
        end
    elseif msg == "status" or msg == "debug" or msg == "info" then
        print("|cff00ff00" .. L["STATUS_TITLE"] .. "|r")
        print(L["VERSION"] .. ": 1.0.0")
        print(L["PLAYER"] .. ": " .. UnitName("player") .. "-" .. GetRealmName())
        
        local sessionCurrencies, todayCurrencies, weekCurrencies, monthCurrencies, currentCurrencies = CalculateEarningsAllCharacters()
        
        -- Count total characters
        local charCount = 0
        for _ in pairs(GoldLogDB.characters) do
            charCount = charCount + 1
        end
        print("|cff00ff00Charaktere:|r " .. charCount)
        
        -- Show Gold (total across all characters)
        local goldSession = sessionCurrencies[0]
        local goldToday = todayCurrencies[0]
        local goldWeek = weekCurrencies[0]
        local goldMonth = monthCurrencies[0]
        
        print(L["CURRENT_GOLD"] .. ": " .. FormatGold(GetMoney()))
        if goldSession then
            print("|cff00ff00" .. L["SESSION"] .. ":|r " .. FormatGold(goldSession.change))
        end
        if goldToday then
            print("|cff00ff00" .. L["TODAY"] .. ":|r " .. FormatGold(goldToday.change))
        end
        if goldWeek then
            print("|cff00ff00" .. L["THIS_WEEK"] .. ":|r " .. FormatGold(goldWeek.change))
        end
        if goldMonth then
            print("|cff00ff00" .. L["THIS_MONTH"] .. ":|r " .. FormatGold(goldMonth.change))
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
        
        print("|cff00ff00" .. L["CURRENCIES_SESSION"] .. ":|r " .. sessionCount)
        print("|cff00ff00" .. L["CURRENCIES_TODAY"] .. ":|r " .. todayCount)
        
        -- Show all current currencies
        local currCount = 0
        for currencyID in pairs(currentCurrencies) do 
            if currencyID ~= 0 then currCount = currCount + 1 end
        end
        print("|cff00ff00" .. L["CURRENCIES_OWNED"] .. ":|r " .. currCount)
        
        if currCount > 0 then
            print("|cff888888" .. L["LIST"] .. ":|r")
            for currencyID, data in pairs(currentCurrencies) do
                if currencyID ~= 0 then
                    print("  - " .. data.name .. ": " .. data.quantity)
                end
            end
        end
        
        if LDB then
            print("|cff00ff00LibDataBroker:|r " .. L["FOUND"])
            if dataObject then
                print("|cff00ff00DataBroker Plugin:|r " .. L["ACTIVE"])
            else
                print("|cffff0000DataBroker Plugin:|r " .. L["NOT_CREATED"])
            end
        else
            print("|cffff0000LibDataBroker:|r " .. L["LDB_NOT_FOUND"])
        end
        
        if frame then
            print("|cff00ff00" .. L["MAIN_WINDOW"] .. ":|r " .. (frame:IsVisible() and L["VISIBLE"] or L["HIDDEN"]))
        else
            print("|cffff0000" .. L["MAIN_WINDOW"] .. ":|r " .. L["NOT_CREATED"])
        end
        
        local charData = GoldLogDB.characters[playerName]
        if charData then
            -- Show reset info
            local lastDay = charData.lastDayDate or L["NOT_INITIALIZED"]
            local lastWednesday = charData.lastWeeklyReset or L["NOT_INITIALIZED"]
            local lastMonth = charData.lastMonthlyReset or L["NOT_INITIALIZED"]
            
            print("|cff00ff00" .. L["DAILY_RESET"] .. ":|r " .. lastDay .. " (" .. L["EVERY_DAY"] .. ")")
            print("|cff00ff00" .. L["WEEKLY_RESET"] .. ":|r " .. lastWednesday .. " (" .. L["EVERY_WEDNESDAY"] .. ")")
            print("|cff00ff00" .. L["MONTHLY_RESET"] .. ":|r " .. lastMonth .. " (" .. L["EVERY_FIRST"] .. ")")
        end
        
    elseif msg == "help" then
        print("|cff00ff00" .. L["HELP_TITLE"] .. ":|r")
        print(L["HELP_TOGGLE"])
        print(L["HELP_STATUS"])
        print(L["HELP_RELOAD"])
        print(L["HELP_RESET"])
        print(L["HELP_HELP"])
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
