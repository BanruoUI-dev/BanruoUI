-- Modules/MinimapIcon.lua
-- Minimap shortcut button (launcher style, no external libs)
-- LeftClick: toggle main frame
-- RightClick: menu (show/hide, open)

local B = BanruoUI
if not B then return end

local ICON_TEX = "Interface\\AddOns\\BanruoUI\\Media\\Logo\\Logo64X64.tga"

local function ensureDB()
  _G.BanruoUIDB = _G.BanruoUIDB or {}
  _G.BanruoUIDB.minimap = _G.BanruoUIDB.minimap or {}
  local mm = _G.BanruoUIDB.minimap
  if mm.hide == nil then mm.hide = false end
  if type(mm.minimapPos) ~= "number" then mm.minimapPos = 220 end -- degrees
  return mm
end

local function clampAngle(a)
  if type(a) ~= "number" then return 0 end
  a = a % 360
  if a < 0 then a = a + 360 end
  return a
end

local function setButtonPos(btn, deg)
  if not btn or not _G.Minimap then return end
  deg = clampAngle(deg)
  local rad = deg * math.pi / 180

  -- dynamic radius: follow minimap size (and button size) automatically
  local mmW, mmH = _G.Minimap:GetSize()
  local mmR = math.min(mmW or 0, mmH or 0) * 0.5

  local bW, bH = btn:GetSize()
  local bR = math.min(bW or 0, bH or 0) * 0.5

  -- gap: distance between minimap rim and button rim (can be negative for tighter fit)
  local gap = -15
  local r = mmR + bR + gap

  local x = math.cos(rad) * r
  local y = math.sin(rad) * r

  btn:ClearAllPoints()
  btn:SetPoint("CENTER", _G.Minimap, "CENTER", x, y)
end

local function calcAngleFromCursor()
  if not _G.Minimap then return 0 end
  local x, y = GetCursorPosition()
  local scale = _G.Minimap:GetEffectiveScale() or 1
  x = x / scale
  y = y / scale

  local mx, my = _G.Minimap:GetCenter()
  if not mx or not my then return 0 end

  local dx = x - mx
  local dy = y - my
  local a = math.deg(math.atan2(dy, dx))
  return clampAngle(a)
end

local function ensureMinimapSizeHook()
  if B._minimapSizeHooked then return end
  if not _G.Minimap then return end
  _G.Minimap:HookScript("OnSizeChanged", function()
    local mm = ensureDB()
    if B.minimapButton then
      setButtonPos(B.minimapButton, mm.minimapPos)
    end
  end)
  B._minimapSizeHooked = true
end


local function showTip(btn)
  if not _G.GameTooltip then return end
  _G.GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
  _G.GameTooltip:SetText((B.Loc and B:Loc("MINIMAP_TOOLTIP")) or "BanruoUI")
  _G.GameTooltip:Show()
end

local function hideTip()
  if _G.GameTooltip then _G.GameTooltip:Hide() end
end

local function toggleMainFrame()
  if not B then return end
  if not B.frame then
    if B.CreateMainFrame then B:CreateMainFrame() end
  end
  if not B.frame then
    if B.Print then B:Print((B.Loc and B:Loc("PRINT_LOADED_HINT")) or "Loaded") end
    return
  end
  if B.frame:IsShown() then B.frame:Hide() else B.frame:Show() end
end

local menuFrame
local function ensureMenuFrame()
  if menuFrame then return menuFrame end
  menuFrame = CreateFrame("Frame", "BanruoUI_MinimapIconMenu", UIParent, "UIDropDownMenuTemplate")
  return menuFrame
end

local function showMenu(btn)
  ensureDB()
  local mm = _G.BanruoUIDB.minimap

  local items = {
    {
      text = "BanruoUI",
      isTitle = true,
      notCheckable = true,
    },
    {
      text = (B.Loc and B:Loc("MINIMAP_MENU_OPEN")) or "Open",
      notCheckable = true,
      func = function() toggleMainFrame() end,
    },
    {
      text = mm.hide and ((B.Loc and B:Loc("MINIMAP_MENU_SHOW")) or "Show minimap icon")
               or ((B.Loc and B:Loc("MINIMAP_MENU_HIDE")) or "Hide minimap icon"),
      notCheckable = true,
      func = function()
        mm.hide = not mm.hide
        if B.SetMinimapIconShown then
          B:SetMinimapIconShown(not mm.hide)
        end
      end,
    },
  }

  local f = ensureMenuFrame()
  EasyMenu(items, f, "cursor", 0, 0, "MENU")
end

function B:SetMinimapIconShown(shown)
  local btn = self.minimapButton
  if not btn then return end
  if shown then btn:Show() else btn:Hide() end
end

function B:InitMinimapIcon()
  if self.minimapButton then
    -- refresh from DB
    local mm = ensureDB()
    ensureMinimapSizeHook()
    setButtonPos(self.minimapButton, mm.minimapPos)
    self:SetMinimapIconShown(not mm.hide)
    return self.minimapButton
  end

  local mm = ensureDB()
  ensureMinimapSizeHook()

  local btn = CreateFrame("Button", "BanruoUI_MinimapButton", _G.Minimap, "BackdropTemplate")
  self.minimapButton = btn

  btn:SetSize(32, 32)
  btn:SetFrameStrata("MEDIUM")
  btn:SetClampedToScreen(true)

  local icon = btn:CreateTexture(nil, "ARTWORK")
  icon:ClearAllPoints()
  icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, -0)
  icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -0, 0)
  icon:SetTexture(ICON_TEX)
  btn.icon = icon

  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  btn:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
      showMenu(btn)
    else
      toggleMainFrame()
    end
  end)

  btn:SetScript("OnEnter", function() showTip(btn) end)
  btn:SetScript("OnLeave", hideTip)

  btn:RegisterForDrag("LeftButton")
  btn:SetScript("OnDragStart", function()
    btn.isDragging = true
    hideTip()
  end)
  btn:SetScript("OnDragStop", function()
    btn.isDragging = false
    local a = calcAngleFromCursor()
    mm.minimapPos = a
    setButtonPos(btn, a)
  end)

  btn:SetScript("OnUpdate", function()
    if not btn.isDragging then return end
    local a = calcAngleFromCursor()
    setButtonPos(btn, a)
  end)

  -- initial pos/vis
  setButtonPos(btn, mm.minimapPos)
  self:SetMinimapIconShown(not mm.hide)

  return btn
end
