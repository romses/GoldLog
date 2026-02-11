-- German (Germany) Localization

local ADDON_NAME = "GoldLog"
local L = LibStub("AceLocale-3.0"):NewLocale(ADDON_NAME, "deDE")
if not L then return end

-- Addon
L["ADDON_NAME"] = "Gold Log"
L["LOADED"] = "geladen. Benutze /goldlog oder /gl zum Anzeigen."
L["VERSION"] = "Version"

-- Tabs
L["TAB_BALANCE"] = "Saldo"
L["TAB_INCOME"] = "Einnahmen"
L["TAB_EXPENSE"] = "Ausgaben"

-- Headers
L["HEADER_NAME"] = "Name"
L["HEADER_SESSION"] = "Session"
L["HEADER_TODAY"] = "Heute"
L["HEADER_WEEK"] = "Woche"
L["HEADER_MONTH"] = "Monat"
L["HEADER_CATEGORY"] = "Kategorie"
L["HEADER_AMOUNT"] = "Betrag"
L["HEADER_PERCENT"] = "Prozent"

-- Currencies
L["CURRENCIES"] = "Währungen"
L["CURRENCIES_BALANCE"] = "Währungen - Saldo"
L["CURRENCIES_INCOME"] = "Währungen - Einnahmen"
L["CURRENCIES_EXPENSE"] = "Währungen - Ausgaben"
L["CURRENCIES_SESSION"] = "Währungen (Session)"
L["CURRENCIES_TODAY"] = "Währungen (Heute)"
L["CURRENCIES_OWNED"] = "Aktuell besessene Währungen"

-- LibDataBroker
L["LDB_FOUND"] = "LibDataBroker gefunden - Bazooka-Integration aktiv."
L["LDB_NOT_FOUND"] = "LibDataBroker nicht gefunden. Installiere Bazooka oder ein anderes LDB-Display-Addon."
L["DB_CREATED"] = "DataBroker erstellt."
L["DB_NOT_AVAILABLE"] = "LibDataBroker nicht verfügbar."
L["DB_EXISTS"] = "DataBroker existiert bereits."

-- Reset
L["RESET_CONFIRM"] = "Daten zurückgesetzt."
L["DATA_RESET"] = "Alle Daten zurückgesetzt!"
L["SESSION_RESET"] = "Session zurückgesetzt!"
L["SESSION_RESET_CONFIRM"] = "Möchtest du die Session-Daten wirklich zurücksetzen?"

-- Window
L["FRAME_CREATED"] = "Hauptfenster erstellt."
L["MAIN_WINDOW"] = "Hauptfenster"
L["VISIBLE"] = "Sichtbar"
L["HIDDEN"] = "Versteckt"
L["NOT_CREATED"] = "Nicht erstellt!"

-- Status
L["STATUS_TITLE"] = "=== GoldLog Status ==="
L["PLAYER"] = "Spieler"
L["CURRENT_GOLD"] = "Aktuelles Gold"
L["SESSION"] = "Session"
L["TODAY"] = "Heute"
L["THIS_WEEK"] = "Diese Woche"
L["THIS_MONTH"] = "Dieser Monat"
L["LIST"] = "Liste"
L["SAVED_DAYS"] = "Gespeicherte Tage"
L["ACTIVE_WEEKDAY_BUCKETS"] = "Aktive Wochentag-Buckets"
L["ACTIVE_MONTHDAY_BUCKETS"] = "Aktive Monatstag-Buckets"
L["MONTH_TOTAL"] = "Monatstotal"
L["NOT_INITIALIZED"] = "Nicht initialisiert"

-- Help
L["HELP_TITLE"] = "GoldLog Befehle"
L["HELP_TOGGLE"] = "/goldlog oder /gl - Zeigt/versteckt das Gold-Fenster"
L["HELP_STATUS"] = "/goldlog status - Zeigt Addon-Status und aktuelle Statistiken"
L["HELP_RELOAD"] = "/goldlog reload - Erstellt Minimap-Button und Fenster neu"
L["HELP_RESET"] = "/goldlog reset - Setzt alle Daten zurück"
L["HELP_HELP"] = "/goldlog help - Zeigt diese Hilfe"

-- Tooltip
L["TOOLTIP_LEFT_CLICK"] = "Linksklick"
L["TOOLTIP_RIGHT_CLICK"] = "Rechtsklick"
L["TOOLTIP_OPEN_WINDOW"] = "Fenster öffnen"
L["TOOLTIP_RESET_DATA"] = "Session zurücksetzen"

-- Misc
L["AND_MORE"] = "... und %d weitere"
L["NO_DATA"] = "Keine Daten verfügbar"
L["GOLD"] = "Gold"
L["FOUND"] = "Gefunden"
L["ACTIVE"] = "Aktiv"

-- Transaction Categories
L["CATEGORY_MERCHANT_BUY"] = "Händler (Kauf)"
L["CATEGORY_MERCHANT_SELL"] = "Händler (Verkauf)"
L["CATEGORY_REPAIR"] = "Reparaturen"
L["CATEGORY_MAIL_SEND"] = "Post (Gesendet)"
L["CATEGORY_MAIL_RECEIVE"] = "Post (Empfangen)"
L["CATEGORY_TRADE"] = "Handel"
L["CATEGORY_QUEST"] = "Quests"
L["CATEGORY_LOOT"] = "Beute"
L["CATEGORY_AUCTION_BUY"] = "Auktionshaus (Kauf)"
L["CATEGORY_AUCTION_SELL"] = "Auktionshaus (Verkauf)"
L["CATEGORY_GUILD_BANK"] = "Gildenbank"
L["CATEGORY_OTHER"] = "Sonstiges"
