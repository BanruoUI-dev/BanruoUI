-- Bre/Core/DrawerControls.lua
-- L1: DrawerControls - unified control factory for drawer templates.
-- Step2 (v2.14.69): factory methods for standard drawer controls.

--[[
  ✅ ARCH PRINCIPLE (Constitution Article 16: UI Specification)
  DrawerControls responsibilities:
  - Generate standard controls with enforced styling
  - All controls follow fixed width/height/spacing rules
  - No custom styling allowed outside this factory
  
  Control types:
  - Label (fixed font)
  - EditBox (fixed width/height)
  - Slider (fixed width)
  - Dropdown (fixed width)
  - Checkbox (fixed style)
  - ColorButton (fixed size)
  - Section divider (fixed style)
]]

local addonName, Bre = ...
Bre = Bre or {}

Bre.DrawerControls = Bre.DrawerControls or {
  version = "2.14.69",
}

local DC = Bre.DrawerControls

-- Get layout constants from DrawerTemplate
local function _GetLayout()
  return Bre.DrawerTemplate and Bre.DrawerTemplate.LAYOUT or {}
end

-- Step7.3: Simplified (debug removed, Locale.lua fixed)
local function _L(key)
  if Bre and Bre.L then
    return Bre.L(key)
  end
  return tostring(key)
end

-- ------------------------------------------------------------
-- Label Factory
-- ------------------------------------------------------------
function DC:MakeLabel(parent, textKey, x, y)
  local L = _GetLayout()
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("TOPLEFT", x or 0, y or 0)
  fs:SetTextColor(L.YELLOW_R or 1, L.YELLOW_G or 0.82, L.YELLOW_B or 0)
  fs:SetText(_L(textKey))
  return fs
end

-- ------------------------------------------------------------
-- Section Title Factory
-- ------------------------------------------------------------
function DC:MakeSectionTitle(parent, textKey, x, y)
  local L = _GetLayout()
  local fs = parent:CreateFontString(nil, "OVERLAY", L.SECTION_TITLE_FONT or "GameFontNormalLarge")
  fs:SetPoint("TOPLEFT", x or 16, y or 0)
  fs:SetTextColor(L.YELLOW_R or 1, L.YELLOW_G or 0.82, L.YELLOW_B or 0)
  fs:SetText(_L(textKey))
  return fs
end

-- ------------------------------------------------------------
-- Section Divider Factory
-- ------------------------------------------------------------
function DC:MakeSectionDivider(parent, y)
  local L = _GetLayout()
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(1, 1, 1, L.DIVIDER_ALPHA or 0.12)
  line:SetPoint("TOPLEFT", L.CONTENT_LEFT or 16, y or 0)
  line:SetPoint("TOPRIGHT", L.CONTENT_RIGHT or -16, y or 0)
  line:SetHeight(1)
  return line
end

-- ------------------------------------------------------------
-- EditBox Factory
-- ------------------------------------------------------------
function DC:MakeEditBox(parent, x, y, width)
  local L = _GetLayout()
  width = width or L.CONTROL_WIDTH or 150
  
  local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  eb:SetSize(width, 22)
  eb:SetAutoFocus(false)
  eb:SetFontObject(ChatFontNormal)
  eb:SetJustifyH("LEFT")
  if eb.SetTextInsets then eb:SetTextInsets(6, 6, 0, 0) end
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  eb:SetPoint("TOPLEFT", x or 0, y or 0)
  return eb
end

-- ------------------------------------------------------------
-- Numeric EditBox Factory (for slider companions)
-- ------------------------------------------------------------
function DC:MakeNumericBox(parent, x, y)
  local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  eb:SetSize(48, 20)
  eb:SetAutoFocus(false)
  eb:SetFontObject(ChatFontNormal)
  eb:SetJustifyH("CENTER")
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  eb:SetPoint("TOPLEFT", x or 0, y or 0)
  return eb
end

