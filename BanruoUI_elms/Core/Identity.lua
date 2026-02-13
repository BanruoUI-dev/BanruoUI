-- Bre/Core/Identity.lua
-- Centralized identity / naming for future split builds (Bre_theme vs Brelms_full)

local addonName, Bre = ...
Bre = Bre or {}

Bre.Identity = Bre.Identity or {}
local I = Bre.Identity

-- Addon folder / toc name ("Bre" for theme edition, "Brelms" for full edition build)
I.addonName = addonName

-- Display name (used in chat prefix etc.)
I.displayName = (addonName == "BanruoUI_elms") and "BanruoUI_elms" or addonName

-- SavedVariables name (keep stable per build)
-- NOTE: Theme edition uses BreSaved.
-- Full edition build should use BrelmsSaved (set by its own toc).
I.savedVarName = (addonName == "Brelms") and "BrelmsSaved" or "BreSaved"

-- Root group namespace prefix for themes (BanruoUI contract)
I.themeRootPrefix = "BANRUOUI"

-- Export/Import magic header (string format namespace)
I.magic = (addonName == "BanruoUI_elms") and "BRE" or "BRELMS"

function I:MakeThemeRootGroupName(themeId)
  themeId = tostring(themeId or "")
  return self.themeRootPrefix .. "[" .. themeId .. "]"
end
