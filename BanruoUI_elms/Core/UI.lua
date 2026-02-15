-- Bre/Core/UI.lua
-- Main UI shell (WA-like) for Bre. No engine logic; reads BreSaved.displays only.

local addonName, Bre = ...
Bre = Bre or {}
Bre.UI = Bre.UI or {}

local UI = Bre.UI

-- (SizeMode) Loaded via Bre.toc: Bre/Core/UI_SizeMode.lua

-- ------------------------------------------------------------
-- UI whitelist hook (v1.13):
-- - Only defines data+switch+apply entrypoints.
-- - Default switches are OFF -> preserves current UI.
-- ------------------------------------------------------------
function UI:ApplyUIWhitelist()
  if Bre and Bre.UIWhitelist and Bre.UIWhitelist.Apply then
    Bre.UIWhitelist:Apply(self)
  end
  -- Keep NewOverlay mode in sync with ThemeMinimal toggles
  self:_ApplyNewOverlayMode()
end

function UI:ApplyTopButtonsWhitelist(cfg)
  local f = self.frame
  if not f or not f._topBar then return end
  local allow = (cfg and cfg.allow) or nil
  local btns = f._topBar._btns or {}

  -- If cfg is nil (whitelist disabled), show all buttons.
  if not allow then
    for _, b in pairs(btns) do
      if b and b.Show then b:Show() end
    end
    self:UpdateHeaderHitInsets()
    return
  end

  -- Policy (B): Import <-> New are bound (always same shown state).
  -- Close remains independent.
  local importOn = (allow.Import == true)
  local newOn = importOn

  for k, b in pairs(btns) do
    if b and b.SetShown then
      if k == "Import" then
        b:SetShown(importOn)
      elseif k == "New" then
        b:SetShown(newOn)
      else
        b:SetShown(allow[k] == true)
      end
    end
  end
  self:UpdateHeaderHitInsets()
end

function UI:UpdateHeaderHitInsets()
  local f = self.frame
  if not f or not f._headerHit then return end
  local hit = f._headerHit
  local btnNew = f._headerHitBtnNew
  local btnImport = f._headerHitBtnImport
  local btnClose = f._headerHitBtnClose
  if not (hit.GetLeft and hit.GetRight) then return end
  local l = hit:GetLeft()
  local r = hit:GetRight()
  if not l or not r then return end

  -- Left block: use the right-most edge among ALL shown left buttons.
  -- (Fixes the case where Import+New are both shown, but only Import was blocking.)
  local leftBlockRight
  if btnImport and btnImport.IsShown and btnImport:IsShown() and btnImport.GetRight then
    leftBlockRight = btnImport:GetRight()
  end
  if btnNew and btnNew.IsShown and btnNew:IsShown() and btnNew.GetRight then
    local nr = btnNew:GetRight()
    if nr and (not leftBlockRight or nr > leftBlockRight) then
      leftBlockRight = nr
    end
  end
  local closeLeft
  if btnClose and btnClose.IsShown and btnClose:IsShown() and btnClose.GetLeft then
    closeLeft = btnClose:GetLeft()
  end

  local leftInset = 0
  if leftBlockRight then
    leftInset = math.max(0, (leftBlockRight - l) + 6)
  end
  local rightInset = 0
  if closeLeft then
    rightInset = math.max(0, (r - closeLeft) + 6)
  end
  if hit.SetHitRectInsets then
    hit:SetHitRectInsets(leftInset, rightInset, 0, 0)
  end
end


function UI:ApplyDrawersWhitelist(cfg)
  local f = self.frame
  if not f or not f._rightPanel then return end
  local allow = (cfg and cfg.allow) or nil
  local right = f._rightPanel

  -- If cfg is nil (whitelist disabled), show all drawer tabs.
  if not allow then
    for _, b in pairs(right._tabBtns or {}) do
      if b and b.Show then b:Show() end
    end
    return
  end

  -- hide/show tab buttons
  for k, b in pairs(right._tabBtns or {}) do
    if b and b.SetShown then
      b:SetShown(allow[k] == true)
    end
  end

  -- if current tab becomes hidden, switch to first allowed
  local cur = f._rightTab
  if cur and allow[cur] ~= true then
    local first
    for _, k in ipairs({"Element", "LoadIO", "Group", "Conditions", "Actions", "CustomFn"}) do
      if allow[k] == true then first = k break end
    end
    if first then
      self:ShowRightTab(first)
    end
  end
end

-- L2 module capability declaration (v1.5 mandatory)
UI.runtime_required = false
UI.authoring_required = true
-- NOTE: Do NOT capture Bre.L at load time.
-- Locale bootstrap may run before/after this file depending on load order,
-- so always resolve dynamically to avoid showing raw keys (e.g. "MAIN_TITLE").
local function L(key)
  if Bre and Bre.L then
    return Bre.L(key)
  end
  return tostring(key)
end

local Gate = Bre.Gate
local function _iface(name)
  if Gate and Gate.Get then return Gate:Get(name) end
  return {}
end

local function _proxy(ifaceName)
  return setmetatable({}, {
    __index = function(_, k)
      local s = _iface(ifaceName)
      local v = s and s[k]
      if type(v) == "function" then
        return function(_, ...) return v(s, ...) end
      end
      return v
    end
  })
end

local DB = _proxy("DB")
local API = _proxy("API_Data")
local TreeIndex = _proxy("TreeIndex")
local UIB = _proxy("UIBindings")
local Skin = _proxy("Skin")
local View = _proxy("View")
local Render = _proxy("Render")
local Sel = _proxy("SelectionService")

local function _MoveSvc() return _iface("Move") end

local function GetData(id) return API and API.GetData and API:GetData(id) end


local MAIN_W = (Bre.Const and Bre.Const.WIDTH) or 820
local MAIN_H = (Bre.Const and Bre.Const.HEIGHT) or 560

local LEFT_W = 360
local TOP_H  = 26

-- Square fixed layout (SizeMode DEFAULT): 560x560 with strict 2 columns (Tree 310 + Right 250).
local SQUARE_W = 560  -- content width
local SQUARE_H = 560  -- content height
local TREE_W_FIXED = 310
local RIGHT_W_FIXED = 250

-- BanruoUI DialogBox insets (used to grow outer frame so border wraps content)
local DIALOG_INSET_L = 11
local DIALOG_INSET_R = 12
local DIALOG_INSET_T = 12
local DIALOG_INSET_B = 11
local COMPACT_OUTER_W = SQUARE_W + DIALOG_INSET_L + DIALOG_INSET_R
local COMPACT_OUTER_H = SQUARE_H + DIALOG_INSET_T + DIALOG_INSET_B

local YELLOW_R, YELLOW_G, YELLOW_B = 1.0, 0.82, 0.0 -- legacy fallback

local function safeCall(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c = pcall(fn, ...)
  if ok then return a, b, c end
  return nil
end


-- ------------------------------------------------------------
-- SizeMode apply hook
-- v1.13.14: Compact mode is auto-applied during UI show (per user requirement).
-- ------------------------------------------------------------
function UI:SetLayoutPreset(preset)
  preset = tostring(preset or ""):upper()
  if preset ~= "LEGACY_DEFAULT" and preset ~= "THEME_320_240" then
    return
  end
  self._layoutPreset = preset
  if self.ApplyLayoutPreset then
    pcall(function() self:ApplyLayoutPreset(preset) end)
  end
end

function UI:ApplyLayoutPreset(preset)
  preset = tostring(preset or (self._layoutPreset or "LEGACY_DEFAULT")):upper()

  local f = self.frame
  if not f or not f._body or not f._body._inner then return end

  local body = f._body
  local inner = body._inner
  local left = inner._left
  local right = inner._right
  if not left or not right then return end

  -- cache legacy anchors once (from the UI that was actually created)
  if not f._layoutCache then
    f._layoutCache = {
      body = { body:GetPoint(1), body:GetPoint(2) },
      leftW = left:GetWidth(),
    }
  end

  -- optional split line (visual only)
  local split = inner._splitLine

  if preset == "THEME_320_240" then
    -- Body spans full width; keep existing vertical offsets (top bar stays padded)
    body:ClearAllPoints()
    body:SetPoint("TOPLEFT", DIALOG_INSET_L, -34 - TOP_H - 6 - DIALOG_INSET_T)
    body:SetPoint("BOTTOMRIGHT", -DIALOG_INSET_R, DIALOG_INSET_B)

    -- Strict 2 columns: Tree 310 + Right 250, no gap
    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", inner, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", inner, "BOTTOMLEFT", 0, 0)
    left:SetWidth(TREE_W_FIXED)

    right:ClearAllPoints()
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", inner, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(RIGHT_W_FIXED)

    if split then
      split:ClearAllPoints()
      split:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
      split:SetPoint("BOTTOMLEFT", left, "BOTTOMRIGHT", 0, 0)
      split:SetWidth(1)
      split:Show()
    end
  else
    -- Restore legacy layout (keep original spacing behavior)
    body:ClearAllPoints()
    body:SetPoint("TOPLEFT", 12, -34 - TOP_H - 6)
    body:SetPoint("BOTTOMRIGHT", -12, 12)

    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", inner, "TOPLEFT", 10, -10)
    left:SetPoint("BOTTOMLEFT", inner, "BOTTOMLEFT", 10, 10)
    left:SetWidth(LEFT_W)

    right:ClearAllPoints()
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 10, 0)
    right:SetPoint("BOTTOMRIGHT", inner, "BOTTOMRIGHT", -10, 10)

    if split then split:Hide() end
  end
end

-- ------------------------------------------------------------
-- SizeMode apply hook
-- v1.13.14: Compact mode is auto-applied during UI show (per user requirement).
-- NOTE (v1.13.19): Internal 2-column layout is controlled by LayoutPreset, not SizeMode.
-- ------------------------------------------------------------
function UI:OnSizeModeApplied(mode)
  -- Backward-compat default: COMPACT implies THEME_320_240 unless overridden.
  local preset = self._layoutPreset
  if not preset then
    mode = (mode or ""):upper()
    preset = (mode == "COMPACT") and "THEME_320_240" or "LEGACY_DEFAULT"
    self._layoutPreset = preset
  end
  if self.ApplyLayoutPreset then
    pcall(function() self:ApplyLayoutPreset(preset) end)
  end
end



-- ------------------------------------------------------------
-- Display label formatter (external UI only)
-- - Internal names may keep type suffixes like " (group)" / " (custom)".
-- - UI display/search/rename should not show these suffixes.
-- ------------------------------------------------------------
local function _StripTypeSuffix(label)
  if type(label) ~= "string" then return label end
  local out = label

  -- strip trailing colored " (type)" like: "  |cff888888(progress)|r"
  out = out:gsub("%s*|c[fF][fF]%x%x%x%x%x%x%s*%(%s*[^%)]+%s*%)|r%s*$", "")

  -- strip trailing plain " (progress)" fallback (case-insensitive)
  out = out:gsub("%s%(%s*[Pp][Rr][Oo][Gg][Rr][Ee][Ss][Ss]%s*%)%s*$", "")

  -- strip trailing plain " (group)" / " (custom)" (case-insensitive)
  out = out:gsub("%s%(%s*[Gg][Rr][Oo][Uu][Pp]%s*%)%s*$", "")
  out = out:gsub("%s%(%s*[Cc][Uu][Ss][Tt][Oo][Mm]%s*%)%s*$", "")
  return out
end

-- ------------------------------------------------------------
-- Edit session (stable commits must bind to nodeId + rev, never "current selected")
-- ------------------------------------------------------------
local function _EnsureEditSession(f)
  if not f then return { nodeId = nil, rev = 0 } end
  if type(f._editSession) ~= "table" then
    f._editSession = { nodeId = nil, rev = 0 }
  end
  f._editSession.rev = tonumber(f._editSession.rev) or 0
  return f._editSession
end

local function _BumpEditSession(f, nodeId)
  local es = _EnsureEditSession(f)
  es.rev = (tonumber(es.rev) or 0) + 1
  es.nodeId = nodeId
  return es
end

local function _GetBoundNodeId(ctrl, f)
  if ctrl and ctrl._editBindNodeId then return ctrl._editBindNodeId, ctrl._editBindRev end
  local es = f and _EnsureEditSession(f) or nil
  return es and es.nodeId or nil, es and es.rev or nil
end

local function _IsBindAlive(f, rev)
  if not f or rev == nil then return true end
  local es = _EnsureEditSession(f)
  return rev == es.rev
end

local function ensureDB()
  -- DB initialization is centralized in Core (Gate→DB)
end

local function getBindings()
  return UIB
end

local function applyPanelBackdrop(frame, borderAlpha, inset)
  if Skin and Skin.ApplyPanelBackdrop then
    Skin:ApplyPanelBackdrop(frame, { borderAlpha = borderAlpha, inset = inset, strong = false })
    return
  end
  borderAlpha = borderAlpha or 0.35
  inset = inset or 2
  frame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Buttons/WHITE8x8",
    edgeSize = 1,
    insets = { left = inset, right = inset, top = inset, bottom = inset },
  })
  frame:SetBackdropColor(0.03, 0.03, 0.03, 0.88)
  frame:SetBackdropBorderColor(YELLOW_R, YELLOW_G, YELLOW_B, borderAlpha)
end

local function applyMainBackdrop(frame)
  -- BanruoUI-style main frame border (UI-DialogBox). Keep everything else unchanged.
  if not frame or not frame.SetBackdrop then return end
  frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  frame:SetBackdropColor(0, 0, 0, 0.92)
end


-- Step1: minimal visibility placeholder (no logic, no state)
local function makeVisibilityPlaceholder(parent)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(14, 14)
  b:SetAlpha(0.35)
  return b
end

local function makeTopBtn(parent, label, w)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w or 56, 18)
  if Skin and Skin.ApplyButtonBorder then
    Skin:ApplyButtonBorder(b, { strong = true })
  else
    b:SetBackdrop({ edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1 })
    b:SetBackdropBorderColor(YELLOW_R, YELLOW_G, YELLOW_B, 0.65)
    b:SetBackdropColor(0,0,0,0)
  end

  local t = b:CreateFontString(nil, "OVERLAY", (Bre.Font and Bre.Font:Normal() or "GameFontNormal"))
  t:SetPoint("CENTER")
  t:SetText(label)
  if Skin and Skin.ApplyFontColor then
    Skin:ApplyFontColor(t, "ACCENT")
  else
    t:SetTextColor(YELLOW_R, YELLOW_G, YELLOW_B)
  end
  b._text = t
  return b
end

local function makeTabBtn(parent, label)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(72, 22)
  if Skin and Skin.ApplyButtonBorder then
    Skin:ApplyButtonBorder(b, { strong = false })
  else
    b:SetBackdrop({ edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1 })
    b:SetBackdropBorderColor(YELLOW_R, YELLOW_G, YELLOW_B, 0.55)
    b:SetBackdropColor(0,0,0,0)
  end

  local t = b:CreateFontString(nil, "OVERLAY", (Bre.Font and Bre.Font:Small() or "GameFontNormalSmall"))
  t:SetPoint("CENTER")
  t:SetText(label)
  if Skin and Skin.ApplyFontColor then
    Skin:ApplyFontColor(t, "ACCENT")
  else
    t:SetTextColor(YELLOW_R, YELLOW_G, YELLOW_B)
  end
  b._text = t

  -- Selected/hover visuals: Blizzard textures (no font recolor).
  -- Keep this ultra-safe: no reliance on color objects/methods.
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  -- Use a neutral Blizzard texture so the selected/hover state is gray (not blue).
  hl:SetTexture("Interface/Buttons/WHITE8x8")
  hl:SetBlendMode("BLEND")
  hl:SetAlpha(0.15)
  if hl.SetVertexColor then hl:SetVertexColor(0.55, 0.55, 0.55, 0.3) end

  local sel = b:CreateTexture(nil, "ARTWORK")
  sel:SetAllPoints()
  sel:SetTexture("Interface/Buttons/WHITE8x8")
  sel:SetBlendMode("BLEND")
  sel:SetAlpha(0.25)
  if sel.SetVertexColor then sel:SetVertexColor(0.55, 0.55, 0.55, 0.3) end
  sel:Hide()
  b._selTex = sel

  function b:SetActive(on)
    if self._selTex then
      if on then self._selTex:Show() else self._selTex:Hide() end
    end
  end

  return b
end

-- ------------------------------------------------------------
-- Frame creation
-- ------------------------------------------------------------
function UI:EnsureFrame()
  if self.frame then return self.frame end
  ensureDB()

  local f = CreateFrame("Frame", "BreMainFrame", UIParent, "BackdropTemplate")
  f:SetSize(MAIN_W, MAIN_H)
  f:SetPoint("CENTER")
  f:EnableMouse(true)
  f:SetMovable(true)
  f:Hide()
  f:SetScript("OnHide", function()
    if UI and UI._SyncMoverBody then UI:_SyncMoverBody() end
  end)

  -- Drag: headerHit is the ONLY drag entry (avoid floaty drag caused by dual drag sources)
  -- Keep f movable so headerHit can call StartMoving/StopMovingOrSizing.
  f:HookScript("OnSizeChanged", function()
    if UI and UI.UpdateHeaderHitInsets then UI:UpdateHeaderHitInsets() end
  end)

  applyMainBackdrop(f)

  -- Title
  local title = f:CreateFontString(nil, "OVERLAY", (Bre.Font and Bre.Font:Large() or "GameFontNormalLarge"))
  title:SetPoint("TOPLEFT", 14, -10)
  title:SetText(L("MAIN_TITLE"))
  if Skin and Skin.ApplyFontColor then
    Skin:ApplyFontColor(title, "ACCENT")
  else
    title:SetTextColor(YELLOW_R, YELLOW_G, YELLOW_B)
  end

  -- Close
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)
  f._closeX = close

  -- Top actions bar (New/Import)
  local top = CreateFrame("Frame", nil, f)
  top:SetPoint("TOPLEFT", 12, -34)
  top:SetPoint("TOPRIGHT", -12, -34)
  top:SetHeight(TOP_H)

  local btnImport = makeTopBtn(top, L("BTN_IMPORT"), 46)
  btnImport:SetPoint("LEFT", 0, 0)
  btnImport:SetScript("OnClick", function() UI:OpenImportWindow() end)
  top._btnImport = btnImport

  local btnNew = makeTopBtn(top, L("BTN_NEW"), 46)
  btnNew:SetPoint("LEFT", btnImport, "RIGHT", 6, 0)
  btnNew:SetScript("OnClick", function() UI:OpenNewOverlay() end)
  top._btnNew = btnNew


  -- whitelist refs (top bar)
  f._topBar = top
  -- SizeMode references
  self.topBar = top
  top._btns = {
    New = btnNew,
    Import = btnImport,
    Close = close,
  }

  -- Header blank click -> Clear selection (v1.13.20)
  -- Scope: only the area above Body (title + top bar empty space). No UI-outside capture.
  -- Safety: do not clear while an EditBox is focused (avoid accidental EditFocusLost commit).
  local headerHit = CreateFrame("Button", nil, f)
  headerHit:SetPoint("TOPLEFT", DIALOG_INSET_L, -DIALOG_INSET_T)
  headerHit:SetPoint("TOPRIGHT", -DIALOG_INSET_R, -DIALOG_INSET_T)
  -- bottom is anchored to Body after Body is created; we temporarily anchor to the top bar.
  headerHit:SetPoint("BOTTOMLEFT", top, "BOTTOMLEFT", 0, 0)
  headerHit:SetPoint("BOTTOMRIGHT", top, "BOTTOMRIGHT", 0, 0)
  headerHit:EnableMouse(true)
  local topLevel = (top and top.GetFrameLevel) and top:GetFrameLevel() or 0
  headerHit:SetFrameLevel(topLevel + 20) -- above top bar; hit rect insets prevent stealing button clicks
  headerHit:RegisterForDrag("LeftButton")
  local _dragging = false
  local _down = false

  headerHit:SetScript("OnMouseDown", function()
    _down = true
    _dragging = false
  end)

  headerHit:SetScript("OnDragStart", function()
    _dragging = true
    if f and f.StartMoving then
      f:StartMoving()
    end
  end)

  headerHit:SetScript("OnDragStop", function()
    if f and f.StopMovingOrSizing then
      f:StopMovingOrSizing()
    end
    _dragging = false
    _down = false
  end)

  headerHit:SetScript("OnMouseUp", function(_, btn)
    if btn ~= "LeftButton" then return end
    if not _down then return end
    _down = false
    if _dragging then return end
    -- click on blank header: clear selection (no side effects, no implicit commit)
    if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then return end
    if UI and UI.ClearSelection then
      safeCall(UI.ClearSelection, UI)
    else
      if Sel and Sel.Clear then
        Sel:Clear("header")
      end
      if UI and UI.RefreshAll then
        safeCall(UI.RefreshAll, UI)
      end
    end
  end)
  f._headerHit = headerHit
  f._headerHitBtnNew = btnNew
  f._headerHitBtnImport = btnImport
  f._headerHitBtnClose = close
  headerHit:SetScript("OnShow", function()
    if UI and UI.UpdateHeaderHitInsets then
      safeCall(UI.UpdateHeaderHitInsets, UI)
    end
  end)
  -- initialize hit rect after first layout pass
  C_Timer.After(0, function()
    if UI and UI.UpdateHeaderHitInsets then
      safeCall(UI.UpdateHeaderHitInsets, UI)
    end
  end)


  -- Body
  local body = CreateFrame("Frame", nil, f)
  body:SetPoint("TOPLEFT", 12, -34 - TOP_H - 6)
  body:SetPoint("BOTTOMRIGHT", -12, 12)
  f._body = body

  -- Re-anchor header hitbox bottom to the Body top so it always covers the whole header area.
  if f._headerHit then
    f._headerHit:ClearAllPoints()
    f._headerHit:SetPoint("TOPLEFT", DIALOG_INSET_L, -DIALOG_INSET_T)
    f._headerHit:SetPoint("TOPRIGHT", -DIALOG_INSET_R, -DIALOG_INSET_T)
    f._headerHit:SetPoint("BOTTOMLEFT", body, "TOPLEFT", 0, 0)
    f._headerHit:SetPoint("BOTTOMRIGHT", body, "TOPRIGHT", 0, 0)
    if UI and UI.UpdateHeaderHitInsets then safeCall(UI.UpdateHeaderHitInsets, UI) end
  end

  -- Inner container border (like your mock's big inner frame)
  local inner = CreateFrame("Frame", nil, body, "BackdropTemplate")
  inner:SetAllPoints()
  -- inner container: subtle border only
  applyPanelBackdrop(inner, 0.25, 3)
  body._inner = inner

  -- Split line (visual only). Shown in SizeMode DEFAULT strict 2-column layout.
  local splitLine = CreateFrame("Frame", nil, inner, "BackdropTemplate")
  splitLine:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8" })
  splitLine:SetBackdropColor(YELLOW_R, YELLOW_G, YELLOW_B, 0.35)
  splitLine:SetWidth(1)
  splitLine:Hide()
  inner._splitLine = splitLine

  -- Left panel
  local left = CreateFrame("Frame", nil, inner, "BackdropTemplate")
  left:SetPoint("TOPLEFT", 10, -10)
  left:SetPoint("BOTTOMLEFT", 10, 10)
  -- Left tree width is user-resizable (persisted)
  local initTreeW = LEFT_W
  left:SetWidth(initTreeW)
  -- left panel: no extra border (avoid "double lines")
  applyPanelBackdrop(left, 0.0, 2)
  inner._left = left
  -- SizeMode references
  self.treeFrame = left

  -- Search bar
  local searchBox = CreateFrame("Frame", nil, left, "BackdropTemplate")
  searchBox:SetPoint("TOPLEFT", 10, -10)
  searchBox:SetPoint("TOPRIGHT", -10, -10)
  searchBox:SetHeight(22)
  -- Background/Border is separated into a dedicated layer so the Tree list can visually sit above it
  -- without breaking the search EditBox interaction.
  local searchBg = CreateFrame("Frame", nil, searchBox, "BackdropTemplate")
  searchBg:SetAllPoints(searchBox)
  searchBg:SetBackdrop({ edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1 })
  searchBg:SetBackdropBorderColor(YELLOW_R, YELLOW_G, YELLOW_B, 0.55)
  searchBg:SetBackdropColor(0,0,0,0)
  searchBg:SetFrameLevel(searchBox:GetFrameLevel())
  searchBox._bg = searchBg

  local searchEdit = CreateFrame("EditBox", nil, searchBox)
  searchEdit:SetAutoFocus(false)
  searchEdit:SetFont("Fonts\ARKai_T.ttf", 13, "")
  searchEdit:SetPoint("LEFT", 24, 0)
  searchEdit:SetPoint("RIGHT", -6, 0)
  searchEdit:SetHeight(18)
  searchEdit:SetText("")
  searchEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  left._searchEdit = searchEdit
  local searchIcon = searchBox:CreateTexture(nil, "OVERLAY")
  searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
  searchIcon:SetSize(14, 14)
  searchIcon:SetPoint("LEFT", searchBox, "LEFT", 6, 0)
  left._searchIcon = searchIcon

  -- Section headers are created inside the scroll content so they can move/scroll with rows.
-- Tree scroll
	local scroll = CreateFrame("ScrollFrame", "BreTreeScroll", left, "UIPanelScrollFrameTemplate")
	-- CRITICAL FIX: Disable mouse interception on ScrollFrame to allow row drag & drop
	scroll:EnableMouse(false)
	-- Visually prioritize the Tree list: allow it to sit above the Search/HDR backgrounds.
	-- Search EditBox remains interactable above the Tree.
		scroll:SetPoint("TOPLEFT", 10, -38)
	  scroll:SetPoint("BOTTOMRIGHT", -28, 10)

	  -- Visual-only: keep Tree fixed, nudge the ScrollBar so its top button/track align with the Tree top.
	  -- (No behavior changes; anchors only.)
	  local sb = scroll.ScrollBar or _G["BreTreeScrollScrollBar"]
	  if sb and sb.SetPoint then
	    local TOP_PAD = -43  -- move ScrollBar down a bit to match the Tree top baseline
	    local BOT_PAD = 6   -- symmetric bottom padding
	    sb:ClearAllPoints()
	    sb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 20, TOP_PAD)
	    sb:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 0, BOT_PAD)
	  end
	if left._searchEdit and left._searchEdit.GetParent and left._searchEdit:GetParent() then
	  local sbParent = left._searchEdit:GetParent()
	  local baseLevel = (sbParent.GetFrameLevel and sbParent:GetFrameLevel()) or 1
	  scroll:SetFrameLevel(baseLevel + 2)
	  left._searchEdit:SetFrameLevel(baseLevel + 5)
	end

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(1, 1)
  scroll:SetScrollChild(content)


    left._scroll = scroll
  left._content = content



-- Tree scroll: enable mouse wheel + clamp scroll range after content height updates.
scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", function(selfFrame, delta)
  local sb = selfFrame.ScrollBar or _G["BreTreeScrollScrollBar"]
  if not sb then return end
  local cur = sb:GetValue() or 0
  local minv, maxv = sb:GetMinMaxValues()
  local step = (sb.GetValueStep and sb:GetValueStep()) or 20
  if not step or step <= 0 then step = 20 end
  local nextv = cur - (delta * step * 3)
  if nextv < minv then nextv = minv end
  if nextv > maxv then nextv = maxv end
  sb:SetValue(nextv)
end)

-- helper used by RefreshTree to avoid "stuck/blank" when content shrinks
left._ClampTreeScroll = function()
  local sb = scroll.ScrollBar or _G["BreTreeScrollScrollBar"]
  if not sb or not sb.GetMinMaxValues then return end
  local minv, maxv = sb:GetMinMaxValues()
  local cur = sb:GetValue() or 0
  if maxv < minv then maxv = minv end
  if cur < minv then sb:SetValue(minv) end
  if cur > maxv then sb:SetValue(maxv) end
