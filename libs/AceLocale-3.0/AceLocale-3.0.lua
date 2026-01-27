--- **AceLocale-3.0** manages localization in addons, allowing for multiple locale to be registered with fallback to the base locale for untranslated strings.
-- @class file
-- @name AceLocale-3.0
-- @release $Id: AceLocale-3.0.lua 1035 2011-07-09 03:20:13Z kaelten $
local MAJOR, MINOR = "AceLocale-3.0", 6

local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

-- Lua APIs
local assert, tostring, error = assert, tostring, error
local getmetatable, setmetatable, rawset, rawget = getmetatable, setmetatable, rawset, rawget

-- WoW APIs
local GetLocale = GetLocale

local GAME_LOCALE = GetLocale()

local function new()
	return {}
end

local function del(t)
	for k in pairs(t) do
		t[k] = nil
	end
end

-- This metatable is used on all tables returned from GetLocale
local readmeta = {
	__index = function(self, key) -- requesting totally unknown entries: fire off a nonbreaking error and return key
		rawset(self, key, key)		-- only need to see the warning once, really
		geterrorhandler()(MAJOR..": "..tostring(key).." not found")
		return key
	end
}

-- This metatable is used on all tables returned from GetLocale if the silent flag is true, it does not issue a warning on missing keys
local readmetasilent = {
	__index = function(self, key) -- requesting totally unknown entries: return key
		rawset(self, key, key)		-- only need to see the warning once, really
		return key
	end
}

-- Remember the locale table being registered right now (it gets set by :NewLocale())
-- NOTE: Do never try to register 2 locale tables at once and mix their definition.
local registering

-- Local proxy table metatable
local writeproxy = {
	__newindex = function(self, key, value)
		rawset(registering, key, value == true and key or value) -- assigning values: replace 'true' with key string
	end,
	__index = assertmeta.__index
}

-- Register a new locale (or extend an existing one) for the specified application.
-- :NewLocale will return a table you can fill your locale into, or nil if the locale isn't needed for the players
-- game locale.
-- @paramsig application, locale[, isDefault[, silent]]
-- @param application Unique name of addon / module
-- @param locale Name of the locale to register, e.g. "enUS", "deDE", etc.
-- @param isDefault If this is the default locale being registered (your addon is written in this language, generally enUS)
-- @param silent If true, the locale will not issue warnings for missing keys. Must be set on the first locale registered. If set to "raw", nils will be returned for unknown keys (no metatable used).
-- @return Locale Table to add localizations to, or nil if the current locale is not required.
-- @usage
-- -- enUS.lua
-- local L = LibStub("AceLocale-3.0"):NewLocale("TestLocale", "enUS", true)
-- L["string1"] = true
--
-- -- deDE.lua
-- local L = LibStub("AceLocale-3.0"):NewLocale("TestLocale", "deDE")
-- if not L then return end
-- L["string1"] = "Zeichenkette1"
function lib:NewLocale(application, locale, isDefault, silent)
	
	-- GAME_LOCALE allows the game's locale to be overridden in the library to allow for testing
	-- Note that this should only be used by localization tools to test strings
	local gameLocale = GAME_LOCALE
	
	-- Check if we need to create a new table
	local app = lib.apps[application]
	
	if silent and app and getmetatable(app) ~= readmetasilent then
		geterrorhandler()("Usage: NewLocale(application, locale[, isDefault[, silent]]): 'silent' must be specified for the first locale registered")
	end
	
	if not app then
		if silent=="raw" then
			app = {}
		else
			app = setmetatable({}, silent and readmetasilent or readmeta)
		end
		lib.apps[application] = app
		lib.appnames[app] = application
	end
	
	if locale ~= gameLocale and not isDefault then
		return -- nop, we don't need these translations
	end
	
	registering = app -- remember globally for writeproxy and writedefault
	
	if isDefault then
		lib.defaultLocale[application] = locale
	end
	
	return setmetatable({}, writeproxy)
end

-- Returns localizations for the current locale (or default locale if translations are missing).
-- Errors if nothing is registered (spank developer, not just a missing translation)
-- @paramsig application[, silent]
-- @param application Unique name of addon / module
-- @param silent If true, the locale is optional, silently return nil if it's not found (defaults to false, optional)
-- @return The locale table for the current language.
function lib:GetLocale(application, silent)
	if not silent and not lib.apps[application] then
		error("Usage: GetLocale(application[, silent]): 'application' - No locales registered for '"..tostring(application).."'", 2)
	end
	return lib.apps[application]
end

-- local debug helper
local function assertunregistered(t)
	if registering then
		geterrorhandler()("Attempt to use locale table outside of the NewLocale constructor")
	end
end

-- This metatable proxy is used when registering your defaults in your default locale.
-- Deprecated: Try to register in one locale table for best results.
local writedefault = {
	__newindex = function(self, key, value)
		assertunregistered()
		
		rawset(registering, key, value == true and key or value)
	end,
	__index = assertmeta.__index
}

-- These assertions make sure that the locale function is only called when actively registering a locale
local assertmeta = {
	__index = function(self,key) 
		assertunregistered()
		return nil
	end
}

lib.apps = lib.apps or {}
lib.appnames = lib.appnames or {}
lib.defaultLocale = lib.defaultLocale or {}
