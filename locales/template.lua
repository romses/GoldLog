-- Translation Template
-- Copy this file and rename it to your locale code (e.g., frFR.lua, esES.lua, etc.)
-- Translate the strings on the right side of the = sign
-- Uncomment the locale registration line at the top
-- Add your locale file to locales.xml

--[[
Supported WoW Locales:
- enUS (English US) - Default/Fallback
- enGB (English GB)
- deDE (German)
- frFR (French)
- esES (Spanish Spain)
- esMX (Spanish Mexico)
- ruRU (Russian)
- koKR (Korean)
- zhCN (Chinese Simplified)
- zhTW (Chinese Traditional)
- ptBR (Portuguese Brazil)
- itIT (Italian)
]]

--[[
local ADDON_NAME = "gold_log"
local L = LibStub("AceLocale-3.0"):NewLocale(ADDON_NAME, "YOUR_LOCALE_CODE")
if not L then return end

-- Addon
L["ADDON_NAME"] = "Gold Log"
L["LOADED"] = "loaded. Use /goldlog or /gl to display."
L["VERSION"] = "Version"

-- Tabs
L["TAB_BALANCE"] = "Balance"
L["TAB_INCOME"] = "Income"
L["TAB_EXPENSE"] = "Expenses"

-- Headers
L["HEADER_NAME"] = "Name"
L["HEADER_SESSION"] = "Session"
L["HEADER_TODAY"] = "Today"
L["HEADER_WEEK"] = "Week"
L["HEADER_MONTH"] = "Month"
L["HEADER_CATEGORY"] = "Category"
L["HEADER_AMOUNT"] = "Amount"
L["HEADER_PERCENT"] = "Percent"

-- Currencies
L["CURRENCIES"] = "Currencies"
L["CURRENCIES_BALANCE"] = "Currencies - Balance"
L["CURRENCIES_INCOME"] = "Currencies - Income"
L["CURRENCIES_EXPENSE"] = "Currencies - Expenses"
L["CURRENCIES_SESSION"] = "Currencies (Session)"
L["CURRENCIES_TODAY"] = "Currencies (Today)"
L["CURRENCIES_OWNED"] = "Currently owned currencies"

-- LibDataBroker
L["LDB_FOUND"] = "LibDataBroker found - Bazooka integration active."
L["LDB_NOT_FOUND"] = "LibDataBroker not found. Install Bazooka or another LDB display addon."
L["DB_CREATED"] = "DataBroker created."
L["DB_NOT_AVAILABLE"] = "LibDataBroker not available."
L["DB_EXISTS"] = "DataBroker already exists."

-- Reset
L["RESET_CONFIRM"] = "Data reset."
L["DATA_RESET"] = "All data reset!"
L["SESSION_RESET"] = "Session reset!"

-- Window
L["FRAME_CREATED"] = "Main window created."
L["MAIN_WINDOW"] = "Main Window"
L["VISIBLE"] = "Visible"
L["HIDDEN"] = "Hidden"
L["NOT_CREATED"] = "Not created!"

-- Status
L["STATUS_TITLE"] = "=== GoldLog Status ==="
L["PLAYER"] = "Player"
L["CURRENT_GOLD"] = "Current Gold"
L["SESSION"] = "Session"
L["TODAY"] = "Today"
L["THIS_WEEK"] = "This Week"
L["THIS_MONTH"] = "This Month"
L["LIST"] = "List"
L["SAVED_DAYS"] = "Saved Days"
L["ACTIVE_WEEKDAY_BUCKETS"] = "Active Weekday Buckets"
L["ACTIVE_MONTHDAY_BUCKETS"] = "Active Monthday Buckets"
L["MONTH_TOTAL"] = "Month Total"
L["NOT_INITIALIZED"] = "Not initialized"

-- Help
L["HELP_TITLE"] = "GoldLog Commands"
L["HELP_TOGGLE"] = "/goldlog or /gl - Shows/hides the gold window"
L["HELP_STATUS"] = "/goldlog status - Shows addon status and current statistics"
L["HELP_RELOAD"] = "/goldlog reload - Recreates minimap button and window"
L["HELP_RESET"] = "/goldlog reset - Resets all data"
L["HELP_HELP"] = "/goldlog help - Shows this help"

-- Tooltip
L["TOOLTIP_LEFT_CLICK"] = "Left click"
L["TOOLTIP_RIGHT_CLICK"] = "Right click"
L["TOOLTIP_OPEN_WINDOW"] = "Open window"
L["TOOLTIP_RESET_DATA"] = "Reset session"

-- Misc
L["AND_MORE"] = "... and %d more"
L["NO_DATA"] = "No data available"
L["GOLD"] = "Gold"
L["FOUND"] = "Found"
L["ACTIVE"] = "Active"

-- Transaction Categories
L["CATEGORY_MERCHANT_BUY"] = "Merchant (Buy)"
L["CATEGORY_MERCHANT_SELL"] = "Merchant (Sell)"
L["CATEGORY_REPAIR"] = "Repairs"
L["CATEGORY_MAIL_SEND"] = "Mail (Sent)"
L["CATEGORY_MAIL_RECEIVE"] = "Mail (Received)"
L["CATEGORY_TRADE"] = "Trade"
L["CATEGORY_QUEST"] = "Quests"
L["CATEGORY_LOOT"] = "Loot"
L["CATEGORY_AUCTION_BUY"] = "Auction House (Buy)"
L["CATEGORY_AUCTION_SELL"] = "Auction House (Sell)"
L["CATEGORY_GUILD_BANK"] = "Guild Bank"
L["CATEGORY_OTHER"] = "Other"
]]