end

  -- Click blank area in tree panel to clear selection
  left:EnableMouse(true)
  left:SetScript("OnMouseDown", function(selfFrame, btn)
    if btn == "LeftButton" then UI:ClearSelection() end
  end)
  scroll:EnableMouse(true)
  scroll:SetScript("OnMouseDown", function(selfFrame, btn)
    if btn == "LeftButton" then UI:ClearSelection() end
  end)
  content:EnableMouse(true)
  content:SetScript("OnMouseDown", function(selfFrame, btn)
    if btn == "LeftButton" then UI:ClearSelection() end
  end)


  -- Section headers (inside scroll content)
  local hdrLoaded = content:CreateFontString(nil, "OVERLAY", (Bre.Font and Bre.Font:Normal() or "GameFontNormal"))
	-- NOTE: positive Y on TOPLEFT can push the header above the scroll clip and appear "cut".
	hdrLoaded:SetPoint("TOPLEFT", 8, -8)
  hdrLoaded:SetText(L("HDR_LOADED"))
  if Skin and Skin.ApplyFontColor then
    Skin:ApplyFontColor(hdrLoaded, "ACCENT")
  else
    hdrLoaded:SetTextColor(YELLOW_R, YELLOW_G, YELLOW_B)
  end
  left._hdrLoaded = hdrLoaded

  local hdrUnloaded = content:CreateFontString(nil, "OVERLAY", (Bre.Font and Bre.Font:Normal() or "GameFontNormal"))
  hdrUnloaded:SetPoint("TOPLEFT", 12, -192) -- will be repositioned in RefreshTree
  hdrUnloaded:SetText(L("HDR_UNLOADED"))
  if Skin and Skin.ApplyFontColor then
    Skin:ApplyFontColor(hdrUnloaded, "ACCENT")
  else
    hdrUnloaded:SetTextColor(YELLOW_R, YELLOW_G, YELLOW_B)
  end
  left._hdrUnloaded = hdrUnloaded

  -- Right panel
  local right = CreateFrame("Frame", nil, inner, "BackdropTemplate")
  right:SetPoint("TOPLEFT", left, "TOPRIGHT", 10, 0)
  right:SetPoint("BOTTOMRIGHT", -10, 10)
  -- right panel: no extra border (avoid "double lines")
  applyPanelBackdrop(right, 0.0, 2)
  inner._right = right
  f._rightPanel = right
  f._rightPanel = right
  -- SizeMode references
  self.rightPane = right
  -- Tree panel resize disabled (fixed layout). v2.8.7

  -- Right top tabs (Group/Element/Conditions/LoadExport/CustomFn)
  local rightTabs = CreateFrame("Frame", nil, right)
  rightTabs:SetPoint("TOPLEFT", 10, -10)
  rightTabs:SetPoint("TOPRIGHT", -10, -10)
  rightTabs:SetHeight(24)
  right._tabs = rightTabs

  right._tabBtns = {
    Group = makeTabBtn(rightTabs, L("TAB_GROUP")),
    Element = makeTabBtn(rightTabs, L("TAB_ELEMENT")),
    Conditions = makeTabBtn(rightTabs, L("TAB_CONDITIONS")),
    Actions = makeTabBtn(rightTabs, L("TAB_ACTIONS")),
    LoadIO = makeTabBtn(rightTabs, L("TAB_LOAD")),
    CustomFn = makeTabBtn(rightTabs, L("TAB_CUSTOM")),
  }

  right._tabBtns.Group:SetPoint("LEFT", 0, 0)
  right._tabBtns.Element:SetPoint("LEFT", right._tabBtns.Group, "RIGHT", 8, 0)
  right._tabBtns.Conditions:SetPoint("LEFT", right._tabBtns.Element, "RIGHT", 8, 0)
  right._tabBtns.Actions:SetPoint("LEFT", right._tabBtns.Conditions, "RIGHT", 8, 0)
  right._tabBtns.LoadIO:SetPoint("LEFT", right._tabBtns.Actions, "RIGHT", 8, 0)
  right._tabBtns.CustomFn:SetPoint("LEFT", right._tabBtns.LoadIO, "RIGHT", 8, 0)

  for k, b in pairs(right._tabBtns) do
    b:SetScript("OnClick", function() UI:ShowRightTab(k) end)
  end

  -- Right content border box
  local box = CreateFrame("Frame", nil, right, "BackdropTemplate")
  box:SetPoint("TOPLEFT", 10, -44)
  box:SetPoint("BOTTOMRIGHT", -10, 10)
  -- main right content box: subtle border
  applyPanelBackdrop(box, 0.28, 3)
  right._box = box

  -- Placeholder panes
  right._panes = {}
  local function makePane(key)
    local p = CreateFrame("Frame", nil, box)
    p:SetAllPoints()
    p:Hide()
    -- Click blank area on the pane background to clear selection.
    -- NOTE: We intentionally avoid clearing selection when clicking interactive controls.
    p:EnableMouse(false)

    local blank = CreateFrame("Frame", nil, p)
    blank:SetAllPoints()
    blank:SetFrameStrata("BACKGROUND")
    -- Ensure the blank catcher stays BEHIND interactive controls (buttons/dropdowns/scroll).
    -- Otherwise it may intercept clicks and clear selection or block OnClick handlers.
    blank:SetFrameLevel(p:GetFrameLevel())
    blank:EnableMouse(true)
    blank:SetScript("OnMouseDown", function(_, btn)
      if btn == "LeftButton" then UI:ClearSelection() end
    end)
    p._blankCatcher = blank

    local header = p:CreateFontString(nil, "OVERLAY", (Bre.Font and Bre.Font:Large() or "GameFontNormalLarge"))
    header:SetPoint("TOPLEFT", 16, -14)
    header:SetTextColor(YELLOW_R, YELLOW_G, YELLOW_B)
    header:SetText(L("RIGHT_TITLE"))

    -- Keep refs so specialized panes can hide the generic placeholder title/hint
    p._defaultHeader = header

    local hint = p:CreateFontString(nil, "OVERLAY", (Bre.Font and Bre.Font:HighlightSmall() or "GameFontHighlightSmall"))
    hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
    hint:SetText(L("SELECT_HINT"))

    p._defaultHint = hint
    right._panes[key] = p
    return p
  end

  makePane("Group")
  makePane("Element")
  makePane("Conditions")
  makePane("Actions")
  makePane("LoadIO")
  makePane("CustomFn")

  -- Build Group pane UI
  self:BuildGroupPane(right._panes.Group)

  -- Build Element pane UI (custom texture v2.8.1)
  self:BuildElementPane(right._panes.Element)

  -- Build Conditions pane UI (Input Conditions drawer)
  self:BuildConditionsPane(right._panes.Conditions)

  -- Build Actions pane UI (Output Actions drawer)
  self:BuildActionsPane(right._panes.Actions)

  -- New overlay panel (covers the whole right side incl. tabs)
  right._newOverlay = self:BuildNewOverlay(right)


  -- State
  f._selectedId = nil
  _EnsureEditSession(f)
  -- Expand/collapse state is persisted via SavedVariables
  -- Expanded/collapsed state (persisted)
  f._expanded = {}
  if BreSaved and BreSaved.ui and BreSaved.ui.tree and type(BreSaved.ui.tree.expanded) == "table" then
    for k, v in pairs(BreSaved.ui.tree.expanded) do
      f._expanded[k] = (v and true) or false
    end
  end
  f._buttons = {}
  f._rightTab = "Group"
  f._rightMode = "GROUP"
  f._lastElementTab = "Element"
  self:_ApplyRightTabLayout("GROUP")
    f._showingNew = false

  -- Key: ESC clears selection (non-destructive)
  f:EnableKeyboard(true)
  if f.SetPropagateKeyboardInput then f:SetPropagateKeyboardInput(true) end
  f:SetScript("OnKeyDown", function(selfFrame, key)
    if key == "ESCAPE" then
      UI:ClearSelection()
      if selfFrame.SetPropagateKeyboardInput then selfFrame:SetPropagateKeyboardInput(true) end
    end
  end)

  self.frame = f

  -- Apply UI whitelist (ThemeMinimal default may hide buttons/tabs).
  self:ApplyUIWhitelist()


  self:ShowRightTab("Element")
  self:RefreshTree()

  -- Restore last selected node (UI-only state)
  -- NOTE: defer 0-frame so Tree/Right panes are fully built before restoring selection.
  do
    local function _restore()
      local f2 = UI.frame
      if not f2 or f2 ~= f then return end
      local DB = Bre and Bre.DB
      local savedId = DB and DB.GetSelectedId and DB:GetSelectedId() or nil
      if type(savedId) == "string" and savedId ~= "" then
        -- Use the same data access path as the rest of UI (Gate->API_Data first).
        local api = Gate and Gate.Get and Gate:Get('API_Data')
        local d = (api and api.GetData and api:GetData(savedId)) or (GetData and GetData(savedId)) or nil
        if type(d) == "table" then
          if Sel and Sel.SetActive then Sel:SetActive(savedId, "restore") end
          UI:_SyncSelectionFromService()
          UI:RefreshTree()
          UI:RefreshRight()
        end
      end
    end
    if C_Timer and C_Timer.After then
      C_Timer.After(0, _restore)
    else
      _restore()
    end
  end

  return f
end

-- ------------------------------------------------------------
-- Right tab switching
-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- Group depth rules (v2.19.8)
-- ------------------------------------------------------------
local GROUP_DRAWER_MAX_DEPTH = 5   -- only depth 1-2 groups show Group drawer
local MAX_GROUP_DEPTH = 5          -- group nesting limit (depth 1..5)

local function _GetGroupDepth(id, data)
  if type(id) ~= "string" or id == "" or type(data) ~= "table" then return 0 end
  local depth = 1
  local cur = data
  local guard = 0
  while cur and type(cur.parent) == "string" and cur.parent ~= "" do
    guard = guard + 1
    if guard > 80 then break end
    local pid = cur.parent
    local pdata = (GetData and GetData(pid)) or nil
    if type(pdata) ~= "table" then break end
    depth = depth + 1
    cur = pdata
  end
  return depth
end

local function _IsGroupId(id, data)
  local U = UIB
  if U and U.IsGroupNode and type(data) == "table" then
    if safeCall(U.IsGroupNode, U, data) then return true end
  end
  if type(id) == "string" and id:match("^Group_") then return true end
  return false
end

local function _GetGroupSubtreeMaxDepth(rootId)
  local root = (GetData and GetData(rootId)) or nil
  if type(rootId) ~= "string" or rootId == "" or type(root) ~= "table" then return 0 end
  if not _IsGroupId(rootId, root) then return 0 end

  local maxDepth = 1
  local guard = 0

  local function dfs(id, depth)
    guard = guard + 1
    if guard > 500 then return end
    if depth > maxDepth then maxDepth = depth end
    local node = (GetData and GetData(id)) or nil
    if type(node) ~= "table" then return end
    local children = node.controlledChildren
    if type(children) ~= "table" then return end
    for _, cid in ipairs(children) do
      local cdata = (GetData and GetData(cid)) or nil
      if _IsGroupId(cid, cdata) then
        dfs(cid, depth + 1)
      end
    end
  end

  dfs(rootId, 1)
  return maxDepth
end

local function _WouldExceedGroupDepthLimit(movingId, newParentId)
  if type(movingId) ~= "string" or movingId == "" then return false end
  if type(newParentId) ~= "string" or newParentId == "" then return false end
  local m = (GetData and GetData(movingId)) or nil
  local p = (GetData and GetData(newParentId)) or nil
  if not _IsGroupId(movingId, m) then return false end
  if not _IsGroupId(newParentId, p) then return false end

  local parentDepth = _GetGroupDepth(newParentId, p)
  local subtreeDepth = _GetGroupSubtreeMaxDepth(movingId)
  if parentDepth <= 0 or subtreeDepth <= 0 then return false end

  return (parentDepth + subtreeDepth) > MAX_GROUP_DEPTH
end

-- Right mode routing (Group vs Element)
-- Desired UX: Tabs are always present; only the FIRST tab switches between Element/Group.
local function _detectRightMode(id)
  if not id then return "ELEMENT" end
  local api = Gate and Gate.Get and Gate:Get('API_Data')
  local data = (api and api.GetData and api:GetData(id)) or (GetData and GetData(id)) or nil

  -- Group detection must be strict. Many element nodes may carry empty children tables
  -- for compatibility; do NOT use children/controlledChildren heuristics here.
  local isGroup = false
  local U = UIB
  if U and U.IsGroupNode then
    isGroup = safeCall(U.IsGroupNode, U, data) and true or false
  end
  -- Fallback for legacy/empty groups: id prefix.
  if not isGroup and type(id) == 'string' and id:match('^Group_') then
    isGroup = true
  end

  local gDepth = isGroup and _GetGroupDepth(id, data) or 0

  -- v2.19.8: Only groups at depth 1-2 show GROUP mode (Group drawer).
  if isGroup and gDepth > GROUP_DRAWER_MAX_DEPTH then
    return "ELEMENT"
  end

  return isGroup and "GROUP" or "ELEMENT"
end

function UI:_ApplyRightTabLayout(mode)
  local f = self.frame
  if not f then return end
  local right = f._body and f._body._inner and f._body._inner._right
  if not right or not right._tabBtns then return end

  local btn = right._tabBtns
  local gap = 8

  -- Always hide the dedicated Group button; the primary (Element) button switches label.
  if btn.Group then btn.Group:Hide() end

  -- NOTE: Right tab visibility is controlled by UIWhitelist (theme minimal mode).
  -- _ApplyRightTabLayout is called frequently (mode switches / modal exit), so it MUST
  -- respect the whitelist if enabled. Otherwise it would re-show hidden tabs.
  local allow
  do
    local W = Bre and Bre.UIWhitelist
    if W and W.state and W.state.enabled and W.state.enable_drawers and W.config and W.config.drawers then
      allow = W.config.drawers.allow or {}
    end
  end

  local function _showTab(key)
    local b = btn[key]
    if not b then return end
    if allow then
      b:SetShown(allow[key] == true)
    else
      b:Show()
    end
  end

  _showTab("Element")
  _showTab("Conditions")
  _showTab("Actions")
  _showTab("LoadIO")
  _showTab("CustomFn")

  -- Update primary tab label
  if btn.Element and btn.Element._text then
    if mode == "GROUP" then
      btn.Element._text:SetText(L("TAB_GROUP"))
    else
      btn.Element._text:SetText(L("TAB_ELEMENT"))
    end
  end

  -- Pack visible tabs left
  local prev
  local order = { "Element", "Conditions", "Actions", "LoadIO", "CustomFn" }
  for _, k in ipairs(order) do
    local b = btn[k]
    if b and b:IsShown() then
      b:ClearAllPoints()
      if not prev then
        b:SetPoint("LEFT", 0, 0)
      else
        b:SetPoint("LEFT", prev, "RIGHT", gap, 0)
      end
      prev = b
    end
  end
end

function UI:_EnsureRightMode()
  local f = self.frame
  if not f then return end

  local mode = _detectRightMode(f._selectedId)
  if f._rightMode ~= mode then
    f._rightMode = mode
    self:_ApplyRightTabLayout(mode)

    -- Keep last tab; group mode defaults to the primary tab (Element btn shows Group label)
    if not f._rightTab then
      f._rightTab = "Element"
    end
  end

  -- No hidden tabs in this UX; keep user's current tab selection.
end

-- ------------------------------------------------------------
-- Drawer mutex helper: ensure only one drawer is visible at a time
-- ------------------------------------------------------------
function UI:_CloseAllRightDrawers(right)
  if not right or type(right._panes) ~= "table" then return end

  local function _hideFrame(fr)
    if fr and fr.Hide then fr:Hide() end
  end

  for _, p in pairs(right._panes) do
    -- legacy actions drawer bits (pre-template)
    _hideFrame(p._actionsScroll)
    _hideFrame(p._actionsTop)

    -- known drawer fields
    _hideFrame(p._drawerCustomMat)
    _hideFrame(p._drawerCustomMat_new)
    _hideFrame(p._drawerProgressMat_new)
    _hideFrame(p._drawerActions_new)
    _hideFrame(p._drawerConditions_new)

    -- generic drawers table
    if type(p._drawers) == "table" then
      for _, d in pairs(p._drawers) do
        _hideFrame(d)
      end
    end
  end
end

function UI:ShowRightTab(key)
  local f = self.frame
  if not f then return end
  local right = f._body._inner._right
  if not right then return end

  -- safety: always clear refresh suppression lock first (avoid leaking across early returns)
  do
    local ep0 = right._panes and right._panes.Element
    if ep0 and ep0._elemMat then
      ep0._elemMat._suppressCommit = false
    end
  end


  -- Ensure mode (Group vs Element) and tab visibility are aligned with current selection
  self:_EnsureRightMode()

  -- New overlay is modal: hide all tabs/panes and show overlay only.
  if f._showingNew then
    for _, b in pairs(right._tabBtns or {}) do b:Hide() end
    for _, p in pairs(right._panes or {}) do p:Hide() end
    if right._newOverlay then right._newOverlay:Show() end
    return
  end

  -- Restore tab visibility/layout after leaving modal overlays
  self:_ApplyRightTabLayout(f._rightMode)

  -- Primary tab switches pane by mode
  if key == "Group" then key = "Element" end
  if f._rightMode == "GROUP" and key == "Element" then
    key = "Group"
  end

  f._rightTab = key
  if key ~= "Group" then
    f._lastElementTab = key
  end

  local activeKey = key
  if activeKey == "Group" then activeKey = "Element" end
  for k, b in pairs(right._tabBtns or {}) do
    if b:IsShown() then
      b:SetActive(k == activeKey)
    else
      b:SetActive(false)
    end
  end

  
  -- Drawer mutex: close any previously visible drawers before switching panes
  self:_CloseAllRightDrawers(right)

for k, p in pairs(right._panes or {}) do
    p:SetShown(k == key and not f._showingNew)
  end

  if right._newOverlay then right._newOverlay:Hide() end

  self:RefreshRight()
end