-- ------------------------------------------------------------
-- Slider Factory
-- ------------------------------------------------------------
function DC:MakeSlider(parent, x, y, width)
  local L = _GetLayout()
  width = width or L.CONTROL_WIDTH or 150
  
  local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
  slider:SetSize(width, 16)
  slider:SetMinMaxValues(0, 1)
  slider:SetValueStep(0.01)
  slider:SetObeyStepOnDrag(true)
  slider:SetPoint("TOPLEFT", x or 0, y or 0)
  
  -- Hide default labels (we use separate label + numeric box)
  if slider.Low then slider.Low:SetText("") end
  if slider.High then slider.High:SetText("") end
  if slider.Text then slider.Text:SetText("") end
  
  return slider
end

-- ------------------------------------------------------------
-- Dropdown Factory
-- ------------------------------------------------------------
function DC:MakeDropdown(parent, x, y, width)
  local L = _GetLayout()
  width = width or L.CONTROL_WIDTH or 150
  
  local dd = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
  UIDropDownMenu_SetWidth(dd, width)
  UIDropDownMenu_SetText(dd, "")
  dd:SetPoint("TOPLEFT", x or 0, y or 0)
  return dd
end

-- ------------------------------------------------------------
-- Pager + Input Factory (UI only; no wiring)
-- ------------------------------------------------------------
function DC:MakePagerInput(parent, x, y, width)
  local L = _GetLayout()
  width = width or L.CONTROL_WIDTH or 150

  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(width, 22)
  f:SetPoint("TOPLEFT", x or 0, y or 0)

  local btnSize = 22
  local pad = 4

  local prev = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  prev:SetSize(btnSize, btnSize)
  prev:SetPoint("LEFT", 0, 0)
  prev:SetText("<")

  local next = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  next:SetSize(btnSize, btnSize)
  next:SetPoint("RIGHT", 0, 0)
  next:SetText(">")

  local inputW = math.max(40, width - (btnSize * 2) - (pad * 2))
  local eb = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  eb:SetSize(inputW, 22)
  eb:SetAutoFocus(false)
  eb:SetFontObject(ChatFontNormal)
  eb:SetJustifyH("LEFT")
  if eb.SetTextInsets then eb:SetTextInsets(6, 6, 0, 0) end
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  eb:SetPoint("LEFT", prev, "RIGHT", pad, 0)
  eb:SetPoint("RIGHT", next, "LEFT", -pad, 0)

  f._prev = prev
  f._next = next
  f._editbox = eb
  f.SetText = function(self, txt) eb:SetText(txt or "") end
  f.GetText = function(self) return eb:GetText() end

  return f
end

-- ------------------------------------------------------------
-- Checkbox Factory
-- ------------------------------------------------------------
function DC:MakeCheckbox(parent, textKey, x, y)
  local L = _GetLayout()
  
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(24, 24)
  f:SetPoint("TOPLEFT", x or 0, y or 0)
  
  local chk = CreateFrame("CheckButton", nil, f, "InterfaceOptionsCheckButtonTemplate")
  chk:SetPoint("LEFT", 0, 0)
  chk:SetSize(24, 24)
  chk:SetHitRectInsets(0, -100, 0, 0) -- expand clickable area to include label
  
  local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("LEFT", chk, "RIGHT", 2, 0)
  label:SetTextColor(L.YELLOW_R or 1, L.YELLOW_G or 0.82, L.YELLOW_B or 0)
  label:SetText(_L(textKey))
  
  f._checkbox = chk
  f._label = label
  f.SetChecked = function(self, val) chk:SetChecked(val) end
  f.GetChecked = function(self) return chk:GetChecked() end
  
  return f
end

-- ------------------------------------------------------------
-- Color Button Factory (for color picker)
-- ------------------------------------------------------------
function DC:MakeColorButton(parent, x, y)
  local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
  btn:SetSize(36, 12)
  btn:SetPoint("TOPLEFT", x or 0, y or 0)
  
  -- Checker background
  local checker = btn:CreateTexture(nil, "BACKGROUND")
  checker:SetAllPoints()
  checker:SetTexture("Interface\\Buttons\\WHITE8X8")
  checker:SetTexCoord(0, 1, 0, 1)
  checker:SetAlpha(0.25)
  
  -- Color swatch
  local swatch = btn:CreateTexture(nil, "ARTWORK")
  swatch:SetAllPoints()
  swatch:SetColorTexture(1, 1, 1, 1)
  
  btn._checker = checker
  btn._swatch = swatch
  
  function btn:SetColor(r, g, b, a)
    swatch:SetColorTexture(r or 1, g or 1, b or 1, a or 1)
  end
  
  return btn
