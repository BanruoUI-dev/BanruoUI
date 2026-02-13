-- Bre/Core/Locale.lua
-- Simple localization bootstrap (zhCN/enUS). No external libs.
local addonName, Bre = ...
Bre = Bre or {}
Bre.Locales = Bre.Locales or {}

local function pickLocale()
  local loc = GetLocale and GetLocale() or "enUS"
  if Bre.Locales[loc] then return loc end
  if loc == "zhTW" and Bre.Locales.zhCN then return "zhCN" end
  return "enUS"
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