-- ------------------------------------------------------------
-- New overlay (matches your mock: functions + presets)
-- ------------------------------------------------------------
function UI:BuildNewOverlay(parent)
  local p = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  -- IMPORTANT: this overlay must only cover the RIGHT panel (not the tree)
  p:ClearAllPoints()
  p:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
  p:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
  p:Hide()

  -- Modal overlay: sit above tabs/panes and swallow mouse
  p:SetFrameStrata("DIALOG")
  p:SetFrameLevel((parent:GetFrameLevel() or 0) + 50)
  p:EnableMouse(true)
  p:SetScript("OnMouseDown", function() end)

  -- Backdrop
  if p.SetBackdrop then
    p:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
    p:SetBackdropColor(0, 0, 0, 0.65)
  else
    local bg = p:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.65)
  end

  -- NOTE: New overlay is now aligned to DrawerTemplate FULL grid.
  local DT = Bre and Bre.DrawerTemplate
  local LAYOUT = DT and DT.LAYOUT
  local COL1_X = (LAYOUT and LAYOUT.COL1_X) or 18
  local COL2_X = (LAYOUT and LAYOUT.COL2_X) or 210
  local SCROLL_RIGHT = (LAYOUT and LAYOUT.SCROLL_RIGHT) or -29

  -- Standard sizes for this overlay (keep consistent across FULL/DEV; THEME may hide sections)
  local btnW = 180
  local btnH = 28
  local gapY = 10
  local titleY = -26
  local firstY = -58

  local function mkBigButton(parentFrame, x, y, label, onClick)
    local b = CreateFrame("Button", nil, parentFrame, "BackdropTemplate")
    b:SetSize(btnW, btnH)
    b:SetPoint("TOPLEFT", x, y)
    b:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
    b:SetBackdropColor(0.28, 0.28, 0.28, 0.9)

    local t = b:CreateFontString(nil, "OVERLAY", (Bre.Font and Bre.Font:Normal() or "GameFontNormal"))
    t:SetPoint("CENTER")
    t:SetTextColor(YELLOW_R, YELLOW_G, YELLOW_B)
    t:SetText(label)

    b:SetScript("OnClick", function()
      if type(onClick) == "function" then onClick() end
    end)
    return b
  end

  local function mkTitle(x, y, text)
    local title = p:CreateFontString(nil, "OVERLAY", (Bre.Font and Bre.Font:Normal() or "GameFontNormal"))
    title:SetPoint("TOPLEFT", x, y)
    title:SetTextColor(YELLOW_R, YELLOW_G, YELLOW_B)
    title:SetText(text)
    return title
  end

  -- Left column: functions (elements)
  local leftTitle = mkTitle(COL1_X, titleY, L("NEW_FUNC_TITLE"))

  local funcs = {
    { key = "group",      label = L("NEW_BTN_GROUP") or "Group" },
    { key = "mat_custom", label = L("NEW_BTN_MAT_CUSTOM") or "Custom Texture" },
    -- Always show (base element)
    { key = "progress",   label = L("NEW_BTN_MAT_PROGRESS") or "Progress Texture" },
    { key = "stopmotion", label = L("NEW_BTN_STOPMOTION") or "Stop Motion" },
    { key = "model",      label = L("NEW_BTN_MODEL") or "3D Model" },
    { key = "pet",        label = L("NEW_BTN_PET") or "3D Pet" },
    { key = "fx",         label = L("NEW_BTN_FX") or "3D FX" },
  }

  local leftBtns = {}
  for i, item in ipairs(funcs) do
    local key = item.key
    local label = item.label
    leftBtns[i] = mkBigButton(p, COL1_X, firstY - (i - 1) * (btnH + gapY), label, function()
      if Bre and Bre.UI and Bre.UI.OnNewOverlayAction then
        Bre.UI:OnNewOverlayAction(key)
      end
    end)
  end

  -- Right column: presets (groups)
  -- Right column: presets (groups)
  -- NOTE: wrap in a dedicated block so THEME can hide it without leaving UI-only "ghost" widgets.
  local rightBlock = CreateFrame("Frame", nil, p)
  rightBlock:SetAllPoints(p)

  local rightTitle = rightBlock:CreateFontString(nil, "OVERLAY", (Bre.Font and Bre.Font:Normal() or "GameFontNormal"))
  rightTitle:SetPoint("TOPLEFT", COL2_X, titleY)
  rightTitle:SetTextColor(YELLOW_R, YELLOW_G, YELLOW_B)
  rightTitle:SetText(L("NEW_PRESET_TITLE"))

  local scroll = CreateFrame("ScrollFrame", nil, rightBlock, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", COL2_X, firstY + 8)
  scroll:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", SCROLL_RIGHT, 24)

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(1, 1)
  scroll:SetScrollChild(content)

  local presets = {
    L("NEW_PRESET_BTN"),
    L("NEW_PRESET_TIMER"),
    "xx", "xx", "xx", "xx", "xx", "xx",
  }

  local y = -4
  for i, label in ipairs(presets) do
    local b = CreateFrame("Button", nil, content, "BackdropTemplate")
    b:SetSize(btnW, btnH)
    b:SetPoint("TOPLEFT", 0, y)
    b:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
    b:SetBackdropColor(0.28, 0.28, 0.28, 0.9)

    local t = b:CreateFontString(nil, "OVERLAY", (Bre.Font and Bre.Font:Normal() or "GameFontNormal"))
    t:SetPoint("CENTER")
    t:SetTextColor(YELLOW_R, YELLOW_G, YELLOW_B)
    t:SetText(label)

    y = y - (btnH + gapY)
  end
  content:SetHeight(math.max(1, -y + 20))

  -- Keep refs for dynamic mode switching (ThemeMinimal <-> Full)
  p._newOverlayRightBlock = rightBlock
  p._newOverlayRightScroll = scroll


  -- THEME MINIMAL: handled at open/whitelist-apply time (see UI:_ApplyNewOverlayMode)


  return p
end




function UI:_ApplyNewOverlayMode()
  local f = self.frame
  if not f or not f._rightPanel or not f._rightPanel._newOverlay then return end
  local p = f._rightPanel._newOverlay
  local rightBlock = p._newOverlayRightBlock
  local scroll = p._newOverlayRightScroll

  if not rightBlock then return end

  local W = Bre and Bre.UIWhitelist
  local themeMinimal = W and W.state and W.state.enabled and W.state.theme_minimal_mode

  if themeMinimal then
    rightBlock:Hide()
    if scroll and scroll.ScrollBar then scroll.ScrollBar:Hide() end
    if scroll and scroll.scrollBar then scroll.scrollBar:Hide() end
  else
    rightBlock:Show()
    if scroll and scroll.ScrollBar then scroll.ScrollBar:Show() end
    if scroll and scroll.scrollBar then scroll.scrollBar:Show() end
  end
end


function UI:OpenNewOverlay()
  local f = self:EnsureFrame()
  if not f then return end
  -- Re-apply mode each time (ThemeMinimal may have toggled)
  self:_ApplyNewOverlayMode()
  f._showingNew = true
  self:ShowRightTab(f._rightTab or "Group")
end

function UI:CloseNewOverlay()
  local f = self.frame
  if not f then return end
  f._showingNew = false
  self:ShowRightTab(f._rightTab or "Group")
end

-- ------------------------------------------------------------
-- New overlay actions (v2.8.1)
-- "New" creates nodes and immediately reflects them in TreeRow.
-- Insertion rules (user-defined, simplified):
--  - selected element: insert AFTER it (same container)
--  - selected group/subgroup: insert as FIRST child
--  - no selection: insert as FIRST root
--  - selected root element: treated as "selected element"
-- Group/SubGroup uses the same rules.
-- ------------------------------------------------------------
local function _ensureSaved()
  -- DB initialization is centralized in Core (Gate→DB)
  return BreSaved
end

local function _indexOf(arr, v)
  if type(arr) ~= "table" then return nil end
  for i, x in ipairs(arr) do if x == v then return i end end
  return nil
end

local function _insertUniqueAt(arr, idx, v)
  if type(arr) ~= "table" then return end
  local existing = _indexOf(arr, v)
  if existing then
    table.remove(arr, existing)
    if existing < idx then idx = idx - 1 end
  end
  if idx < 1 then idx = 1 end
  if idx > (#arr + 1) then idx = #arr + 1 end
  table.insert(arr, idx, v)
end

local function _genId(prefix)
  local sv = _ensureSaved()
  sv.meta._idCounters = sv.meta._idCounters or {}
  sv.meta._idCounters[prefix] = (tonumber(sv.meta._idCounters[prefix]) or 0) + 1
  local n = sv.meta._idCounters[prefix]
  return string.format("%s_%03d", prefix, n)
end

local function _createNode(regionType, id, parentId)
  local S = Bre.Schema
  local node
  if S and S.CreateElement then
    node = S:CreateElement(regionType, { id = id, parent = parentId })
  else
    node = { id = id, regionType = regionType, parent = parentId, controlledChildren = {} }
  end
  node.id = id
  node.parent = parentId
  node.controlledChildren = node.controlledChildren or {}
  if regionType == "group" or regionType == "dynamicgroup" then
    node.group = node.group or {}
  end
  
  -- Progress bar specific defaults (v2.16.0)
  if regionType == "progress" then
    -- Default size: 256x256
    node.size = node.size or {}
    node.size.width = 256
    node.size.height = 256
    
    -- Default progress bar settings
    node.foreground = ""  -- Empty = show white color texture
    node.background = nil
    node.mask = nil
    node.progressType = "PROG_TYPE_HEALTH"
    node.progressUnit = "player"
    node.progressValue = 0.6  -- Static fallback value
    node.progressDirection = "BottomToTop"
    
    -- Get default color from ProgressData source
    local PD = Bre.Gate and Bre.Gate.Get and Bre.Gate:Get("ProgressData")
    local defaultColor = nil
    if PD and PD._sources and PD._sources["Health"] then
      defaultColor = PD._sources["Health"].defaultColor
    end
    
    -- Fallback to white if no default color found
    node.fgColor = defaultColor or {r=1, g=1, b=1, a=1}
    node.bgColor = {r=0.3, g=0.3, b=0.3, a=1}
    node.alpha = 1
    node.fade = false
    node.mirror = false
  end

  -- Model specific defaults (v2.18.78)
  if regionType == "model" then
    -- Default size: 256x256 (matches ProgressMat default scale)
    node.size = node.size or {}
    node.size.width = node.size.width or 256
    node.size.height = node.size.height or 256

    -- Minimal model settings
    node.modelMode = node.modelMode or "unit"       -- "unit" / "file"
    node.modelUnit = node.modelUnit or "player"     -- player / target / focus
    node.modelFileID = node.modelFileID             -- number / nil
    node.alpha = node.alpha or 1
  end

  return node
end

-- Decide target container + insertion index according to current selection.
local function _resolveInsertTarget(selectedId)
  local sv = _ensureSaved()
  local d = sv.displays
  local U = UIB

  -- default: root at first
  local container = sv.rootChildren
  local parentId = nil
  local insertIndex = 1

  if type(selectedId) ~= "string" or selectedId == "" then
    return container, parentId, insertIndex
  end

  local data = d[selectedId]
  local isGroup = U and safeCall(U.IsGroupNode, U, data) or false

  if isGroup then
    -- inside group: first child
    parentId = selectedId
    local p = d[parentId]
    p.controlledChildren = p.controlledChildren or {}
    container = p.controlledChildren
    insertIndex = 1
    return container, parentId, insertIndex
  end

  -- selected is element (including root element)
  local pid = data and data.parent
  if type(pid) == "string" and pid ~= "" and d[pid] then
    parentId = pid
    local p = d[pid]
    p.controlledChildren = p.controlledChildren or {}
    container = p.controlledChildren
    local idx = _indexOf(container, selectedId) or #container
    insertIndex = idx + 1
  else
    -- root element: after it in rootChildren
    container = sv.rootChildren
    local idx = _indexOf(container, selectedId)
    if not idx then
      -- rootChildren may not yet track it: ensure it exists at end then insert after
      table.insert(container, selectedId)
      idx = #container
    end
    insertIndex = idx + 1
  end

  return container, parentId, insertIndex
end

function UI:OnNewOverlayAction(key)
  local f = self.frame
  if not f then return end

  -- Implement base test actions now: group + custom texture + progress + model (shell only).
  if key ~= "group" and key ~= "mat_custom" and key ~= "progress" and key ~= "model" and key ~= "stopmotion" then
    return
  end

  local sv = _ensureSaved()
  local d = sv.displays
  local selectedId = f._selectedId

  local container, parentId, insertIndex = _resolveInsertTarget(selectedId)

  -- v2.19.8: Limit group nesting depth (max 5).
  if key == 'group' and type(parentId) == 'string' and parentId ~= '' then
    local pd = d and d[parentId] or (GetData and GetData(parentId)) or nil
    local pDepth = _IsGroupId(parentId, pd) and _GetGroupDepth(parentId, pd) or 0
    if pDepth >= MAX_GROUP_DEPTH then
      return
    end
  end


  local regionType
  if key == "group" then
    regionType = "group"
  elseif key == "progress" then
    regionType = "progress"
  elseif key == "stopmotion" then
    regionType = "stopmotion"
  elseif key == "model" then
    regionType = "model"
  else
    regionType = "custom"
  end
  local prefix
  if key == "group" then
    prefix = "Group"
  elseif key == "progress" then
    prefix = "Progress"
  elseif key == "stopmotion" then
    prefix = "StopMotion"
  elseif key == "model" then
    prefix = "Model"
  else
    prefix = "Mat"
  end
  local newId = _genId(prefix)

  local node = _createNode(regionType, newId, parentId)
  d[newId] = node

  -- Maintain ordering: insert into the resolved container.
  _insertUniqueAt(container, insertIndex, newId)

  -- If this is a root node (no parent), ensure rootChildren also tracks it.
  if not parentId then
    _insertUniqueAt(sv.rootChildren, insertIndex, newId)
  end

  -- Close overlay + select new node (via SelectionService) + refresh.
  self:CloseNewOverlay()
  if Sel and Sel.SetActive then Sel:SetActive(newId, "new") end
  self:_SyncSelectionFromService()
  _BumpEditSession(f, newId)
  self:RefreshTree()
  self:RefreshRight()
end

-- ------------------------------------------------------------
-- Tree rendering (left)
-- ------------------------------------------------------------
local function clearButtons(f)
  for _, b in ipairs(f._buttons) do
    b:Hide()
    b:SetParent(nil)
  end
  f._buttons = {}
end


-- ------------------------------------------------------------
-- Multi-selection (SubGroup + Element; root Group selects all descendant elements)
-- ------------------------------------------------------------
-- Hover callbacks (optional; modules can assign UI.onTreeRowEnter/Leave)
function UI:_OnTreeRowEnter(id, row)
  if type(self.onTreeRowEnter) == "function" then
    self:onTreeRowEnter(id, row)
  end
end

function UI:_OnTreeRowLeave(id, row)
  if type(self.onTreeRowLeave) == "function" then
    self:onTreeRowLeave(id, row)
  end
end

function UI:_EnsureMultiSel()
  -- deprecated (C2): selection state lives in SelectionService
end

function UI:_SyncSelectionFromService()
  local f = self.frame
  if not f then return end
  local st = Sel and Sel.GetState and Sel:GetState() or nil
  if type(st) ~= "table" then return end
  f._selectedId = st.active

  -- Persist UI selection (safe: UI-only state)
  local DB = Bre and Bre.DB
  if DB and DB.SetSelectedId then
    pcall(DB.SetSelectedId, DB, st.active)
  end
end

function UI:_IsSelectableNode(isGroup, depth)
  -- Root-level groups are not selectable in multi-select
  if isGroup and (tonumber(depth) or 0) <= 0 then return false end
  -- SubGroup (isGroup && depth>0) and Element (!isGroup) are selectable
  return true
end

-- Root group click behavior: select all descendant elements (leaf nodes)
function UI:_CollectDescendantElementIds(rootGroupId, out, visited)
  if type(out) ~= "table" then return out end
  visited = visited or {}
  if visited[rootGroupId] then return out end
  visited[rootGroupId] = true

  local d = GetData and GetData(rootGroupId)
  if type(d) ~= "table" then return out end

  local children = d.controlledChildren
  if type(children) ~= "table" then return out end

  for _, cid in ipairs(children) do
    if type(cid) == "string" then
      local cd = GetData and GetData(cid)
      if type(cd) == "table" then
        if cd.regionType == "group" then
          self:_CollectDescendantElementIds(cid, out, visited)
        else
          out[#out + 1] = cid
        end
      end
    end
  end

  return out
end

function UI:_ClearMultiSel()
  -- deprecated (C2): selection state lives in SelectionService
end


function UI:ClearSelection()
  local f = self.frame
  if not f then return end
  local Move = _MoveSvc()

  -- Close overlay so right panel routes back to default state.
  if f._showingNew then
    self:CloseNewOverlay()
  end

  if Sel and Sel.Clear then Sel:Clear("clear") end
  self:_SyncSelectionFromService()
  _BumpEditSession(f, nil)

  -- Hide movers/render immediately
  if Render and Render.Hide then Render:Hide() end
  if Move and Move.HideGroupBox then Move:HideGroupBox() end
  if Move and Move.Hide then Move:Hide() end

  self:RefreshTree()
  self:RefreshRight()
end

function UI:_SetOnlySelected(id)
  local f = self.frame
  if not f then return end
  self:_EnsureMultiSel()
  if Sel and Sel.SetActive then
    Sel:SetActive(id, "single")
  end
  self:_SyncSelectionFromService()
  local d = GetData and GetData(id)
  f._selAnchorId = id
  f._selAnchorParent = d and d.parent or nil
end

function UI:_ToggleSelected(id)
  local f = self.frame
  if not f then return end
  self:_EnsureMultiSel()
  if Sel and Sel.Toggle then
    Sel:Toggle(id, "toggle")
  end
  self:_SyncSelectionFromService()
  if Sel and Sel.IsSelected and Sel:IsSelected(id) then
    local d = GetData and GetData(id)
    f._selAnchorId = id
    f._selAnchorParent = d and d.parent or nil
  end
end

function UI:_GetRangeSelectionIds(anchorId, clickedId, parentId)
  local f = self.frame
  if not f then return {} end
  if type(f._rowOrder) ~= "table" or type(f._rowMeta) ~= "table" then return {} end

  -- Build candidate list: visible siblings under the same parent, selectable only.
  local candidates = {}
  for _, nid in ipairs(f._rowOrder) do
    local m = f._rowMeta[nid]
    if m and m.parent == parentId and m.selectable then
      table.insert(candidates, nid)
    end
  end

  local aIdx, cIdx
  for i, nid in ipairs(candidates) do
    if nid == anchorId then aIdx = i end
    if nid == clickedId then cIdx = i end
  end
  if not aIdx or not cIdx then
    return { clickedId }
  end

  local s = math.min(aIdx, cIdx)
  local e = math.max(aIdx, cIdx)
  local out = {}
  for i = s, e do
    table.insert(out, candidates[i])
  end
  return out
end

local function _CollectDescendantElements(rootId, out, visited)
  if type(rootId) ~= "string" then return end
  visited = visited or {}
  if visited[rootId] then return end
  visited[rootId] = true

  local d = GetData and GetData(rootId)
  if type(d) ~= "table" then return end

  local kids = d.controlledChildren
  if type(kids) ~= "table" then return end

  for _, cid in ipairs(kids) do
    local cd = GetData and GetData(cid)
    if type(cd) == "table" then
      if cd.regionType == "group" then
        _CollectDescendantElements(cid, out, visited)
      else
        out[#out + 1] = cid
      end
    end
  end
end

function UI:_ApplyShiftRange(clickedId)
  local f = self.frame
  if not f then return end
  self:_EnsureMultiSel()

  local d = GetData and GetData(clickedId)
  local pid = d and d.parent or nil
  if not f._selAnchorId or f._selAnchorParent ~= pid then
    -- degrade to single select
    self:_SetOnlySelected(clickedId)
    return
  end

  local ids = self:_GetRangeSelectionIds(f._selAnchorId, clickedId, pid)
  if Sel and Sel.SetSet then Sel:SetSet(ids, "shift") end
  if Sel and Sel.SetActiveInSet then Sel:SetActiveInSet(clickedId, "shift") end
  self:_SyncSelectionFromService()
  f._selAnchorId = clickedId
  f._selAnchorParent = pid
end

function UI:_HandleTreeRowClick(id, depth, isGroup)
  local f = self.frame
  if not f or not id then return end

  -- If the "New" overlay is open, close it so selection can route the right panel.
  if f._showingNew then
    self:CloseNewOverlay()
    -- refresh local reference in case CloseNewOverlay reallocated state
    f = self.frame or f
  end

  local selectable = self:_IsSelectableNode(isGroup, depth)
  if not selectable then
    -- Root group: click selects all descendant elements
    self:_EnsureMultiSel()
    local ids = self:_CollectDescendantElementIds(id, {})
    if Sel and Sel.SetSet then Sel:SetSet(ids, "root") end
    if Sel and Sel.SetActiveRaw then Sel:SetActiveRaw(id, "root") end
    self:_SyncSelectionFromService()
    f._selAnchorId = nil
    f._selAnchorParent = nil
    _BumpEditSession(f, id)
    self:RefreshTree()
    self:RefreshRight()
    return
  end

  self:_EnsureMultiSel()

  local shift = IsShiftKeyDown and IsShiftKeyDown() or false
  local ctrl  = IsControlKeyDown and IsControlKeyDown() or false

  if Sel and Sel.OnTreeClick then
    local d = GetData and GetData(id)
    local pid = d and d.parent or nil
    Sel:OnTreeClick({
      clickedId = id,
      selectable = selectable,
      isRootGroup = (not selectable) and isGroup and ((tonumber(depth) or 0) <= 0),
      descendantIds = (not selectable) and isGroup and self:_CollectDescendantElementIds(id, {}) or nil,
      parentId = pid,
      rowOrder = f._rowOrder,
      rowMeta = f._rowMeta,
      shift = shift,
      ctrl = ctrl,
    })
    self:_SyncSelectionFromService()
  else
    if shift then
      self:_ApplyShiftRange(id)
    elseif ctrl then
      self:_ToggleSelected(id)
    else
      self:_SetOnlySelected(id)
    end
  end

  _BumpEditSession(f, id)
  self:RefreshTree()
  self:RefreshRight()
end



function UI:_BuildTreeRowContextMenuList(nodeId, onPick)
  -- NOTE: Context menu item order is a contract.
  -- Contract: RENAME, COPY, (LOAD/UNLOAD), EXPORT, DELETE.
  local U = getBindings()

  local data = (U and U.GetNode and safeCall(U.GetNode, U, nodeId)) or (GetData and GetData(nodeId)) or nil
  local isHardUnloaded = false
  do
    data = data or ((U and U.GetNode and safeCall(U.GetNode, U, nodeId)) or (GetData and GetData(nodeId)) or nil)
    local LS = Gate and Gate.Get and Gate:Get('LoadState') or nil
    if LS and LS.IsHardUnloaded then
      isHardUnloaded = LS:IsHardUnloaded(nodeId, data) and true or false
    else
      -- Fallback: treat load.never==true as hard-unloaded
      isHardUnloaded = (data and data.load and data.load.never == true) and true or false
    end
  end
  local isGroup = (U and U.IsGroupNode and U:IsGroupNode(data)) and true or false

  local loadText = isHardUnloaded and (L("MENU_LOAD") or "Load") or (L("MENU_UNLOAD") or "Unload")
  local loadAction = isHardUnloaded and "load" or "unload"

  local menu = {
    { text = L("MENU_RENAME") or "Rename", notCheckable = true, func = function() onPick("rename") end },
    { text = L("MENU_COPY") or "Copy", notCheckable = true, func = function() onPick("copy") end },

    -- Load/Unload toggle (UI only in Step2; execution wired in Step3).
    { text = loadText, notCheckable = true, func = function() onPick(loadAction) end },
  }

  if isGroup then
    table.insert(menu, { text = L("MENU_EXPORT") or "Export", notCheckable = true, func = function() onPick("export") end })
  end

  table.insert(menu, { text = L("MENU_DELETE") or "Delete", notCheckable = true, func = function() onPick("delete") end })

  return menu
end

function UI:ShowTreeRowContextMenu(nodeId, anchorFrame)

  local f = self.frame
  if not f or not nodeId then return end

  if not f._rowMenuFrame then
    f._rowMenuFrame = CreateFrame("Frame", "Bre_RowContextMenu", UIParent, "UIDropDownMenuTemplate")
  end

  local function onPick(action)
    local Actions = Bre.Gate:Get("Actions")
    if Actions and Actions.Execute then
      Actions:Execute(action, { nodeId = nodeId })
    end
  end

  local menuList = self:_BuildTreeRowContextMenuList(nodeId, onPick)

  if type(EasyMenu) == "function" then
    EasyMenu(menuList, f._rowMenuFrame, anchorFrame or "cursor", 0, 0, "MENU")
  else
    -- Fallback: UIDropDownMenu_Initialize + ToggleDropDownMenu
    if type(UIDropDownMenu_Initialize) == "function" and type(ToggleDropDownMenu) == "function" then
      UIDropDownMenu_Initialize(f._rowMenuFrame, function(self, level)
        if not level or level ~= 1 then return end
        for _, info in ipairs(menuList) do
          UIDropDownMenu_AddButton(info, level)
        end
      end, "MENU")
      ToggleDropDownMenu(1, nil, f._rowMenuFrame, anchorFrame or "cursor", 0, 0)
    end
  end
end



function UI:BeginInlineRename(nodeId)
  local f = self.frame
  if not f or not nodeId then return end
  -- Resolve visible row for this node
  local row = f._rowById and f._rowById[nodeId] or nil
  if not row or not row._fs or not row._renameEdit then return end

  -- Close any previous inline rename session
  if f._activeRenameRow and f._activeRenameRow ~= row then
    local r = f._activeRenameRow
    if r._renameEdit then r._renameEdit:Hide() end
    if r._fs then r._fs:Show() end
  end
  f._activeRenameRow = row

  local edit = row._renameEdit
  local cur = row._fs:GetText() or ""
  row._fs:Hide()
  edit:Show()
  edit:SetText(cur)
  edit:HighlightText()
  edit:SetFocus()

  local function cancel()
    edit:ClearFocus()
    edit:Hide()
    if row._fs then row._fs:Show() end
    if f._activeRenameRow == row then f._activeRenameRow = nil end
  end

  local function commit()
    local newName = edit:GetText() or ""
    newName = strtrim and strtrim(newName) or (newName:gsub("^%s+",""):gsub("%s+$",""))
    cancel()
    if newName == "" then return end
    local Gate = Bre.Gate
--[[
  ⚠️ ARCH NOTE (Step7)
  Cached module reference detected at file scope:
    local Move = Gate:Get("Move")
  Policy:
  - Avoid caching real module refs at load time.
  - Prefer resolving via Gate:Get(...) at call time or rely on Gate proxy.
  - Step7 does NOT change behavior; this is a guidance marker.
]]
    local Move = Gate:Get("Move")
    if type(Move.RenameNode) == "function" then
      Move:RenameNode(nodeId, newName)
    end
    self:RefreshTree(); self:RefreshRight()
  end

  edit:SetScript("OnEscapePressed", cancel)
  edit:SetScript("OnEnterPressed", commit)
  edit:SetScript("OnEditFocusLost", cancel)
end

function UI:PromptRename(nodeId, onOk)
  local f = self.frame
  if not f then return end
  if not StaticPopupDialogs then return end

  -- IMPORTANT: do not cache OnAccept closure; it must use the latest callback.
  StaticPopupDialogs["BRELMS_RENAME"] = {
    text = L("MENU_RENAME") or "Rename",
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnShow = function(self)
      self.editBox:SetAutoFocus(true)
      self.editBox:SetText("")
      self.editBox:HighlightText()
    end,
    OnAccept = function(self)
      local t = self.editBox:GetText()
      if type(onOk) == "function" then onOk(t) end
    end,
  }

  StaticPopup_Show("BRELMS_RENAME")
end


function UI:ConfirmDelete(nodeId, onOk)
  if not StaticPopupDialogs then return end

  -- IMPORTANT: do not cache OnAccept closure; it must use the latest callback.
  StaticPopupDialogs["BRELMS_DELETE"] = {
    text = (L("MENU_DELETE") or "Delete") .. ": " .. tostring(nodeId),
    button1 = OKAY,
    button2 = CANCEL,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnAccept = function(self)
      if type(onOk) == "function" then onOk() end
    end,
  }

  StaticPopup_Show("BRELMS_DELETE")
end




function UI:OpenExportWindow(text)
  local f = self:EnsureFrame()
  if f._exportWindow then
    local w = f._exportWindow
    -- Keep the export overlay above the main panel.
    if w.SetFrameStrata then w:SetFrameStrata("DIALOG") end
    if w.SetToplevel then w:SetToplevel(true) end
    if self.frame and w.SetFrameLevel then w:SetFrameLevel((self.frame:GetFrameLevel() or 0) + 50) end
    w:Show()
    if w._edit then
      w._edit:SetText(text or "")
      w._edit:SetFocus()
      w._edit:HighlightText()
    end
    if w.Raise then w:Raise() end
    return
  end

  local w = CreateFrame("Frame", "BreExportWindow", UIParent, "BackdropTemplate")
  -- Raise strata/level so it won't be covered by the main panel.
  w:SetFrameStrata("DIALOG")
  w:SetToplevel(true)
  if self.frame and w.SetFrameLevel then w:SetFrameLevel((self.frame:GetFrameLevel() or 0) + 50) end
  w:SetSize(520, 360)
  w:SetPoint("CENTER", 0, 0)
  w:SetMovable(true)
  w:EnableMouse(true)
  w:RegisterForDrag("LeftButton")
  w:SetScript("OnDragStart", function(self) self:StartMoving() end)
  w:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  w:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Buttons/WHITE8x8",
    edgeSize = 2,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  w:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
  w:SetBackdropBorderColor(YELLOW_R, YELLOW_G, YELLOW_B, 1)

  local title = w:CreateFontString(nil, "OVERLAY", (Bre.Font and Bre.Font:Normal() or "GameFontNormal"))
  title:SetPoint("TOPLEFT", 10, -10)
  title:SetTextColor(YELLOW_R, YELLOW_G, YELLOW_B)
  title:SetText(L("MENU_EXPORT") or "Export")

  local close = CreateFrame("Button", nil, w, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)

  local scroll = CreateFrame("ScrollFrame", nil, w, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, -36)
  scroll:SetPoint("BOTTOMRIGHT", -30, 50)

  local edit = CreateFrame("EditBox", nil, scroll)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
	edit:SetFont("Fonts\\ARKai_T.ttf", 13, "")
	edit:SetWidth(460)
	-- IMPORTANT: MultiLine EditBox used as a ScrollChild must have a non-zero height,
	-- otherwise its text will not render (appears empty).
	edit:SetHeight(800)
  edit:SetText(text or "")
  edit:SetScript("OnEscapePressed", function() edit:ClearFocus() end)
  scroll:SetScrollChild(edit)

  local btnClose = CreateFrame("Button", nil, w, "UIPanelButtonTemplate")
  btnClose:SetSize(80, 22)
  btnClose:SetPoint("BOTTOMRIGHT", -12, 12)
  btnClose:SetText(L("BTN_CLOSE") or "Close")
  btnClose:SetScript("OnClick", function() w:Hide() end)

  w._edit = edit
  w:SetScript("OnShow", function()
    edit:SetText(text or edit:GetText() or "")
    edit:SetFocus()
    edit:HighlightText()
  end)

  f._exportWindow = w
  w:Show()
  edit:SetFocus()
  edit:HighlightText()
end

function UI:ShowExportBox(text)
  -- Use the same window style as Import. Keep export UI state driven by explicit refresh/activation.
  if self.OpenExportWindow then
    self:OpenExportWindow(text)
  end
end




function UI:_GetTargetsOrSingle(contextId, requireSameParent)
  local f = self.frame
  if not f then return {} end
  self:_EnsureMultiSel()

  local out = {}
  local meta = f._rowMeta or {}
  local ctx = meta[contextId]
  local ctxParent = (ctx and ctx.parent) or (GetData and (GetData(contextId) or {}).parent) or nil

  local function add(id)
    if id and type(id) == "string" then table.insert(out, id) end
  end

  local st = Sel and Sel.GetState and Sel:GetState() or nil
  local set = st and st.set or nil
  if type(set)=='table' and next(set) ~= nil and set[contextId] then
    for id, on in pairs(set) do
      if on then
        if not requireSameParent then
          add(id)
        else
          local m = meta[id]
          local p = m and m.parent or (GetData and (GetData(id) or {}).parent) or nil
          if p == ctxParent then add(id) end
        end
      end
    end
  else
    add(contextId)
  end

  return out
end

function UI:_MoveSiblingsMulti(ids, dir)
  if type(ids) ~= "table" or #ids == 0 then return end
  dir = tonumber(dir) or 0
  if dir ~= -1 and dir ~= 1 then return end

  local first = GetData and GetData(ids[1])
  if not first or type(first.parent) ~= "string" or first.parent == "" then return end
  local pid = first.parent
  for i = 2, #ids do
    local d = GetData and GetData(ids[i])
    if not d or d.parent ~= pid then return end
  end

  local p = GetData and GetData(pid)
  if not p then return end
  p.controlledChildren = p.controlledChildren or {}
  local arr = p.controlledChildren

  local sel = {}
  for _, id in ipairs(ids) do sel[id] = true end

  if dir == -1 then
    for i = 2, #arr do
      if sel[arr[i]] and not sel[arr[i-1]] then
        arr[i], arr[i-1] = arr[i-1], arr[i]
      end
    end
  else
    for i = #arr - 1, 1, -1 do
      if sel[arr[i]] and not sel[arr[i+1]] then
        arr[i], arr[i+1] = arr[i+1], arr[i]
      end
    end
  end
end

local function makeTreeRow(parent, nodeId, text, indent, y, onClick, isSelected, showMove, hasChildren, expanded, onToggle, iconPath, isGroup, rowW)
  local row = CreateFrame("Button", nil, parent)
  -- BrA-style row height for a thicker, easier-to-hit tree line.
  row:SetSize(rowW or 240, 34)
  -- Keep the row itself left-aligned. Indent is applied to left-side controls only,
  -- so right-side columns (e.g. caret) stay fixed across different depths.
  row:SetPoint("TOPLEFT", 0, y)
  row:SetHighlightTexture("Interface/Buttons/UI-Listbox-Highlight2", "ADD")
local _hl = row:GetHighlightTexture()
if _hl then
  _hl:SetAllPoints()
  _hl:SetVertexColor(1, 1, 1, 0.18)
end
  -- Persistent selection background (not only mouseover highlight)
  local selBg = row:CreateTexture(nil, "BACKGROUND")
  selBg:SetAllPoints()
  selBg:SetTexture("Interface/Buttons/WHITE8x8")
  if Skin and Skin.ApplyRowSelected then
    Skin:ApplyRowSelected(selBg)
  else
    selBg:SetVertexColor(YELLOW_R, YELLOW_G, YELLOW_B, 0.18)
  end
  selBg:Hide()
  row._selBg = selBg

-- Subtle row divider (non-hover). Keep it purely visual.
local div = row:CreateTexture(nil, "ARTWORK")
div:SetTexture("Interface/Buttons/WHITE8x8")
div:SetHeight(1)
div:SetVertexColor(1, 1, 1, 0.05)
div:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 1)
div:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 1)
row._divider = div

row:HookScript("OnEnter", function(self)
  if self._divider then self._divider:Hide() end
end)
row:HookScript("OnLeave", function(self)
  if self._divider then self._divider:Show() end
end)

  row._nodeId = nodeId
  row._depth = math.floor((tonumber(indent) or 0) / 14 + 0.5)
  row._isGroup = isGroup and true or false

  -- Layout anchors (match WA/BrA row anatomy)
  local INDENT = tonumber(indent) or 0
  local X_EXPAND = INDENT + 2
  local X_MOVE_BASE = INDENT + 22
  local X_JOIN = INDENT + 64
  -- NOTE: X_CHECK is a reserved slot used for (hidden) selection placeholder and now also a preview box.
  -- Keep it after move/join cluster, but do not leave an excessive gap.
  -- Align root-level rows: reserve the expand-button slot even when there is no actual +/- button.
  -- This keeps top-level elements and empty groups visually aligned with normal groups.
  local HAS_EXPAND_SLOT = hasChildren or isGroup or (INDENT == 0)
  local X_CHECK = (showMove and (INDENT + 42)) or (HAS_EXPAND_SLOT and (INDENT + 18)) or (INDENT + 2)
  -- Preview box size (and reserved label start) sits on top of the hidden checkbox slot.
  local PREVIEW_W = 28
  local PREVIEW_GAP = 6
  local X_LABEL = X_CHECK + PREVIEW_W + PREVIEW_GAP
  -- Right-side fixed columns (keep inside row hit-rect; do NOT anchor into scrollbar gap)
  local X_EYE   = (rowW or 240) - 18

  -- Join button position differs depending on whether move arrows are present.
  -- When there are no move arrows (root-level nodes), we still want a "join group" entry point.
  local X_JOIN_NO_MOVE = X_EYE - 18

  -- Expand button (+/-) or spacer slot.
  -- When there is no real expand button (e.g. top-level element or empty group), create a mouse-ignored spacer
  -- so the row keeps a consistent left anatomy.
  if HAS_EXPAND_SLOT then
    local ex
    if hasChildren then
      ex = CreateFrame("Button", nil, row)
      ex:SetSize(16, 16)
      ex:SetPoint("LEFT", X_EXPAND, 0)
      local t = ex:CreateFontString(nil, "OVERLAY", (Bre.Font and Bre.Font:HighlightSmall() or "GameFontHighlightSmall"))
      t:SetPoint("CENTER")
      t:SetText(expanded and "-" or "+")
      t:SetTextColor(YELLOW_R, YELLOW_G, YELLOW_B)
      ex._t = t
      ex:SetScript("OnClick", function()
        if type(onToggle) == "function" then onToggle() end
      end)
      row._ex = ex
    else
      -- spacer
      ex = CreateFrame("Frame", nil, row)
      ex:SetSize(16, 16)
      ex:SetPoint("LEFT", X_EXPAND, 0)
      ex:EnableMouse(false)
      row._exSpacer = ex
    end
  end

  -- Selection toggle (checkbox placeholder; future multi-select)
  local cb = CreateFrame("Button", nil, row)
  cb:SetSize(4, 12)
  cb:SetPoint("LEFT", X_CHECK, 0)
  local bg = CreateFrame("Frame", nil, cb, "BackdropTemplate")
  bg:SetAllPoints()
  bg:SetBackdrop({ edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1 })
  bg:SetBackdropBorderColor(YELLOW_R, YELLOW_G, YELLOW_B, 0.35)
  bg:SetBackdropColor(0,0,0,0.15)
  local mark = cb:CreateFontString(nil, "OVERLAY", (Bre.Font and Bre.Font:HighlightSmall() or "GameFontHighlightSmall"))
  mark:SetPoint("CENTER", 0, -0.5)
  mark:SetText("✓")
  mark:SetTextColor(YELLOW_R, YELLOW_G, YELLOW_B)
  mark:Hide()
  cb._mark = mark
  row._check = cb
  -- Hide the left checkbox placeholder visually, but keep its reserved space for layout/drag hit rect.
  cb:SetAlpha(0)
  cb:EnableMouse(false)

  -- Preview box (28px) overlays the hidden checkbox slot.
  -- Purely visual: no clicks, no data writes. Content can be filled by higher-level preview hooks later.
  local pb = CreateFrame("Frame", nil, row, "BackdropTemplate")
  pb:SetSize(PREVIEW_W, PREVIEW_W)
  pb:SetPoint("LEFT", X_CHECK, 0)
  pb:EnableMouse(false)
  pb:SetBackdrop({ edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 8 })
  pb:SetBackdropBorderColor(1, 1, 1, 0.35)
  pb:SetBackdropColor(0, 0, 0, 0)

  -- Preview content texture (filled via Gate->View:GetNodePreview during tree refresh)
  local ptex = pb:CreateTexture(nil, "ARTWORK")
  ptex:SetPoint("TOPLEFT", pb, "TOPLEFT", 2, -2)
  ptex:SetPoint("BOTTOMRIGHT", pb, "BOTTOMRIGHT", -2, 2)
  ptex:Hide()
  pb._tex = ptex
  row._previewBox = pb

  -- Visibility (BrA-style eye): 0/1/2 tri-state (hidden/mixed/shown)
  -- NOTE: Fold/unfold is ONLY via +/- (no extra V/∨ column).
  local eye = CreateFrame("Button", nil, row)
  eye:SetSize(16, 16)
  -- BrA-style: anchor to the right edge of the row so it's always clickable.
  -- (Fix: previous X-based LEFT anchor could place the button outside the row hit-rect,
  -- making it look clickable while actually clicking "air".)
  eye:ClearAllPoints()
  eye:SetPoint("RIGHT", row, "RIGHT", -18, 0)
  eye:EnableMouse(true)
  -- Ensure click is captured by the eye button (not the row) across skins.
  if eye.RegisterForClicks then eye:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
  eye:SetFrameLevel((row:GetFrameLevel() or 0) + 10)
  local eyeTex = eye:CreateTexture(nil, "OVERLAY")
  eyeTex:SetAllPoints()
  eye._tex = eyeTex
  row._eye = eye

  -- ViewService: UI must ONLY go through Gate('View')
local View = _iface('View', nil)
local LoadState = _iface('LoadState')

local function _isHardUnloaded()
  if LoadState and LoadState.IsHardUnloaded then
    return LoadState:IsHardUnloaded(nodeId) and true or false
  end
  if LoadState and LoadState.GetTri then
    return LoadState:GetTri(nodeId) == nil
  end
  return false
end


local function _getVisState()
  if View and View.GetState then
    local s = View:GetState(nodeId)
    if type(s) == "number" then return s end
  end
  return 2
end

local function _setEyeTexture(state)
  -- Keep the exact texture mapping from BrA for instant visual recognition.
  if _isHardUnloaded() then
    -- Visual-only: hard-unloaded nodes look "closed/grey" but do NOT modify hidden state.
    eyeTex:SetTexture("Interface\\LFGFrame\\BattlenetWorking4.blp")
    if eyeTex.SetDesaturated then eyeTex:SetDesaturated(true) end
    eyeTex:SetAlpha(0.35)
    return
  end

  if eyeTex.SetDesaturated then eyeTex:SetDesaturated(false) end
  eyeTex:SetAlpha(1)

  if state == 2 then
    eyeTex:SetTexture("Interface\\LFGFrame\\BattlenetWorking0.blp")
  elseif state == 1 then
    eyeTex:SetTexture("Interface\\LFGFrame\\BattlenetWorking2.blp")
  else
    eyeTex:SetTexture("Interface\\LFGFrame\\BattlenetWorking4.blp")
  end
end

local function _refreshEye()
  _setEyeTexture(_getVisState())
end
row._refreshEye = _refreshEye
_refreshEye()

eye:SetScript("OnClick", function()
  if type(onClick)=="function" then onClick() end
  View = _iface('View', nil)
  if View and View.Toggle then
    View:Toggle(nodeId)
  end
  if row and row._refreshEye then row._refreshEye() end
  if UI and UI.RefreshTree then UI:RefreshTree() end
  if UI and UI.RefreshRight then UI:RefreshRight() end
end)

-- Group icon (inherits)
  if isGroup then
    local ibg = CreateFrame("Frame", nil, row, "BackdropTemplate")
    ibg:SetSize(16, 16)
    ibg:SetPoint("LEFT", X_ICON, 0)
    ibg:SetBackdrop({ edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1 })
    ibg:SetBackdropBorderColor(YELLOW_R, YELLOW_G, YELLOW_B, 0.35)
    ibg:SetBackdropColor(0,0,0,0.15)

    local tex = ibg:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture(iconPath or "Interface/Icons/INV_Misc_QuestionMark")
    tex:SetTexCoord(0.08,0.92,0.08,0.92)
    row._icon = tex
  end


  -- Move arrows (for sub nodes)
  if showMove then
    local ARROW_TEX = "Interface\\AddOns\\BanruoUI_elms\\Media\\Textures\\arrow.tga"
    local BTN = 12  -- hit size
    local VIS = 10  -- visible arrow size (px)
    local GAP = 1   -- vertical gap between arrows

    local function mk(sym, x, y, rot)
      local bb = CreateFrame("Button", nil, row)
      bb:SetSize(BTN, BTN)
      bb:SetPoint("LEFT", x, y)

      local tex = bb:CreateTexture(nil, "OVERLAY")
      tex:SetTexture(ARROW_TEX)
      tex:SetSize(VIS, VIS)
      tex:SetPoint("CENTER")
      if tex.SetRotation and rot then tex:SetRotation(rot) end
      bb._tex = tex

      bb:SetScript("OnClick", function()
        if row._onMove then row._onMove(sym) end
      end)
      return bb
    end

    -- Layout: a vertical column (Up / Left / Down), centered within rowHeight=32
    local dy = VIS + GAP
    row._mvUp   = mk("↑", X_MOVE_BASE,  dy, 0)
    row._mvOut  = mk("↗", X_MOVE_BASE,   0,  math.pi/2) -- visual Left, keep existing behavior token
    row._mvDown = mk("↓", X_MOVE_BASE, -dy, math.pi)
    -- Visual-only: shrink the whole move-arrow cluster (hitbox scales too) 
    local S = 0.85
    if row._mvUp and row._mvUp.SetScale then row._mvUp:SetScale(S) end
    if row._mvOut and row._mvOut.SetScale then row._mvOut:SetScale(S) end
    if row._mvDown and row._mvDown.SetScale then row._mvDown:SetScale(S) end
  end


  local fs = row:CreateFontString(nil, "OVERLAY", (Bre.Font and Bre.Font:Highlight() or "GameFontHighlight"))
  fs:SetPoint("LEFT", X_LABEL, 0)
  fs:SetText(text)
  if isSelected then
    fs:SetTextColor(YELLOW_R, YELLOW_G, YELLOW_B)
  else
    fs:SetTextColor(0.9, 0.9, 0.9)
  end

  if row._selBg then
    if isSelected then row._selBg:Show() else row._selBg:Hide() end
  end

  row._fs = fs

  -- Inline rename editbox (WA/BrA style): shown on demand, commits on Enter, cancels on Esc/blur
  local eb = CreateFrame("EditBox", nil, row)
  eb:SetAutoFocus(false)
  eb:SetFontObject(Bre.Font and Bre.Font:Highlight() or "GameFontHighlight")
  eb:SetHeight(18)
  eb:SetPoint("LEFT", X_LABEL, 0)
  eb:SetPoint("RIGHT", row, "RIGHT", -24, 0) -- leave room for eye button
  if eb.SetTextInsets then eb:SetTextInsets(2, 2, 0, 0) end
  eb:Hide()
  row._renameEdit = eb


  row:RegisterForClicks("AnyUp")
  row:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
      if Bre.UI and Bre.UI.ShowTreeRowContextMenu then
        Bre.UI:ShowTreeRowContextMenu(nodeId, self)
      end
      return
    end
    if type(onClick) == "function" then onClick() end
  end)

  -- Fold/unfold is ONLY via +/- (no double-click toggle).
  row:SetScript("OnDoubleClick", nil)

  -- Hover callbacks (for tooltip/preview modules)
  row:SetScript("OnEnter", function()
    if Bre.UI and Bre.UI._OnTreeRowEnter then
      Bre.UI:_OnTreeRowEnter(nodeId, row)
    end
  end)
  row:SetScript("OnLeave", function()
    if Bre.UI and Bre.UI._OnTreeRowLeave then
      Bre.UI:_OnTreeRowLeave(nodeId, row)
    end
  end)

  
  -- checkbox behavior (mirrors row click selection rules)
  cb:SetScript("OnClick", function()
    if Bre.UI and Bre.UI._HandleTreeRowClick then
      Bre.UI:_HandleTreeRowClick(nodeId, row._depth or 0, row._isGroup or false)
    end
  end)

  -- eye behavior (toggle hidden flag)
  eye:SetScript("OnClick", function()
    if View and View.Toggle then
      View:Toggle(nodeId)
    end
    if row and row._refreshEye then row._refreshEye() end
    if Bre.UI then
      Bre.UI:RefreshTree()
     if Bre.UI and Bre.UI.RefreshRight then Bre.UI:RefreshRight() end
      Bre.UI:RefreshRight()
    end
  end)


  return row
end


-- ------------------------------------------------------------
-- Tree operations (structure only; no rendering)
-- ------------------------------------------------------------
function UI:_RebuildIndexAndRefresh()
  if TreeIndex and TreeIndex.Build then
    TreeIndex:Build()
  end
  self:RefreshTree()
  self:RefreshRight()
  -- Runtime-only layering sync (no DB writes).
  local Move = (Gate and Gate.Get) and Gate:Get("Move") or nil
  if Move and Move.RefreshAutoLevelsByTree then
    pcall(function() Move:RefreshAutoLevelsByTree(nil) end)
  end
end

local function _removeValue(t, val)
  if type(t) ~= "table" then return end
  for i = #t, 1, -1 do
    if t[i] == val then table.remove(t, i) return end
  end
end

function UI:_MoveSibling(id, dir)
  local Move = Gate:Get("Move")
  if Move and Move.MoveSibling then
    local ok = Move:MoveSibling(id, dir)
    if ok then self:_RebuildIndexAndRefresh() end
    return ok
  end
  return false
end

function UI:_DetachToRoot(id)
  local Move = Gate:Get("Move")
  if Move and Move.SetParentAt then
    local ok = Move:SetParentAt(id, nil, nil)
    if ok then self:_RebuildIndexAndRefresh() end
    return ok
  end
  return false
end

function UI:_AttachToGroup(id, targetGroupId)
  if type(targetGroupId) ~= "string" or targetGroupId == "" then return false end
  if _WouldExceedGroupDepthLimit(id, targetGroupId) then return false end
  local Move = Gate:Get("Move")
  if Move and Move.SetParentAt then
    local ok = Move:SetParentAt(id, targetGroupId, nil)
    if ok then self:_RebuildIndexAndRefresh() end
    return ok
  end
  return false
end


function UI:_EnsureRootOrder()
  -- DB initialization is centralized in Core (Gate→DB)
  return (BreSaved and BreSaved.rootChildren) or {}
end

function UI:_GetSiblingArray(parentId)
  if type(parentId) ~= "string" or parentId == "" then
    return self:_EnsureRootOrder()
  end
  local p = GetData and GetData(parentId)
  if not p then return nil end
  p.controlledChildren = p.controlledChildren or {}
  return p.controlledChildren
end

function UI:_MoveNodeToParentAt(id, newParentId, insertIndex)
  if type(newParentId) == "string" and newParentId ~= "" then
    if _WouldExceedGroupDepthLimit(id, newParentId) then return false end
  end
  local Move = Gate:Get("Move")
  if Move and Move.SetParentAt then
    local ok = Move:SetParentAt(id, newParentId, insertIndex)
    if ok then self:_RebuildIndexAndRefresh() end
    return ok
  end
  return false
end

-- ------------------------------------------------------------
-- Tree drag & drop (structure only)
-- ------------------------------------------------------------
function UI:_IsDescendant(potentialChildId, potentialAncestorId)
  if type(potentialChildId) ~= "string" or type(potentialAncestorId) ~= "string" then return false end
  if potentialChildId == potentialAncestorId then return true end
  local cur = GetData and GetData(potentialChildId)
  local guard = 0
  while cur and type(cur.parent) == "string" and cur.parent ~= "" do
    guard = guard + 1
    if guard > 200 then break end
    if cur.parent == potentialAncestorId then return true end
    cur = GetData and GetData(cur.parent)
  end
  return false
end

function UI:_GetNodeIdFromMouseFocus()
  local focus = GetMouseFocus and GetMouseFocus() or nil
  local guard = 0
  while focus and guard < 20 do
    if focus._nodeId then return focus._nodeId, focus end
    focus = focus.GetParent and focus:GetParent() or nil
    guard = guard + 1
  end
  return nil, nil
end

function UI:_HitTestTreeRowUnderCursor()
  local f = self.frame
  if not f or type(f._visibleTreeRows) ~= "table" then return nil end
  -- Prefer the engine's hit-test; it's more reliable than manual cursor math
  -- when the UI is scaled.
  for _, row in ipairs(f._visibleTreeRows) do
    if row:IsShown() and row.IsMouseOver and row:IsMouseOver() then
      return row._nodeId
    end
  end

  -- Fallback: manual cursor math (rarely needed)
  local x, y = GetCursorPosition()
  local s = UIParent:GetEffectiveScale()
  x, y = x / s, y / s

  for _, row in ipairs(f._visibleTreeRows) do
    if row:IsShown() then
      local l, r, t, b = row:GetLeft(), row:GetRight(), row:GetTop(), row:GetBottom()
      if l and r and t and b and x >= l and x <= r and y <= t and y >= b then
        return row._nodeId
      end
    end
  end
  return nil
end

function UI:BeginTreeDrag(id)
  local f = self.frame
  if not f or not id then 
    return 
  end

  -- If dragging starts on a selected node, drag the entire selection.
  local targets = self:_GetTargetsOrSingle(id, false)
  f._draggingId = id
  f._draggingIds = targets

  if not f._dragTip then
    local tip = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    tip:SetSize(140, 22)
    tip:SetFrameStrata("TOOLTIP")
    tip:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8", edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1 })
    tip:SetBackdropColor(0, 0, 0, 0.85)
    tip:SetBackdropBorderColor(YELLOW_R, YELLOW_G, YELLOW_B, 0.65)
    local fs = tip:CreateFontString(nil, "OVERLAY", (Bre.Font and Bre.Font:HighlightSmall() or "GameFontHighlightSmall"))
    fs:SetPoint("CENTER")
    fs:SetTextColor(1, 1, 1)
    tip._fs = fs
    tip:Hide()
    f._dragTip = tip
  end

  local U = getBindings()
  local data = U and safeCall(U.GetNode, U, id) or nil
  local rawLabel = (U and safeCall(U.GetDisplayLabel, U, id, data)) or tostring(id)
  local label = _StripTypeSuffix(rawLabel)

  if type(targets) == "table" and #targets > 1 then
    label = string.format("%s (+%d)", label, #targets - 1)
  end

  f._dragTip._fs:SetText(label)
  f._dragTip:Show()
  f._dragTip:SetScript("OnUpdate", function(self)
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s + 16, y / s - 16)
  end)
end

function UI:EndTreeDrag(sourceId)
  print("=================================================================")
  print("=================================================================")
  local f = self.frame
  if not f then 
    return 
  end
  local draggingId = f._draggingId
  local draggingIds = f._draggingIds
  f._draggingId = nil
  f._draggingIds = nil
  if f._dragTip then
    f._dragTip:SetScript("OnUpdate", nil)
    f._dragTip:Hide()
  end

  if not draggingId then return end

  -- During drag, mouse focus is often the drag tip or nil.
  -- Use a manual hit-test against the rendered tree rows.
  local targetId = self:_HitTestTreeRowUnderCursor() or self:_GetNodeIdFromMouseFocus()
  if not targetId then return end

  local U = getBindings()
  local tdata = U and safeCall(U.GetNode, U, targetId) or nil
  if not tdata then return end

  local list = (type(draggingIds) == "table" and #draggingIds > 0) and draggingIds or { draggingId }

  -- Default behavior: reorder within the target row's parent list (root/group).
  -- Drop onto a group: attach selected nodes into that group (insert at first).
  -- Rule: groups may be nested (group -> group is allowed). Elements may NOT become children of elements.
  local isTargetGroup = U and safeCall(U.IsGroupNode, U, tdata) or false
  if not isTargetGroup then
    -- Heuristic for legacy/edge cases where a group node may not carry regionType yet.
    -- IMPORTANT: Do NOT treat presence of controlledChildren as "group", because NormalizeNode
    -- ensures controlledChildren is always a table (including for non-group elements).
    if type(tdata) == "table" then
      if type(tdata.id) == "string" and tdata.id:match("^Group_") then
        isTargetGroup = true
      elseif tdata.isGroup == true then
        isTargetGroup = true
      end
    end
  end
  if isTargetGroup then
    -- Attach into group (first position)
    local targetGroupId = targetId
    local g = GetData and GetData(targetGroupId)
    if not g then 
      return 
    end
    g.controlledChildren = g.controlledChildren or {}

    local insertAt = 1
    for _, nid in ipairs(list) do
      -- Prevent cycles: never move a node into its own subtree.
      if nid ~= targetGroupId and not self:_IsDescendant(targetGroupId, nid) then
        self:_MoveNodeToParentAt(nid, targetGroupId, insertAt)
        insertAt = insertAt + 1
      else
      end
    end
  else
    local targetParent = tdata.parent
    local targetArr = self:_GetSiblingArray(targetParent)
    if not targetArr then return end

    local targetIdx = 1
    for i, cid in ipairs(targetArr) do
      if cid == targetId then targetIdx = i break end
    end

    -- Build original position map for target parent to adjust insert index when moving within the same list.
    local posMap = {}
    for i, cid in ipairs(targetArr) do posMap[cid] = i end

    local insertAt = targetIdx

    for _, nid in ipairs(list) do
      -- Prevent cycles: do not move a node into a parent that is inside its own subtree
      if nid ~= targetId and not self:_IsDescendant(targetParent or "", nid) then
        local nd = GetData and GetData(nid)
        local oldParent = nd and nd.parent

        if oldParent == targetParent and posMap[nid] and posMap[nid] < insertAt then
          insertAt = insertAt - 1
        end

        if not self:_IsDescendant(targetParent or "", nid) then
          self:_MoveNodeToParentAt(nid, targetParent, insertAt)
          insertAt = insertAt + 1
        end
      end
    end
  end

  self:_RebuildIndexAndRefresh()
end

function UI:RefreshTree()
  local f = self.frame
  if not f then return end

  local left = f._body._inner._left
  local content = left._content
  -- Tree row width: match the visible scroll area (left panel width minus scroll bar + small padding).
  -- (BrA-style: each row fills the full available width.)
  local rowW = math.max(80, (left:GetWidth() or 240) - 10 - 16)
  clearButtons(f)

  -- Track rows drawn this pass for cursor hit-testing (drag & drop).
  f._visibleTreeRows = {}
  f._rowById = {}

  -- Multi-selection render context (visible order + meta for shift range)
  f._rowOrder = {}
  f._rowMeta = {}

  local U = getBindings()
  local roots = U and safeCall(U.ListRoots, U) or {}

  local hdrLoaded = left._hdrLoaded
  local hdrUnloaded = left._hdrUnloaded
  if hdrLoaded then
    hdrLoaded:ClearAllPoints()
	  hdrLoaded:SetPoint("TOPLEFT", 8, -8)
    hdrLoaded:Show()
  end
  if hdrUnloaded then
    hdrUnloaded:ClearAllPoints()
    hdrUnloaded:SetPoint("TOPLEFT", 12, -192) -- placeholder; will be moved after loaded section
    hdrUnloaded:Hide()
  end

  -- Start rows below the "Loaded" header.
  -- Start rows below the "Loaded" header. Row height is 32, so keep a clear gap.
  local y = -26


  local function nodeMatchesSearch(label)
    local q = (left._searchEdit and left._searchEdit:GetText()) or ""
    q = (q or "")
    if q == "" then return true end
    q = string.lower(q)
    label = string.lower(label or "")
    return string.find(label, q, 1, true) ~= nil
  end

  local function addNode(id, depth)
    local data = U and safeCall(U.GetNode, U, id) or nil
    if Bre.Contract and Bre.Contract.NormalizeNode then
      data = Bre.Contract:NormalizeNode(id, data)
      -- NOTE(v2.10.32): Do NOT write back normalized node during tree refresh (prevents global size pollution).
    end

    local children = U and safeCall(U.ListChildren, U, id) or {}
    local hasChildren = type(children) == "table" and #children > 0

    -- Determine node type early so we can apply sane defaults.
    local isGroup = U and safeCall(U.IsGroupNode, U, data) or false

    -- Expanded state: persisted per-group. Default = expanded.
    if isGroup and f._expanded[id] == nil then
      local saved = API.GetTreeExpanded and API:GetTreeExpanded(id) or nil
      if saved == nil then
        f._expanded[id] = true
        if API.SetTreeExpanded then API:SetTreeExpanded(id, true) end
      else
        f._expanded[id] = (saved and true) or false
      end
    end
    local expanded = f._expanded[id] or false

    local rawLabel = (U and safeCall(U.GetDisplayLabel, U, id, data)) or tostring(id)
    local label = _StripTypeSuffix(rawLabel)

    -- Search filter: show node if it matches, or if any descendant matches.
    local function anyDescMatch()
      if nodeMatchesSearch(label) then return true end
      if not hasChildren then return false end
      for _, cid in ipairs(children) do
        local cdata = U and safeCall(U.GetNode, U, cid) or nil
        local crawLabel = (U and safeCall(U.GetDisplayLabel, U, cid, cdata)) or tostring(cid)
        local clabel = _StripTypeSuffix(crawLabel)
        if string.find(string.lower(clabel), string.lower((left._searchEdit and left._searchEdit:GetText()) or ""), 1, true) then
          return true
        end
      end
      return false
    end

    if not anyDescMatch() then
      return
    end

    local indent = depth * 14

    local iconPath = (U and safeCall(U.GetInheritedGroupIconPath, U, id, data))

    local row = makeTreeRow(content, id, label, indent, y,
      function()
        UI:_HandleTreeRowClick(id, depth, isGroup)
      end,
      (f._selectedId == id) or ((Sel and Sel.IsSelected and Sel:IsSelected(id)) and true or false),
      depth > 0,
      hasChildren,
      expanded,
      function()
        local newState = not expanded
        f._expanded[id] = newState
        if API.SetTreeExpanded then API:SetTreeExpanded(id, newState) end
        UI:RefreshTree()
      end,
      iconPath, isGroup, rowW
    )

    -- TreeRow preview binding (static): fill preview box via Gate -> View:GetNodePreview().
    -- Purely visual; must not write DB or trigger commits.
    do
      local pb = row and row._previewBox
      local ptex = pb and pb._tex
      if pb and ptex and (not isGroup) then
        local Gate = Bre and Bre.Gate
        local View = (Gate and Gate.Get and Gate:Get('View')) or nil
        local desc = (View and View.GetNodePreview and View:GetNodePreview(id)) or nil
        if type(desc) == "table" and (desc.kind == "texture" or desc.kind == (Bre.PreviewTypes and Bre.PreviewTypes.KIND_TEXTURE)) and type(desc.tex) == "string" and desc.tex ~= "" then
          ptex:SetTexture(desc.tex)
          if type(desc.texCoord) == "table" and #desc.texCoord >= 4 and ptex.SetTexCoord then
            ptex:SetTexCoord(desc.texCoord[1], desc.texCoord[2], desc.texCoord[3], desc.texCoord[4])
          else
            if ptex.SetTexCoord then ptex:SetTexCoord(0, 1, 0, 1) end
          end
          if type(desc.color) == "table" and #desc.color >= 4 and ptex.SetVertexColor then
            ptex:SetVertexColor(desc.color[1], desc.color[2], desc.color[3], desc.color[4])
          else
            if ptex.SetVertexColor then ptex:SetVertexColor(1, 1, 1, 1) end
          end
          ptex:Show()
        else
          ptex:Hide()
        end
      elseif pb and ptex and isGroup then
        -- Groups: show inherited iconPath in preview box (purely visual).
        if type(iconPath) == "string" and iconPath ~= "" then
          ptex:SetTexture(iconPath)
          if ptex.SetTexCoord then ptex:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
          if ptex.SetVertexColor then ptex:SetVertexColor(1, 1, 1, 1) end
          ptex:Show()
        else
          ptex:Hide()
        end
      elseif pb and ptex then
        ptex:Hide()
      end
    end

    row._nodeId = id
    f._rowById[id] = row
    if row._check and row._check._mark then
      if Sel and Sel.IsSelected and Sel:IsSelected(id) then row._check._mark:Show() else row._check._mark:Hide() end
    end
    f._rowOrder[#f._rowOrder + 1] = id
    f._rowMeta[id] = { parent = (data and data.parent) or nil, depth = depth, isGroup = isGroup and true or false, selectable = UI:_IsSelectableNode(isGroup, depth) }
    table.insert(f._visibleTreeRows, row)
    -- Drag & drop: hold then drag node into another group.
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", function(self)
      UI:BeginTreeDrag(self._nodeId)
    end)
    row:SetScript("OnDragStop", function(self)
      UI:EndTreeDrag(self._nodeId)
    end)
    row._onMove = function(sym)
      if sym == "↑" then
        local targets = UI:_GetTargetsOrSingle(id, true)
        UI:_MoveSiblingsMulti(targets, -1)
        UI:_RebuildIndexAndRefresh()
      elseif sym == "↓" then
        local targets = UI:_GetTargetsOrSingle(id, true)
        UI:_MoveSiblingsMulti(targets, 1)
        UI:_RebuildIndexAndRefresh()
      elseif sym == "↗" then
        local targets = UI:_GetTargetsOrSingle(id, false)
        for _, nid in ipairs(targets) do
          UI:_DetachToRoot(nid)
        end
        UI:_RebuildIndexAndRefresh()
      end
    end
    table.insert(f._buttons, row)
    y = y - 32

    if expanded and hasChildren then
      for _, cid in ipairs(children) do
        addNode(cid, depth + 1)
      end
    end
  end


  if type(roots) == "table" then
    local rootsLoaded, rootsUnloaded = {}, {}
    for _, rid in ipairs(roots) do
      local rdata = (U and safeCall(U.GetNode, U, rid)) or (GetData and GetData(rid)) or nil
      local LS = Gate and Gate.Get and Gate:Get('LoadState')
      -- Tree section split (BrA-aligned):
      --   Unloaded section  => loadedTri == nil
      --   Loaded section    => loadedTri ~= nil (includes standby=false)
      local tri = false
      if LS and LS.GetTri then
        tri = LS:GetTri(rid, rdata)
      end
      if tri == nil then
        table.insert(rootsUnloaded, rid)
      else
        table.insert(rootsLoaded, rid)
      end
    end

    for _, rid in ipairs(rootsLoaded) do
      addNode(rid, 0)
    end

    if #rootsUnloaded > 0 and hdrUnloaded then
      hdrUnloaded:ClearAllPoints()
      hdrUnloaded:SetPoint("TOPLEFT", 12, y - 10)
      hdrUnloaded:Show()
            y = y - 33  -- extra spacing under Unloaded header (+15px)
      for _, rid in ipairs(rootsUnloaded) do
        addNode(rid, 0)
      end
    end
  end

  content:SetHeight(math.max(1, -y + 10))

-- Ensure ScrollChild rect + scrollbar range are refreshed, and clamp current scroll offset.
local scroll = left._scroll
if scroll and scroll.UpdateScrollChildRect then
  scroll:UpdateScrollChildRect()
end
if left._ClampTreeScroll then
  left._ClampTreeScroll()
end

end

function UI:RefreshRight()
--[[ ARCH HARDENING (Step5)
  RefreshRight MUST be side-effect free: UI refresh must not trigger commits.
  Enforce entering EditGuard structurally (no behavior intent change).
]]
local eg = Gate:Get("EditGuard")
if eg and eg.RunGuarded then
  return eg:RunGuarded("RefreshRight", function()
    local f = self.frame
    if not f then return end

    local right = f._body._inner._right
    if not right then return end

    if f._showingNew then
      -- Overlay ignores selection
      return
    end

    local EG = Gate:Get('EditGuard')
    if EG and EG.Begin then EG:Begin('RefreshRight') end

    -- Sync right mode (Group vs Element) based on current selection
    self:_EnsureRightMode()

    local id = f._selectedId

    -- Ensure the actually-visible pane matches the resolved right tab.
    -- (Selection can change mode without clicking a tab; prevent overlapping panes.)
    local showKey = f._rightTab or "Element"
    if f._rightMode == "GROUP" then
      -- Primary tab is stored as "Group"; tolerate legacy/default "Element".
      if showKey == "Element" then showKey = "Group" end
    else
      -- Element mode: if we were on Group, fall back to last element tab.
      if showKey == "Group" then
        showKey = f._lastElementTab or "Element"
      end

      -- Align with Element pane behavior: when there is no active selection,
      -- force the primary Element pane to be visible (hide Actions/other tabs).
      if not id then
        showKey = "Element"
        f._rightTab = "Element"
        f._lastElementTab = "Element"
        for k, b in pairs(right._tabBtns or {}) do
          if b:IsShown() then
            b:SetActive(k == "Element")
          else
            b:SetActive(false)
          end
        end
      end
    end
    for k, p in pairs(right._panes or {}) do
      p:SetShown(k == showKey and not f._showingNew)
    end

    -- Template-based drawers for secondary tabs (Actions / Conditions).
    -- Mutex may have hidden drawers; ensure the active pane's drawer is shown and refreshed.
    do
      local DT = Bre.DrawerTemplate
      if showKey == "Actions" then
        local ap = right._panes and right._panes.Actions
        if ap and ap._drawerActions_new then
          ap._drawerActions_new:Show()
          if DT and DT.Refresh then DT:Refresh(ap._drawerActions_new, id) end
        end
      elseif showKey == "Conditions" then
        local cp = right._panes and right._panes.Conditions
        if cp and cp._drawerConditions_new then
          cp._drawerConditions_new:Show()
          if DT and DT.Refresh then DT:Refresh(cp._drawerConditions_new, id) end
        end
      end
    end


    -- Update hint labels for each pane
    for _, p in pairs(right._panes or {}) do
      if p._hint then
        if id then
          p._hint:SetText(string.format("%s: %s", L("SELECTED"), tostring(id)))
        else
          p._hint:SetText(L("SELECT_HINT"))
        end
      end
    end

    -- Data getter (single source of truth): prefer Gate->API_Data
    local API = Gate and Gate.Get and Gate:Get('API_Data')
    local function _GetData(nid)
      if type(nid) ~= 'string' then return nil end
      if API and API.GetData then
        return API:GetData(nid)
      end
      local U = UIB
      if U and U.GetNode then
        return safeCall(U.GetNode, U, nid)
      end
      return (GetData and GetData(nid)) or nil
    end

    -- Group pane binding (minimal field: iconPath)
    -- v2.19.0: Child groups (nested groups) should not show Group pane
    local gp = right._panes and right._panes.Group
    if gp then
      local function _SetScaleEnabled(on)
        local blk = gp._grpAttrScale
        if not blk then return end
        if blk.slider then
          blk.slider:EnableMouse(on and true or false)
          blk.slider:SetAlpha(on and 1 or 0.35)
        end
        if blk.num then
          blk.num:SetEnabled(on and true or false)
          blk.num:SetAlpha(on and 1 or 0.35)
        end
      end

      if id then
        local data = _GetData(id)
        local U = UIB
        local isGroup = U and safeCall(U.IsGroupNode, U, data) or false
        local groupDepth = isGroup and _GetGroupDepth(id, data) or 0
        -- v2.19.8: Only depth 1-2 groups show Group drawer
        local allowGroupDrawer = isGroup and groupDepth > 0 and groupDepth <= GROUP_DRAWER_MAX_DEPTH

        if gp._groupIconEdit then
          gp._groupIconEdit:SetEnabled(allowGroupDrawer and true or false)
          gp._groupIconEdit._editBindNodeId = id
          gp._groupIconEdit._editBindRev = _EnsureEditSession(f).rev
          if allowGroupDrawer then
            local own = U and safeCall(U.GetGroupIconPath, U, id, data) or nil
            gp._groupIconEdit:SetText(own or "")
             if gp._groupIconPreviewTex then
               local eff = U and safeCall(U.GetInheritedGroupIconPath, U, id, data) or own
               if type(eff) == "string" and eff ~= "" then
                 gp._groupIconPreviewTex:SetTexture(eff)
               else
                 gp._groupIconPreviewTex:SetTexture(nil)
               end
             end
          else
            gp._groupIconEdit:SetText("")
             if gp._groupIconPreviewTex then gp._groupIconPreviewTex:SetTexture(nil) end
            gp._groupIconEdit._editBindNodeId = nil
            gp._groupIconEdit._editBindRev = _EnsureEditSession(f).rev
          end
        end

        -- Step5: Group Scale UI routing + bind nodeId
        -- v2.19.9: Scale controls must remain usable for allowed Group drawers (depth 1-2).
        if gp._groupScale_SetUI then
          local v = 1
          if allowGroupDrawer and type(data.group) == "table" then
            v = tonumber(data.group.scale) or 1
          end
          _SetScaleEnabled(allowGroupDrawer and true or false)
          gp._groupScale_bindNodeId = (allowGroupDrawer and id) or nil
          gp._groupScale_SetUI(v)
        else
          _SetScaleEnabled(false)
          gp._groupScale_bindNodeId = nil
        end
      else
        if gp._groupIconEdit then
          gp._groupIconEdit:SetText("")
          gp._groupIconEdit._editBindNodeId = nil
          gp._groupIconEdit._editBindRev = _EnsureEditSession(f).rev
          gp._groupIconEdit:SetEnabled(false)
           if gp._groupIconPreviewTex then gp._groupIconPreviewTex:SetTexture(nil) end
        end
        _SetScaleEnabled(false)
        if gp then gp._groupScale_bindNodeId = nil end
        if gp._groupScale_SetUI then gp._groupScale_SetUI(1) end
      end
    end

    -- Element pane binding (custom texture)
    local ep = right._panes and right._panes.Element
    local selData = nil
    if id then selData = _GetData(id) end

    -- Drawer routing via API (Step2 v2.14.3)
    -- [SCROLL LOCATOR] CustomMat drawer is shown when Element pane routes:
    --   ep:OpenDrawer("CustomMat")  -> right pane uses Bre_ElementPaneScroll (see BuildElementPane).
    if ep and ep.OpenDrawer and ep.CloseAll then
      local U = UIB
      local isGroup = false
      local isChildGroup = false
      if U and type(selData) == "table" then
        isGroup = safeCall(U.IsGroupNode, U, selData) or false
        -- v2.19.0: Check if this is a child group
        isChildGroup = isGroup and (type(selData.parent) == "string" and selData.parent ~= "")
      end

      local isProgress = false
      local isCustom = false
      local isModel = false
      local isStopMotion = false
      if type(selData) == "table" then
        if selData.regionType == "progress" then
          isProgress = true
        elseif type(selData.features) == "table" and selData.features.progress then
          isProgress = true
        elseif type(selData.region) == "table" and type(selData.region.progress) == "table" then
          isProgress = true
        end

        if selData.regionType == "custom" then
          isCustom = true
        elseif type(selData.features) == "table" and selData.features.custom then
          isCustom = true
        end

        if selData.regionType == "model" then
          isModel = true
        elseif type(selData.features) == "table" and selData.features.model then
          isModel = true
        end

        if selData.regionType == "stopmotion" then
          isStopMotion = true
        elseif type(selData.features) == "table" and selData.features.stopmotion then
          isStopMotion = true
        end
      end

      -- v2.19.0: Close all drawers for child groups (nested groups)
      if (not id) or isChildGroup or type(selData) ~= "table" then
        ep:CloseAll()
        f._rightDrawer = nil
      -- v2.19.0: Top-level groups also close all drawers (Group pane shows instead)
      elseif isGroup and not isChildGroup then
        ep:CloseAll()
        f._rightDrawer = nil
      else
        -- ThemeMinimal routing (opt-in; no behavior change unless explicitly enabled)
        local W = Bre and Bre.UIWhitelist
        local themeMinimal = W and W.state and W.state.enabled and W.state.theme_minimal_mode
        if themeMinimal then
          ep:OpenDrawer("ThemeMinimal")
          f._rightDrawer = "ThemeMinimal"
        elseif isProgress then
          ep:OpenDrawer("ProgressMat")
          f._rightDrawer = "ProgressMat"
        elseif isModel then
          ep:OpenDrawer("Model")
          f._rightDrawer = "Model"
        elseif isStopMotion then
          ep:OpenDrawer("StopMotion")
          f._rightDrawer = "StopMotion"
        elseif isCustom then
          ep:OpenDrawer("CustomMat")
          f._rightDrawer = "CustomMat"
        else
          ep:CloseAll()
          f._rightDrawer = nil
        end
      end
    end

    if ep and ep._elemMat and ep._activeDrawerId == "CustomMat" then
      -- Step5 (v2.14.69): Support new template-based drawer refresh
      local USE_NEW_DRAWER = (ep._drawerCustomMat_new ~= nil)
      
      if USE_NEW_DRAWER and ep._drawerCustomMat_new then
        -- New template-based drawer
        local DT = Bre.DrawerTemplate
        if DT and DT.Refresh then
          DT:Refresh(ep._drawerCustomMat_new, id)
        end
      else
        -- Old drawer (keep existing logic)
        local m = ep._elemMat
      m._suppressCommit = true
      if id then
          local data = _GetData(id)
        local U = UIB
        local isGroup = U and safeCall(U.IsGroupNode, U, data) or false
        local enabled = (not isGroup)
        if not enabled then m._editId = nil; m._editBindNodeId = nil; m._editBindRev = _EnsureEditSession(f).rev end
        m.edit:SetEnabled(enabled)
        m.useColor:SetEnabled(enabled)
        m.mirror:SetEnabled(enabled)
        m.alpha:SetEnabled(enabled)
        if m.alphaNum and m.alphaNum.SetEnabled then m.alphaNum:SetEnabled(enabled) end
        m.rot:SetEnabled(enabled)
        if m.rotNum and m.rotNum.SetEnabled then m.rotNum:SetEnabled(enabled) end
        if enabled and type(data) == "table" then
          m._editId = id
          m._editBindNodeId = id
          m._editBindRev = _EnsureEditSession(f).rev
          data.region = type(data.region) == "table" and data.region or {}
          local tex = data.region.texture or ""
          if m.edit:GetText() ~= tex then m.edit:SetText(tex) end
          m.useColor:SetChecked(data.region.useColor and true or false)
          m.mirror:SetChecked(data.region.mirror and true or false)
          local blend = data.region.blendMode or "BLEND"
          UIDropDownMenu_SetText(m.blendDD, blend)
          local a = tonumber(data.alpha) or 1
          m.alpha:SetValue(a)
          if m.alphaNum and m.alphaNum.SetText then
            m._updatingAlpha = true
            m.alphaNum:SetText(string.format("%.2f", a))
            m._updatingAlpha = false
          end
          local rdeg = tonumber(data.region.rotation) or 0
          m.rot:SetValue(rdeg)
          if m.rotNum and m.rotNum.SetText then
            m._updatingRot = true
            m.rotNum:SetText(tostring(math.floor((tonumber(rdeg) or 0) + 0.5)))
            m._updatingRot = false
          end

          -- position intent sync (data.props)
          data.props = type(data.props) == "table" and data.props or {}
          local at = data.props.anchorTarget or "SCREEN_CENTER"
          -- UI-only: hide SELECTED_NODE mode; treat as SCREEN_CENTER on refresh
          if at ~= "SCREEN_CENTER" then at = "SCREEN_CENTER" end
          local fs = data.props.frameStrata or "AUTO"
          if fs ~= "AUTO" and fs ~= "BACKGROUND" and fs ~= "LOW" and fs ~= "MEDIUM" and fs ~= "HIGH" and fs ~= "DIALOG" and fs ~= "FULLSCREEN" and fs ~= "FULLSCREEN_DIALOG" and fs ~= "TOOLTIP" then
            fs = "AUTO"
          end

          if m._AlignDetach then m:_AlignDetach() end
          m._updatingAlign = true        if m.alignTo then
            UIDropDownMenu_SetText(m.alignTo, L("ELEM_MAT_ALIGN_TO_SCREEN_CENTER"))
            UIDropDownMenu_SetSelectedValue(m.alignTo, "SCREEN_CENTER")
          end
          m._updatingAlign = false
          if m._AlignAttach then m:_AlignAttach() end

          -- frame level intent sync (data.props)
          if m._FrameLevelDetach then m:_FrameLevelDetach() end
          m._updatingFrameLevel = true
          if m.frameLevel then
            if fs == "BACKGROUND" then
              UIDropDownMenu_SetText(m.frameLevel, L("ELEM_MAT_FRAME_LEVEL_BACKGROUND"))
            elseif fs == "LOW" then
              UIDropDownMenu_SetText(m.frameLevel, L("ELEM_MAT_FRAME_LEVEL_LOW"))
            elseif fs == "MEDIUM" then
              UIDropDownMenu_SetText(m.frameLevel, L("ELEM_MAT_FRAME_LEVEL_MEDIUM"))
            elseif fs == "HIGH" then
              UIDropDownMenu_SetText(m.frameLevel, L("ELEM_MAT_FRAME_LEVEL_HIGH"))
            elseif fs == "DIALOG" then
              UIDropDownMenu_SetText(m.frameLevel, L("ELEM_MAT_FRAME_LEVEL_DIALOG"))
            elseif fs == "FULLSCREEN" then
              UIDropDownMenu_SetText(m.frameLevel, L("ELEM_MAT_FRAME_LEVEL_FULLSCREEN"))
            elseif fs == "FULLSCREEN_DIALOG" then
              UIDropDownMenu_SetText(m.frameLevel, L("ELEM_MAT_FRAME_LEVEL_FULLSCREEN_DIALOG"))
            elseif fs == "TOOLTIP" then
              UIDropDownMenu_SetText(m.frameLevel, L("ELEM_MAT_FRAME_LEVEL_TOOLTIP"))
            else
              UIDropDownMenu_SetText(m.frameLevel, L("ELEM_MAT_FRAME_LEVEL_AUTO"))
            end
          end
          m._updatingFrameLevel = false
          if m._FrameLevelAttach then m:_FrameLevelAttach() end
          -- size sync (data.size)
          local sw = (data.size and tonumber(data.size.width)) or 200
          local sh = (data.size and tonumber(data.size.height)) or 200

          -- Hard-isolate refresh from any commits: detach handlers, set values, then re-attach
          if m._SizeDetach then m:_SizeDetach() end
          m._updatingSize = true
          if m.w1 then m.w1:SetMinMaxValues(1, 2048); m.w1:SetValueStep(1); m.w1:SetValue(sw) end
          if m.h1 then m.h1:SetMinMaxValues(1, 2048); m.h1:SetValueStep(1); m.h1:SetValue(sh) end
          if m.wNum and m.wNum.SetText then m.wNum:SetText(tostring(sw)) end
          if m.hNum and m.hNum.SetText then m.hNum:SetText(tostring(sh)) end
          m._updatingSize = false
          if m._SizeAttach then m:_SizeAttach() end

          if m._OffsetDetach then m:_OffsetDetach() end
          m._updatingOffset = true
          if m.xOff then m.xOff:SetMinMaxValues(-4096, 4096); m.xOff:SetValueStep(0.5); m.xOff:SetObeyStepOnDrag(true); m.xOff:SetValue(0) end
          if m.yOff then m.yOff:SetMinMaxValues(-4096, 4096); m.yOff:SetValueStep(0.5); m.yOff:SetObeyStepOnDrag(true); m.yOff:SetValue(0) end
          if m.xNum and m.xNum.SetText then m.xNum:SetText("0") end
          if m.yNum and m.yNum.SetText then m.yNum:SetText("0") end
          m._updatingOffset = false
          if m._OffsetAttach then m:_OffsetAttach() end

          -- position offsets sync (data.props.xOffset/yOffset)
          local xo = tonumber(data.props.xOffset) or 0
          local yo = tonumber(data.props.yOffset) or 0
          if m._OffsetDetach then m:_OffsetDetach() end
          m._updatingOffset = true
          if m.xOff then
            -- Range will be finalized in Step4; keep a safe, wide range for now.
            m.xOff:SetMinMaxValues(-4096, 4096)
            m.xOff:SetValueStep(0.5)
            m.xOff:SetObeyStepOnDrag(true)
            m.xOff:SetValue(xo)
          end
          if m.yOff then
            m.yOff:SetMinMaxValues(-4096, 4096)
            m.yOff:SetValueStep(0.5)
            m.yOff:SetObeyStepOnDrag(true)
            m.yOff:SetValue(yo)
          end
          if m.xNum and m.xNum.SetText then m.xNum:SetText(tostring(xo)) end
          if m.yNum and m.yNum.SetText then m.yNum:SetText(tostring(yo)) end
          m._updatingOffset = false
          if m._OffsetAttach then m:_OffsetAttach() end
          local c = data.region.color or { r=1,g=1,b=1,a=1 }
          if m.colorBtn and m.colorBtn._swatch and m.colorBtn._swatch.SetColorTexture then
            m.colorBtn._swatch:SetColorTexture(c.r or 1, c.g or 1, c.b or 1, c.a or 1)
          end

          -- preview sync
          if m.applyPreview and m.previewTex then
            m.applyPreview(m.previewTex, data.region, data.alpha)
          end
        else
          m._editId = nil
          m._editBindNodeId = nil
          m._editBindRev = _EnsureEditSession(f).rev
          if m.edit:GetText() ~= "" then m.edit:SetText("") end
          m.useColor:SetChecked(false)
          m.mirror:SetChecked(false)
          UIDropDownMenu_SetText(m.blendDD, "BLEND")
          m.alpha:SetValue(1)
          if m.alphaNum and m.alphaNum.SetText then
            m._updatingAlpha = true
            m.alphaNum:SetText("1.00")
            m._updatingAlpha = false
          end
          m.rot:SetValue(0)
          if m.rotNum and m.rotNum.SetText then
            m._updatingRot = true
            m.rotNum:SetText("0")
            m._updatingRot = false
          end
          if m._SizeDetach then m:_SizeDetach() end
          m._updatingSize = true
          if m.w1 then m.w1:SetMinMaxValues(1, 2048); m.w1:SetValueStep(1); m.w1:SetValue(200) end
          if m.h1 then m.h1:SetMinMaxValues(1, 2048); m.h1:SetValueStep(1); m.h1:SetValue(200) end
          if m.wNum and m.wNum.SetText then m.wNum:SetText("200") end
          if m.hNum and m.hNum.SetText then m.hNum:SetText("200") end
          m._updatingSize = false
          if m._SizeAttach then m:_SizeAttach() end

          if m._OffsetDetach then m:_OffsetDetach() end
          m._updatingOffset = true
          if m.xOff then m.xOff:SetMinMaxValues(-4096, 4096); m.xOff:SetValueStep(0.5); m.xOff:SetValue(0) end
          if m.yOff then m.yOff:SetMinMaxValues(-4096, 4096); m.yOff:SetValueStep(0.5); m.yOff:SetValue(0) end
          if m.xNum and m.xNum.SetText then m.xNum:SetText("0") end
          if m.yNum and m.yNum.SetText then m.yNum:SetText("0") end
          m._updatingOffset = false
          if m._OffsetAttach then m:_OffsetAttach() end
          if m.colorBtn and m.colorBtn._swatch and m.colorBtn._swatch.SetColorTexture then
            m.colorBtn._swatch:SetColorTexture(1,1,1,1)
          end

          if m.applyPreview and m.previewTex then
            m.applyPreview(m.previewTex, {}, 1)
          end
        end
      else
        m.edit:SetText("")
        m.edit:SetEnabled(false)
        m.useColor:SetEnabled(false)
        m.mirror:SetEnabled(false)
        m.alpha:SetEnabled(false)
        if m.alphaNum and m.alphaNum.SetEnabled then m.alphaNum:SetEnabled(false) end
        m.rot:SetEnabled(false)
        if m.rotNum and m.rotNum.SetEnabled then m.rotNum:SetEnabled(false) end

        -- keep numeric boxes in sync even when no selection is bound (side-effect free under EditGuard)
        if m.alpha and m.alpha.SetValue then
          m._updatingAlpha = true
          m.alpha:SetValue(1)
          if m.alphaNum and m.alphaNum.SetText then m.alphaNum:SetText("1.00") end
          m._updatingAlpha = false
        end
        if m.rot and m.rot.SetValue then
          m._updatingRot = true
          m.rot:SetValue(0)
          if m.rotNum and m.rotNum.SetText then m.rotNum:SetText("0") end
          m._updatingRot = false
        end

        -- refresh position UI to safe defaults without any commit side effects
        if m._OffsetDetach then m:_OffsetDetach() end
        m._updatingOffset = true
        if m.xOff then m.xOff:SetMinMaxValues(-4096, 4096); m.xOff:SetValueStep(0.5); m.xOff:SetValue(0) end
        if m.yOff then m.yOff:SetMinMaxValues(-4096, 4096); m.yOff:SetValueStep(0.5); m.yOff:SetValue(0) end
        if m.xNum and m.xNum.SetText then m.xNum:SetText("0") end
        if m.yNum and m.yNum.SetText then m.yNum:SetText("0") end
        m._updatingOffset = false
        if m._OffsetAttach then m:_OffsetAttach() end

        if m.applyPreview and m.previewTex then
          m.applyPreview(m.previewTex, {}, 1)
        end
      end
      
      -- Step5 (v2.14.69): Close the if-else block for new/old drawer
      end  -- End of USE_NEW_DRAWER if-else
    end

    
    -- StepX (v2.18.82): Add Model drawer refresh (mirroring ProgressMat logic)
    if ep and ep._activeDrawerId == "Model" then
      local DT = Bre.DrawerTemplate
      local d = (ep._drawers and ep._drawers.Model) or ep._drawerModel_new
      if DT and DT.Refresh and d then
        DT:Refresh(d, id)
      end
    end

    -- Step1 (v2.19.26): StopMotion drawer refresh (path input backfill)
    if ep and ep._activeDrawerId == "StopMotion" then
      local DT = Bre.DrawerTemplate
      local d = (ep._drawers and ep._drawers.StopMotion)
      if DT and DT.Refresh and d then
        DT:Refresh(d, id)
      end
    end

    -- ThemeMinimal drawer refresh (size/strata/offsets)
    if ep and ep._activeDrawerId == "ThemeMinimal" then
      local DT = Bre.DrawerTemplate
      local d = (ep._drawers and ep._drawers.ThemeMinimal)
      if DT and DT.Refresh and d then
        DT:Refresh(d, id)
      end
    end

-- Step3 Fix: Add ProgressMat drawer refresh (mirroring CustomMat logic above)
    if ep and ep._activeDrawerId == "ProgressMat" then
      local USE_NEW_DRAWER = (ep._drawerProgressMat_new ~= nil)
      
      if USE_NEW_DRAWER and ep._drawerProgressMat_new then
        -- New template-based drawer
        local DT = Bre.DrawerTemplate
        if DT and DT.Refresh then
          DT:Refresh(ep._drawerProgressMat_new, id)
        end
      end
    end

    -- Step6 (v2.14.36): after RefreshRight completes updating CustomMat content, run the scroll fix once (guarded; no commits).
    do
      local ep = right and right._panes and right._panes.Element
      if ep and ep._activeDrawerId == "CustomMat" then
        local d = ep._drawerCustomMat or (ep._drawers and ep._drawers.CustomMat)
        if d and d._FixCustomMatScroll then
          if EG and EG.RunGuarded then
            EG:RunGuarded('FixCustomMatScrollAfterRefresh', function()
              if d._SampleElemPaneContentHeightCandidate then d._SampleElemPaneContentHeightCandidate() end
              if d._ApplyElemPaneContentHeightCandidate then d._ApplyElemPaneContentHeightCandidate() end
              if d._RecalcElemPaneContentHeight then d._RecalcElemPaneContentHeight() end
              d._FixCustomMatScroll()
            end)
          end
        end
      end
    end

    -- release refresh suppression lock (must always unlock after binding)
    do
      -- use the same 'right' resolved at the top of RefreshRight (f._body._inner._right)
      local ep = right and right._panes and right._panes.Element
      if ep and ep._elemMat then
        ep._elemMat._suppressCommit = false
      end
    end

    -- v2.8.8
    self:_SyncMoverBody()

    if EG and EG.End then EG:End('RefreshRight') end
  end)
end

-- Fallback (should not happen): run unguarded.
local f = self.frame
if not f then return end

local right = f._body._inner._right
if not right then return end

if f._showingNew then
  -- Overlay ignores selection
  return
end

local EG = Gate:Get('EditGuard')
if EG and EG.Begin then EG:Begin('RefreshRight') end

-- Sync right mode (Group vs Element) based on current selection
self:_EnsureRightMode()
-- Ensure the actually-visible pane matches the resolved right tab.
-- (Selection can change mode without clicking a tab; prevent overlapping panes.)
local showKey = f._rightTab
local id = f._selectedId
if f._rightMode == "GROUP" then
  showKey = "Group"
  f._rightTab = "Group"
else
  if not showKey or showKey == "Group" then
    showKey = f._lastElementTab or "Element"
    f._rightTab = showKey
  end

  -- Align with Element pane behavior: when there is no active selection,
  -- force the primary Element pane to be visible (hide Actions/other tabs).
  if not id then
    showKey = "Element"
    f._rightTab = "Element"
    f._lastElementTab = "Element"
    for k, b in pairs(right._tabBtns or {}) do
      if b:IsShown() then
        b:SetActive(k == "Element")
      else
        b:SetActive(false)
      end
    end
  end
end
for k, p in pairs(right._panes or {}) do
  p:SetShown(k == showKey and not f._showingNew)
end

-- Update hint labels for each pane
for _, p in pairs(right._panes or {}) do
  if p._hint then
    if id then
      p._hint:SetText(string.format("%s: %s", L("SELECTED"), tostring(id)))
    else
      p._hint:SetText(L("SELECT_HINT"))
    end
  end
end

-- Group pane binding (minimal field: iconPath)
local gp = right._panes and right._panes.Group
if gp and gp._groupIconEdit then
  if id then
    local data = GetData and GetData(id) or nil
    local U = UIB
    local isGroup = U and safeCall(U.IsGroupNode, U, data) or false
    gp._groupIconEdit:SetEnabled(isGroup and true or false)
    gp._groupIconEdit._editBindNodeId = id
    gp._groupIconEdit._editBindRev = _EnsureEditSession(f).rev
    if isGroup then
      local own = U and safeCall(U.GetGroupIconPath, U, id, data) or nil
      gp._groupIconEdit:SetText(own or "")
             if gp._groupIconPreviewTex then
               local eff = U and safeCall(U.GetInheritedGroupIconPath, U, id, data) or own
               if type(eff) == "string" and eff ~= "" then
                 gp._groupIconPreviewTex:SetTexture(eff)
               else
                 gp._groupIconPreviewTex:SetTexture(nil)
               end
             end
    else
      gp._groupIconEdit:SetText("")
             if gp._groupIconPreviewTex then gp._groupIconPreviewTex:SetTexture(nil) end
      gp._groupIconEdit._editBindNodeId = nil
      gp._groupIconEdit._editBindRev = _EnsureEditSession(f).rev
    end
  else
    gp._groupIconEdit:SetText("")
             if gp._groupIconPreviewTex then gp._groupIconPreviewTex:SetTexture(nil) end
    gp._groupIconEdit._editBindNodeId = nil
    gp._groupIconEdit._editBindRev = _EnsureEditSession(f).rev
    gp._groupIconEdit:SetEnabled(false)
           if gp._groupIconPreviewTex then gp._groupIconPreviewTex:SetTexture(nil) end
  end
end

-- Element pane binding (custom texture)
    local ep = right._panes and right._panes.Element
    local selData = nil
    if id then selData = _GetData(id) end

-- Drawer routing via API (Step2 v2.14.3)
-- [SCROLL LOCATOR] CustomMat drawer is shown when Element pane routes:
--   ep:OpenDrawer("CustomMat")  -> right pane uses Bre_ElementPaneScroll (see BuildElementPane).
if ep and ep.OpenDrawer and ep.CloseAll then
  local U = UIB
  local isGroup = false
  if U and type(selData) == "table" then
    isGroup = safeCall(U.IsGroupNode, U, selData) or false
  end

  local isProgress = false
  local isCustom = false
  if type(selData) == "table" then
    if selData.regionType == "progress" then
      isProgress = true
    elseif type(selData.features) == "table" and selData.features.progress then
      isProgress = true
    elseif type(selData.region) == "table" and type(selData.region.progress) == "table" then
      isProgress = true
    end

    if selData.regionType == "custom" then
      isCustom = true
    elseif type(selData.features) == "table" and selData.features.custom then
      isCustom = true
    end
  end

  if (not id) or isGroup or type(selData) ~= "table" then
    ep:CloseAll()
    f._rightDrawer = nil
  else
    if isProgress then
      ep:OpenDrawer("ProgressMat")
      f._rightDrawer = "ProgressMat"
    elseif isCustom then
      ep:OpenDrawer("CustomMat")
      f._rightDrawer = "CustomMat"
    else
      ep:CloseAll()
      f._rightDrawer = nil
    end
  end
end

if ep and ep._elemMat and ep._activeDrawerId == "CustomMat" then
  local m = ep._elemMat
  m._suppressCommit = true
  if id then
        local data = _GetData(id)
    local U = UIB
    local isGroup = U and safeCall(U.IsGroupNode, U, data) or false
    local enabled = (not isGroup)
    if not enabled then m._editId = nil; m._editBindNodeId = nil; m._editBindRev = _EnsureEditSession(f).rev end
    m.edit:SetEnabled(enabled)
    m.useColor:SetEnabled(enabled)
    m.mirror:SetEnabled(enabled)
    m.alpha:SetEnabled(enabled)
    if m.alphaNum and m.alphaNum.SetEnabled then m.alphaNum:SetEnabled(enabled) end
    m.rot:SetEnabled(enabled)
    if m.rotNum and m.rotNum.SetEnabled then m.rotNum:SetEnabled(enabled) end
    if enabled and type(data) == "table" then
      m._editId = id
      m._editBindNodeId = id
      m._editBindRev = _EnsureEditSession(f).rev
      data.region = type(data.region) == "table" and data.region or {}
      local tex = data.region.texture or ""
      if m.edit:GetText() ~= tex then m.edit:SetText(tex) end
      m.useColor:SetChecked(data.region.useColor and true or false)
      m.mirror:SetChecked(data.region.mirror and true or false)
      local blend = data.region.blendMode or "BLEND"
      UIDropDownMenu_SetText(m.blendDD, blend)
      local a = tonumber(data.alpha) or 1
      m.alpha:SetValue(a)
      if m.alphaNum and m.alphaNum.SetText then
        m._updatingAlpha = true
        m.alphaNum:SetText(string.format("%.2f", a))
        m._updatingAlpha = false
      end
      local rdeg = tonumber(data.region.rotation) or 0
      m.rot:SetValue(rdeg)
      if m.rotNum and m.rotNum.SetText then
        m._updatingRot = true
        m.rotNum:SetText(tostring(math.floor((tonumber(rdeg) or 0) + 0.5)))
        m._updatingRot = false
      end

      -- position intent sync (data.props)
      data.props = type(data.props) == "table" and data.props or {}
      local at = data.props.anchorTarget or "SCREEN_CENTER"
      -- UI-only: hide SELECTED_NODE mode; treat as SCREEN_CENTER on refresh
      if at ~= "SCREEN_CENTER" then at = "SCREEN_CENTER" end
      local fs = data.props.frameStrata or "AUTO"
      if fs ~= "AUTO" and fs ~= "BACKGROUND" and fs ~= "LOW" and fs ~= "MEDIUM" and fs ~= "HIGH" and fs ~= "DIALOG" and fs ~= "FULLSCREEN" and fs ~= "FULLSCREEN_DIALOG" and fs ~= "TOOLTIP" then
        fs = "AUTO"
      end

      if m._AlignDetach then m:_AlignDetach() end
      m._updatingAlign = true        if m.alignTo then
        UIDropDownMenu_SetText(m.alignTo, L("ELEM_MAT_ALIGN_TO_SCREEN_CENTER"))
        UIDropDownMenu_SetSelectedValue(m.alignTo, "SCREEN_CENTER")
      end
      m._updatingAlign = false
      if m._AlignAttach then m:_AlignAttach() end

      -- frame level intent sync (data.props)
      if m._FrameLevelDetach then m:_FrameLevelDetach() end
      m._updatingFrameLevel = true
      if m.frameLevel then
        if fs == "BACKGROUND" then
          UIDropDownMenu_SetText(m.frameLevel, L("ELEM_MAT_FRAME_LEVEL_BACKGROUND"))
        elseif fs == "LOW" then
          UIDropDownMenu_SetText(m.frameLevel, L("ELEM_MAT_FRAME_LEVEL_LOW"))
        elseif fs == "MEDIUM" then
          UIDropDownMenu_SetText(m.frameLevel, L("ELEM_MAT_FRAME_LEVEL_MEDIUM"))
        elseif fs == "HIGH" then
          UIDropDownMenu_SetText(m.frameLevel, L("ELEM_MAT_FRAME_LEVEL_HIGH"))
        elseif fs == "DIALOG" then
          UIDropDownMenu_SetText(m.frameLevel, L("ELEM_MAT_FRAME_LEVEL_DIALOG"))
        elseif fs == "FULLSCREEN" then
          UIDropDownMenu_SetText(m.frameLevel, L("ELEM_MAT_FRAME_LEVEL_FULLSCREEN"))
        elseif fs == "FULLSCREEN_DIALOG" then
          UIDropDownMenu_SetText(m.frameLevel, L("ELEM_MAT_FRAME_LEVEL_FULLSCREEN_DIALOG"))
        elseif fs == "TOOLTIP" then
          UIDropDownMenu_SetText(m.frameLevel, L("ELEM_MAT_FRAME_LEVEL_TOOLTIP"))
        else
          UIDropDownMenu_SetText(m.frameLevel, L("ELEM_MAT_FRAME_LEVEL_AUTO"))
        end
      end
      m._updatingFrameLevel = false
      if m._FrameLevelAttach then m:_FrameLevelAttach() end
      -- size sync (data.size)
      local sw = (data.size and tonumber(data.size.width)) or 200
      local sh = (data.size and tonumber(data.size.height)) or 200

      -- Hard-isolate refresh from any commits: detach handlers, set values, then re-attach
      if m._SizeDetach then m:_SizeDetach() end
      m._updatingSize = true
      if m.w1 then m.w1:SetMinMaxValues(1, 2048); m.w1:SetValueStep(1); m.w1:SetValue(sw) end
      if m.h1 then m.h1:SetMinMaxValues(1, 2048); m.h1:SetValueStep(1); m.h1:SetValue(sh) end
      if m.wNum and m.wNum.SetText then m.wNum:SetText(tostring(sw)) end
      if m.hNum and m.hNum.SetText then m.hNum:SetText(tostring(sh)) end
      m._updatingSize = false
      if m._SizeAttach then m:_SizeAttach() end

      if m._OffsetDetach then m:_OffsetDetach() end
      m._updatingOffset = true
      if m.xOff then m.xOff:SetMinMaxValues(-4096, 4096); m.xOff:SetValueStep(0.5); m.xOff:SetObeyStepOnDrag(true); m.xOff:SetValue(0) end
      if m.yOff then m.yOff:SetMinMaxValues(-4096, 4096); m.yOff:SetValueStep(0.5); m.yOff:SetObeyStepOnDrag(true); m.yOff:SetValue(0) end
      if m.xNum and m.xNum.SetText then m.xNum:SetText("0") end
      if m.yNum and m.yNum.SetText then m.yNum:SetText("0") end
      m._updatingOffset = false
      if m._OffsetAttach then m:_OffsetAttach() end

      -- position offsets sync (data.props.xOffset/yOffset)
      local xo = tonumber(data.props.xOffset) or 0
      local yo = tonumber(data.props.yOffset) or 0
      if m._OffsetDetach then m:_OffsetDetach() end
      m._updatingOffset = true
      if m.xOff then
        -- Range will be finalized in Step4; keep a safe, wide range for now.
        m.xOff:SetMinMaxValues(-4096, 4096)
        m.xOff:SetValueStep(0.5)
        m.xOff:SetObeyStepOnDrag(true)
        m.xOff:SetValue(xo)
      end
      if m.yOff then
        m.yOff:SetMinMaxValues(-4096, 4096)
        m.yOff:SetValueStep(0.5)
        m.yOff:SetObeyStepOnDrag(true)
        m.yOff:SetValue(yo)
      end
      if m.xNum and m.xNum.SetText then m.xNum:SetText(tostring(xo)) end
      if m.yNum and m.yNum.SetText then m.yNum:SetText(tostring(yo)) end
      m._updatingOffset = false
      if m._OffsetAttach then m:_OffsetAttach() end
      local c = data.region.color or { r=1,g=1,b=1,a=1 }
      if m.colorBtn and m.colorBtn._swatch and m.colorBtn._swatch.SetColorTexture then
        m.colorBtn._swatch:SetColorTexture(c.r or 1, c.g or 1, c.b or 1, c.a or 1)
      end

      -- preview sync
      if m.applyPreview and m.previewTex then
        m.applyPreview(m.previewTex, data.region, data.alpha)
      end
    else
      m._editId = nil
      m._editBindNodeId = nil
      m._editBindRev = _EnsureEditSession(f).rev
      if m.edit:GetText() ~= "" then m.edit:SetText("") end
      m.useColor:SetChecked(false)
      m.mirror:SetChecked(false)
      UIDropDownMenu_SetText(m.blendDD, "BLEND")
      m.alpha:SetValue(1)
      if m.alphaNum and m.alphaNum.SetText then
        m._updatingAlpha = true
        m.alphaNum:SetText("1.00")
        m._updatingAlpha = false
      end
      m.rot:SetValue(0)
      if m.rotNum and m.rotNum.SetText then
        m._updatingRot = true
        m.rotNum:SetText("0")
        m._updatingRot = false
      end
      if m._SizeDetach then m:_SizeDetach() end
      m._updatingSize = true
      if m.w1 then m.w1:SetMinMaxValues(1, 2048); m.w1:SetValueStep(1); m.w1:SetValue(200) end
      if m.h1 then m.h1:SetMinMaxValues(1, 2048); m.h1:SetValueStep(1); m.h1:SetValue(200) end
      if m.wNum and m.wNum.SetText then m.wNum:SetText("200") end
      if m.hNum and m.hNum.SetText then m.hNum:SetText("200") end
      m._updatingSize = false
      if m._SizeAttach then m:_SizeAttach() end

      if m._OffsetDetach then m:_OffsetDetach() end
      m._updatingOffset = true
      if m.xOff then m.xOff:SetMinMaxValues(-4096, 4096); m.xOff:SetValueStep(0.5); m.xOff:SetValue(0) end
      if m.yOff then m.yOff:SetMinMaxValues(-4096, 4096); m.yOff:SetValueStep(0.5); m.yOff:SetValue(0) end
      if m.xNum and m.xNum.SetText then m.xNum:SetText("0") end
      if m.yNum and m.yNum.SetText then m.yNum:SetText("0") end
      m._updatingOffset = false
      if m._OffsetAttach then m:_OffsetAttach() end
      if m.colorBtn and m.colorBtn._swatch and m.colorBtn._swatch.SetColorTexture then
        m.colorBtn._swatch:SetColorTexture(1,1,1,1)
      end

      if m.applyPreview and m.previewTex then
        m.applyPreview(m.previewTex, {}, 1)
      end
    end
  else
    m.edit:SetText("")
    m.edit:SetEnabled(false)
    m.useColor:SetEnabled(false)
    m.mirror:SetEnabled(false)
    m.alpha:SetEnabled(false)
    if m.alphaNum and m.alphaNum.SetEnabled then m.alphaNum:SetEnabled(false) end
    m.rot:SetEnabled(false)
    if m.rotNum and m.rotNum.SetEnabled then m.rotNum:SetEnabled(false) end

    -- keep numeric boxes in sync even when no selection is bound (side-effect free under EditGuard)
    if m.alpha and m.alpha.SetValue then
      m._updatingAlpha = true
      m.alpha:SetValue(1)
      if m.alphaNum and m.alphaNum.SetText then m.alphaNum:SetText("1.00") end
      m._updatingAlpha = false
    end
    if m.rot and m.rot.SetValue then
      m._updatingRot = true
      m.rot:SetValue(0)
      if m.rotNum and m.rotNum.SetText then m.rotNum:SetText("0") end
      m._updatingRot = false
    end

    -- refresh position UI to safe defaults without any commit side effects
    if m._OffsetDetach then m:_OffsetDetach() end
    m._updatingOffset = true
    if m.xOff then m.xOff:SetMinMaxValues(-4096, 4096); m.xOff:SetValueStep(0.5); m.xOff:SetValue(0) end
    if m.yOff then m.yOff:SetMinMaxValues(-4096, 4096); m.yOff:SetValueStep(0.5); m.yOff:SetValue(0) end
    if m.xNum and m.xNum.SetText then m.xNum:SetText("0") end
    if m.yNum and m.yNum.SetText then m.yNum:SetText("0") end
    m._updatingOffset = false
    if m._OffsetAttach then m:_OffsetAttach() end

    if m.applyPreview and m.previewTex then
      m.applyPreview(m.previewTex, {}, 1)
    end
  end
end

-- Step3 Fix (fallback): Add ProgressMat drawer refresh
if ep and ep._activeDrawerId == "ProgressMat" then
  local USE_NEW_DRAWER = (ep._drawerProgressMat_new ~= nil)
  
  if USE_NEW_DRAWER and ep._drawerProgressMat_new then
    -- New template-based drawer
    local DT = Bre.DrawerTemplate
    if DT and DT.Refresh then
      DT:Refresh(ep._drawerProgressMat_new, id)
    end
  end
end

-- Step6 (v2.14.36): after RefreshRight completes updating CustomMat content, run the scroll fix once (guarded; no commits).
do
  local ep = right and right._panes and right._panes.Element
  if ep and ep._activeDrawerId == "CustomMat" then
    local d = ep._drawerCustomMat or (ep._drawers and ep._drawers.CustomMat)
    if d and d._FixCustomMatScroll then
      if EG and EG.RunGuarded then
        EG:RunGuarded('FixCustomMatScrollAfterRefresh', function()
          if d._SampleElemPaneContentHeightCandidate then d._SampleElemPaneContentHeightCandidate() end
          if d._ApplyElemPaneContentHeightCandidate then d._ApplyElemPaneContentHeightCandidate() end
          if d._RecalcElemPaneContentHeight then d._RecalcElemPaneContentHeight() end
          d._FixCustomMatScroll()
        end)
      end
    end
  end
end

-- release refresh suppression lock (must always unlock after binding)
do
  -- use the same 'right' resolved at the top of RefreshRight (f._body._inner._right)
  local ep = right and right._panes and right._panes.Element
  if ep and ep._elemMat then
    ep._elemMat._suppressCommit = false
  end
end

-- Actions pane (Output Actions) refresh (template-based)
do
  local ap = right and right._panes and right._panes.Actions
  if ap and ap._drawerActions_new then
    local shown = ap:IsShown()
    ap._drawerActions_new:SetShown(shown)
    if shown then
      local DT = Bre.DrawerTemplate
      if DT and DT.Refresh then
        DT:Refresh(ap._drawerActions_new, id)
      end
    end
  end
end

-- v2.8.8
self:_SyncMoverBody()

if EG and EG.End then EG:End('RefreshRight') end

end


-- ------------------------------------------------------------
-- Import window (placeholder)
-- ------------------------------------------------------------
function UI:OpenImportWindow()
  local f = self:EnsureFrame()
  if f._importWindow then
    local w = f._importWindow
    -- Keep the import overlay above the main panel.
    if w.SetFrameStrata then w:SetFrameStrata("DIALOG") end
    if w.SetToplevel then w:SetToplevel(true) end
    if self.frame and w.SetFrameLevel then w:SetFrameLevel((self.frame:GetFrameLevel() or 0) + 50) end
    w:Show()
    w:Raise()
    return
  end

  local w = CreateFrame("Frame", "BreImportWindow", UIParent, "BackdropTemplate")
  -- Raise strata/level so it won't be covered by the main panel.
  w:SetFrameStrata("DIALOG")
  w:SetToplevel(true)
  if self.frame and w.SetFrameLevel then w:SetFrameLevel((self.frame:GetFrameLevel() or 0) + 50) end
  w:SetSize(520, 360)
  w:SetPoint("CENTER", 0, 0)
  w:SetMovable(true)
  w:EnableMouse(true)
  w:RegisterForDrag("LeftButton")
  w:SetScript("OnDragStart", function(self) self:StartMoving() end)
  w:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  w:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Buttons/WHITE8x8",
    edgeSize = 2,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  w:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
  w:SetBackdropBorderColor(YELLOW_R, YELLOW_G, YELLOW_B, 1)

  local title = w:CreateFontString(nil, "OVERLAY", (Bre.Font and Bre.Font:Normal() or "GameFontNormal"))
  title:SetPoint("TOPLEFT", 10, -10)
  title:SetTextColor(YELLOW_R, YELLOW_G, YELLOW_B)
  title:SetText(L("WIN_IMPORT_TITLE"))

  local close = CreateFrame("Button", nil, w, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)

  local scroll = CreateFrame("ScrollFrame", nil, w, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, -36)
  scroll:SetPoint("BOTTOMRIGHT", -30, 50)

  local edit = CreateFrame("EditBox", nil, scroll)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
  edit:SetFont("Fonts\ARKai_T.ttf", 13, "")
  edit:SetWidth(460)
  edit:SetText("")
  edit:SetScript("OnEscapePressed", function() edit:ClearFocus() end)
  scroll:SetScrollChild(edit)

  local hint = w:CreateFontString(nil, "OVERLAY", (Bre.Font and Bre.Font:HighlightSmall() or "GameFontHighlightSmall"))
  hint:SetPoint("BOTTOMLEFT", 12, 34)
  hint:SetText(L("MSG_NOT_ATTACHED"))

  local btnImport = CreateFrame("Button", nil, w, "UIPanelButtonTemplate")
  btnImport:SetSize(80, 22)
  btnImport:SetPoint("BOTTOMRIGHT", -12, 12)
  btnImport:SetText(L("BTN_IMPORT"))
  btnImport:SetScript("OnClick", function()
    local s = (edit and edit.GetText and edit:GetText()) or ""
    s = tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" then
      hint:SetText(L("MSG_IMPORT_EMPTY"))
      return
    end

    local IO = Gate and Gate.Get and Gate:Get("IO") or nil
    if not (IO and IO.ImportString) then
      hint:SetText(L("MSG_NOT_ATTACHED"))
      return
    end

    local newRoot, err = IO:ImportString(s)
    if not newRoot then
      hint:SetText(L("MSG_IMPORT_FAILED") .. " " .. tostring(err or ""))
      return
    end

    local SS = Gate and Gate.Get and Gate:Get("SelectionService") or nil
    if SS and SS.SetActive then SS:SetActive(newRoot) end

    if self.RefreshTree then self:RefreshTree() end
    if self.RefreshRight then self:RefreshRight() end
    hint:SetText(L("MSG_IMPORT_OK"))
  end)

  local btnClose = CreateFrame("Button", nil, w, "UIPanelButtonTemplate")
  btnClose:SetSize(80, 22)
  btnClose:SetPoint("RIGHT", btnImport, "LEFT", -6, 0)
  btnClose:SetText(L("BTN_CLOSE"))
  btnClose:SetScript("OnClick", function() w:Hide() end)

  w._edit = edit
  f._importWindow = w
  w:Show()
end
-- ------------------------------------------------------------
-- Group pane (minimal fields: iconPath)
-- ------------------------------------------------------------
function UI:BuildGroupPane(p)
  if not p or p._builtGroup then return end
  p._builtGroup = true

  -- Hide generic placeholder title/hint for the specialized Group pane
  if p._defaultHeader then p._defaultHeader:Hide() end
  if p._defaultHint then p._defaultHint:Hide() end

  local L = Bre.L

  local title = p:CreateFontString(nil, "OVERLAY", (Bre.Font and Bre.Font:Large() or "GameFontNormalLarge"))
  title:SetPoint("TOPLEFT", 16, -14)
  title:SetTextColor(YELLOW_R, YELLOW_G, YELLOW_B)
  title:SetText(L("GROUP_SETTINGS_TITLE"))

  -- Icon row
  local lbl = p:CreateFontString(nil, "OVERLAY", (Bre.Font and Bre.Font:Normal() or "GameFontNormal"))
  lbl:SetPoint("TOPLEFT", 18, -56)
  lbl:SetTextColor(YELLOW_R, YELLOW_G, YELLOW_B)
  lbl:SetText(L("GROUP_ICON_LABEL"))

  local box = CreateFrame("Frame", nil, p, "BackdropTemplate")
  box:SetPoint("TOPLEFT", 18, -78)
  box:SetPoint("TOPRIGHT", -64, -78)
  box:SetHeight(24)
  box:SetBackdrop({ edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1 })
  box:SetBackdropBorderColor(YELLOW_R, YELLOW_G, YELLOW_B, 0.55)
  box:SetBackdropColor(0,0,0,0.10)

  -- Preview box (shows inherited icon)
  local preview = CreateFrame("Frame", nil, p, "BackdropTemplate")
  preview:SetSize(40, 40)
  preview:SetPoint("TOPRIGHT", -18, -78)
  preview:SetBackdrop({ edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1 })
  preview:SetBackdropBorderColor(YELLOW_R, YELLOW_G, YELLOW_B, 0.55)
  preview:SetBackdropColor(0,0,0,0.10)
  local ptex = preview:CreateTexture(nil, "ARTWORK")
  ptex:SetAllPoints(preview)
  ptex:SetTexture(nil)
  ptex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  p._groupIconPreview = preview
  p._groupIconPreviewTex = ptex

  local DC = Bre.DrawerControls
local edit = (DC and DC.MakeEditBox and DC:MakeEditBox(box, 0, 0, 180)) or CreateFrame("EditBox", nil, box, "InputBoxTemplate")
edit:ClearAllPoints()
edit:SetPoint("LEFT", 6, 0)
edit:SetPoint("RIGHT", -6, 0)
edit:SetHeight(20)
edit:SetAutoFocus(false)
edit:SetFont("Fonts\ARKai_T.ttf", 13, "")
if edit.SetTextInsets then edit:SetTextInsets(6, 6, 0, 0) end
edit:EnableMouse(true)
edit:SetScript("OnMouseDown", function(self) self:SetFocus() end)
edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

  local hint = p:CreateFontString(nil, "OVERLAY", (Bre.Font and Bre.Font:HighlightSmall() or "GameFontHighlightSmall"))
  hint:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -6)
  hint:SetTextColor(0.8, 0.8, 0.8)
  hint:SetText(L("GROUP_ICON_INHERIT"))

  p._groupIconEdit = edit

  local function commit()
    local f = Bre.UI and Bre.UI.frame
    local id = edit and edit._editBindNodeId or nil
    local rev = edit and edit._editBindRev or nil
    if not id then return end
    if not _IsBindAlive(f, rev) then return end
    local data = GetData and GetData(id)
    if type(data) ~= "table" then return end
    data.group = data.group or {}
    local v = (edit:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if v ~= "" then
      -- normalize: Interface/... -> Interface\...
      v = v:gsub("/", "\\")
    end
    if v == "" then v = nil end
    data.group.iconPath = v
    Bre.SetData(id, data)
    Bre.UI:RefreshTree()
     if Bre.UI and Bre.UI.RefreshRight then Bre.UI:RefreshRight() end
  end

  edit:SetScript("OnEnterPressed", function(self) self:ClearFocus(); commit() end)
  edit:SetScript("OnEditFocusLost", function() commit() end)

  -- ------------------------------------------------------------
  -- Group Attributes (Shell only; no binding in this step)
  -- ------------------------------------------------------------
  local DC = Bre.DrawerControls
  local DT = Bre.DrawerTemplate
  local LAY = (DT and DT.LAYOUT) or {}
  -- Group drawer only: keep 2-column layout but avoid overly-long controls.
  -- (Do NOT change global template constants; this is local to Group pane.)
  local CW = 150
  local COL1_X = LAY.CONTENT_LEFT or 18
  local COL2_X = (COL1_X + CW + 60)

  local sectionTopY = -140
  if DC and DC.MakeSectionDivider then
    DC:MakeSectionDivider(p, sectionTopY)
  end

  if DC and DC.MakeSectionTitle then
    DC:MakeSectionTitle(p, "GROUP_ATTR_TITLE", COL1_X, sectionTopY - 18)
  else
    local fs = p:CreateFontString(nil, "OVERLAY", (Bre.Font and Bre.Font:Large() or "GameFontNormalLarge"))
    fs:SetPoint("TOPLEFT", COL1_X, sectionTopY - 18)
    fs:SetTextColor(YELLOW_R, YELLOW_G, YELLOW_B)
    fs:SetText(L("GROUP_ATTR_TITLE"))
  end

  local baseY = (sectionTopY - 18) - 26

  local function _MakeAttrBlock(colX, topY, labelKey)
    if not DC then return nil end
    local lbl = DC.MakeLabel and DC:MakeLabel(p, labelKey, colX, topY) or nil

    -- Template style: label + small numeric box on the same line; slider below.
    local num = (DC.MakeNumericBox and DC:MakeNumericBox(p, colX + 48, topY +4)) or nil

    local slY = topY - (LAY.LABEL_TO_CONTROL or 18)
    local sl = (DC.MakeSlider and DC:MakeSlider(p, colX, slY, CW)) or nil

    -- Shell placeholders (no commit / no preview yet)
    if num then
      num:SetEnabled(false)
      num:SetText("")
    end
    if sl then
      sl:EnableMouse(false)
      sl:SetValue(0)
    end

    return { label = lbl, num = num, slider = sl }
  end

  -- Row 1
  p._grpAttrScale = _MakeAttrBlock(COL1_X, baseY, "GROUP_SCALE_LABEL")  
  -- ------------------------------------------------------------
  -- Step3: Group Scale UI (UI-only; no commit / no batch apply yet)
  -- Only enabled for top-level groups (no parent). Child groups remain disabled.
  -- ------------------------------------------------------------
  local function _Round1(v)
    v = tonumber(v) or 1
    return math.floor(v * 10 + 0.5) / 10
  end

  local function _ClampScale(v)
    v = tonumber(v) or 1
    if v < 0.6 then v = 0.6 end
    if v > 1.4 then v = 1.4 end
    return _Round1(v)
  end

  -- Expose helpers for the right-panel refresh router.
  p._groupScale_isRefreshing = false
  p._groupScale_Clamp = _ClampScale

  local function _GroupScaleCommit(val)
    if p._groupScale_isRefreshing then return end
    local id = p._groupScale_bindNodeId
    if not id then return end
    local Gate = Bre.Gate
    local PS = Gate and Gate.Get and Gate:Get('PropertyService') or nil
    if not PS or not PS.Set then return end
    local v = _ClampScale(val)
    pcall(function() PS:Set(id, 'group.scale', v) end)
  end

  p._groupScale_SetUI = function(val)
    local blk = p._grpAttrScale
    if not blk then return end
    local v = _ClampScale(val)
    p._groupScale_isRefreshing = true
    if blk.slider then blk.slider:SetValue(v) end
    if blk.num then blk.num:SetText(string.format("%.1f", v)) end
    p._groupScale_isRefreshing = false
  end

  do
    local blk = p._grpAttrScale
    if blk and blk.slider then
      blk.slider:SetMinMaxValues(0.6, 1.4)
      blk.slider:SetValueStep(0.1)
      blk.slider:SetObeyStepOnDrag(true)
      blk.slider:EnableMouse(true) -- actual enable/disable is controlled by refresh routing
      blk.slider:SetScript("OnValueChanged", function(self, value)
        if p._groupScale_isRefreshing then return end
        if not value then return end
        p._groupScale_SetUI(value)
      end)

      -- Commit only on whitelist event: MouseUp
      blk.slider:SetScript("OnMouseUp", function(self)
        if p._groupScale_isRefreshing then return end
        _GroupScaleCommit(self:GetValue())
      end)
    end

    if blk and blk.num then
      blk.num:SetEnabled(true) -- actual enable/disable is controlled by refresh routing
      blk.num:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        local v = tonumber(self:GetText())
        if v then
          p._groupScale_SetUI(v)
          _GroupScaleCommit(v)
        end
      end)
      blk.num:SetScript("OnEditFocusLost", function(self)
        local v = tonumber(self:GetText())
        if v then
          p._groupScale_SetUI(v)
          _GroupScaleCommit(v)
        end
      end)
    end

    -- Default UI state
    p._groupScale_SetUI(1)
  end

end

function UI:BuildElementPane(p)
  if not p or p._builtElement then return end
  p._builtElement = true

  if p._defaultHeader then p._defaultHeader:Hide() end
  if p._defaultHint then p._defaultHint:Hide() end

  local L = Bre.L

  -- ------------------------------------------------------------
  -- Helpers: self-drawn controls (NO Blizzard templates)
  -- Step1 (v2.10.5): layout + placeholders only (no data binding)
  -- ------------------------------------------------------------
  local function MakeLabel(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", (Bre.Font and Bre.Font:Normal() or "GameFontNormal"))
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetTextColor(YELLOW_R, YELLOW_G, YELLOW_B)
    fs:SetText(text)
    return fs
  end

  local function MakeBox(parent, w, h)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetSize(w, h)
    f:SetBackdrop({ edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1 })
    f:SetBackdropBorderColor(YELLOW_R, YELLOW_G, YELLOW_B, 0.55)
    f:SetBackdropColor(0, 0, 0, 0.10)
    return f
  end

  -- Blizzard template checkbox (visual only in Step1)
  local function MakeCheckbox(parent, labelText)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    if cb.Text then
      cb.Text:SetText(labelText or "")
      cb.Text:SetTextColor(YELLOW_R, YELLOW_G, YELLOW_B)
    end
    cb._label = cb.Text
    return cb
  end

  -- Blizzard template slider (visual only in Step1)
  local function MakeSliderPlaceholder(parent, w)
    local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    s:SetWidth(w)
    s:SetHeight(16)
    s:SetMinMaxValues(0, 1)
    s:SetValue(0)
    s:SetValueStep(0.01)
    s:SetObeyStepOnDrag(true)
    -- Hide template labels (we draw our own labels)
    for _, r in ipairs({ s:GetRegions() }) do
      if r and r.GetObjectType and r:GetObjectType() == "FontString" then
        r:Hide()
      end
    end
    return s
  end

  -- Blizzard template dropdown (visual only in Step1)
  local function MakeDropdownPlaceholder(parent, w)
    local dd = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dd, w)
    UIDropDownMenu_SetText(dd, "")
    return dd
  end

-- ------------------------------------------------------------
-- Layout (match reference image)
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- Drawer Layer 1 (Custom Texture) - base drawer wrapper (Step1 v2.14.2)
-- - This wrapper becomes the baseline drawer for FrameLevel stacking.
-- ------------------------------------------------------------
-- [SCROLL LOCATOR] CustomMat Element table scroll objects (Step2 v2.14.32)
-- - ScrollFrame:   Bre_ElementPaneScroll  (scroll variable: `scroll`)
-- - ScrollBar:     scroll.ScrollBar or _G["Bre_ElementPaneScrollScrollBar"]
-- - ScrollChild:   `content` (scroll:SetScrollChild(content))
-- - Legacy height: (removed in Step7) content height now recalculated from real layout
-- - Refresh entry: UI:RefreshRight() routes drawers via right._panes.Element:OpenDrawer("CustomMat")
--   (Search: "Drawer routing via API" / "ep:OpenDrawer(\"CustomMat\")")
-- ------------------------------------------------------------
local customDrawer = CreateFrame("Frame", nil, p, "BackdropTemplate")
customDrawer:ClearAllPoints()
customDrawer:SetAllPoints(p)
-- Keep same strata as pane; base drawer does not change Strata.
do
  local strata = (p and p.GetFrameStrata and p:GetFrameStrata()) or nil
  if strata and customDrawer.SetFrameStrata then customDrawer:SetFrameStrata(strata) end
end
-- Baseline: inherit pane frame level (no delta)
do
  local baseLevel = (p and p.GetFrameLevel and p:GetFrameLevel()) or 0
  if customDrawer.SetFrameLevel then customDrawer:SetFrameLevel(baseLevel) end
end
applyPanelBackdrop(customDrawer, 0.35, 2)
p._drawerCustomMat = customDrawer

-- Step4 (v2.14.69): Create new template-based CustomMat drawer (coexist with old one)
-- Step7 (v2.14.69): Switch to new drawer by default
local USE_NEW_CUSTOMMAT_DRAWER = true  -- Changed to true in Step7

if USE_NEW_CUSTOMMAT_DRAWER then
  local DT = Bre.DrawerTemplate
  local spec = Bre.DrawerSpec_CustomMat
  if DT and spec then
    local newDrawer = DT:Create(p, spec)
    if newDrawer then
      -- Hide old drawer, store new drawer
      customDrawer:Hide()
      p._drawerCustomMat_new = newDrawer
      -- Temporarily use new drawer as main
      p._drawerCustomMat = newDrawer
    end
  end
end

-- Scroll container (Step1: visual only)
local scroll = CreateFrame("ScrollFrame", "Bre_ElementPaneScroll", customDrawer, "UIPanelScrollFrameTemplate")
-- Scrollbar should live INSIDE the content box area:
-- top aligned with the section title, bottom reaches the inner border.
scroll:SetPoint("TOPLEFT", 8, -8)
local SCROLL_RIGHT_PAD = 29 -- always reserve right space to prevent width jump when ScrollBar hides
scroll:SetPoint("BOTTOMRIGHT", -SCROLL_RIGHT_PAD, 8)

local content = CreateFrame("Frame", nil, scroll)
content:SetPoint("TOPLEFT", 0, 0)
content:SetPoint("TOPRIGHT", 0, 0)
scroll:SetScrollChild(content)

-- Section title lives inside the scroll child so the scrollbar top aligns with it.
local title = content:CreateFontString(nil, "OVERLAY", (Bre.Font and Bre.Font:Large() or "GameFontNormalLarge"))
title:SetPoint("TOPLEFT", 16, -14)
title:SetTextColor(YELLOW_R, YELLOW_G, YELLOW_B)
title:SetText(L("ELEM_MAT_TITLE"))

-- keep scroll-child width synced (avoid horizontal clipping)
local function _SyncElemPaneScrollWidth()
  local w = p:GetWidth()
  if not w or w <= 0 then w = 440 end
  -- leave room for scrollbar + padding (scrollbar is inside the box)
  content:SetWidth(w - 68)
end


-- Step7 (v2.14.37): derive real scroll-child height from the actual laid-out controls (no more fixed content height).
local ENABLE_CUSTOMMAT_REAL_CONTENT_HEIGHT = false -- Step7 repair Step1: keep disabled; will be enabled after height truth is stabilized
local function _RecalcElemPaneContentHeight()
  if not ENABLE_CUSTOMMAT_REAL_CONTENT_HEIGHT then return end
  if not content or not content.GetTop then return end
  local top = content:GetTop()
  if not top then return end

  local minBottom = top
  local n = select("#", content:GetChildren())
  for i = 1, n do
    local child = select(i, content:GetChildren())
    if child and child.IsShown and child:IsShown() and child.GetBottom then
      local b = child:GetBottom()
      if b and b < minBottom then
        minBottom = b
      end
    end
  end

  local h = (top - minBottom) + 24 -- padding to avoid clipping last row
  if not h or h < 1 then h = 1 end
  if content and content.SetHeight then
    content:SetHeight(h)
  end
end

customDrawer._RecalcElemPaneContentHeight = _RecalcElemPaneContentHeight

function _SampleElemPaneScrollMetrics()
  -- Step2 (v2.14.32): read-only sampling for later hidden-scrollbar logic (no behavior changes).
  local sf = scroll
  if not sf or not sf.GetHeight then return end
  local sb = sf.ScrollBar or _G["Bre_ElementPaneScrollScrollBar"]
  local viewH = sf:GetHeight() or 0
  local contentH = (content and content.GetHeight and content:GetHeight()) or 0

  customDrawer._elemPaneScrollSample = customDrawer._elemPaneScrollSample or {}
  local s = customDrawer._elemPaneScrollSample
  s.viewH = viewH
  s.contentH = contentH
  s.hasSB = (sb ~= nil)
end


function _SampleElemPaneContentHeightCandidate()
  -- Step7fix Step2 (v2.14.39): read-only candidate sampling for real content height (no behavior changes).
  local sf = scroll
  if not sf or not sf.GetHeight then return end
  local sb = sf.ScrollBar or _G["Bre_ElementPaneScrollScrollBar"]
  local viewH = sf:GetHeight() or 0
  local contentH = (content and content.GetHeight and content:GetHeight()) or 0

  local top = content and content.GetTop and content:GetTop()
  local minBottom = nil
  if content and content.GetChildren then
    local n = select("#", content:GetChildren())
    for i = 1, n do
      local child = select(i, content:GetChildren())
      if child and child.GetBottom then
        local b = child:GetBottom()
        if b and (not minBottom or b < minBottom) then
          minBottom = b
        end
      end
    end
  end

  local candidateH = 0
  if top and minBottom then
    candidateH = (top - minBottom) + 24
    if not candidateH or candidateH < 1 then candidateH = 1 end
  end

  customDrawer._elemPaneContentHeightCandidate = customDrawer._elemPaneContentHeightCandidate or {}
  local c = customDrawer._elemPaneContentHeightCandidate
  c.viewH = viewH
  c.contentH = contentH
  c.top = top
  c.minBottom = minBottom
  c.candidateH = candidateH
  c.hasSB = (sb ~= nil)
end


-- Step7fix Step3 (v2.14.40): apply sampled candidate content height (guarded) with reversible toggle.
-- Default ON, but safe-fallback to the legacy fixed height when candidate is not yet stable.
local ENABLE_CUSTOMMAT_APPLY_CONTENT_HEIGHT_CANDIDATE = true
local CUSTOMMAT_CONTENT_HEIGHT_FALLBACK = 1

local function _ApplyElemPaneContentHeightCandidate()
  if not content or not content.SetHeight then return end

  if not ENABLE_CUSTOMMAT_APPLY_CONTENT_HEIGHT_CANDIDATE then
    content:SetHeight(CUSTOMMAT_CONTENT_HEIGHT_FALLBACK)
    return
  end

  local c = customDrawer and customDrawer._elemPaneContentHeightCandidate
  local h = c and c.candidateH
  if not h or h < 1 then
    h = CUSTOMMAT_CONTENT_HEIGHT_FALLBACK
  end
  content:SetHeight(h)
end

customDrawer._SampleElemPaneContentHeightCandidate = _SampleElemPaneContentHeightCandidate
customDrawer._ApplyElemPaneContentHeightCandidate = _ApplyElemPaneContentHeightCandidate

function _SyncElemPaneScrollWidthAndSample()
  _SyncElemPaneScrollWidth()
  _SampleElemPaneScrollMetrics()
end

-- Step4 (v2.14.34): introduce ProgressMat-style Fix function for CustomMat scroll (default DISABLED; behavior unchanged).
local ENABLE_CUSTOMMAT_HIDE_SCROLLBAR = false

local function FixCustomMatScroll()
  if not ENABLE_CUSTOMMAT_HIDE_SCROLLBAR then return end
  local sf = scroll
  if not sf or not sf.GetHeight then return end
  local sb = sf.ScrollBar or _G["Bre_ElementPaneScrollScrollBar"]
  if not sb then return end

  -- Ensure the template recalculates child rect first.
  if sf.UpdateScrollChildRect then sf:UpdateScrollChildRect() end

  local viewH = sf:GetHeight() or 0
  local contentH = (content and content.GetHeight and content:GetHeight()) or 0

  local maxScroll = 0
  if viewH > 0 and contentH > viewH then
    maxScroll = contentH - viewH
  end

  sb:SetMinMaxValues(0, maxScroll)
  if maxScroll <= 0 then
    sb:SetValue(0)
    sb:Hide()
  else
    sb:Show()
    local cur = sb:GetValue() or 0
    if cur < 0 then cur = 0 end
    if cur > maxScroll then cur = maxScroll end
    sb:SetValue(cur)
  end

  -- Keep content width aligned (leave room for scrollbar + padding).
  local w = (customDrawer and customDrawer.GetWidth and customDrawer:GetWidth()) or (p and p.GetWidth and p:GetWidth()) or 440
  if not w or w <= 0 then w = 440 end
  if content and content.SetWidth then content:SetWidth(w - 68) end
end

customDrawer._FixCustomMatScroll = FixCustomMatScroll
-- Step5 (v2.14.35): wire FixCustomMatScroll into CustomMat drawer lifecycle (guarded), still DISABLED by default.
-- Behavior remains unchanged until ENABLE_CUSTOMMAT_HIDE_SCROLLBAR = true.
customDrawer:HookScript("OnShow", function()
  -- Run inside EditGuard when available to guarantee "refresh has no side effects".
  local G = Bre and Bre.Gate
  local eg = (G and G.Get and G:Get("EditGuard")) or nil
  if eg and eg.RunGuarded then
    eg:RunGuarded(function()
      if customDrawer and customDrawer._SampleElemPaneContentHeightCandidate then
        customDrawer._SampleElemPaneContentHeightCandidate()
      end
      if customDrawer and customDrawer._ApplyElemPaneContentHeightCandidate then
        customDrawer._ApplyElemPaneContentHeightCandidate()
      end
      if customDrawer and customDrawer._RecalcElemPaneContentHeight then
        customDrawer._RecalcElemPaneContentHeight()
      end
      if customDrawer and customDrawer._FixCustomMatScroll then
        customDrawer._FixCustomMatScroll()
      end
    end)
  else
    if customDrawer and customDrawer._SampleElemPaneContentHeightCandidate then
      customDrawer._SampleElemPaneContentHeightCandidate()
    end
    if customDrawer and customDrawer._ApplyElemPaneContentHeightCandidate then
      customDrawer._ApplyElemPaneContentHeightCandidate()
    end
    if customDrawer and customDrawer._RecalcElemPaneContentHeight then
      customDrawer._RecalcElemPaneContentHeight()
    end
    if customDrawer and customDrawer._FixCustomMatScroll then
      customDrawer._FixCustomMatScroll()
    end
  end
end)


_SyncElemPaneScrollWidthAndSample()
p:HookScript("OnSizeChanged", _SyncElemPaneScrollWidthAndSample)

scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", function(self, delta)
  local sb = self.ScrollBar or _G["Bre_ElementPaneScrollScrollBar"]
  if not sb then return end
  local cur = sb:GetValue()
  local minv, maxv = sb:GetMinMaxValues()
  local step = (sb:GetValueStep() and sb:GetValueStep() > 0) and sb:GetValueStep() or 20
  local nextv = cur - (delta * step * 3)
  if nextv < minv then nextv = minv end
  if nextv > maxv then nextv = maxv end
  sb:SetValue(nextv)
end)