end

-- ------------------------------------------------------------
-- Texture Preview Factory (for CustomMat)
-- ------------------------------------------------------------
function DC:MakeTexturePreview(parent, x, y, size)
  local L = _GetLayout()
  size = size or 72
  
  local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  frame:SetSize(size, size)
  frame:SetPoint("TOPLEFT", x or 0, y or 0)
  frame:SetBackdrop({ edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1 })
  frame:SetBackdropBorderColor(L.YELLOW_R or 1, L.YELLOW_G or 0.82, L.YELLOW_B or 0, 0.55)
  frame:SetBackdropColor(0, 0, 0, 0.85)
  
  local tex = frame:CreateTexture(nil, "ARTWORK")
  tex:SetPoint("TOPLEFT", 2, -2)
  tex:SetPoint("BOTTOMRIGHT", -2, 2)
  tex:SetColorTexture(0, 0, 0, 0)
  
  frame._texture = tex
  
  return frame
end

-- ------------------------------------------------------------
-- Full-width EditBox Factory (spans entire drawer width)
-- ------------------------------------------------------------
function DC:MakeFullWidthEditBox(parent, x, y)
  local L = _GetLayout()
  
  -- Container frame to handle anchoring
  local container = CreateFrame("Frame", nil, parent)
  container:SetPoint("TOPLEFT", x or 18, y or 0)
  container:SetPoint("TOPRIGHT", -66, y or 0) -- leave room for scrollbar
  container:SetHeight(24)
  
  local eb = CreateFrame("EditBox", nil, container)
  eb:SetAutoFocus(false)
  eb:SetFontObject(ChatFontNormal)
  eb:SetPoint("LEFT", 6, 0)
  eb:SetPoint("RIGHT", -6, 0)
  eb:SetHeight(20)
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  
  -- Visual box background
  local box = CreateFrame("Frame", nil, container, "BackdropTemplate")
  box:SetAllPoints()
  box:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  box:SetBackdropColor(0, 0, 0, 0.5)
  box:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
  box:SetFrameLevel(container:GetFrameLevel())
  eb:SetFrameLevel(container:GetFrameLevel() + 1)
  
  container._editbox = eb
  container._box = box
  
  return container
end

-- ------------------------------------------------------------
-- Combo Input Factory (EditBox + Dropdown button)
-- Used in ProgressMat for material selection
-- ------------------------------------------------------------
function DC:MakeComboInput(parent, x, y, width)
  local L = _GetLayout()
  width = width or L.CONTROL_WIDTH or 150
  
  local container = CreateFrame("Frame", nil, parent)
  container:SetSize(width, 22)
  container:SetPoint("TOPLEFT", x or 0, y or 0)
  
  local eb = CreateFrame("EditBox", nil, container, "InputBoxTemplate")
  eb:SetSize(width - 22, 22)
  eb:SetAutoFocus(false)
  eb:SetFontObject(ChatFontNormal)
  eb:SetJustifyH("LEFT")
  if eb.SetTextInsets then eb:SetTextInsets(6, 6, 0, 0) end
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  eb:SetPoint("LEFT", 0, 0)
  
  local btn = CreateFrame("Button", nil, container, "UIPanelScrollDownButtonTemplate")
  btn:SetSize(18, 18)
  btn:ClearAllPoints()
  btn:SetPoint("RIGHT", -2, 0)
  
  container._editbox = eb
  container._button = btn
  container._options = {}
  
  function container:SetText(text)
    eb:SetText(text or "")
  end
  
  function container:GetText()
    return eb:GetText()
  end
  
  return container
end

return DC
