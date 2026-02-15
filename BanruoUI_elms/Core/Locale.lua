-- Bre/Core/Locale.lua
-- Simple localization bootstrap (zhCN/enUS). No external libs.
local addonName, Bre = ...
Bre = Bre or {}
Bre.Locales = Bre.Locales or {}

local function pickLocale()
  -- SavedVariables override: BreSaved.langOverride = "auto" | "zhCN" | "enUS"
  local ov = (_G.BreSaved and _G.BreSaved.langOverride) or nil
  if ov == "zhCN" or ov == "enUS" then
    return ov
  end

  local loc = (type(GetLocale) == "function" and GetLocale()) or "enUS"
  if Bre.Locales[loc] then return loc end
  if loc == "zhTW" and Bre.Locales.zhCN then return "zhCN" end
  return "enUS"
end

function Bre.SetLangOverride(val)
  _G.BreSaved = _G.BreSaved or {}
  if val == nil or val == "" or val == "auto" then
    _G.BreSaved.langOverride = "auto"
    return
  end
  if val == "zhCN" or val == "enUS" then
    _G.BreSaved.langOverride = val
  end
end

function Bre.GetLangOverride()
  return (_G.BreSaved and _G.BreSaved.langOverride) or "auto"
end

-- Step7.3: Make Bre.L dynamically query the dictionary
function Bre.L(key)
  -- Dynamically pick locale and dict every time
  local active = pickLocale()
  local dict = Bre.Locales[active] or Bre.Locales.enUS or {}
  
  local v = dict[key]
  if v ~= nil then return v end
  return tostring(key)
end

function Bre.GetLocaleKey()
  return pickLocale()
end