-- ------------------------------------------------------------
-- Drawer Layer 2 (Progress Texture) - empty shell (Step2 v2.14.0)
-- - Same FrameStrata as base; use FrameLevel stacking (no Strata stacking)
-- - Base drawer: Element custom texture table lives in this pane/scroll
-- - This drawer will later be shown when selecting "progress texture" in Tree
-- ------------------------------------------------------------
do
  -- IMPORTANT:
  -- Do NOT parent ProgressMat drawer under CustomMat drawer.
  -- OpenDrawer() hides CustomMat when switching drawers; if ProgressMat is a child of it,
  -- it will remain hidden -> right pane appears blank.
  local base = (p and p._drawerCustomMat) or scroll or p
  local parent = p or base
  local drawer = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  drawer:Hide()
  drawer:ClearAllPoints()
  drawer:SetAllPoints(base)

  -- Step1 (ProgressMat ScrollShell): create scroll container shell but DO NOT re-parent any controls yet.
  -- This step is intentionally visual-noop for safe iteration.
  local pmScroll = CreateFrame("ScrollFrame", nil, drawer, "UIPanelScrollFrameTemplate")
  pmScroll:Hide() -- Step2 will show it on drawer OnShow (safe, visual-minimal)
  pmScroll:SetPoint("TOPLEFT", 8, -8)
  pmScroll:SetPoint("BOTTOMRIGHT", -29, 8)
  local pmContent = CreateFrame("Frame", nil, pmScroll)
  pmContent:SetSize(1, 1) -- Step3: controls migrated; Step4 will set fixed content height formula
 -- Step2: allow one-row smoke test content to render safely
  pmScroll:SetScrollChild(pmContent)
  drawer._pmScroll = pmScroll
  drawer._pmContent = pmContent

  -- Step2: show the scroll container when the drawer is shown (still minimal; controls remain on drawer for now)
  drawer:HookScript("OnShow", function()
    if drawer._pmScroll then drawer._pmScroll:Show() end
    if drawer._FixProgressMatScroll then drawer._FixProgressMatScroll() end
  end)
  drawer:HookScript("OnHide", function()
    if drawer._pmScroll then drawer._pmScroll:Hide() end
  end)



  -- Step5: FixScroll for ProgressMat (stable, no side effects)
  local function _FixProgressMatScroll()
    if not drawer._pmScroll or not drawer._pmContent then return end
    local sf = drawer._pmScroll
    local content = drawer._pmContent

    -- Ensure the template recalculates child rect first.
    if sf.UpdateScrollChildRect then sf:UpdateScrollChildRect() end

    local sb = sf.ScrollBar
    if not sb then return end

    local viewH = sf:GetHeight() or 0
    local contentH = content:GetHeight() or 0
    local maxScroll = 0
    if viewH > 0 and contentH > viewH then
      maxScroll = contentH - viewH
    end

    sb:SetMinMaxValues(0, maxScroll)
    if maxScroll <= 0 then
      sb:SetValue(0)
      sb:Hide()
    else
      sb:Show()
      -- Clamp current value
      local cur = sb:GetValue() or 0
      if cur < 0 then cur = 0 end
      if cur > maxScroll then cur = maxScroll end
      sb:SetValue(cur)
    end

    -- Keep content width aligned with CustomMat scroll container (leave room for scrollbar + padding).
    local w = drawer:GetWidth()
    if not w or w <= 0 then w = 440 end
    content:SetWidth(w - 68)
  end

  -- Mouse wheel scroll (matches other scroll containers)
  pmScroll:EnableMouseWheel(true)
  pmScroll:SetScript("OnMouseWheel", function(self, delta)
    local sb = self.ScrollBar
    if not sb then return end
    local cur = sb:GetValue() or 0
    local minv, maxv = sb:GetMinMaxValues()
    local step = 24
    if delta > 0 then
      cur = cur - step
    else
      cur = cur + step
    end
    if cur < minv then cur = minv end
    if cur > maxv then cur = maxv end
    sb:SetValue(cur)
  end)

  drawer._FixProgressMatScroll = _FixProgressMatScroll

  -- Keep same strata; ONLY use FrameLevel delta
  local function _SyncDrawerLayer()
    local strata = (base and base.GetFrameStrata and base:GetFrameStrata()) or (p and p.GetFrameStrata and p:GetFrameStrata()) or nil
    if strata and drawer.SetFrameStrata then drawer:SetFrameStrata(strata) end

    local baseLevel = (base and base.GetFrameLevel and base:GetFrameLevel()) or (p and p.GetFrameLevel and p:GetFrameLevel()) or 0
    local delta = 10
    drawer:SetFrameLevel((baseLevel or 0) + (delta or 0))
  end
  _SyncDrawerLayer()
  drawer:HookScript("OnShow", _SyncDrawerLayer)
  drawer:HookScript("OnSizeChanged", function()
    if drawer._FixProgressMatScroll then drawer._FixProgressMatScroll() end
  end)

  applyPanelBackdrop(drawer, 0.35, 2)

  -- Step2: migrate the first row (title) into ScrollChild for smoke-test.
  local t = pmContent:CreateFontString(nil, "OVERLAY", (Bre.Font and Bre.Font:Large() or "GameFontNormalLarge"))
  -- Keep the same absolute visual position as before: drawer(24,-24) == scroll inset(8,-8) + content(16,-16)
  t:SetPoint("TOPLEFT", 16, -16)
  t:SetTextColor(YELLOW_R, YELLOW_G, YELLOW_B)
  t:SetText(L("NEW_BTN_MAT_PROGRESS"))

  local function _T(key, fallback)
    local v = L(key)
    if v == tostring(key) then return fallback end
    return v
  end

  -- ------------------------------------------------------------
  -- ProgressMat: UI placeholders (v2.14.19)
  -- - Title font: GameFontNormalLarge (16)
  -- - Labels: GameFontNormal (12)
  -- - Inputs/Dropdowns width: 150px (match CustomMat table)
  -- ------------------------------------------------------------
  local INPUT_W = 150
  local INPUT_H = 22

  local function _MakeLabel(textKeyOrText, x, y)
    local fs = pmContent:CreateFontString(nil, "OVERLAY", (Bre.Font and Bre.Font:Normal() or "GameFontNormal"))
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetTextColor(YELLOW_R, YELLOW_G, YELLOW_B)
    fs:SetText(textKeyOrText)
    return fs
  end

  local function _MakeTextBox(x, y)
    local eb = CreateFrame("EditBox", nil, pmContent, "InputBoxTemplate")
    eb:SetSize(INPUT_W, INPUT_H)
    eb:SetAutoFocus(false)
    eb:SetFont("Fonts\ARKai_T.ttf", 13, "")
    eb:SetJustifyH("LEFT")
    if eb.SetTextInsets then eb:SetTextInsets(6, 6, 0, 0) end
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetPoint("TOPLEFT", x, y)
    return eb
  end

  local function _MakeDropdown(x, y)
    local dd = CreateFrame("Frame", nil, pmContent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dd, INPUT_W)
    UIDropDownMenu_SetText(dd, "")
    dd:SetPoint("TOPLEFT", x, y)
    return dd
  end

  -- Step1: ComboInput (EditBox as single source of truth + dropdown button as filler)
  -- NOTE: This is only a control abstraction. No behavior wiring to data/commit in Step1.
  local function _MakeComboInput(x, y)
  local f = CreateFrame("Frame", nil, pmContent)
  f:SetSize(INPUT_W, INPUT_H)
  f:SetPoint("TOPLEFT", x, y)

  local eb = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  eb:SetSize(INPUT_W - 22, INPUT_H)
  eb:SetAutoFocus(false)
  eb:SetFont("Fonts\ARKai_T.ttf", 13, "")
  eb:SetJustifyH("LEFT")
  if eb.SetTextInsets then eb:SetTextInsets(6, 6, 0, 0) end
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  eb:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

  local btn = CreateFrame("Button", nil, f, "UIPanelScrollDownButtonTemplate")
  btn:SetSize(18, 18)
  btn:ClearAllPoints()
  btn:SetPoint("RIGHT", f, "RIGHT", -2, 0)

  local menuFrame = CreateFrame("Frame", nil, f, "UIDropDownMenuTemplate")
  menuFrame:Hide()

  -- Step3: lock refresh/selection into EditGuard (no side effects),
  -- and support "input + dropdown" as a single-source-of-truth control.
  local function _RunGuarded(reason, fn)
    local EG = Gate and Gate.Get and Gate:Get("EditGuard")
    if EG and EG.RunGuarded then
      EG:RunGuarded(reason or "ComboInput", fn)
    else
      fn()
    end
  end

  f._options = {}
  f._optionsProvider = nil
  f._onPick = nil

  function f:SetOptions(options)
    self._optionsProvider = nil
    self._options = options or {}
  end

  function f:SetOptionsProvider(fn)
    self._optionsProvider = fn
  end

  function f:SetOnPick(fn)
    self._onPick = fn
  end

  function f:SetText(v)
    eb:SetText(v or "")
  end

  function f:SetTextSilent(v)
    _RunGuarded("ComboInput:SetTextSilent", function()
      eb:SetText(v or "")
    end)
  end

  function f:GetText()
    return eb:GetText() or ""
  end

  local function _NormalizeOpt(opt)
    local t = opt
    local v = opt
    if type(opt) == "table" then
      t = opt.text or opt.label or opt.value or opt[1] or ""
      v = opt.value or opt.text or opt.label or opt[1] or ""
    end
    return tostring(t or ""), tostring(v or ""), opt
  end

  local function _MatchesFilter(label, filter)
    if not filter or filter == "" then return true end
    label = tostring(label or "")
    filter = tostring(filter or "")
    if label == "" then return false end
    label = label:lower()
    filter = filter:lower()
    return label:find(filter, 1, true) ~= nil
  end

  local function _OpenMenu()
    local options = nil
    if type(f._optionsProvider) == "function" then
      local ok, ret = pcall(f._optionsProvider, f, f:GetText())
      if ok and type(ret) == "table" then options = ret end
    end
    if not options then options = f._options or {} end

    local filter = f:GetText()
    local menu = {}
    for _, opt in ipairs(options) do
      local label, value, raw = _NormalizeOpt(opt)
      if _MatchesFilter(label, filter) or _MatchesFilter(value, filter) then
        menu[#menu+1] = {
          text = label,
          notCheckable = true,
          func = function()
            _RunGuarded("ComboInput:Pick", function()
              eb:SetText(value or "")
            end)
            if type(f._onPick) == "function" then
              f._onPick(tostring(value or ""), raw)
            end
          end,
        }
      end
    end
    if #menu == 0 then
      menu[1] = { text = " ", isTitle = true, notCheckable = true }
    end
    EasyMenu(menu, menuFrame, btn, 0, 0, "MENU")
  end

  btn:SetScript("OnClick", _OpenMenu)
  eb:SetScript("OnKeyDown", function(self, key)
    if key == "DOWN" then
      _OpenMenu()
    end
  end)

  f._editBox = eb
  f._button = btn
  f._menuFrame = menuFrame
  return f
