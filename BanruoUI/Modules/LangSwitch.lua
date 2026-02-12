-- Modules/LangSwitch.lua
-- v2.5 Step0: Language switch (ReloadUI). TOC-controlled.
-- v2.5.15: Default follows client locale; gear menu provides optional override (zhCN/enUS) or Auto (Follow System).

local B = BanruoUI
if not B then return end

-- Toggle override between zhCN/enUS, then reload.
-- (Kept for compatibility; menu uses explicit selections.)
function B:ToggleLangOverride()
  BanruoUIDB = BanruoUIDB or {}
  local cur = BanruoUIDB.langOverride or B.__activeLocale or ((type(GetLocale) == 'function' and GetLocale()) or 'enUS')
  local nextLoc = (cur == 'zhCN') and 'enUS' or 'zhCN'
  BanruoUIDB.langOverride = nextLoc
  ReloadUI()
end

local function setOverride(loc)
  BanruoUIDB = BanruoUIDB or {}
  if loc == nil then
    BanruoUIDB.langOverride = nil
  else
    BanruoUIDB.langOverride = loc
  end
  ReloadUI()
end

-- Show a tiny dropdown menu anchored to the gear button.
function B:ShowLangMenu(anchor)
  if not anchor then return end

  -- Ensure the locale table matches the latest SavedVariables override.
  if B and B.ApplyLocale then B:ApplyLocale() end

  local function initMenu(self, level)
    if level ~= 1 then return end

    local override = BanruoUIDB and BanruoUIDB.langOverride
    local gameLoc = (type(GetLocale) == 'function') and GetLocale() or 'enUS'

    -- Auto / Follow system
    UIDropDownMenu_AddButton({
      text = B:Loc('LANG_AUTO'),
      checked = (override == nil),
      func = function() setOverride(nil) end,
    }, level)

    UIDropDownMenu_AddButton({
      text = B:Loc('LANG_ZH'),
      checked = (override == 'zhCN') or (override == nil and gameLoc == 'zhCN'),
      func = function() setOverride('zhCN') end,
    }, level)

    UIDropDownMenu_AddButton({
      text = B:Loc('LANG_EN'),
      checked = (override == 'enUS') or (override == nil and gameLoc == 'enUS'),
      func = function() setOverride('enUS') end,
    }, level)
  end

  if not B.__langDD then
    local dd = CreateFrame('Frame', 'BanruoUI_LangDropDown', UIParent, 'UIDropDownMenuTemplate')
    dd.displayMode = 'MENU'
    B.__langDD = dd
  end
  -- Use Blizzard dropdown APIs directly (EasyMenu may be unavailable in some load orders)
  UIDropDownMenu_Initialize(B.__langDD, initMenu, 'MENU')
  ToggleDropDownMenu(1, nil, B.__langDD, anchor, 0, 0)
end
