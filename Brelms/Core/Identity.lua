-- Bre/Core/Identity.lua
-- Centralized identity / naming for future split builds (Bre_theme vs Brelms_full)

local addonName, Bre = ...
Bre = Bre or {}

Bre.Identity = Bre.Identity or {}
local I = Bre.Identity

-- Addon folder / toc name ("Bre" for theme edition, "Brelms" for full edition build)
I.addonName = addonName

-- Display name (used in chat prefix etc.)
I.displayName = addonName

-- SavedVariables name (keep stable per build)
-- NOTE: Theme edition uses BrelmsSaved.
-- Full edition build should use BrelmsSaved (set by its own toc).
I.savedVarName = "BrelmsSaved"

-- Root group namespace prefix for themes (BanruoUI contract)
I.themeRootPrefix = "BANRUOUI"

-- Export/Import magic header (string format namespace)
I.magic = "BRE"

function I:MakeThemeRootGroupName(themeId)
  themeId = tostring(themeId or "")
  return self.themeRootPrefix .. "[" .. themeId .. "]"
end