end



  -- Layout (match CustomMat spacing)
  -- Labels use the same column anchors as CustomMat (18 / 210)
  -- Controls are nudged left by 18px (0 / 190) to match Blizzard dropdown padding.
  local LBL_LX  = 20
  local LBL_RX  = 212
  local CTRL_LX = 20
  local CTRL_RX = 210
  local ROW1_Y  = -52
  local BOX1_Y  = ROW1_Y - 20
  local ROW2_Y  = ROW1_Y - 56
  local BOX2_Y  = ROW2_Y - 20

  -- Step4: fixed content height (viewport is fixed; content height must be > viewport to enable scrolling)
  -- Compute from the lowest control row + padding; no dynamic layout needed for this drawer.
  local CONTENT_PAD_BOTTOM = 16
  local CONTENT_PAD_TOP    = 16

  local fgLbl = _MakeLabel(_T("PROG_MAT_FG", "前景材质"), LBL_LX-2, ROW1_Y)
  local fgBox = _MakeComboInput(CTRL_LX+3, BOX1_Y)

  local bgLbl = _MakeLabel(_T("PROG_MAT_BG", "背景材质"), LBL_RX, ROW1_Y)
  local bgBox = _MakeComboInput(CTRL_RX+5, BOX1_Y)

  local typeLbl = _MakeLabel(_T("PROG_MAT_TYPE", "进度条类型"), LBL_LX-2, ROW2_Y)
  local typeBox = _MakeComboInput(CTRL_LX+3, BOX2_Y)

  local maskLbl = _MakeLabel(_T("PROG_MAT_MASK", "遮罩材质"), LBL_RX, ROW2_Y)
  local maskBox = _MakeComboInput(CTRL_RX+5, BOX2_Y)

  -- Step4: apply fixed content height formula
  -- Lowest row is BOX2_Y (top of EditBox). Height = distance from top padding to bottom of last EditBox + bottom padding.
  local lastBottomY = BOX2_Y - INPUT_H
  local contentH = (-lastBottomY) + CONTENT_PAD_BOTTOM
  if contentH < 1 then contentH = 1 end
  pmContent:SetHeight(contentH)

  -- Step9: UI-only append (do NOT touch existing layout). Add 6 placeholder controls under the first 4 rows.
  do
        -- New rows baseline (below BOX2) - keep alignment with existing grid.
        local LINE1_Y = ROW2_Y - 72
        local LINE2_Y = LINE1_Y - 42

        -- 2-row, 3-col layout: each label + its control share the same Y (one horizontal line per row).
        local COL1_X = LBL_LX-3
        local COL2_X = 85
        local COL3_X = LBL_RX-13

        -- Row 1: FG Color | Shape
        local fgColorLbl = _MakeLabel(_T("PROG_MAT_FG_COLOR", "前景颜色"), 0, 0)
        fgColorLbl:ClearAllPoints()
        fgColorLbl:SetPoint("LEFT", pmContent, "TOPLEFT", COL1_X, LINE1_Y)
        local fgSwatch = CreateFrame("Button", nil, pmContent, "BackdropTemplate")
        fgSwatch:SetSize(34, 22)
        fgSwatch:ClearAllPoints()
        fgSwatch:SetPoint("LEFT", fgColorLbl, "RIGHT", 3, 0)
        fgSwatch:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile="Interface/Tooltips/UI-Tooltip-Border", edgeSize=10, insets={left=2,right=2,top=2,bottom=2} })
        fgSwatch:SetBackdropColor(1, 1, 1, 1)

        local shapeLbl = _MakeLabel(_T("PROG_MAT_SHAPE", "进度条形状"), 0, 0)
        shapeLbl:ClearAllPoints()
        shapeLbl:SetPoint("LEFT", pmContent, "TOPLEFT", COL3_X, LINE1_Y)
        local shapeDD  = _MakeDropdown(0, 0)
        shapeDD:ClearAllPoints()
        shapeDD:SetPoint("LEFT", shapeLbl, "RIGHT", -15, -2)
        UIDropDownMenu_SetWidth(shapeDD, 80)

        -- Row 2: BG Color | Direction
        local bgColorLbl = _MakeLabel(_T("PROG_MAT_BG_COLOR", "背景颜色"), 0, 0)
        bgColorLbl:ClearAllPoints()
        bgColorLbl:SetPoint("LEFT", pmContent, "TOPLEFT", COL1_X, LINE2_Y)
        local bgSwatch = CreateFrame("Button", nil, pmContent, "BackdropTemplate")
        bgSwatch:SetSize(34, 22)
        bgSwatch:ClearAllPoints()
        bgSwatch:SetPoint("LEFT", bgColorLbl, "RIGHT", 3, 0)
        bgSwatch:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile="Interface/Tooltips/UI-Tooltip-Border", edgeSize=10, insets={left=2,right=2,top=2,bottom=2} })
        bgSwatch:SetBackdropColor(0.7, 0.7, 0.7, 1)

        local dirLbl = _MakeLabel(_T("PROG_MAT_DIR", "进度条方向"), 0, 0)
        dirLbl:ClearAllPoints()
        dirLbl:SetPoint("LEFT", pmContent, "TOPLEFT", COL3_X, LINE2_Y)
        local dirDD  = _MakeDropdown(0, 0)
        dirDD:ClearAllPoints()
        dirDD:SetPoint("LEFT", dirLbl, "RIGHT", -15, -2)
        UIDropDownMenu_SetWidth(dirDD, 80)

        -- Raise content height to include new rows (append-only; do not touch earlier layout math)
        local extra = 120
        local h = pmContent:GetHeight() or 1
        pmContent:SetHeight(h + extra)

        -- Keep references (UI-only)
        drawer._pmFgSwatch = fgSwatch
        drawer._pmBgSwatch = bgSwatch
        drawer._pmShapeDD = shapeDD
        drawer._pmDirDD = dirDD
      end


  if drawer._FixProgressMatScroll then drawer._FixProgressMatScroll() end

