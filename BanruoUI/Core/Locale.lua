-- Core/Locale.lua
-- v2.5 Step0: Locale framework (zhCN/enUS) + optional override in BanruoUIDB

local B = BanruoUI
if not B then return end

B.__locales = B.__locales or {}
B.L = B.L or {}

local function safeFormat(fmt, ...)
  if type(fmt) ~= "string" then return tostring(fmt) end
  local ok, out = pcall(string.format, fmt, ...)
  if ok then return out end
  return fmt
end

-- Public: translated string lookup.
-- If key is missing, return the key itself (helps spot missing translations).
function B:Loc(key, ...)
  local v = self.L and self.L[key]
  if v == nil then
    -- Fallback bridge for BrMusic locale keys, so BanruoUI modules can use B:Loc
    -- without duplicating BrMusic translations inside BanruoUI/Locales.
    local bm = _G.BrMusic
    local bv = bm and bm.L and bm.L[key]
    if bv ~= nil then
      if type(bv) == "function" then return bv(...) end
      if select('#', ...) > 0 then
        return safeFormat(bv, ...)
      end
      return bv
    end
    return tostring(key)
  end
  if select('#', ...) > 0 then
    return safeFormat(v, ...)
  end
  return v
end

-- Decide active locale: default follows client locale; if BanruoUIDB.langOverride is set,
-- it takes precedence ("zhCN" or "enUS").
function B:ApplyLocale()
  -- SavedVariables should be available by the time addon code runs, but we
  -- always read through _G to avoid any shadowing edge-cases.
  _G.BanruoUIDB = _G.BanruoUIDB or {}
  local override = _G.BanruoUIDB.langOverride
  local gameLoc = (type(GetLocale) == 'function') and GetLocale() or 'enUS'
  local loc = override or gameLoc
  if loc ~= 'zhCN' and loc ~= 'enUS' then loc = 'enUS' end

  local tbl = (self.__locales and self.__locales[loc]) or {}
  local fallback = (self.__locales and self.__locales['enUS']) or {}
  self.L = setmetatable(tbl, { __index = fallback })
  self.__activeLocale = loc
end

-- Apply immediately on load (safe: uses fallback if locales not loaded yet).
B:ApplyLocale()

-- Also apply once on ADDON_LOADED for this addon to guarantee that any
-- SavedVariables overrides are respected even if files load in an unexpected order.
do
  local f = CreateFrame('Frame')
  f:RegisterEvent('ADDON_LOADED')
  f:SetScript('OnEvent', function(_, _, name)
    if name ~= B.addonName then return end
    if B and B.ApplyLocale then B:ApplyLocale() end
  end)
end
