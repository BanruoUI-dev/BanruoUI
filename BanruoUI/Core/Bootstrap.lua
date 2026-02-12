-- Core/Bootstrap.lua
-- API + Theme Registry (NO built-in themes)

local ADDON_NAME, ns = ...

BanruoUI = BanruoUI or {}
local B = BanruoUI

B.addonName = ADDON_NAME
B.ns = ns

B._themes = B._themes or {}          -- id -> themeTable
B._themeOrder = B._themeOrder or {}  -- ordered ids

local function normalizeId(id)
  if not id then return nil end
  id = tostring(id)
  id = id:gsub("%s+", "_")
  id = id:lower()
  return id
end

local function safeStr(v)
  if v == nil then return "" end
  return tostring(v)
end

local function shallowCopy(t)
  local out = {}
  if type(t) ~= "table" then return out end
  for k, v in pairs(t) do out[k] = v end
  return out
end

local function deepCopy(t, seen)
  if type(t) ~= "table" then return t end
  if not seen then seen = {} end
  if seen[t] then return seen[t] end
  local out = {}
  seen[t] = out
  for k, v in pairs(t) do
    out[deepCopy(k, seen)] = deepCopy(v, seen)
  end
  return out
end

local function deepMerge(dst, src)
  if type(dst) ~= "table" then dst = {} end
  if type(src) ~= "table" then return dst end
  for k, v in pairs(src) do
    if type(v) == "table" and type(dst[k]) == "table" then
      deepMerge(dst[k], v)
    else
      dst[k] = v
    end
  end
  return dst
end

-- PUBLIC API: RegisterTheme(themeTable)
-- Minimal:
--   id (string), title (string)
-- Recommended:
--   author, version, preview
--   defaults = { elements = { modelBody="...", modelBG="..." ... } }
--   elementOptions = { modelBody = { {id="a", title="A"}, ... }, modelBG = {...}, ... }
function B:RegisterTheme(theme)
  if type(theme) ~= "table" then return false, "theme not table" end

  local id = normalizeId(theme.id)
  if not id or id == "" then return false, "missing id" end

  local title = safeStr(theme.title)
  if title == "" then return false, "missing title" end

  theme.id = id
  theme.themeId = theme.themeId or id  -- compatibility: some code uses themeId

  -- Bre root groupName default: BANRUOUI[themeId]
  if type(theme.bre) == "table" then
    if not theme.bre.groupName or theme.bre.groupName == "" then
      theme.bre.groupName = "BANRUOUI[" .. id .. "]"
    end
  end

  theme.title = title
  theme.author = safeStr(theme.author)
  theme.version = safeStr(theme.version)
  theme.preview = safeStr(theme.preview)

  if type(theme.defaults) ~= "table" then theme.defaults = {} end
  if type(theme.defaults.elements) ~= "table" then theme.defaults.elements = {} end

  if type(theme.elementOptions) ~= "table" then theme.elementOptions = {} end

  local isNew = (B._themes[id] == nil)
  B._themes[id] = theme

  if isNew then
    table.insert(B._themeOrder, id)
  end

  if B.OnThemesChanged then
    pcall(B.OnThemesChanged, B)
  end

  return true
end

function B:GetThemeIds()
  local out = {}
  for i = 1, #B._themeOrder do out[i] = B._themeOrder[i] end
  return out
end

function B:GetTheme(id)
  id = normalizeId(id)
  if not id then return nil end
  return B._themes[id]
end

function B:GetThemes()
  local out = {}
  for i = 1, #B._themeOrder do
    local id = B._themeOrder[i]
    out[i] = B._themes[id]
  end
  return out
end

-- Merge order:
-- theme.defaults  <- saved overrides (SavedVariables) <- session draft (not persisted)
function B:GetMergedConfig(themeId, saved, draft)
  local theme = self:GetTheme(themeId)
  if not theme then return nil end

  local cfg = deepCopy(theme.defaults or {})
  deepMerge(cfg, saved or {})
  deepMerge(cfg, draft or {})
  if type(cfg.elements) ~= "table" then cfg.elements = {} end
  return cfg
end

-- Expose helpers for other files
B._normalizeId = normalizeId
B._deepCopy = deepCopy
B._deepMerge = deepMerge
B._shallowCopy = shallowCopy

function B:Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00BanruoUI:|r " .. safeStr(msg))
end