-- Step3: default option lists (dropdown is a filler; EditBox remains the true source)
typeBox:SetOptions({
  { text = _T("PROG_TYPE_LINEAR", "线性"), value = "linear" },
  { text = _T("PROG_TYPE_CIRCULAR", "圆形"), value = "circular" },
})


  drawer._progressMat = {
    fgLbl = fgLbl, fgBox = fgBox,
    bgLbl = bgLbl, bgBox = bgBox,
    typeLbl = typeLbl, typeBox = typeBox,
    maskLbl = maskLbl, maskBox = maskBox,
  }
  -- expose controls to pane for RefreshRight/validation
  p._progressMat = drawer._progressMat



  -- register drawer (routing via OpenDrawer("ProgressMat"))
  p._drawers = p._drawers or {}
  p._drawerOrder = p._drawerOrder or {}
  
  -- Step8 (v2.14.69): Create new template-based ProgressMat drawer
  local USE_NEW_PROGRESSMAT_DRAWER = true
  
  if USE_NEW_PROGRESSMAT_DRAWER then
    local DT = Bre.DrawerTemplate
    local spec = Bre.DrawerSpec_ProgressMat
    if DT and spec then
      local newDrawer = DT:Create(p, spec)
      if newDrawer then
        drawer:Hide()
        p._drawerProgressMat_new = newDrawer
        p._drawers.ProgressMat = newDrawer
      else
        p._drawers.ProgressMat = drawer
      end
    else
      p._drawers.ProgressMat = drawer
    end
  else
    p._drawers.ProgressMat = drawer
  end
  
  p._drawerOrder.ProgressMat = p._drawerOrder.ProgressMat or 1

  -- StepX (v2.19.25): Create new template-based StopMotion drawer (定格动画) - Empty Drawer shell
  do
    local DT = Bre.DrawerTemplate
    local spec = Bre.DrawerSpec_StopMotion
    if DT and spec then
      local newDrawer = DT:Create(p, spec)
      if newDrawer then
        p._drawers.StopMotion = newDrawer
      end
    end
    if not (p._drawers and p._drawers.StopMotion) then
      local drawer = CreateFrame("Frame", nil, p, "BackdropTemplate")
      drawer:SetAllPoints(p)
      drawer:Hide()
      p._drawers.StopMotion = drawer
    end
    p._drawerOrder.StopMotion = p._drawerOrder.StopMotion or 3
  end

  -- StepX (v2.18.74): Create new template-based Model drawer (3D人物) - empty shell in Step1
  do
    local DT = Bre.DrawerTemplate
    local spec = Bre.DrawerSpec_Model
    if DT and spec then
      local newDrawer = DT:Create(p, spec)
      if newDrawer then
        p._drawers.Model = newDrawer
      end
    end
    -- Fallback to a blank frame if template not available (should not happen)
    if not p._drawers.Model then
      local drawer = CreateFrame("Frame", nil, p, "BackdropTemplate")
      drawer:SetAllPoints(p)
      drawer:Hide()
      p._drawers.Model = drawer
    end
    p._drawerOrder.Model = p._drawerOrder.Model or 2
  end

  -- StepX (v1.13.x): ThemeMinimal drawer (single-column: size + strata + offsets)
  -- NOTE: Not used by default routing; intended for future profile/theme mode.
  do
    local DT = Bre.DrawerTemplate
    local spec = Bre.DrawerSpec_ThemeMinimal
    if DT and spec then
      local newDrawer = DT:Create(p, spec)
      if newDrawer then
        p._drawers.ThemeMinimal = newDrawer
      end
    end
    if not (p._drawers and p._drawers.ThemeMinimal) then
      local drawer = CreateFrame("Frame", nil, p, "BackdropTemplate")
      drawer:SetAllPoints(p)
      drawer:Hide()
      p._drawers.ThemeMinimal = drawer
    end
    p._drawerOrder.ThemeMinimal = p._drawerOrder.ThemeMinimal or 4
  end

