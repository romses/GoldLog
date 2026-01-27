# Gold Log - Localization

This directory contains all localization files for the Gold Log addon.

## Supported Locales

- **enUS.lua** - English (US) - Default/Fallback locale
- **deDE.lua** - German (Germany)

## Adding a New Translation

1. Copy `template.lua` to a new file named after your locale (e.g., `frFR.lua`, `esES.lua`)
2. Uncomment the code in the new file
3. Replace `YOUR_LOCALE_CODE` with the appropriate locale code
4. Translate all strings on the right side of the `=` sign
5. Add your new locale file to `locales.xml`
6. Test your translation in-game

## WoW Locale Codes

- `enUS` - English (United States)
- `enGB` - English (Great Britain)
- `deDE` - German (Germany)
- `frFR` - French (France)
- `esES` - Spanish (Spain)
- `esMX` - Spanish (Mexico)
- `ruRU` - Russian (Russia)
- `koKR` - Korean (Korea)
- `zhCN` - Chinese (Simplified)
- `zhTW` - Chinese (Traditional)
- `ptBR` - Portuguese (Brazil)
- `itIT` - Italian (Italy)

## Translation Guidelines

1. Keep formatting codes intact (e.g., `%d`, `%s`)
2. Maintain the same tone and style as the default locale
3. Test all strings in-game to ensure they fit in the UI
4. Use proper capitalization for your language
5. Keep strings concise but descriptive

## Fallback Behavior

If a string is not translated in your locale, the addon will automatically fall back to the English (enUS) translation. This means you can:
- Translate only some strings (partial translation)
- Leave technical terms in English if appropriate
- Update translations gradually over time

## Example: Adding French Translation

1. Copy `template.lua` to `frFR.lua`
2. Edit the file:
```lua
local ADDON_NAME = "gold_log"
local L = LibStub("AceLocale-3.0"):NewLocale(ADDON_NAME, "frFR")
if not L then return end

L["TAB_BALANCE"] = "Solde"
L["TAB_INCOME"] = "Revenus"
L["TAB_EXPENSE"] = "Dépenses"
-- ... continue with other translations
```
3. Add to `locales.xml`:
```xml
<Script file="frFR.lua"/>
```
4. Reload the addon and test

## Questions?

If you have questions about localization, please open an issue on the project repository.