end



-- ------------------------------------------------------------
-- Drawer API (Step2 v2.14.3)
-- - OpenDrawer(id) / CloseAll()
-- - Manages Show/Hide + Enable/Disable + FrameLevel stacking
-- ------------------------------------------------------------
do
  -- Drawer registry (extensible; no hard upper limit)
  p._drawers = p._drawers or {}
  p._drawerOrder = p._drawerOrder or {}

  -- Register known drawers (baseline + layer2)
  if p._drawerCustomMat and not p._drawers.CustomMat then
    p._drawers.CustomMat = p._drawerCustomMat
    p._drawerOrder.CustomMat = p._drawerOrder.CustomMat or 0
  end


  local function _GetNextOrder()
    local maxv = -1
    for _, v in pairs(p._drawerOrder) do
      if type(v) == "number" and v > maxv then maxv = v end
    end
    return maxv + 1
  end

  local function _SyncDrawerLayer(drawerId)
    local drawer = p._drawers and p._drawers[drawerId]
    if not drawer then return end

    -- Same strata as pane; do not promote to DIALOG/TOOLTIP.
    local strata = (p and p.GetFrameStrata and p:GetFrameStrata()) or nil
    if strata and drawer.SetFrameStrata then drawer:SetFrameStrata(strata) end

    local baseLevel = (p._drawerCustomMat and p._drawerCustomMat.GetFrameLevel and p._drawerCustomMat:GetFrameLevel())
      or (p and p.GetFrameLevel and p:GetFrameLevel()) or 0
    local delta = 10
    local order = (p._drawerOrder and p._drawerOrder[drawerId])
    if type(order) ~= "number" then
      order = _GetNextOrder()
      p._drawerOrder[drawerId] = order
    end

    drawer:SetFrameLevel((baseLevel or 0) + ((order or 0) * (delta or 0)))
  end

  local function _SetInteractive(frame, on)
    if not frame then return end
    if frame.EnableMouse then frame:EnableMouse(on and true or false) end
    if frame.SetMouseClickEnabled then frame:SetMouseClickEnabled(on and true or false) end
  end

  function p:CloseAll()
    if not self._drawers then return end
    for id, fr in pairs(self._drawers) do
      if fr then
        _SetInteractive(fr, false)
        fr:Hide()
      end
    end
    self._activeDrawerId = nil
  end

  function p:OpenDrawer(drawerId)
    if not drawerId then
      self:CloseAll()
      return
    end

    -- ensure registered (allow late-added drawers)
    if self._drawers and not self._drawers[drawerId] then
      return
    end

    self:CloseAll()

    local fr = self._drawers[drawerId]
    if fr then
      _SyncDrawerLayer(drawerId)
      _SetInteractive(fr, true)
      fr:Show()
      self._activeDrawerId = drawerId
    end
  end
end

local lp = content

  -- Texture path
  MakeLabel(lp, L("ELEM_MAT_TEXTURE"), 18, -52)

  local box = MakeBox(lp, 10, 24) -- size set by anchors
  box:SetPoint("TOPLEFT", 18, -74)
  box:SetPoint("TOPRIGHT", -66, -74)
  box:SetHeight(24)

  local DC = Bre.DrawerControls
local edit = (DC and DC.MakeEditBox and DC:MakeEditBox(box, 0, 0, 180)) or CreateFrame("EditBox", nil, box, "InputBoxTemplate")
edit:ClearAllPoints()
edit:SetPoint("LEFT", 6, 0)
edit:SetPoint("RIGHT", -6, 0)
edit:SetHeight(20)
edit:SetAutoFocus(false)
edit:SetFont("Fonts\ARKai_T.ttf", 13, "")
if edit.SetTextInsets then edit:SetTextInsets(6, 6, 0, 0) end
edit:EnableMouse(true)
edit:SetScript("OnMouseDown", function(self) self:SetFocus() end)
edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

  -- Preview swatch
  local prev = CreateFrame("Frame", nil, lp, "BackdropTemplate")
  prev:SetSize(72, 72)
  -- leave room for scrollbar
  prev:SetPoint("TOPLEFT", 18, -112)
  prev:SetBackdrop({ edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1 })
  prev:SetBackdropBorderColor(YELLOW_R, YELLOW_G, YELLOW_B, 0.55)
  prev:SetBackdropColor(0, 0, 0, 0.85)
  local prevTex = prev:CreateTexture(nil, "ARTWORK")
  prevTex:SetPoint("TOPLEFT", 2, -2)
  prevTex:SetPoint("BOTTOMRIGHT", -2, 2)
  prevTex:SetColorTexture(0, 0, 0, 0)

  -- Row 1: checkboxes (UseColor + Mirror + Fade)
  local chkUse = MakeCheckbox(lp, L("ELEM_MAT_USE_COLOR"))
  chkUse:SetPoint("TOPLEFT", 100, -118)

	  local colorBtn = MakeBox(lp, 36, 12)
  -- place swatch right after the UseColor label (not after the fixed-width checkbox wrapper)
  colorBtn:SetPoint("LEFT", chkUse._label, "RIGHT", 10, 0)

  -- BrA-style swatch: checker background + color fill + border
  local checker = colorBtn:CreateTexture(nil, "BACKGROUND")
  checker:SetAllPoints()
  checker:SetTexture("Interface\\Buttons\\WHITE8X8")
  checker:SetTexCoord(0, 1, 0, 1)
  checker:SetAlpha(0.25)
  colorBtn._checker = checker

  local swatch = colorBtn:CreateTexture(nil, "ARTWORK")
  swatch:SetAllPoints()
  swatch:SetColorTexture(1, 1, 1, 1)
  colorBtn._swatch = swatch

  local border = colorBtn:CreateTexture(nil, "OVERLAY")
  border:SetAllPoints()
  border:SetTexture("Interface\\ChatFrame\\ChatFrameColorSwatch")
  colorBtn._border = border

  local chkMirror = MakeCheckbox(lp, L("ELEM_MAT_MIRROR"))
  chkMirror:SetPoint("TOPLEFT", 260, -158)

  local chkFade = MakeCheckbox(lp, L("ELEM_MAT_FADE"))
  -- v2.10.5 tweak: move Fade slightly LEFT (previous adjustment direction was wrong)
  chkFade:SetPoint("TOPLEFT", 260, -118)


  -- ------------------------------------------------------------
  -- Section: Attributes
  -- ------------------------------------------------------------

  -- Y spacing knobs (do NOT change X values)
  local ATTR_DY = -16  -- move Attributes block down (more negative = lower)
  local POS_DY  = -32  -- move Position block down (more negative = lower)
  local sepAttr = lp:CreateTexture(nil, "ARTWORK")
  sepAttr:SetColorTexture(1, 1, 1, 0.12)
  -- push the divider down a bit for better spacing under the checkbox row
  -- extra spacing: push divider further down from the top block
  sepAttr:SetPoint("TOPLEFT", 16, (-186 + ATTR_DY))
  sepAttr:SetPoint("TOPRIGHT", -16, (-186 + ATTR_DY))
  sepAttr:SetHeight(1)

  local attrTitle = lp:CreateFontString(nil, "OVERLAY", (Bre.Font and Bre.Font:Large() or "GameFontNormalLarge"))
  attrTitle:SetPoint("TOPLEFT", 16, (-204 + ATTR_DY))
  attrTitle:SetTextColor(YELLOW_R, YELLOW_G, YELLOW_B)
  attrTitle:SetText(L("ELEM_MAT_ATTR"))

  -- Row 2: Alpha / Rotation / Fold (Blend swapped with Rotation)
  local alphaLbl = MakeLabel(lp, L("ELEM_MAT_ALPHA"), 18, (-230 + ATTR_DY))
  local alphaNum = CreateFrame("EditBox", nil, lp, "InputBoxTemplate")
  alphaNum:SetSize(48, 20)
  alphaNum:SetAutoFocus(false)
  alphaNum:SetFont("Fonts\ARKai_T.ttf", 13, "")
  alphaNum:SetJustifyH("CENTER")
  alphaNum:SetText("1.00")
  alphaNum:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  alphaNum:SetPoint("TOPLEFT", alphaLbl, "TOPRIGHT", 8, -2)
  local alpha = MakeSliderPlaceholder(lp, 150)
  alpha:SetPoint("TOPLEFT", 18, (-248 + ATTR_DY))

  -- Rotation moved to right column (was left)
  local rotLbl = MakeLabel(lp, L("ELEM_MAT_ROT"), 210, (-230 + ATTR_DY))
  local rotNum = CreateFrame("EditBox", nil, lp, "InputBoxTemplate")
  rotNum:SetSize(48, 20)
  rotNum:SetAutoFocus(false)
  rotNum:SetFont("Fonts\ARKai_T.ttf", 13, "")
  rotNum:SetJustifyH("CENTER")
  rotNum:SetText("0")
  rotNum:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  rotNum:SetPoint("TOPLEFT", rotLbl, "TOPRIGHT", 8, -2)
  local rot = MakeSliderPlaceholder(lp, 150)
	  -- v2.10.28: Rotation is expressed in degrees. The slider template defaults to 0..1,
	  -- which effectively disables rotation and clamps existing values.
	  -- Use a practical degree range and a sane step so SetValue(rdeg) works.
	  rot:SetMinMaxValues(-180, 180)
	  rot:SetValueStep(1)
	  rot:SetObeyStepOnDrag(true)
  rot:SetPoint("TOPLEFT", 210, (-248 + ATTR_DY))

  -- Fold stays in right column, below Rotation
  MakeLabel(lp, L("ELEM_MAT_FOLD"), 210, (-286 + ATTR_DY))
  local ddFold = MakeDropdownPlaceholder(lp, 150)
  ddFold:SetPoint("TOPLEFT", 190, (-306 + ATTR_DY))

  -- Blend moved to left column (was right)
  MakeLabel(lp, L("ELEM_MAT_BLEND"), 18, (-286 + ATTR_DY))
  local ddBlend = MakeDropdownPlaceholder(lp, 150)
  ddBlend:SetPoint("TOPLEFT", 0, (-306 + ATTR_DY))

  -- Size (Height / Width)
  local hLbl = MakeLabel(lp, L("ELEM_MAT_HEIGHT"), 18, (-342 + ATTR_DY))
  local hNum = CreateFrame("EditBox", nil, lp, "InputBoxTemplate")
  hNum:SetSize(48, 20)
  hNum:SetAutoFocus(false)
  hNum:SetFont("Fonts\ARKai_T.ttf", 13, "")
  hNum:SetJustifyH("CENTER")
  hNum:SetText("0")
  hNum:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  -- place numeric box right after the label (requested)
  hNum:SetPoint("TOPLEFT", hLbl, "TOPRIGHT", 8, -2)

  local h1 = MakeSliderPlaceholder(lp, 150)
  h1:SetPoint("TOPLEFT", 18, (-360 + ATTR_DY))

  local wLbl = MakeLabel(lp, L("ELEM_MAT_WIDTH"), 210, (-342 + ATTR_DY))
  local wNum = CreateFrame("EditBox", nil, lp, "InputBoxTemplate")
  wNum:SetSize(48, 20)
  wNum:SetAutoFocus(false)
  wNum:SetFont("Fonts\ARKai_T.ttf", 13, "")
  wNum:SetJustifyH("CENTER")
  wNum:SetText("0")
  wNum:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  wNum:SetPoint("TOPLEFT", wLbl, "TOPRIGHT", 8, -2)

  local w1 = MakeSliderPlaceholder(lp, 150)
  w1:SetPoint("TOPLEFT", 210, (-360 + ATTR_DY))

  -- ------------------------------------------------------------
  -- Section: Position
  -- ------------------------------------------------------------
  local sepPos = lp:CreateTexture(nil, "ARTWORK")
  sepPos:SetColorTexture(1, 1, 1, 0.12)
  sepPos:SetPoint("TOPLEFT", 16, (-386 + POS_DY))
  sepPos:SetPoint("TOPRIGHT", -16, (-386 + POS_DY))
  sepPos:SetHeight(1)

  local posTitle = lp:CreateFontString(nil, "OVERLAY", (Bre.Font and Bre.Font:Large() or "GameFontNormalLarge"))
  posTitle:SetPoint("TOPLEFT", 16, (-410 + POS_DY))
  posTitle:SetTextColor(YELLOW_R, YELLOW_G, YELLOW_B)
  posTitle:SetText(L("ELEM_MAT_POS"))


  MakeLabel(lp, L("ELEM_MAT_ALIGN_TO"), 18, (-450 + POS_DY))
  local alignTo = MakeDropdownPlaceholder(lp, 150)
  alignTo:SetPoint("TOPLEFT", 0, (-470 + POS_DY))

  local alignPick = nil
MakeLabel(lp, L("ELEM_MAT_FRAME_LEVEL"), 210, (-450 + POS_DY))
  local frameLevel = MakeDropdownPlaceholder(lp, 150)
  frameLevel:SetPoint("TOPLEFT", 190, (-470 + POS_DY))


  -- X/Y Offset (numeric input boxes only, no commit binding in Step2)
  local xLbl = MakeLabel(lp, L("ELEM_MAT_XOFF"), 18, (-510 + POS_DY))
  local xNum = CreateFrame("EditBox", nil, lp, "InputBoxTemplate")
  xNum:SetSize(48, 20)
  xNum:SetAutoFocus(false)
  xNum:SetFont("Fonts\ARKai_T.ttf", 13, "")
  xNum:SetJustifyH("CENTER")
  xNum:SetText("0")
  xNum:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  xNum:SetPoint("TOPLEFT", xLbl, "TOPRIGHT", 8, -2)

  local xOff = MakeSliderPlaceholder(lp, 150)
  xOff:SetPoint("TOPLEFT", 18, (-530 + POS_DY))

  local yLbl = MakeLabel(lp, L("ELEM_MAT_YOFF"), 210, (-510 + POS_DY))
  local yNum = CreateFrame("EditBox", nil, lp, "InputBoxTemplate")
  yNum:SetSize(48, 20)
  yNum:SetAutoFocus(false)
  yNum:SetFont("Fonts\ARKai_T.ttf", 13, "")
  yNum:SetJustifyH("CENTER")
  yNum:SetText("0")
  yNum:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  yNum:SetPoint("TOPLEFT", yLbl, "TOPRIGHT", 8, -2)

  local yOff = MakeSliderPlaceholder(lp, 150)
  yOff:SetPoint("TOPLEFT", 210, (-530 + POS_DY))


  -- store for later steps (binding will be added in Step2+)
  p._elemMat = {
    edit = edit,
    useColor = chkUse,
    colorBtn = colorBtn,
    mirror = chkMirror,
    fade = chkFade,
    blendDD = ddBlend,
    foldDD = ddFold,
    alpha = alpha,
    alphaNum = alphaNum,
    rot = rot,
    rotNum = rotNum,
    h1 = h1,
    hNum = hNum,
    w1 = w1,
    wNum = wNum,
    alignTo = alignTo,
    frameLevel = frameLevel,
    alignPick = alignPick,
	    xOff = xOff,
    xNum = xNum,
	    yOff = yOff,
    yNum = yNum,
    preview = prev,
    previewTex = prevTex,
  }


-- ------------------------------------------------------------
-- Wiring (Step2): all writes must go through Gate:Get("CustomMat")
-- CustomMat off => true no-op (no data writes, no preview apply, no side effects).
-- ------------------------------------------------------------
local function _CMEnabled()
  return Gate and Gate.Has and Gate:Has("CustomMat")
end
local function _CM()
  return Gate:Get("CustomMat")
end

local function _EnsureCMEnabled()
  if _CMEnabled() then return true end
  local Mods = Bre.Modules
  if Mods and Mods.Enable then
    pcall(function() Mods:Enable("CustomMat") end)
  end
  return _CMEnabled()
end


-- preview: when module is off, force-clear the preview to avoid stale visuals
p._elemMat.applyPreview = function(texObj, region, alphaVal)
  if not texObj then return end
  if not _CMEnabled() then
    if texObj.SetColorTexture then texObj:SetColorTexture(0, 0, 0, 0) end
    if texObj.SetTexCoord then texObj:SetTexCoord(0, 1, 0, 1) end
    if texObj.SetVertexColor then texObj:SetVertexColor(1, 1, 1, 1) end
    if texObj.SetAlpha then texObj:SetAlpha(1) end
    return
  end
  local CM = _CM()
  if CM and CM.ApplyToTexture then
    CM:ApplyToTexture(texObj, region, alphaVal)
  end
end

local function _CommitCustomMat()
  if not _EnsureCMEnabled() then return end
  local m = (p and p._elemMat) or nil
  if m and (m._suppressCommit or m._updatingSize or m._updatingAlign or m._updatingFrameLevel) then return end
  local EG = Gate:Get('EditGuard')
  if EG and EG.IsGuarded and EG:IsGuarded() then return end
  local f = UI.frame
  local es = f and _EnsureEditSession(f) or nil
  local m = p and p._elemMat
  local id, rev = _GetBoundNodeId(m, f)
  if not _IsBindAlive(f, rev) then return end
  if not id or not GetData then return end
  local data = GetData(id)
  if type(data) ~= "table" then return end

  local m = p._elemMat
  local CM = _CM()
  if not (CM and CM.CommitFromUI) then return end

  local blendText = nil
  if UIDropDownMenu_GetText then
    blendText = UIDropDownMenu_GetText(m.blendDD)
  end

  CM:CommitFromUI({
    id = id,
    data = data,
    textureText = (m.edit and m.edit.GetText and m.edit:GetText()) or "",
    useColor = (m.useColor and m.useColor.GetChecked and m.useColor:GetChecked()) or false,
    -- NOTE (v2.12.4+): mirror/fade/blend/size are owned by PropertyService (L1)
    previewTex = m.previewTex,
  })
end

local function _ClampSize(v)
  v = tonumber(v)
  if not v then return nil end
  v = math.floor(v + 0.5)
  if v < 1 then v = 1 end
  if v > 2048 then v = 2048 end
  return v
end

-- Only commit on explicit user interactions (avoid spam on RefreshRight)
if edit then
  edit:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    _CommitCustomMat()
    UI:RefreshRight()
  end)
end

if chkUse then
  chkUse:SetScript("OnClick", function()
      if not _EnsureCMEnabled() then return end
    _CommitCustomMat()
    UI:RefreshRight()
  end)
end

if chkMirror then
  chkMirror:SetScript("OnClick", function(self)
    local f = UI.frame
    local id, rev = _GetBoundNodeId(p and p._elemMat, f)
    if not _IsBindAlive(f, rev) then return end
    if not id then return end
    local PS = Gate:Get('PropertyService')
    if PS and PS.Set then
      local ok, data = PS:Set(id, 'mirror', self:GetChecked() and true or false)
      if ok and data and p and p._elemMat and p._elemMat.applyPreview then
        local m = p._elemMat
        p._elemMat.applyPreview(m.previewTex, data.region, data.alpha)
      end
    end
    UI:RefreshRight()
  end)
end

  if chkFade then
    chkFade:SetScript("OnClick", function(self)
      local f = UI.frame
      local id, rev = _GetBoundNodeId(p and p._elemMat, f)
      if not _IsBindAlive(f, rev) then return end
      if not id then return end
      local PS = Gate:Get('PropertyService')
      if PS and PS.Set then
        local ok, data = PS:Set(id, 'fade', self:GetChecked() and true or false)
        if ok and data and p and p._elemMat and p._elemMat.applyPreview then
          local m = p._elemMat
          p._elemMat.applyPreview(m.previewTex, data.region, data.alpha)
        end
      end
      UI:RefreshRight()
    end)
  end

-- BlendMode dropdown (Step5): commit via PropertyService (L1)
if ddBlend and UIDropDownMenu_Initialize then
  UIDropDownMenu_Initialize(ddBlend, function(self, level)
    if level ~= 1 then return end
    local function _choose(v)
      local f = UI.frame
      local id, rev = _GetBoundNodeId(p and p._elemMat, f)
      if not _IsBindAlive(f, rev) then return end
      if not id then return end
      UIDropDownMenu_SetText(ddBlend, v)
      local PS = Gate:Get('PropertyService')
      if PS and PS.Set then
        PS:Set(id, 'blendMode', v)
      end
      UI:RefreshRight()
    end

    for _, v in ipairs({ 'BLEND', 'ADD', 'MOD', 'ALPHAKEY' }) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = v
      info.value = v
      info.func = function() _choose(v) end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
end


if alpha then
    local function _previewAlphaFromUI(val)
      local f = UI.frame
      local id, rev = _GetBoundNodeId(p and p._elemMat, f)
      if not _IsBindAlive(f, rev) then return end
      local PS = Gate:Get('PropertyService')
      if PS and PS.PreviewSet then
        local ok, data = PS:PreviewSet(id, 'alpha', val)
        if ok and data and p and p._elemMat and p._elemMat.applyPreview then
          local m = p._elemMat
          p._elemMat.applyPreview(m.previewTex, data.region, data.alpha)
        end
      end
    end

    local function _commitAlphaFromUI(val)
      local f = UI.frame
      local id, rev = _GetBoundNodeId(p and p._elemMat, f)
      if not _IsBindAlive(f, rev) then return end
      local PS = Gate:Get('PropertyService')
      if PS and PS.Set then
        local ok, data = PS:Set(id, 'alpha', val)
        if ok and data and p and p._elemMat and p._elemMat.applyPreview then
          local m = p._elemMat
          p._elemMat.applyPreview(m.previewTex, data.region, data.alpha)
        end
      end
    end

    -- Live preview while dragging (no DB write)
    alpha:HookScript("OnValueChanged", function(self)
      _previewAlphaFromUI(self:GetValue())
    end)
    -- Commit on release
    alpha:HookScript("OnMouseUp", function(self)
      _commitAlphaFromUI(self:GetValue())
    end)
    -- Keep numeric box in sync (slider -> text)
    alpha:HookScript("OnValueChanged", function(self)
      local m = (p and p._elemMat) or nil
      if not m or m._updatingAlpha then return end
      if m.alphaNum and m.alphaNum.SetText then
        m._updatingAlpha = true
        m.alphaNum:SetText(string.format("%.2f", self:GetValue()))
        m._updatingAlpha = false
      end
    end)

    -- Numeric box -> slider + commit
    local m = (p and p._elemMat) or nil
    if m and m.alphaNum then
      local function _applyAlphaNum()
        if m._updatingAlpha then return end
        local v = tonumber(m.alphaNum:GetText())
        if not v then v = tonumber(alpha:GetValue()) or 1 end
        if v < 0 then v = 0 elseif v > 1 then v = 1 end
        m._updatingAlpha = true
        alpha:SetValue(v)
        m.alphaNum:SetText(string.format("%.2f", v))
        m._updatingAlpha = false
        _commitAlphaFromUI(v)
        UI:RefreshRight()
      end
      m.alphaNum:SetScript("OnEnterPressed", function(self) self:ClearFocus(); _applyAlphaNum() end)
      m.alphaNum:SetScript("OnEditFocusLost", function() _applyAlphaNum() end)
    end
  end

if rot then
	  local function _previewRotFromUI(val)
      local f = UI.frame
      local id, rev = _GetBoundNodeId(p and p._elemMat, f)
      if not _IsBindAlive(f, rev) then return end
      local PS = Gate:Get('PropertyService')
      if PS and PS.PreviewSet then
        local ok, data = PS:PreviewSet(id, 'rotation', val)
        if ok and data and p and p._elemMat and p._elemMat.applyPreview then
          local m = p._elemMat
          p._elemMat.applyPreview(m.previewTex, data.region, data.alpha)
        end
      end
    end

	  local function _commitRotFromUI(val)
      local f = UI.frame
      local id, rev = _GetBoundNodeId(p and p._elemMat, f)
      if not _IsBindAlive(f, rev) then return end
      local PS = Gate:Get('PropertyService')
      if PS and PS.Set then
        local ok, data = PS:Set(id, 'rotation', val)
        if ok and data and p and p._elemMat and p._elemMat.applyPreview then
          local m = p._elemMat
          p._elemMat.applyPreview(m.previewTex, data.region, data.alpha)
        end
      end
    end
	  -- live preview while dragging (no DB write)
	  rot:HookScript("OnValueChanged", function(self)
	    _previewRotFromUI(self:GetValue())
	  end)
	  -- commit on release
	  rot:HookScript("OnMouseUp", function(self)
	    _commitRotFromUI(self:GetValue())
	  end)
	  -- Keep numeric box in sync (slider -> text)
	  rot:HookScript("OnValueChanged", function(self)
	    local m = (p and p._elemMat) or nil
	    if not m or m._updatingRot then return end
	    if m.rotNum and m.rotNum.SetText then
	      m._updatingRot = true
	      m.rotNum:SetText(tostring(math.floor((tonumber(self:GetValue()) or 0) + 0.5)))
	      m._updatingRot = false
	    end
	  end)

	  -- Numeric box -> slider + commit
	  local m = (p and p._elemMat) or nil
	  if m and m.rotNum then
	    local function _applyRotNum()
	      if m._updatingRot then return end
	      local v = tonumber(m.rotNum:GetText())
	      if not v then v = tonumber(rot:GetValue()) or 0 end
	      v = math.floor(v + 0.5)
	      if v < -180 then v = -180 elseif v > 180 then v = 180 end
	      m._updatingRot = true
	      rot:SetValue(v)
	      m.rotNum:SetText(tostring(v))
	      m._updatingRot = false
	      _commitRotFromUI(v)
	      UI:RefreshRight()
	    end
	    m.rotNum:SetNumeric(true)
	    m.rotNum:SetScript("OnEnterPressed", function(self) self:ClearFocus(); _applyRotNum() end)
	    m.rotNum:SetScript("OnEditFocusLost", function() _applyRotNum() end)
	  end
end

-- Size (Height/Width): UI -> data.size -> runtime apply
if h1 or w1 or hNum or wNum then
  local mSize = p._elemMat
  mSize._updatingSize = false

  local function _syncSizeFromSliders()
    if mSize._updatingSize then return end
    mSize._updatingSize = true
    local hv = h1 and _ClampSize(h1:GetValue())
    local wv = w1 and _ClampSize(w1:GetValue())
    if hv and h1 then h1:SetValue(hv) end
    if wv and w1 then w1:SetValue(wv) end
    if hv and hNum and hNum.SetText then hNum:SetText(tostring(hv)) end
    if wv and wNum and wNum.SetText then wNum:SetText(tostring(wv)) end
    mSize._updatingSize = false
  end

local function _previewSize()
  if mSize._updatingSize then return end
  local f = UI.frame
  local id, rev = _GetBoundNodeId(p and p._elemMat, f)
  if not _IsBindAlive(f, rev) then return end
  if not id then return end
  local PS = Gate:Get('PropertyService')
  if PS and PS.PreviewApply then
    local hv = h1 and _ClampSize(h1:GetValue())
    local wv = w1 and _ClampSize(w1:GetValue())
    PS:PreviewApply(id, { sizeH = hv, sizeW = wv })
  end
end


  local function _commitSize()
    if mSize._updatingSize then return end
    local f = UI.frame
    local id, rev = _GetBoundNodeId(p and p._elemMat, f)
    if not _IsBindAlive(f, rev) then return end
    if not id then return end
    local PS = Gate:Get('PropertyService')
    if PS and PS.Apply then
      local hv = h1 and _ClampSize(h1:GetValue())
      local wv = w1 and _ClampSize(w1:GetValue())
      PS:Apply(id, { sizeH = hv, sizeW = wv })
    end
  end

  if h1 then
    h1:SetMinMaxValues(1, 2048)
    h1:SetValueStep(1)
    h1:SetObeyStepOnDrag(true)
    h1:SetScript("OnValueChanged", function()
      if mSize._updatingSize then return end
      _syncSizeFromSliders()
      _previewSize()
    end)
    h1:SetScript("OnMouseUp", function() _commitSize() end)
  end

  if w1 then
    w1:SetMinMaxValues(1, 2048)
    w1:SetValueStep(1)
    w1:SetObeyStepOnDrag(true)
    w1:SetScript("OnValueChanged", function()
      if mSize._updatingSize then return end
      _syncSizeFromSliders()
      _previewSize()
    end)
    w1:SetScript("OnMouseUp", function() _commitSize() end)
  end

  local function _applyNumToSlider(which)
    if mSize._updatingSize then return end
    local eb = (which == "H") and hNum or wNum
    local sb = (which == "H") and h1 or w1
    if not eb or not sb then return end
    local v = _ClampSize(eb:GetText())
    if not v then
      v = _ClampSize(sb:GetValue())
    end
    mSize._updatingSize = true
    sb:SetValue(v)
    eb:SetText(_FmtOffset(v))
    mSize._updatingSize = false
    _commitSize()
    UI:RefreshRight()
  end

  if hNum then
    hNum:SetNumeric(true)
    hNum:SetScript("OnEnterPressed", function(self) self:ClearFocus(); _applyNumToSlider("H") end)
  end

  if wNum then
    wNum:SetNumeric(true)
    wNum:SetScript("OnEnterPressed", function(self) self:ClearFocus(); _applyNumToSlider("W") end)
  end

  -- Hard isolate refresh: allow RefreshRight to detach handlers while setting values
  mSize._handlers = mSize._handlers or {}
  mSize._handlers.h1 = h1 and { OnValueChanged = h1:GetScript("OnValueChanged"), OnMouseUp = h1:GetScript("OnMouseUp") } or nil
  mSize._handlers.w1 = w1 and { OnValueChanged = w1:GetScript("OnValueChanged"), OnMouseUp = w1:GetScript("OnMouseUp") } or nil

  function mSize:_SizeDetach()
    if h1 then h1:SetScript("OnValueChanged", nil); h1:SetScript("OnMouseUp", nil) end
    if w1 then w1:SetScript("OnValueChanged", nil); w1:SetScript("OnMouseUp", nil) end
  end

  function mSize:_SizeAttach()
    local hh = self._handlers
    if h1 and hh and hh.h1 then
      h1:SetScript("OnValueChanged", hh.h1.OnValueChanged)
      h1:SetScript("OnMouseUp", hh.h1.OnMouseUp)
    end
    if w1 and hh and hh.w1 then
      w1:SetScript("OnValueChanged", hh.w1.OnValueChanged)
      w1:SetScript("OnMouseUp", hh.w1.OnMouseUp)
    end
  end

end

-- ------------------------------------------------------------
-- Position: AlignTo (Step3)
-- Stable chain: RefreshRight must never trigger commit.
-- Commit only happens on user selection.
-- Switch align target is a structure-level change: route via Gate:Get('Move').
-- ------------------------------------------------------------
do
  local mPos = p._elemMat
  if mPos and mPos.alignTo then
    mPos._updatingAlign = false

    local function _commitAlign(value)
      if mPos._updatingAlign then return end
      local f = UI.frame
      local id, rev = _GetBoundNodeId(mPos, f)
      if not _IsBindAlive(f, rev) then return end
      if not id then return end
      local TS = Gate:Get('TargetService')
      if TS and TS.CommitAlignToMode then
        TS:CommitAlignToMode(id, value)
      end
      UI:RefreshRight()
    end

    local function _initAlignDD(self, level)
      if level ~= 1 then return end
      local info = UIDropDownMenu_CreateInfo()

      info.func = function(btn)
        local v = btn and btn.value
        if not v then return end
        UIDropDownMenu_SetSelectedValue(mPos.alignTo, v)
        if v ~= 'SCREEN_CENTER' then v = 'SCREEN_CENTER' end
        UIDropDownMenu_SetText(mPos.alignTo, L('ELEM_MAT_ALIGN_TO_SCREEN_CENTER'))
        _commitAlign(v)
      end

      info.text = L('ELEM_MAT_ALIGN_TO_SCREEN_CENTER')
      info.value = 'SCREEN_CENTER'
      UIDropDownMenu_AddButton(info, level)
      -- (UI hidden) SELECTED_NODE option removed
end

    UIDropDownMenu_Initialize(mPos.alignTo, _initAlignDD)
    UIDropDownMenu_SetSelectedValue(mPos.alignTo, 'SCREEN_CENTER')
    UIDropDownMenu_SetText(mPos.alignTo, L('ELEM_MAT_ALIGN_TO_SCREEN_CENTER'))

    

    -- Step M5: Pick targetId on screen (delegated to TargetService)

    if mPos.alignPick then
      mPos.alignPick:SetScript("OnClick", function()
        local f = UI.frame
        local id, rev = _GetBoundNodeId(mPos, f)
        if not _IsBindAlive(f, rev) then return end
        if not id then return end
        local TS = Gate:Get("TargetService")
        if TS and TS.BeginPickTarget then
          TS:BeginPickTarget(id, function()
            UI:RefreshRight()
          end)
        end
      end)
    end
-- Hard isolate refresh: allow RefreshRight to detach handlers while setting text.
    function mPos:_AlignDetach()
      self._updatingAlign = true
    end
    function mPos:_AlignAttach()
      self._updatingAlign = false
    end
  end
end


-- ------------------------------------------------------------
-- Position: Offsets (Step4)
-- Stable chain: RefreshRight must never trigger commit.
-- Commit only happens on explicit user interactions:
--   - sliders: OnMouseUp
--   - numeric boxes: OnEnterPressed / OnEditFocusLost
-- During drag/value change, we only sync UI (no writes).
-- ------------------------------------------------------------
do
  local mPos = p._elemMat
  if mPos and (mPos.xOff or mPos.yOff) and (mPos.xNum or mPos.yNum) then
    mPos._updatingOffset = false

    local function _ClampOffset(v)
      v = tonumber(v)
      if not v then return nil end
      if v < -4096 then v = -4096 end
      if v > 4096 then v = 4096 end
      return v
    end

    local function _FmtOffset(v)
      v = tonumber(v) or 0
      if v < -4096 then v = -4096 end
      if v > 4096 then v = 4096 end
      local iv = math.floor(v)
      if math.abs(v - iv) < 1e-9 then
        return tostring(iv)
      end
      return string.format("%.1f", v)
    end

    local function _syncOffsetFromSliders()
      if mPos._updatingOffset then return end
      local xo = (mPos.xOff and mPos.xOff.GetValue and mPos.xOff:GetValue()) or 0
      local yo = (mPos.yOff and mPos.yOff.GetValue and mPos.yOff:GetValue()) or 0
      xo = _ClampOffset(xo) or 0
      yo = _ClampOffset(yo) or 0
      mPos._updatingOffset = true
      if mPos.xNum and mPos.xNum.SetText then mPos.xNum:SetText(_FmtOffset(xo)) end
      if mPos.yNum and mPos.yNum.SetText then mPos.yNum:SetText(_FmtOffset(yo)) end
      mPos._updatingOffset = false
    end

    local function _commitOffset()
      if mPos._updatingOffset then return end
      local f = UI.frame
      local id, rev = _GetBoundNodeId(mPos, f)
      if not _IsBindAlive(f, rev) then return end
      if not id then return end

      local xo = (mPos.xOff and mPos.xOff.GetValue and mPos.xOff:GetValue()) or 0
      local yo = (mPos.yOff and mPos.yOff.GetValue and mPos.yOff:GetValue()) or 0
      xo = _ClampOffset(xo) or 0
      yo = _ClampOffset(yo) or 0

      local Move = Gate:Get('Move')
      if Move and Move.CommitOffsets then
        Move:CommitOffsets({ id = id, xOffset = xo, yOffset = yo })
      end
    end

    local function _applyNumToSlider(which)
      if mPos._updatingOffset then return end
      local eb = (which == "Y") and mPos.yNum or mPos.xNum
      local sb = (which == "Y") and mPos.yOff or mPos.xOff
      if not eb or not sb then return end
      local v = _ClampOffset(eb:GetText())
      if not v then
        v = _ClampOffset(sb:GetValue()) or 0
      end
      mPos._updatingOffset = true
      sb:SetValue(v)
      eb:SetText(_FmtOffset(v))
      mPos._updatingOffset = false
      _commitOffset()
      UI:RefreshRight()
    end

    -- sliders: value changed only syncs numeric display (no commit)
    if mPos.xOff then
      mPos.xOff:SetScript("OnValueChanged", function()
        if mPos._updatingOffset then return end
        _syncOffsetFromSliders()
      end)
      mPos.xOff:SetScript("OnMouseUp", function()
        _commitOffset()
        UI:RefreshRight()
      end)
    end
    if mPos.yOff then
      mPos.yOff:SetScript("OnValueChanged", function()
        if mPos._updatingOffset then return end
        _syncOffsetFromSliders()
      end)
      mPos.yOff:SetScript("OnMouseUp", function()
        _commitOffset()
        UI:RefreshRight()
      end)
    end

    -- numeric boxes: commit on Enter / focus lost
    if mPos.xNum then
            mPos.xNum:SetScript("OnEnterPressed", function(self) self:ClearFocus(); _applyNumToSlider("X") end)
      mPos.xNum:SetScript("OnEditFocusLost", function() _applyNumToSlider("X") end)
    end
    if mPos.yNum then
            mPos.yNum:SetScript("OnEnterPressed", function(self) self:ClearFocus(); _applyNumToSlider("Y") end)
      mPos.yNum:SetScript("OnEditFocusLost", function() _applyNumToSlider("Y") end)
    end

    -- Hard isolate refresh: allow RefreshRight to detach handlers while setting values
    mPos._handlers = mPos._handlers or {}
    mPos._handlers.xOff = mPos.xOff and { OnValueChanged = mPos.xOff:GetScript("OnValueChanged"), OnMouseUp = mPos.xOff:GetScript("OnMouseUp") } or nil
    mPos._handlers.yOff = mPos.yOff and { OnValueChanged = mPos.yOff:GetScript("OnValueChanged"), OnMouseUp = mPos.yOff:GetScript("OnMouseUp") } or nil

    function mPos:_OffsetDetach()
      if self.xOff then self.xOff:SetScript("OnValueChanged", nil); self.xOff:SetScript("OnMouseUp", nil) end
      if self.yOff then self.yOff:SetScript("OnValueChanged", nil); self.yOff:SetScript("OnMouseUp", nil) end
    end

    function mPos:_OffsetAttach()
      local hh = self._handlers
      if self.xOff and hh and hh.xOff then
        self.xOff:SetScript("OnValueChanged", hh.xOff.OnValueChanged)
        self.xOff:SetScript("OnMouseUp", hh.xOff.OnMouseUp)
      end
      if self.yOff and hh and hh.yOff then
        self.yOff:SetScript("OnValueChanged", hh.yOff.OnValueChanged)
        self.yOff:SetScript("OnMouseUp", hh.yOff.OnMouseUp)
      end
    end

  end
end

-- ------------------------------------------------------------
-- Frame Level (Step4)
-- Stable chain: RefreshRight must never trigger commit.
-- Commit only happens on user selection.
-- Frame level is a structure-level intent: route via Gate:Get('Move').
-- ------------------------------------------------------------
do
  local mPos = p._elemMat
  if mPos and mPos.frameLevel then
    mPos._updatingFrameLevel = false

    local function _commitFrameLevel(value)
      if mPos._updatingFrameLevel then return end
      local f = UI.frame
      local id, rev = _GetBoundNodeId(mPos, f)
      if not _IsBindAlive(f, rev) then return end
      if not id then return end
      local Move = Gate:Get('Move')
      if Move and Move.CommitFrameStrata then
        Move:CommitFrameStrata({ id = id, value = value })
      end
      UI:RefreshRight()
    end

    local function _setFrameLevelText(v)
      if not UIDropDownMenu_SetText then return end
      if v == 'BACKGROUND' then
        UIDropDownMenu_SetText(mPos.frameLevel, L('ELEM_MAT_FRAME_LEVEL_BACKGROUND'))
      elseif v == 'LOW' then
        UIDropDownMenu_SetText(mPos.frameLevel, L('ELEM_MAT_FRAME_LEVEL_LOW'))
      elseif v == 'MEDIUM' then
        UIDropDownMenu_SetText(mPos.frameLevel, L('ELEM_MAT_FRAME_LEVEL_MEDIUM'))
      elseif v == 'HIGH' then
        UIDropDownMenu_SetText(mPos.frameLevel, L('ELEM_MAT_FRAME_LEVEL_HIGH'))
      elseif v == 'DIALOG' then
        UIDropDownMenu_SetText(mPos.frameLevel, L('ELEM_MAT_FRAME_LEVEL_DIALOG'))
      elseif v == 'FULLSCREEN' then
        UIDropDownMenu_SetText(mPos.frameLevel, L('ELEM_MAT_FRAME_LEVEL_FULLSCREEN'))
      elseif v == 'FULLSCREEN_DIALOG' then
        UIDropDownMenu_SetText(mPos.frameLevel, L('ELEM_MAT_FRAME_LEVEL_FULLSCREEN_DIALOG'))
      elseif v == 'TOOLTIP' then
        UIDropDownMenu_SetText(mPos.frameLevel, L('ELEM_MAT_FRAME_LEVEL_TOOLTIP'))
      else
        UIDropDownMenu_SetText(mPos.frameLevel, L('ELEM_MAT_FRAME_LEVEL_AUTO'))
      end
    end

    local function _initFrameDD(self, level)
      if level ~= 1 then return end

      local function _add(textKey, value)
        local info = UIDropDownMenu_CreateInfo()
        info.text = L(textKey)
        info.value = value
        info.arg1 = value
        info.func = function(_, arg1)
          local v = arg1
          if not v then return end
          UIDropDownMenu_SetSelectedValue(mPos.frameLevel, v)
          _setFrameLevelText(v)
          _commitFrameLevel(v)
        end
        UIDropDownMenu_AddButton(info, level)
      end

      _add('ELEM_MAT_FRAME_LEVEL_AUTO', 'AUTO')
      _add('ELEM_MAT_FRAME_LEVEL_BACKGROUND', 'BACKGROUND')
      _add('ELEM_MAT_FRAME_LEVEL_LOW', 'LOW')
      _add('ELEM_MAT_FRAME_LEVEL_MEDIUM', 'MEDIUM')
      _add('ELEM_MAT_FRAME_LEVEL_HIGH', 'HIGH')
      _add('ELEM_MAT_FRAME_LEVEL_DIALOG', 'DIALOG')
      _add('ELEM_MAT_FRAME_LEVEL_FULLSCREEN', 'FULLSCREEN')
      _add('ELEM_MAT_FRAME_LEVEL_FULLSCREEN_DIALOG', 'FULLSCREEN_DIALOG')
      _add('ELEM_MAT_FRAME_LEVEL_TOOLTIP', 'TOOLTIP')
    end

    UIDropDownMenu_Initialize(mPos.frameLevel, _initFrameDD)
    UIDropDownMenu_SetSelectedValue(mPos.frameLevel, 'AUTO')
    _setFrameLevelText('AUTO')

    function mPos:_FrameLevelDetach()
      self._updatingFrameLevel = true
    end
    function mPos:_FrameLevelAttach()
      self._updatingFrameLevel = false
    end
  end
end

-- ------------------------------------------------------------
-- X/Y Offsets (Step3)
-- RefreshRight must be able to set slider/editbox values WITHOUT triggering any commit.
-- In Step3 we only provide the hard isolate (Detach -> Set -> Attach).
-- Actual commit wiring is added in Step4.
-- ------------------------------------------------------------
do
  local mOff = p._elemMat
  if mOff and (mOff.xOff or mOff.yOff or mOff.xNum or mOff.yNum) then
    mOff._updatingOffset = mOff._updatingOffset or false

    -- snapshot current handlers so RefreshRight can hard-detach and restore
    mOff._offsetHandlers = mOff._offsetHandlers or {}
    if mOff.xOff and not mOff._offsetHandlers.xOff then
      mOff._offsetHandlers.xOff = {
        OnValueChanged = mOff.xOff:GetScript("OnValueChanged"),
        OnMouseUp = mOff.xOff:GetScript("OnMouseUp"),
      }
    end
    if mOff.yOff and not mOff._offsetHandlers.yOff then
      mOff._offsetHandlers.yOff = {
        OnValueChanged = mOff.yOff:GetScript("OnValueChanged"),
        OnMouseUp = mOff.yOff:GetScript("OnMouseUp"),
      }
    end
    if mOff.xNum and not mOff._offsetHandlers.xNum then
      mOff._offsetHandlers.xNum = {
        OnEnterPressed = mOff.xNum:GetScript("OnEnterPressed"),
        OnEditFocusLost = mOff.xNum:GetScript("OnEditFocusLost"),
        OnTextChanged = mOff.xNum:GetScript("OnTextChanged"),
      }
    end
    if mOff.yNum and not mOff._offsetHandlers.yNum then
      mOff._offsetHandlers.yNum = {
        OnEnterPressed = mOff.yNum:GetScript("OnEnterPressed"),
        OnEditFocusLost = mOff.yNum:GetScript("OnEditFocusLost"),
        OnTextChanged = mOff.yNum:GetScript("OnTextChanged"),
      }
    end

    function mOff:_OffsetDetach()
      if self.xOff then self.xOff:SetScript("OnValueChanged", nil); self.xOff:SetScript("OnMouseUp", nil) end
      if self.yOff then self.yOff:SetScript("OnValueChanged", nil); self.yOff:SetScript("OnMouseUp", nil) end
      if self.xNum then self.xNum:SetScript("OnEnterPressed", nil); self.xNum:SetScript("OnEditFocusLost", nil); self.xNum:SetScript("OnTextChanged", nil) end
      if self.yNum then self.yNum:SetScript("OnEnterPressed", nil); self.yNum:SetScript("OnEditFocusLost", nil); self.yNum:SetScript("OnTextChanged", nil) end
    end

    function mOff:_OffsetAttach()
      local h = self._offsetHandlers
      if self.xOff and h and h.xOff then
        self.xOff:SetScript("OnValueChanged", h.xOff.OnValueChanged)
        self.xOff:SetScript("OnMouseUp", h.xOff.OnMouseUp)
      end
      if self.yOff and h and h.yOff then
        self.yOff:SetScript("OnValueChanged", h.yOff.OnValueChanged)
        self.yOff:SetScript("OnMouseUp", h.yOff.OnMouseUp)
      end
      if self.xNum and h and h.xNum then
        self.xNum:SetScript("OnEnterPressed", h.xNum.OnEnterPressed)
        self.xNum:SetScript("OnEditFocusLost", h.xNum.OnEditFocusLost)
        self.xNum:SetScript("OnTextChanged", h.xNum.OnTextChanged)
      end
      if self.yNum and h and h.yNum then
        self.yNum:SetScript("OnEnterPressed", h.yNum.OnEnterPressed)
        self.yNum:SetScript("OnEditFocusLost", h.yNum.OnEditFocusLost)
        self.yNum:SetScript("OnTextChanged", h.yNum.OnTextChanged)
      end
    end
  end
end

-- Color picker -> CommitColorFromUI (still gated)
if colorBtn then
  colorBtn:EnableMouse(true)
  colorBtn:SetScript("OnMouseUp", function()
    if not _EnsureCMEnabled() then return end
    -- BrA behavior: clicking swatch implicitly enables tint
    if chkUse and chkUse.GetChecked and (not chkUse:GetChecked()) then
      chkUse:SetChecked(true)
      _CommitCustomMat()
    end
    local f = UI.frame
    local m = p and p._elemMat
    local id, rev = _GetBoundNodeId(m, f)
    if not _IsBindAlive(f, rev) then return end
    if not id or not GetData then return end
    local data = GetData(id)
    if type(data) ~= "table" then return end

    data.region = type(data.region) == "table" and data.region or {}
    local c = type(data.region.color) == "table" and data.region.color or { r = 1, g = 1, b = 1, a = 1 }

    local function _applyColor()
      local r, g, b = ColorPickerFrame:GetColorRGB()
      local a = 1 - (OpacitySliderFrame and OpacitySliderFrame:GetValue() or 0)
      local CM = _CM()
      if CM and CM.CommitColorFromUI then
        CM:CommitColorFromUI({
          id = id,
          data = data,
          r = r, g = g, b = b, a = a,
          previewTex = p._elemMat and p._elemMat.previewTex,
        })
        UI:RefreshRight()
      end
    end

    ColorPickerFrame.func = _applyColor
    ColorPickerFrame.opacityFunc = _applyColor
    ColorPickerFrame.cancelFunc = _applyColor
    ColorPickerFrame.hasOpacity = true
    ColorPickerFrame.opacity = 1 - (c.a or 1)
    ColorPickerFrame:SetColorRGB(c.r or 1, c.g or 1, c.b or 1)
    ColorPickerFrame:Show()
  end)
end

end


-- ------------------------------------------------------------
-- Actions pane (Output Actions drawer) - UI only (no execution)
-- ------------------------------------------------------------

function UI:BuildConditionsPane(p)
  if not p then return end

  -- Hide generic placeholder title/hint
  if p._defaultHeader then p._defaultHeader:Hide() end
  if p._defaultHint then p._defaultHint:Hide() end

  -- Create unified template-based drawer (bottom plate + scrollbar)
  local DT = Bre.DrawerTemplate
  local spec = Bre.DrawerSpec_Conditions
  if DT and spec and DT.Create then
    local d = DT:Create(p, spec)
    if d then
      p._drawerConditions_new = d
      d:Hide()
    end
  end
end

function UI:BuildActionsPane(p)
  if not p then return end

  -- Hide generic placeholder title/hint
  if p._defaultHeader then p._defaultHeader:Hide() end
  if p._defaultHint then p._defaultHint:Hide() end

  -- Tear down old hand-made Actions drawer (v2.18.39 and earlier)
  if p._actionsScroll then p._actionsScroll:Hide() end
  p._actionsScroll = nil
  p._actionsContent = nil
  p._actionRows = nil
  p._actionsTop = nil
  p._btnAddAction = nil
  p._ddActionType = nil

  -- Create unified template-based drawer (bottom plate + scrollbar)
  local DT = Bre.DrawerTemplate
  local spec = Bre.DrawerSpec_Actions
  if DT and spec and DT.Create then
    local d = DT:Create(p, spec)
    if d then
      p._drawerActions_new = d
      -- shown when Actions tab is active
      d:Hide()
    end
  end
end



-- ------------------------------------------------------------
-- Public
-- ------------------------------------------------------------
function UI:Toggle()
  local f = self:EnsureFrame()
  if f:IsShown() then
    f:Hide()
  else
    -- v1.13.14: auto-apply Compact (560x560) during show flow.
    -- This is intentionally an automatic SetSize in the display path (user-requested).
    if Bre and Bre.Profile and Bre.Profile.Apply then
      pcall(function() Bre.Profile:Apply(UI) end)
    end
    f:Show()
    self:UpdateHeaderHitInsets()
    self:RefreshTree()
    self:RefreshRight()
  end
end


-- v2.8.8: sync mover body (on-screen) with current selection
function UI:_SyncMoverBody()
  local f = self.frame

  -- M4: all visible/invisible routing goes through ViewService.
  local View = Gate:Get("View")
  if View and View.SyncSelection then
    View:SyncSelection(f)
  end
end