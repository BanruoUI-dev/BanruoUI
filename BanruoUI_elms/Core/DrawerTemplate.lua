-- Bre/Core/DrawerTemplate.lua
-- L1: DrawerTemplate (DrawerChassis) - unified drawer chassis for element.table drawers.
-- Step1 (v2.18.65): freeze as L1 chassis; no behavior change; prepare Spec boundary.
-- Step2 (v2.18.68): add new L2 Specs (BlankDrawerSpec / PropPosSpec). No behavior change.

--[[
  ✅ ARCH PRINCIPLE (Constitution Article 14-16)
  DrawerTemplate responsibilities:
  - Unified scroll container management (ScrollFrame + ScrollBar)
  - Auto content height calculation
  - Mouse wheel support
  - Title styling enforcement
  - Layout specification enforcement (alignment / spacing / font size)
  - Centralized refresh mechanism
  - EditGuard integration
  
  DrawerTemplate does NOT:
  - Contain specific business UI
  - Directly manipulate data
  
  All element.table drawers MUST use this template.
  Drawer differences MUST be declared via Spec.
]]

local addonName, Bre = ...
Bre = Bre or {}

Bre.DrawerTemplate = Bre.DrawerTemplate or {
  version = "2.18.70",
}

local DT = Bre.DrawerTemplate

-- ------------------------------------------------------------
-- Offset formatting helper (file-local)
-- - Keep precision (support .5 etc.) to avoid edge snap on reload.
-- - Never export to _G (not a public contract).
local function _FmtOffset(v)
  v = tonumber(v) or 0
  if v < -4096 then v = -4096 elseif v > 4096 then v = 4096 end
  local iv = math.floor(v)
  if math.abs(v - iv) < 1e-9 then
    return tostring(iv)
  end
  return string.format("%.1f", v)
end


-- ------------------------------------------------------------
-- Layout Constants (Constitution Article 16: UI Specification Hard Limits)
-- These values are ENFORCED and cannot be overridden by individual drawers.
-- Step9 FINAL: Optimized layout with confirmed alignment
--   TITLE_X = 23 (main title)
--   CONTENT_LEFT = 18 (section titles like "属性", "位置")
--   COL1_X = 18 (first column labels)
-- ------------------------------------------------------------
DT.LAYOUT = {
  -- Title area (fixed, does not scroll)
  HEADER_HEIGHT = 36,      -- reduced from 60 (saves 24px)
  TITLE_X = 23,            -- final alignment value (after visual adjustment)
  TITLE_Y = -13,           -- adjusted from -8, moved down 5px
  TITLE_FONT = (Bre.Font and Bre.Font:Large() or "GameFontNormalLarge"),
  
  -- Scroll area
  SCROLL_TOP = -36,        -- adjusted to match HEADER_HEIGHT (was -60)
  SCROLL_LEFT = 8,
  SCROLL_RIGHT = -39,      -- reserve space for scrollbar
  SCROLL_BOTTOM = 8,
  
  -- Content area layout
  CONTENT_LEFT = 18,       -- adjusted from 16 to align with TITLE_X and COL1_X
  CONTENT_RIGHT = -16,
  SECTION_TITLE_FONT = (Bre.Font and Bre.Font:Large() or "GameFontNormalLarge"),
  
  -- Two-column layout
  COL1_X = 18,          -- left column X (aligned with title)
  COL2_X = 210,         -- right column X
  CONTROL_WIDTH = 150,  -- standard control width
  LABEL_WIDTH = 100,    -- label column width
  
  -- Spacing
  ROW_HEIGHT = 56,      -- single row height (label + control + spacing)
  SECTION_GAP = 40,     -- gap between sections
  LABEL_TO_CONTROL = 18,-- vertical distance from label to control
  SECTION_TITLE_GAP = 18, -- gap from section divider to title
  SECTION_TITLE_TO_CONTENT = 26, -- gap from section title to first control
  
  -- Colors
  YELLOW_R = 1.0,
  YELLOW_G = 0.82,
  YELLOW_B = 0.0,
  DIVIDER_ALPHA = 0.12,
}


-- ------------------------------------------------------------
-- Step1: Spec Boundary Helpers (no behavior change)
-- These helpers are intentionally NOT wired into legacy flow yet.
-- They define the chassis boundary that future L2 Specs can implement.
-- ------------------------------------------------------------
function DT:_MakeCtx(drawer, nodeId, spec, data)
  return {
    drawer = drawer,
    nodeId = nodeId,
    spec = spec or (drawer and drawer._spec),
    data = data,
    controls = drawer and drawer._controls,
    content = drawer and drawer._content,
    header = drawer and drawer._header,
    scroll = drawer and drawer._scroll,
  }
end

function DT:CallSpecBuild(drawer, nodeId)
  local spec = drawer and drawer._spec
  if spec and type(spec.Build) == "function" then
    spec:Build(self:_MakeCtx(drawer, nodeId, spec, nil))
  end
end

function DT:CallSpecRefresh(drawer, nodeId)
  local spec = drawer and drawer._spec
  if spec and type(spec.Refresh) == "function" then
    spec:Refresh(self:_MakeCtx(drawer, nodeId, spec, nil))
  end
end

function DT:CallSpecWireEvents(drawer, nodeId)
  local spec = drawer and drawer._spec
  if spec and type(spec.WireEvents) == "function" then
    spec:WireEvents(self:_MakeCtx(drawer, nodeId, spec, nil))
  end
end


-- ------------------------------------------------------------
-- Step3: Template Implementation - Create Drawer Structure
-- This step implements the real drawer creation logic.
-- ------------------------------------------------------------

-- API: Create a drawer from spec
-- @param parent: parent frame
-- @param spec: drawer specification
-- @return drawer frame
function DT:Create(parent, spec)
  if not parent or type(spec) ~= "table" then return nil end
  
  local drawer = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  drawer:SetAllPoints(parent)
  drawer:Hide() -- hidden by default; shown by OpenDrawer
  
  -- Apply backdrop
  drawer:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
  })
  drawer:SetBackdropColor(0, 0, 0, 0.35)
  drawer:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
  
  -- Store spec
  drawer._spec = spec
  drawer._controls = {}
  
  -- 1. Create header (fixed, does not scroll)
  local header = self:_CreateHeader(drawer, spec.title)
  drawer._header = header
  
  -- 2. Create scroll container
  local scroll, content = self:_CreateScrollContainer(drawer)
  drawer._scroll = scroll
  drawer._content = content
  
  -- 3. Build specific content section
  -- Step9: Reduced from -16 to -4 (saves 12px)
  local startY = -4
  if spec.specificContent then
    startY = self:_BuildSpecificContent(content, spec.specificContent, startY)
  end
  
  -- 4. Build attribute section (built-in)
  if spec.attributes == "default" then
    startY = self:_BuildAttributeSection(content, startY)
  end
  
  -- 5. Build position section (built-in)
  if spec.position == "default" then
    startY = self:_BuildPositionSection(content, startY)
  end
  
  -- 6. Configure scroll behavior
  self:_ConfigureScroll(drawer, startY)
  
  -- 7. Wire OnShow/OnSizeChanged hooks
  self:_WireScrollHooks(drawer)
  
  -- 8. Wire event handlers (Step6)
  self:WireEvents(drawer, nil)
  
  return drawer
end

-- Create header area (title, fixed at top)
function DT:_CreateHeader(drawer, titleKey)
  local L = self.LAYOUT
  local header = CreateFrame("Frame", nil, drawer)
  header:SetPoint("TOPLEFT", 0, 0)
  header:SetPoint("TOPRIGHT", 0, 0)
  header:SetHeight(L.HEADER_HEIGHT)
  
  local title = header:CreateFontString(nil, "OVERLAY", L.TITLE_FONT)
  title:SetPoint("TOPLEFT", L.TITLE_X, L.TITLE_Y)
  title:SetTextColor(L.YELLOW_R, L.YELLOW_G, L.YELLOW_B)
  
  -- Step7.3: Direct call (Locale.lua fixed)
  if Bre and Bre.L then
    title:SetText(Bre.L(titleKey))
  else
    title:SetText(tostring(titleKey))
  end
  
  header._title = title
  return header
end

-- Create scroll container
function DT:_CreateScrollContainer(drawer)
  local L = self.LAYOUT
  local scroll = CreateFrame("ScrollFrame", nil, drawer, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", L.SCROLL_LEFT, L.SCROLL_TOP)
  scroll:SetPoint("BOTTOMRIGHT", L.SCROLL_RIGHT, L.SCROLL_BOTTOM)
  
  local content = CreateFrame("Frame", nil, scroll)
  content:SetPoint("TOPLEFT", 0, 0)
  content:SetPoint("TOPRIGHT", 0, 0)
  scroll:SetScrollChild(content)
  
  -- Enable mouse wheel
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local sb = self.ScrollBar
    if not sb then return end
    local cur = sb:GetValue() or 0
    local minv, maxv = sb:GetMinMaxValues()
    local step = 24
    local nextv = cur - (delta * step)
    if nextv < minv then nextv = minv end
    if nextv > maxv then nextv = maxv end
    sb:SetValue(nextv)
  end)
  
  return scroll, content
end

-- Build specific content section (drawer-unique content)
function DT:_BuildSpecificContent(content, spec, startY)
  local DC = Bre.DrawerControls
  if not DC or type(spec) ~= "table" then return startY end
  
  local controls = {}
  local currentY = startY
  local minY = startY  -- track the lowest Y position
  
  for i, item in ipairs(spec) do
    if type(item) ~= "table" then
      -- skip invalid items
    elseif item.type == "label" then
      DC:MakeLabel(content, item.text, item.x or 0, currentY + (item.y or 0))
      local itemY = currentY + (item.y or 0)
      if itemY < minY then minY = itemY end
      
    elseif item.type == "fullwidth_editbox" then
      local eb = DC:MakeFullWidthEditBox(content, item.x or 18, currentY + (item.y or 0))
      if item.id then controls[item.id] = eb end
      local itemY = currentY + (item.y or 0) - 24
      if itemY < minY then minY = itemY end
      
    elseif item.type == "texture_preview" then
      local prev = DC:MakeTexturePreview(content, item.x or 0, currentY + (item.y or 0), item.size)
      if item.id then controls[item.id] = prev end
      local itemY = currentY + (item.y or 0) - (item.size or 72)
      if itemY < minY then minY = itemY end
      
    elseif item.type == "checkbox" then
      local chk = DC:MakeCheckbox(content, item.text, item.x or 0, currentY + (item.y or 0))
      if item.id then controls[item.id] = chk end
      local itemY = currentY + (item.y or 0) - 24
      if itemY < minY then minY = itemY end
      
    elseif item.type == "color_button" then
      local btn = DC:MakeColorButton(content, item.x or 0, currentY + (item.y or 0))
      if item.id then controls[item.id] = btn end
      local itemY = currentY + (item.y or 0) - 12
      if itemY < minY then minY = itemY end
      
    elseif item.type == "editbox" then
      local eb = DC:MakeEditBox(content, item.x or 0, currentY + (item.y or 0), item.width)
      if item.id then controls[item.id] = eb end
      local itemY = currentY + (item.y or 0) - 22
      if itemY < minY then minY = itemY end

    elseif item.type == "numericbox" then
      local eb = DC:MakeNumericBox(content, item.x or 0, currentY + (item.y or 0))
      if item.id then controls[item.id] = eb end
      local itemY = currentY + (item.y or 0) - 22
      if itemY < minY then minY = itemY end
      
    elseif item.type == "slider" then
      local slider = DC:MakeSlider(content, item.x or 0, currentY + (item.y or 0), item.width)
      -- Apply custom range if specified (v2.18.85)
      if item.min and item.max then
        slider:SetMinMaxValues(item.min, item.max)
      end
      if item.step then
        slider:SetValueStep(item.step)
      end
      if item.id then controls[item.id] = slider end
      local itemY = currentY + (item.y or 0) - 16
      if itemY < minY then minY = itemY end
      
    elseif item.type == "dropdown" then
      local dd = DC:MakeDropdown(content, item.x or 0, currentY + (item.y or 0), item.width)
      if item.id then controls[item.id] = dd end

      -- Shell-safe dropdown init: if spec provides item.items, initialize immediately (no data binding).
      if item.items and type(item.items) == "table" then
        UIDropDownMenu_Initialize(dd, function(self, level)
          for _, opt in ipairs(item.items) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = (opt.textKey and Bre and Bre.L and Bre.L(opt.textKey)) or opt.text or tostring(opt.value)
            info.value = opt.value
            info.func = function()
              dd.__value = opt.value
              UIDropDownMenu_SetText(dd, info.text)
            end
            UIDropDownMenu_AddButton(info, level)
          end
        end)
        -- Default text
        local first = item.items[1]
        if first then
          local t = (first.textKey and Bre and Bre.L and Bre.L(first.textKey)) or first.text or tostring(first.value)
          UIDropDownMenu_SetText(dd, t)
          dd.__value = first.value
        end
      end

      local itemY = currentY + (item.y or 0) - 32
      if itemY < minY then minY = itemY end
      local itemY = currentY + (item.y or 0) - 32
      if itemY < minY then minY = itemY end
      
    elseif item.type == "combo_input" then
      local combo = DC:MakeComboInput(content, item.x or 0, currentY + (item.y or 0), item.width)
      if item.id then controls[item.id] = combo end
      local itemY = currentY + (item.y or 0) - 22
      if itemY < minY then minY = itemY end

    elseif item.type == "pager_input" then
      local pager = DC:MakePagerInput(content, item.x or 0, currentY + (item.y or 0), item.width)
      if item.id then controls[item.id] = pager end
      local itemY = currentY + (item.y or 0) - 22
      if itemY < minY then minY = itemY end
      
    end
  end
  
  -- Store controls in parent drawer
  -- Navigate: content -> scroll -> drawer
  local scroll = content:GetParent()
  if scroll then
    local drawer = scroll:GetParent()
    if drawer and drawer._controls then
      for k, v in pairs(controls) do
        drawer._controls[k] = v
      end
    end
  end
  
  -- Return Y position after all specific content
  return minY - 20 -- add some bottom padding
end

-- Build attribute section (built-in)
function DT:_BuildAttributeSection(content, startY)
  local L = self.LAYOUT
  local DC = Bre.DrawerControls
  if not DC then return startY end
  
  local y = startY - L.SECTION_GAP
  
  -- Section divider
  DC:MakeSectionDivider(content, y)
  
  -- Section title
  y = y - L.SECTION_TITLE_GAP
  DC:MakeSectionTitle(content, "ELEM_MAT_ATTR", L.CONTENT_LEFT, y)
  
  -- Row 1: Alpha (left) + Rotation (right)
  y = y - L.SECTION_TITLE_TO_CONTENT
  DC:MakeLabel(content, "ELEM_MAT_ALPHA", L.COL1_X, y)
  local alphaNum = DC:MakeNumericBox(content, L.COL1_X + 52, y - 2)
  alphaNum:SetText("1.00")
  local alphaSlider = DC:MakeSlider(content, L.COL1_X, y - L.LABEL_TO_CONTROL)
  alphaSlider:SetMinMaxValues(0, 1)
  alphaSlider:SetValueStep(0.01)
  
  DC:MakeLabel(content, "ELEM_MAT_ROT", L.COL2_X, y)
  local rotNum = DC:MakeNumericBox(content, L.COL2_X + 52, y - 2)
  rotNum:SetText("0")
  local rotSlider = DC:MakeSlider(content, L.COL2_X, y - L.LABEL_TO_CONTROL)
  rotSlider:SetMinMaxValues(-180, 180)
  rotSlider:SetValueStep(1)
  
  -- Row 2: Blend (left) + Fold (right)
  y = y - L.ROW_HEIGHT
  DC:MakeLabel(content, "ELEM_MAT_BLEND", L.COL1_X, y)
  local blendDD = DC:MakeDropdown(content, L.COL1_X - 18, y - L.LABEL_TO_CONTROL + 2)
  
  DC:MakeLabel(content, "ELEM_MAT_FOLD", L.COL2_X, y)
  local foldDD = DC:MakeDropdown(content, L.COL2_X - 18, y - L.LABEL_TO_CONTROL + 2)
  
  -- Row 3: Height (left) + Width (right)
  y = y - L.ROW_HEIGHT
  DC:MakeLabel(content, "ELEM_MAT_HEIGHT", L.COL1_X, y)
  local hNum = DC:MakeNumericBox(content, L.COL1_X + 52, y - 2)
  hNum:SetText("300")
  local hSlider = DC:MakeSlider(content, L.COL1_X, y - L.LABEL_TO_CONTROL)
  hSlider:SetMinMaxValues(1, 2048)
  hSlider:SetValueStep(1)
  
  DC:MakeLabel(content, "ELEM_MAT_WIDTH", L.COL2_X, y)
  local wNum = DC:MakeNumericBox(content, L.COL2_X + 52, y - 2)
  wNum:SetText("300")
  local wSlider = DC:MakeSlider(content, L.COL2_X, y - L.LABEL_TO_CONTROL)
  wSlider:SetMinMaxValues(1, 2048)
  wSlider:SetValueStep(1)
  
  -- Step10: Store all controls for later access (Refresh + WireEvents)
  local scroll = content:GetParent()
  if scroll then
    local drawer = scroll:GetParent()
    if drawer and drawer._controls then
      drawer._controls.alphaSlider = alphaSlider
      drawer._controls.alphaNum = alphaNum
      drawer._controls.rotSlider = rotSlider
      drawer._controls.rotNum = rotNum
      drawer._controls.blendDD = blendDD
      drawer._controls.foldDD = foldDD
      drawer._controls.hSlider = hSlider
      drawer._controls.hNum = hNum
      drawer._controls.wSlider = wSlider
      drawer._controls.wNum = wNum
    end
  end
  
  return y - 20
end

-- Build position section (built-in)
function DT:_BuildPositionSection(content, startY)
  local L = self.LAYOUT
  local DC = Bre.DrawerControls
  if not DC then return startY end
  
  local y = startY - L.SECTION_GAP
  
  -- Section divider
  DC:MakeSectionDivider(content, y)
  
  -- Section title
  y = y - L.SECTION_TITLE_GAP
  DC:MakeSectionTitle(content, "ELEM_MAT_POS", L.CONTENT_LEFT, y)
  
  -- Row 1: AlignTo (left) + FrameLevel (right)
  y = y - L.SECTION_TITLE_TO_CONTENT
  DC:MakeLabel(content, "ELEM_MAT_ALIGN_TO", L.COL1_X, y)
  local alignDD = DC:MakeDropdown(content, L.COL1_X - 18, y - L.LABEL_TO_CONTROL + 2)
  
  DC:MakeLabel(content, "ELEM_MAT_FRAME_LEVEL", L.COL2_X, y)
  local levelDD = DC:MakeDropdown(content, L.COL2_X - 18, y - L.LABEL_TO_CONTROL + 2)
  
  -- Row 2: X Offset (left) + Y Offset (right)
  y = y - L.ROW_HEIGHT
  DC:MakeLabel(content, "ELEM_MAT_XOFF", L.COL1_X, y)
  local xNum = DC:MakeNumericBox(content, L.COL1_X + 52, y - 2)
  xNum:SetText("0")
  local xSlider = DC:MakeSlider(content, L.COL1_X, y - L.LABEL_TO_CONTROL)
  xSlider:SetMinMaxValues(-4096, 4096)
  xSlider:SetValueStep(0.5)
  
  DC:MakeLabel(content, "ELEM_MAT_YOFF", L.COL2_X, y)
  local yNum = DC:MakeNumericBox(content, L.COL2_X + 52, y - 2)
  yNum:SetText("0")
  local ySlider = DC:MakeSlider(content, L.COL2_X, y - L.LABEL_TO_CONTROL)
  ySlider:SetMinMaxValues(-4096, 4096)
  ySlider:SetValueStep(0.5)
  
  -- Step10: Store all controls
  local scroll = content:GetParent()
  if scroll then
    local drawer = scroll:GetParent()
    if drawer and drawer._controls then
      drawer._controls.alignDD = alignDD
      drawer._controls.levelDD = levelDD
      drawer._controls.xSlider = xSlider
      drawer._controls.xNum = xNum
      drawer._controls.ySlider = ySlider
      drawer._controls.yNum = yNum
    end
  end
  
  return y - 20
end

-- Configure scroll behavior (content height, scrollbar visibility)
function DT:_ConfigureScroll(drawer, endY)
  local content = drawer._content
  local scroll = drawer._scroll
  if not content or not scroll then return end
  
  -- Calculate content height
  local contentHeight = math.abs(endY) + 24 -- bottom padding
  content:SetHeight(contentHeight)
  
  -- Store for later use
  drawer._contentHeight = contentHeight
end

-- Wire scroll-related hooks
function DT:_WireScrollHooks(drawer)
  local self = DT
  
  drawer:HookScript("OnShow", function()
    self:_UpdateScroll(drawer)
  end)
  
  drawer:HookScript("OnSizeChanged", function()
    self:_UpdateScroll(drawer)
  end)
end

-- Update scroll state (show/hide scrollbar, update dimensions)
function DT:_UpdateScroll(drawer)
  local scroll = drawer._scroll
  local content = drawer._content
  if not scroll or not content then return end
  
  local sb = scroll.ScrollBar
  if not sb then return end
  
  -- Update scroll child rect
  if scroll.UpdateScrollChildRect then
    scroll:UpdateScrollChildRect()
  end
  
  local viewH = scroll:GetHeight() or 0
  local contentH = content:GetHeight() or 0
  
  -- Calculate max scroll value
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
  
  -- Update content width
  local L = self.LAYOUT
  local drawerWidth = drawer:GetWidth() or 440
  local contentWidth = drawerWidth - 68 -- room for scrollbar + padding
  content:SetWidth(contentWidth)
end

-- API: Get control references from drawer
function DT:GetControls(drawer)
  if not drawer or not drawer._controls then return {} end
  return drawer._controls
end

-- API: Update drawer content (refresh without side effects)
function DT:Refresh(drawer, nodeId)
  if not drawer or not drawer._spec then return end
  
  -- Get data
  local GetData = Bre.GetData
  if type(GetData) ~= "function" then return end
  local data = GetData(nodeId)
  if type(data) ~= "table" then
    -- Actions drawer is UI-only and must still refresh/initialize even without a bound node.
    if drawer._spec and (drawer._spec.drawerId == "Actions" or drawer._spec.drawerId == "Conditions") then
      data = {}
    else
      return
    end
  end
  
  -- Enter EditGuard to ensure refresh has no side effects
  local Gate = Bre.Gate
  local EG = Gate and Gate:Get("EditGuard")
  
  local function _DoRefresh()
    local controls = drawer._controls or {}
    local spec = drawer._spec

    -- v1.4: Functional Drawer MUST provide explicit Refresh backfill.
    -- Prefer Spec:Refresh(ctx). Keep legacy fallback for safety.
    if spec and type(spec.Refresh) == "function" then
      local ctx = self:_MakeCtx(drawer, nodeId, spec, data)
      ctx.controls = controls -- ensure ctx has latest
      spec:Refresh(ctx)
    else
      -- Legacy refresh routing (deprecated)
      if spec and spec.drawerId == "CustomMat" then
        self:_RefreshCustomMat(controls, data, nodeId)
      elseif spec and spec.drawerId == "ProgressMat" then
        self:_RefreshProgressMat(controls, data, nodeId)
      elseif spec and spec.drawerId == "Actions" then
        self:_RefreshActions(drawer, controls, data, nodeId)
      elseif spec and spec.drawerId == "Model" then
        self:_RefreshModel(drawer, controls, data, nodeId)
      elseif spec and spec.drawerId == "Conditions" then
        self:_RefreshConditions(drawer, controls, data, nodeId)
      end
    end

    -- Refresh built-in attribute section

    if drawer._spec.attributes == "default" then
      self:_RefreshAttributes(controls, data)
    end
    
    -- Refresh built-in position section
    if drawer._spec.position == "default" then
      self:_RefreshPosition(controls, data, nodeId)
    end
  end
  
  if EG and EG.RunGuarded then
    EG:RunGuarded("DrawerTemplate:Refresh", _DoRefresh)
  else
    _DoRefresh()
  end
end

-- Refresh Actions specific content (UI-only; no commit logic)
function DT:_RefreshActions(drawer, controls, data, nodeId)
  local enabled = (nodeId ~= nil)
  -- Normalize data to avoid nil-index during early wiring (no selection yet)
  if type(data) ~= "table" then data = {} end
  local spec = drawer and drawer._spec
  local Gate = Bre.Gate
  local PS = Gate and Gate.Get and Gate:Get("PropertyService") or nil
  local Sel = Gate and Gate.Get and Gate:Get("SelectionService") or nil

  local function _L(key)
    if Bre and Bre.L then return Bre.L(key) end
    return tostring(key)
  end

  local function _EnsureRotate(d)
    d.actions = type(d.actions) == "table" and d.actions or {}
    d.actions.rotate = type(d.actions.rotate) == "table" and d.actions.rotate or {}
    return d.actions.rotate
  end

  local function _GetSelSet()
    local st = Sel and Sel.GetState and Sel:GetState() or nil
    local set = st and st.set or nil
    if type(set) ~= "table" or next(set) == nil then
      if nodeId then return { [nodeId] = true } end
      return {}
    end
    return set
  end

  local function _ForEachSelected(fn)
    local set = _GetSelSet()
    for nid, on in pairs(set) do
      if on and nid then fn(nid) end
    end
  end

  local function _Preview(propKey, val)
    if not PS or not PS.PreviewSet then return end
    _ForEachSelected(function(nid)
      pcall(PS.PreviewSet, PS, nid, propKey, val)
    end)
  end

  local function _Commit(propKey, val)
    if not PS or not PS.Set then return end
    _ForEachSelected(function(nid)
      pcall(PS.Set, PS, nid, propKey, val)
    end)
  end

  local function _EnableEditBox(eb, on)
    if not eb then return end
    if eb.SetEnabled then eb:SetEnabled(on and true or false) end
    if eb.SetTextColor then
      if on then eb:SetTextColor(1, 1, 1) else eb:SetTextColor(0.6, 0.6, 0.6) end
    end
  end

  local function _EnableSlider(sl, on)
    if not sl then return end
    if sl.SetEnabled then sl:SetEnabled(on and true or false) end
    if sl.SetAlpha then sl:SetAlpha(on and 1 or 0.6) end
  end

  -- Dropdown initializer (stores dd._br_value and calls onSelect)
  local function _InitDD(dd, options, currentValue, defaultValue, initFlagKey, onSelect)
    if not dd then return end
    options = options or {}
    local dv = defaultValue or (options[1] and options[1].value) or nil
    local v = (currentValue ~= nil) and currentValue or dv

    local function _TextForValue(val)
      for _, opt in ipairs(options) do
        if opt.value == val then
          if opt.textKey then return _L(opt.textKey) end
          if opt.text then return opt.text end
          return tostring(opt.value)
        end
      end
      return ""
    end

    if not dd[initFlagKey] and UIDropDownMenu_Initialize then
      UIDropDownMenu_Initialize(dd, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, opt in ipairs(options) do
          local text = opt.textKey and _L(opt.textKey) or opt.text or tostring(opt.value)
          info.text = text
          info.value = opt.value
          info.func = function()
            dd._br_value = opt.value
            if UIDropDownMenu_SetText then UIDropDownMenu_SetText(dd, text) end
            if type(onSelect) == "function" and not drawer._br_actions_suppress then
              onSelect(opt.value)
            end
          end
          UIDropDownMenu_AddButton(info)
        end
      end)
      dd[initFlagKey] = true
    end

    dd._br_value = v
    local t = _TextForValue(v)
    if t ~= "" and UIDropDownMenu_SetText then UIDropDownMenu_SetText(dd, t) end

    if UIDropDownMenu_DisableDropDown and UIDropDownMenu_EnableDropDown then
      if enabled then UIDropDownMenu_EnableDropDown(dd) else UIDropDownMenu_DisableDropDown(dd) end
    end
  end

  -- Pull current rotate config (data-only)
  local rot = _EnsureRotate(data)
  local curRotEnabled = rot.enabled and true or false
  local curLoop = rot.loop and true or false
  local curDuration = tonumber(rot.duration) or 0
  local curSpeed = tonumber(rot.speed)
  if curSpeed == nil then curSpeed = (spec and spec.defaultSpeed) or 90 end
  local smin = (spec and spec.speedMin) or 0
  local smax = (spec and spec.speedMax) or 300
  if curSpeed < smin then curSpeed = smin end
  if curSpeed > smax then curSpeed = smax end
  local curDelay = tonumber(rot.delay) or 0
  local curAngle = tonumber(rot.angle) or (spec and spec.defaultAngle) or 0
  local curDir = rot.dir or (spec and spec.defaultDirValue) or "cw"
  local curAnchor = rot.anchor or (spec and spec.defaultAnchorValue) or "CENTER"
  local curEnd = rot.endState or (spec and spec.defaultEndStateValue) or "keep"

  -- One-time wiring of scripts
  if drawer and not drawer._br_actions_wired then
    drawer._br_actions_wired = true

    -- Enable checkbox
    if controls.rot_enable and controls.rot_enable._checkbox and controls.rot_enable._checkbox.SetScript then
      controls.rot_enable._checkbox:SetScript("OnClick", function(btn)
        if drawer._br_actions_suppress then return end
        local v = btn:GetChecked() and true or false
        _Commit("actions.rotate.enabled", v)

	        -- Immediate UI refresh: enabling rotate gates dependent controls (speed slider / numeric / duration / delay).
	        -- Without an explicit refresh here, the controls may remain disabled until an external refresh happens.
	        local f = Bre and Bre.UI and Bre.UI.frame
	        local nid = f and f._selectedId or nil
	        if DT and DT.Refresh then pcall(DT.Refresh, DT, drawer, nid) end
      end)
    end



    -- Loop checkbox
    if controls.rot_loop and controls.rot_loop._checkbox and controls.rot_loop._checkbox.SetScript then
      controls.rot_loop._checkbox:SetScript("OnClick", function(btn)
        if drawer._br_actions_suppress then return end
        local v = btn:GetChecked() and true or false
        _Commit("actions.rotate.loop", v)
      end)
    end

    -- Duration / Delay editboxes (commit on Enter/FocusLost)
    local function _WireNumEditBox(eb, key)
      if not eb or not eb.SetScript then return end
      local function _CommitText()
        if drawer._br_actions_suppress then return end
        local t = eb:GetText() or ""
        local n = tonumber(t)
        if n == nil then n = 0 end
        _Commit(key, n)
      end
      eb:SetScript("OnEnterPressed", function(self) _CommitText(); self:ClearFocus() end)
      eb:SetScript("OnEditFocusLost", function(self) _CommitText() end)
    end
    _WireNumEditBox(controls.rot_duration, "actions.rotate.duration")
    _WireNumEditBox(controls.rot_delay, "actions.rotate.delay")

    -- Speed slider + numeric box (preview during drag; commit on MouseUp/Enter/FocusLost)
    local spdSlider = controls.rot_speed_slider
    local spdBox = controls.rot_speed_num

    if spdSlider and not spdSlider._br_actions_speed_inited then
      local smin2 = (spec and spec.speedMin) or 0
      local smax2 = (spec and spec.speedMax) or 300
      local sstep = (spec and spec.speedStep) or 1
      if spdSlider.SetMinMaxValues then spdSlider:SetMinMaxValues(smin2, smax2) end
      if spdSlider.SetValueStep then spdSlider:SetValueStep(sstep) end
      if spdSlider.SetObeyStepOnDrag then spdSlider:SetObeyStepOnDrag(true) end

      if spdSlider.SetScript then
        spdSlider:SetScript("OnValueChanged", function(self, val)
          if drawer._br_actions_suppress then return end
          local v = math.floor((val or 0) + 0.5)
          if spdBox and spdBox.SetText then spdBox:SetText(string.format("%d", v)) end
          _Preview("actions.rotate.speed", v)
        end)

        spdSlider:SetScript("OnMouseUp", function(self)
          if drawer._br_actions_suppress then return end
          local v = math.floor((self.GetValue and self:GetValue() or 0) + 0.5)
          _Commit("actions.rotate.speed", v)
        end)
      end

      if spdBox and spdBox.SetScript then
        local function _ApplySpeedText(commit)
          local t = spdBox:GetText() or ""
          local n = tonumber(t)
          if n == nil then return end
          n = math.floor(n + 0.5)
          if n < smin2 then n = smin2 end
          if n > smax2 then n = smax2 end
          drawer._br_actions_suppress = true
          if spdSlider and spdSlider.SetValue then spdSlider:SetValue(n) end
          drawer._br_actions_suppress = false
          _Preview("actions.rotate.speed", n)
          if commit then _Commit("actions.rotate.speed", n) end
        end
        spdBox:SetScript("OnEnterPressed", function(self) _ApplySpeedText(true); self:ClearFocus() end)
        spdBox:SetScript("OnEditFocusLost", function(self) _ApplySpeedText(true) end)
      end

      spdSlider._br_actions_speed_inited = true
    end

    -- Direction dropdown (preview + commit)
    _InitDD(controls.rot_dir, spec and spec.dirOptions, nil, spec and spec.defaultDirValue, "_br_actions_dir_inited", function(v)
      _Preview("actions.rotate.dir", v)
      _Commit("actions.rotate.dir", v)
    end)

    -- Anchor dropdown (commit)
    _InitDD(controls.rot_anchor, spec and spec.anchorOptions, nil, spec and spec.defaultAnchorValue, "_br_actions_anchor_inited", function(v)
      _Commit("actions.rotate.anchor", v)
    end)

    -- EndState dropdown (commit)
    _InitDD(controls.rot_endstate, spec and spec.endStateOptions, nil, spec and spec.defaultEndStateValue, "_br_actions_end_inited", function(v)
      _Commit("actions.rotate.endState", v)
    end)

    -- Angle slider + input (preview during drag; commit on MouseUp/Enter/FocusLost)
    local angleSlider = controls.rot_angle_slider
    local angleBox = controls.rot_angle

    if angleSlider and not angleSlider._br_actions_angle_inited then
      local amin = (spec and spec.angleMin) or 0
      local amax = (spec and spec.angleMax) or 360
      local astep = (spec and spec.angleStep) or 1
      if angleSlider.SetMinMaxValues then angleSlider:SetMinMaxValues(amin, amax) end
      if angleSlider.SetValueStep then angleSlider:SetValueStep(astep) end
      if angleSlider.SetObeyStepOnDrag then angleSlider:SetObeyStepOnDrag(true) end

      if angleSlider.SetScript then
        angleSlider:SetScript("OnValueChanged", function(self, val)
          if drawer._br_actions_suppress then return end
          local v = math.floor((val or 0) + 0.5)
          if angleBox and angleBox.SetText then
            angleBox:SetText(string.format("%d", v))
          end
          _Preview("actions.rotate.angle", v)
        end)

        angleSlider:SetScript("OnMouseUp", function(self)
          if drawer._br_actions_suppress then return end
          local v = math.floor((self.GetValue and self:GetValue() or 0) + 0.5)
          _Commit("actions.rotate.angle", v)
        end)
      end

      if angleBox and angleBox.SetScript then
        local function _ApplyAngleText(commit)
          local t = angleBox:GetText() or ""
          local n = tonumber(t)
          if not n then return end
          local amin2 = (spec and spec.angleMin) or 0
          local amax2 = (spec and spec.angleMax) or 360
          n = math.floor(n + 0.5)
          if n < amin2 then n = amin2 end
          if n > amax2 then n = amax2 end
          drawer._br_actions_suppress = true
          if angleSlider and angleSlider.SetValue then angleSlider:SetValue(n) end
          drawer._br_actions_suppress = false
          _Preview("actions.rotate.angle", n)
          if commit then _Commit("actions.rotate.angle", n) end
        end
        angleBox:SetScript("OnEnterPressed", function(self) _ApplyAngleText(true); self:ClearFocus() end)
        angleBox:SetScript("OnEditFocusLost", function(self) _ApplyAngleText(true) end)
      end

      angleSlider._br_actions_angle_inited = true
    end
  end

  -- Refresh UI values (no side effects)
  drawer._br_actions_suppress = true

  -- Enable checkbox
  if controls.rot_enable then
    if controls.rot_enable.SetChecked then controls.rot_enable:SetChecked(curRotEnabled) end
    if controls.rot_enable._checkbox and controls.rot_enable._checkbox.SetEnabled then
      controls.rot_enable._checkbox:SetEnabled(enabled and true or false)
    end
  end

-- Loop checkbox
  if controls.rot_loop then
    if controls.rot_loop.SetChecked then controls.rot_loop:SetChecked(curLoop) end
    if controls.rot_loop._checkbox and controls.rot_loop._checkbox.SetEnabled then
      controls.rot_loop._checkbox:SetEnabled((enabled and curRotEnabled) and true or false)
    end
  end

  -- Duration / Delay editboxes
  if controls.rot_duration and controls.rot_duration.SetText then
    controls.rot_duration:SetText(tostring(curDuration))
  end
  if controls.rot_delay and controls.rot_delay.SetText then
    controls.rot_delay:SetText(tostring(curDelay))
  end
  _EnableEditBox(controls.rot_duration, (enabled and curRotEnabled))
  _EnableEditBox(controls.rot_delay, (enabled and curRotEnabled))

  -- Speed slider + numeric box
  local spdSlider = controls.rot_speed_slider
  local spdBox = controls.rot_speed_num
  if spdSlider and spdSlider.SetValue then spdSlider:SetValue(curSpeed) end
  if spdBox and spdBox.SetText then spdBox:SetText(tostring(curSpeed)) end
  _EnableSlider(spdSlider, (enabled and curRotEnabled))
  _EnableEditBox(spdBox, (enabled and curRotEnabled))

  -- Angle slider + input
  local angleSlider = controls.rot_angle_slider
  local angleBox = controls.rot_angle
  if angleSlider and angleSlider.SetValue then
    angleSlider:SetValue(curAngle)
  end
  if angleBox and angleBox.SetText then
    angleBox:SetText(tostring(curAngle))
  end
  _EnableSlider(angleSlider, enabled)
  _EnableEditBox(angleBox, enabled)

  -- Direction / Anchor / EndState dropdowns
  _InitDD(controls.rot_dir, spec and spec.dirOptions, curDir, spec and spec.defaultDirValue, "_br_actions_dir_inited", function(v)
    _Preview("actions.rotate.dir", v)
    _Commit("actions.rotate.dir", v)
  end)
  _InitDD(controls.rot_anchor, spec and spec.anchorOptions, curAnchor, spec and spec.defaultAnchorValue, "_br_actions_anchor_inited", function(v)
    _Commit("actions.rotate.anchor", v)
  end)
  _InitDD(controls.rot_endstate, spec and spec.endStateOptions, curEnd, spec and spec.defaultEndStateValue, "_br_actions_end_inited", function(v)
    _Commit("actions.rotate.endState", v)
  end)

  drawer._br_actions_suppress = false
end


function DT:_RefreshConditions(drawer, controls, data, nodeId)
  -- UI-only skeleton: show placeholder labels, disable future controls when no selection.
  -- Keep behavior side-effect free.
  local enabled = (nodeId ~= nil)

  -- If future interactive controls exist, they should be enabled/disabled here.
  -- For now, nothing to toggle.
  drawer._br_conditions_enabled = enabled and true or false
end

-- Refresh CustomMat specific content

function DT:_RefreshCustomMat(controls, data, nodeId)
  data.region = type(data.region) == "table" and data.region or {}
  
  -- Texture path
  if controls.texturePath and controls.texturePath._editbox then
    local tex = data.region.texture or ""
    if controls.texturePath._editbox:GetText() ~= tex then
      controls.texturePath._editbox:SetText(tex)
    end
  end
  
  -- Mirror checkbox
  if controls.mirror then
    controls.mirror:SetChecked(data.region.mirror and true or false)
  end
  
  -- Fade checkbox
  if controls.fade then
    controls.fade:SetChecked(data.region.desaturate and true or false)
  end
  
  -- Color button
  if controls.colorBtn and controls.colorBtn.SetColor then
    local c = data.region.color or {r=1, g=1, b=1, a=1}
    controls.colorBtn:SetColor(c.r or 1, c.g or 1, c.b or 1, c.a or 1)
  end
  
  -- Step10.1: Update preview texture (CRITICAL FIX)
  if controls.preview and controls.preview._texture then
    local Gate = Bre.Gate
    if Gate and Gate.Get then
      -- Check if CustomMat module is enabled
      local CMEnabled = Gate.Has and Gate:Has("CustomMat")
      if not CMEnabled then
        -- Module off, clear preview
        local tex = controls.preview._texture
        if tex.SetColorTexture then tex:SetColorTexture(0, 0, 0, 0) end
        if tex.SetTexCoord then tex:SetTexCoord(0, 1, 0, 1) end
        if tex.SetVertexColor then tex:SetVertexColor(1, 1, 1, 1) end
        if tex.SetAlpha then tex:SetAlpha(1) end
      else
        -- Module on, apply preview
        local CM = Gate:Get("CustomMat")
        if CM and CM.ApplyToTexture then
          CM:ApplyToTexture(controls.preview._texture, data.region, data.alpha)
        end
      end
    end
  end
end

-- Refresh ProgressMat specific content
function DT:_RefreshProgressMat(controls, data, nodeId)
  -- Helper: Localize text
  local function _L(key)
    if Bre and Bre.L then return Bre.L(key) end
    return key
  end
  
  -- Material type dropdown (NEW)
  if controls.materialType then
    local mtype = data.materialType or "Custom"
    local mtypeMap = {
      Custom = "PROG_MAT_MATERIAL_CUSTOM",
      Blizzard = "PROG_MAT_MATERIAL_BLIZZARD",
    }
    local textKey = mtypeMap[mtype] or "PROG_MAT_MATERIAL_CUSTOM"
    UIDropDownMenu_SetText(controls.materialType, _L(textKey))
  end
  
  -- Foreground material (required)
  if controls.foreground and controls.foreground._editbox then
    local fg = data.foreground or ""
    if controls.foreground._editbox:GetText() ~= fg then
      controls.foreground._editbox:SetText(fg)
    end
  end
  
  -- Background material (optional)
  if controls.background and controls.background._editbox then
    local bg = data.background or ""
    if controls.background._editbox:GetText() ~= bg then
      controls.background._editbox:SetText(bg)
    end
  end
  
  -- Mask material (optional)
  if controls.mask and controls.mask._editbox then
    local mask = data.mask or ""
    if controls.mask._editbox:GetText() ~= mask then
      controls.mask._editbox:SetText(mask)
    end
  end
  
  -- Progress type dropdown (Phase 1: Health only)
  if controls.type then
    local ptype = data.progressType
    if not ptype or ptype == "" then ptype = "PROG_TYPE_HEALTH" end
    UIDropDownMenu_SetText(controls.type, _L(ptype))
  end

  -- Progress unit dropdown
  if controls.progressUnit then
    local u = data.progressUnit
    if not u or u == "" then u = "player" end
    local uMap = {
      player = "PROG_UNIT_PLAYER",
      target = "PROG_UNIT_TARGET",
      focus = "PROG_UNIT_FOCUS",
      pet = "PROG_UNIT_PET",
    }
    local textKey = uMap[u] or u
    UIDropDownMenu_SetText(controls.progressUnit, _L(textKey))
  end
  
  -- Progress algorithm option is removed (Linear-only MaskTexture route)
  
  -- Progress direction dropdown (no empty option, show localized text)
  if controls.progressDirection then
    local dir = data.progressDirection or "LeftToRight"
    local dirMap = {
      LeftToRight = "PROG_DIR_LTR",
      RightToLeft = "PROG_DIR_RTL",
      TopToBottom = "PROG_DIR_TTB",
      BottomToTop = "PROG_DIR_BTT",
    }
    local textKey = dirMap[dir] or "PROG_DIR_LTR"
    UIDropDownMenu_SetText(controls.progressDirection, _L(textKey))
  end
  
  -- Foreground color button
  if controls.fgColor and controls.fgColor.SetColor then
    local c = data.fgColor or {r=1, g=1, b=1, a=1}
    controls.fgColor:SetColor(c.r or 1, c.g or 1, c.b or 1, c.a or 1)
  end
  
  -- Background color button
  if controls.bgColor and controls.bgColor.SetColor then
    local c = data.bgColor or {r=1, g=1, b=1, a=1}
    controls.bgColor:SetColor(c.r or 1, c.g or 1, c.b or 1, c.a or 1)
  end
end


-- Refresh Model specific content (minimal: mode + unit/displayID)
function DT:_RefreshModel(drawer, controls, data, nodeId)
  if type(data) ~= "table" then data = {} end

  local function _L(key)
    if Bre and Bre.L then return Bre.L(key) end
    return tostring(key)
  end

  local mode = tostring(data.modelMode or drawer._modelMode or "unit")
  if mode ~= "unit" and mode ~= "file" then mode = "unit" end
  drawer._modelMode = mode

  -- Mode dropdown
  if controls.modelMode then
    local dd = controls.modelMode
    UIDropDownMenu_SetSelectedValue(dd, mode)
    UIDropDownMenu_SetText(dd, (mode == "file") and _L("MODEL_MODE_FILEID") or _L("MODEL_MODE_UNIT"))
  end

  -- Value input (unit label or displayID number)
  if controls.modelValue and controls.modelValue._editbox then
    local eb = controls.modelValue._editbox
    if mode == "unit" then
      local unit = tostring(data.modelUnit or "player")
      if unit ~= "player" and unit ~= "target" and unit ~= "focus" then unit = "player" end
      drawer._modelUnit = unit
      local unitTextMap = {
        player = _L("MODEL_UNIT_PLAYER"),
        target = _L("MODEL_UNIT_TARGET"),
        focus  = _L("MODEL_UNIT_FOCUS"),
      }
      local text = unitTextMap[unit] or unit
      if eb.GetText and eb.SetText and eb:GetText() ~= text then
        eb:SetText(text)
      end
    else
      drawer._modelUnit = tostring(data.modelUnit or drawer._modelUnit or "player")
      local fid = tonumber(data.modelFileID)
      local text = fid and tostring(fid) or ""
      if eb.GetText and eb.SetText and eb:GetText() ~= text then
        eb:SetText(text)
      end
    end
  end

  -- Facing controls (v2.18.85)
  local facing = tonumber(data.facing) or 0
  if controls.facingSlider then
    -- Ensure range is set (defensive, should be set during build)
    local min, max = controls.facingSlider:GetMinMaxValues()
    if min == 0 and max == 1 then
      -- Fallback: range not set during build, set it now
      controls.facingSlider:SetMinMaxValues(0, 360)
    end
    controls.facingSlider:SetValue(facing)
  end
  if controls.facing then
    controls.facing:SetText(tostring(math.floor(facing + 0.5)))
  end

  -- Animation sequence (v2.18.87)
  local animSeq = tonumber(data.animSequence) or 0
  if controls.animSequence then
    controls.animSequence:SetText(tostring(animSeq))
  end
end


-- Refresh built-in attributes
function DT:_RefreshAttributes(controls, data)
  if not controls then return end
  
  -- Alpha
  local alpha = tonumber(data.alpha) or 1
  if controls.alphaSlider then
    controls.alphaSlider:SetValue(alpha)
  end
  if controls.alphaNum then
    controls.alphaNum:SetText(string.format("%.2f", alpha))
  end
  
  -- Rotation
  local rot = tonumber((data.region and data.region.rotation)) or 0
  if controls.rotSlider then
    controls.rotSlider:SetValue(rot)
  end
  if controls.rotNum then
    controls.rotNum:SetText(tostring(math.floor(rot + 0.5)))
  end
  
  -- Blend mode
  local blend = (data.region and data.region.blendMode) or "BLEND"
  if controls.blendDD then
    UIDropDownMenu_SetText(controls.blendDD, blend)
  end
  
  -- Fold (placeholder)
  local fold = (data.region and data.region.fold) or "NONE"
  if controls.foldDD then
    UIDropDownMenu_SetText(controls.foldDD, fold)
  end
  
  -- Size
  local w = (data.size and tonumber(data.size.width)) or 300
  local h = (data.size and tonumber(data.size.height)) or 300
  if controls.wSlider then
    controls.wSlider:SetValue(w)
  end
  if controls.wNum then
    controls.wNum:SetText(tostring(math.floor(w + 0.5)))
  end
  if controls.hSlider then
    controls.hSlider:SetValue(h)
  end
  if controls.hNum then
    controls.hNum:SetText(tostring(math.floor(h + 0.5)))
  end
  
  -- Step10.1: Update preview when attributes change
  if controls.preview and controls.preview._texture then
    local Gate = Bre.Gate
    if Gate and Gate.Get then
      local CMEnabled = Gate.Has and Gate:Has("CustomMat")
      if CMEnabled then
        local CM = Gate:Get("CustomMat")
        if CM and CM.ApplyToTexture then
          CM:ApplyToTexture(controls.preview._texture, data.region, data.alpha)
        end
      end
    end
  end
end

-- Refresh built-in position
function DT:_RefreshPosition(controls, data, nodeId)
  if not controls then return end
  
  data.props = type(data.props) == "table" and data.props or {}
  
  -- Align to
  local alignTo = data.props.anchorTarget or "SCREEN_CENTER"
  if alignTo ~= "SCREEN_CENTER" then alignTo = "SCREEN_CENTER" end
  if controls.alignDD then
    local function _L(key)
      if Bre and Bre.L then return Bre.L(key) end
      return key
    end
    UIDropDownMenu_SetText(controls.alignDD, _L("ELEM_MAT_ALIGN_TO_SCREEN_CENTER"))
    UIDropDownMenu_SetSelectedValue(controls.alignDD, "SCREEN_CENTER")
  end
  
  -- Frame strata
  local frameStrata = data.props.frameStrata or "AUTO"
  -- Resolve effective strata for display: if intent is AUTO, inherit from parent chain (runtime only).
  local function _ResolveEffectiveStrata(id, el)
    if type(id) ~= "string" or id == "" then return nil end
    if type(Bre) ~= "table" or type(Bre.GetData) ~= "function" then return nil end
    el = type(el) == "table" and el or Bre.GetData(id)
    if type(el) ~= "table" then return nil end
    local props = type(el.props) == "table" and el.props or {}
    local fs = props.frameStrata
    if fs and fs ~= "" and fs ~= "AUTO" then return fs end
    local pid = el.parent
    local guard = 0
    while type(pid) == "string" and pid ~= "" and guard < 32 do
      guard = guard + 1
      local p = Bre.GetData(pid)
      if type(p) ~= "table" then break end
      local pprops = type(p.props) == "table" and p.props or {}
      local pfs = pprops.frameStrata
      if pfs and pfs ~= "" and pfs ~= "AUTO" then return pfs end
      pid = p.parent
    end
    return nil
  end

  local displayStrata = frameStrata
  if frameStrata == "AUTO" then
    local eff = _ResolveEffectiveStrata(nodeId, data)
    if eff then displayStrata = eff end
  end
  local strataDD = controls.strataDD or controls.levelDD
  if strataDD then
    local function _L(key)
      if Bre and Bre.L then return Bre.L(key) end
      return key
    end
    
    local strataTextMap = {
      BACKGROUND = _L("ELEM_MAT_FRAME_LEVEL_BACKGROUND"),
      LOW = _L("ELEM_MAT_FRAME_LEVEL_LOW"),
      MEDIUM = _L("ELEM_MAT_FRAME_LEVEL_MEDIUM"),
      HIGH = _L("ELEM_MAT_FRAME_LEVEL_HIGH"),
      DIALOG = _L("ELEM_MAT_FRAME_LEVEL_DIALOG"),
      FULLSCREEN = _L("ELEM_MAT_FRAME_LEVEL_FULLSCREEN"),
      FULLSCREEN_DIALOG = _L("ELEM_MAT_FRAME_LEVEL_FULLSCREEN_DIALOG"),
      TOOLTIP = _L("ELEM_MAT_FRAME_LEVEL_TOOLTIP"),
      AUTO = _L("ELEM_MAT_FRAME_LEVEL_AUTO"),
    }
    
    local text = strataTextMap[displayStrata]
    if not text then
       text = strataTextMap.AUTO
    end
    UIDropDownMenu_SetText(strataDD, text)
    UIDropDownMenu_SetSelectedValue(strataDD, displayStrata)
  end
  
  -- Offsets
  local xOffset = tonumber(data.props.xOffset) or 0
  local yOffset = tonumber(data.props.yOffset) or 0
  
  if controls.xSlider then
    controls.xSlider:SetValue(xOffset)
  end
  if controls.xNum then
    controls.xNum:SetText(_FmtOffset(xOffset))
  end
  if controls.ySlider then
    controls.ySlider:SetValue(yOffset)
  end
  if controls.yNum then
    controls.yNum:SetText(_FmtOffset(yOffset))
  end
end


-- API: Wire event handlers for drawer controls
function DT:WireEvents(drawer, nodeId)
  local function _ClampOffset(v)
    v = tonumber(v)
    if not v then return nil end
    if v < -4096 then v = -4096 elseif v > 4096 then v = 4096 end
    return v
  end

    if not drawer or not drawer._spec then return end
  
  local controls = drawer._controls or {}
  
  -- Wire specific content events
  if drawer._spec.drawerId == "CustomMat" then
    self:_WireCustomMatEvents(drawer, controls)
  elseif drawer._spec.drawerId == "ProgressMat" then
    self:_WireProgressMatEvents(drawer, controls)
  elseif drawer._spec.drawerId == "Actions" then
    self:_WireActionsEvents(drawer, controls)
  elseif drawer._spec.drawerId == "Model" then
    self:_WireModelEvents(drawer, controls)
  elseif drawer._spec.drawerId == "StopMotion" then
    self:_WireStopMotionEvents(drawer, controls)
  elseif drawer._spec.drawerId == "Conditions" then
    -- No drawer-specific wiring at chassis level (Spec may provide its own wiring in later steps).

  end
  -- Wire attribute section events (built-in)
  if drawer._spec.attributes == "default" then
    self:_WireAttributeEvents(drawer, controls)
  end
  
  -- Wire position section events (built-in)
  if drawer._spec.position == "default" then
    self:_WirePositionEvents(drawer, controls)
  end

  -- Spec-driven wiring (v1.4+): allow individual specs to wire extra handlers.
  -- This is safe for legacy drawers because most specs don't implement WireEvents.
  self:CallSpecWireEvents(drawer, nodeId)
end

-- Wire StopMotion drawer specific events (Step2: path + rows/cols/frames)
function DT:_WireStopMotionEvents(drawer, controls)
  local Gate = Bre.Gate
  local UI = Bre.UI
  if not controls then return end
  if not controls.path then return end

  local function _GetBoundNodeId(control)
    -- Prefer explicit bind set by Spec:Refresh on each control.
    local eb = control or controls.path
    if eb and type(eb._editBindNodeId) == 'string' and eb._editBindNodeId ~= '' then
      return eb._editBindNodeId
    end
    local f = UI and UI.frame
    return f and f._selectedId or nil
  end

  local function _CommitPath()
    local id = _GetBoundNodeId(controls.path)
    if not id then return end
    local PS = Gate and Gate.Get and Gate:Get('PropertyService') or nil
    if not (PS and PS.Set) then return end
    local v = controls.path.GetText and controls.path:GetText() or ""
    pcall(PS.Set, PS, id, 'stopmotion.path', v)
    if UI and UI.RefreshRight then
      pcall(UI.RefreshRight, UI)
    end
  end

  local function _ToInt(text)
    local n = tonumber(text)
    if not n then return nil end
    n = math.floor(n)
    if n < 0 then n = 0 end
    return n
  end

  local function _CommitInt(control, key)
    if not (control and control.GetText) then return end
    local id = _GetBoundNodeId(control)
    if not id then return end
    local PS = Gate and Gate.Get and Gate:Get('PropertyService') or nil
    if not (PS and PS.Set) then return end
    local v = _ToInt(control:GetText() or "")
    if v == nil then v = 0 end
    pcall(PS.Set, PS, id, key, v)
    if UI and UI.RefreshRight then
      pcall(UI.RefreshRight, UI)
    end
  end

  -- Commit white-list: EnterPressed / EditFocusLost
  if controls.path.SetScript then
    controls.path:SetScript('OnEnterPressed', function(self)
      self:ClearFocus()
      _CommitPath()
    end)
    controls.path:SetScript('OnEditFocusLost', function(self)
      _CommitPath()
    end)
  end

  -- Step2: rows/cols/frames numeric boxes (commit on EnterPressed / EditFocusLost)
  local function _WireNumeric(control, key)
    if not (control and control.SetScript) then return end
    control:SetScript('OnEnterPressed', function(self)
      self:ClearFocus()
      _CommitInt(self, key)
    end)
    control:SetScript('OnEditFocusLost', function(self)
      _CommitInt(self, key)
    end)
  end

  -- Normal slicing is square: grid -> rows & cols
  local function _CommitGrid(control)
    if not (control and control.GetText) then return end
    local id = _GetBoundNodeId(control)
    if not id then return end
    local PS = Gate and Gate.Get and Gate:Get('PropertyService') or nil
    if not (PS and PS.Set) then return end
    local n = _ToInt(control:GetText() or '')
    if n == nil then n = 0 end
    pcall(PS.Set, PS, id, 'stopmotion.rows', n)
    pcall(PS.Set, PS, id, 'stopmotion.cols', n)
    -- Clamp frames to n*n if needed
    local frames = controls.frames and _ToInt(controls.frames:GetText() or '') or 0
    if frames and frames > 0 then
      local maxF = n * n
      if frames > maxF then
        pcall(PS.Set, PS, id, 'stopmotion.frames', maxF)
      end
    end
    if UI and UI.RefreshRight then
      pcall(UI.RefreshRight, UI)
    end
  end

  local function _WireGrid(control)
    if not (control and control.SetScript) then return end
    control:SetScript('OnEnterPressed', function(self)
      self:ClearFocus()
      _CommitGrid(self)
    end)
    control:SetScript('OnEditFocusLost', function(self)
      _CommitGrid(self)
    end)
  end

  _WireGrid(controls.grid)
  _WireNumeric(controls.frames, 'stopmotion.frames')

  -- Step2+ Advanced slicing (fileW/fileH/frameW/frameH) -> derive rows/cols + clamp frames
  local function _CommitAdvanced()
    local id = _GetBoundNodeId(controls.fileW or controls.path)
    if not id then return end
    local PS = Gate and Gate.Get and Gate:Get('PropertyService') or nil
    if not (PS and PS.Set) then return end

    local fileW = controls.fileW and _ToInt(controls.fileW:GetText() or '') or 0
    local fileH = controls.fileH and _ToInt(controls.fileH:GetText() or '') or 0
    local frameW = controls.frameW and _ToInt(controls.frameW:GetText() or '') or 0
    local frameH = controls.frameH and _ToInt(controls.frameH:GetText() or '') or 0

    -- Persist advanced fields (allow 0 as unset)
    if controls.fileW then pcall(PS.Set, PS, id, 'stopmotion.fileW', fileW or 0) end
    if controls.fileH then pcall(PS.Set, PS, id, 'stopmotion.fileH', fileH or 0) end
    if controls.frameW then pcall(PS.Set, PS, id, 'stopmotion.frameW', frameW or 0) end
    if controls.frameH then pcall(PS.Set, PS, id, 'stopmotion.frameH', frameH or 0) end

    -- Derive rows/cols when we have enough pixel info
    local rows = 0
    local cols = 0
    if (fileW and fileW > 0) and (frameW and frameW > 0) then
      cols = math.floor(fileW / frameW)
      if cols < 0 then cols = 0 end
    end
    if (fileH and fileH > 0) and (frameH and frameH > 0) then
      rows = math.floor(fileH / frameH)
      if rows < 0 then rows = 0 end
    end

    if rows > 0 and cols > 0 then
      pcall(PS.Set, PS, id, 'stopmotion.rows', rows)
      pcall(PS.Set, PS, id, 'stopmotion.cols', cols)
      -- Clamp frames if present
      local frames = controls.frames and _ToInt(controls.frames:GetText() or '') or 0
      if frames and frames > 0 then
        local maxF = rows * cols
        if frames > maxF then
          pcall(PS.Set, PS, id, 'stopmotion.frames', maxF)
        end
      end
    end

    if UI and UI.RefreshRight then
      pcall(UI.RefreshRight, UI)
    end
  end

  local function _WireAdv(control)
    if not (control and control.SetScript) then return end
    control:SetScript('OnEnterPressed', function(self)
      self:ClearFocus()
      _CommitAdvanced()
    end)
    control:SetScript('OnEditFocusLost', function(self)
      _CommitAdvanced()
    end)
  end

  _WireAdv(controls.fileW)
  _WireAdv(controls.fileH)
  _WireAdv(controls.frameW)
  _WireAdv(controls.frameH)

  -- Advanced enable toggle (source-of-truth switch)
  if controls.useAdvanced and controls.useAdvanced._checkbox and controls.useAdvanced._checkbox.SetScript then
    controls.useAdvanced._checkbox:SetScript("OnClick", function(btn)
      local id = _GetBoundNodeId(controls.useAdvanced)
      if not id then return end
      local PS = Gate and Gate.Get and Gate:Get("PropertyService") or nil
      if not (PS and PS.Set) then return end
      local v = btn and btn.GetChecked and btn:GetChecked() or false
      pcall(PS.Set, PS, id, "stopmotion.useAdvanced", v and true or false)
      if UI and UI.RefreshRight then
        pcall(UI.RefreshRight, UI)
      end
    end)
  end


  -- Step3: playback params (inverse / fps / mode)
  local function _CommitFPS(control)
    if not (control and control.GetText) then return end
    local id = _GetBoundNodeId(control)
    if not id then return end
    local PS = Gate and Gate.Get and Gate:Get('PropertyService') or nil
    if not (PS and PS.Set) then return end
    local n = tonumber(control:GetText() or "")
    if not n then n = 1 end
    n = math.floor(n)
    if n < 1 then n = 1 end
    if n > 60 then n = 60 end
    pcall(PS.Set, PS, id, 'stopmotion.fps', n)
    if UI and UI.RefreshRight then
      pcall(UI.RefreshRight, UI)
    end
  end

  if controls.fps and controls.fps.SetScript then
    controls.fps:SetScript('OnEnterPressed', function(self)
      self:ClearFocus()
      _CommitFPS(self)
    end)
    controls.fps:SetScript('OnEditFocusLost', function(self)
      _CommitFPS(self)
    end)
  end

  if controls.inverse and controls.inverse._checkbox and controls.inverse._checkbox.SetScript then
    controls.inverse._checkbox:SetScript("OnClick", function(btn)
      local id = _GetBoundNodeId(controls.inverse)
      if not id then return end
      local PS = Gate and Gate.Get and Gate:Get("PropertyService") or nil
      if not (PS and PS.Set) then return end
      local v = btn and btn.GetChecked and btn:GetChecked() or false
      pcall(PS.Set, PS, id, "stopmotion.inverse", v and true or false)
      if UI and UI.RefreshRight then
        pcall(UI.RefreshRight, UI)
      end
    end)
  end

  if controls.mode and UIDropDownMenu_Initialize then
    -- Rebuild dropdown to commit selection through PropertyService.
    UIDropDownMenu_Initialize(controls.mode, function(self, level)
      local function _Add(value, textKey)
        local info = UIDropDownMenu_CreateInfo()
        info.text = (Bre and Bre.L and Bre.L(textKey)) or tostring(value)
        info.value = value
        info.func = function()
          local id = _GetBoundNodeId(controls.mode)
          if not id then return end
          local PS = Gate and Gate.Get and Gate:Get('PropertyService') or nil
          if not (PS and PS.Set) then return end
          controls.mode.__value = value
          UIDropDownMenu_SetText(controls.mode, info.text)
          pcall(PS.Set, PS, id, 'stopmotion.mode', value)
          if UI and UI.RefreshRight then
            pcall(UI.RefreshRight, UI)
          end
        end
        UIDropDownMenu_AddButton(info, level)
      end
      _Add('loop', 'ELEM_STOPMOTION_MODE_LOOP')
      _Add('once', 'ELEM_STOPMOTION_MODE_ONCE')
      _Add('bounce', 'ELEM_STOPMOTION_MODE_BOUNCE')
    end)
  end
end

-- Wire Model drawer specific events (UI shell only; no PropertyService/DB/Move writes)
function DT:_WireModelEvents(drawer, controls)
  local Gate = Bre.Gate
  local UI = Bre.UI

  local function _L(key)
    if Bre and Bre.L then return Bre.L(key) end
    return tostring(key)
  end

  if not controls then return end

  local function _GetNodeId()
    local f = UI and UI.frame
    return f and f._selectedId
  end

  local function _Commit(propKey, value)
    local id = _GetNodeId()
    if not id then return end
    local PS = Gate and Gate.Get and Gate:Get("PropertyService") or nil
    if not (PS and PS.Set) then return end
    pcall(PS.Set, PS, id, propKey, value)
    if UI and UI.RefreshRight then
      pcall(UI.RefreshRight, UI)
    end
  end

  -- Mode dropdown: Unit / FileID (commit via PropertyService)
  if controls.modelMode then
    local dd = controls.modelMode

    UIDropDownMenu_Initialize(dd, function(self, level)
      if level ~= 1 then return end
      local opts = {
        { text = _L("MODEL_MODE_UNIT"), value = "unit" },
        { text = _L("MODEL_MODE_FILEID"), value = "file" },
      }
      for _, opt in ipairs(opts) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = opt.text
        info.value = opt.value
        info.func = function()
          UIDropDownMenu_SetSelectedValue(dd, opt.value)
          UIDropDownMenu_SetText(dd, opt.text)
          drawer._modelMode = opt.value
          _Commit("modelMode", opt.value)
        end
        UIDropDownMenu_AddButton(info, level)
      end
    end)
  end

  -- Value combo_input:
  -- - mode=unit: preset dropdown commits modelUnit (player/target/focus)
  -- - mode=file: editbox commits modelFileID on Enter/FocusLost
  if controls.modelValue and controls.modelValue._editbox then
    local eb = controls.modelValue._editbox
    local btn = controls.modelValue._button

    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local function _CommitFileId()
      local mode = drawer._modelMode or "unit"
      if mode ~= "file" then return end
      local raw = (eb and eb.GetText and eb:GetText()) or ""
      raw = tostring(raw or ""):gsub("%s+", "")
      local n = tonumber(raw)
      if not n then
        _Commit("modelFileID", nil)
        return
      end
      _Commit("modelFileID", n)
    end

    eb:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      _CommitFileId()
    end)
    eb:SetScript("OnEditFocusLost", function(self)
      if drawer._suppressModelFileCommit then return end
      _CommitFileId()
    end)

    if btn then
      local dropdownName = "BreModelValuePresetDropdown"
      local dropdown = _G[dropdownName] or CreateFrame("Frame", dropdownName, nil, "UIDropDownMenuTemplate")

      UIDropDownMenu_Initialize(dropdown, function(self, level)
        if level ~= 1 then return end
        local mode = drawer._modelMode or "unit"

        if mode == "unit" then
          local presets = {
            { text = _L("MODEL_UNIT_PLAYER"), value = "player" },
            { text = _L("MODEL_UNIT_TARGET"), value = "target" },
            { text = _L("MODEL_UNIT_FOCUS"), value = "focus" },
          }
          for _, opt in ipairs(presets) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = opt.text
            info.notCheckable = true
            info.func = function()
              drawer._modelUnit = opt.value
              if eb and eb.SetText then
                eb:SetText(opt.text)
                eb:ClearFocus()
              end
              _Commit("modelUnit", opt.value)
            end
            UIDropDownMenu_AddButton(info, level)
          end
        else
          local presets = Bre and Bre.ModelFileIDPresets or {}
          for _, opt in ipairs(presets) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = _L(opt.nameKey or tostring(opt.id))
            info.notCheckable = true
            info.func = function()
              -- IMPORTANT: do NOT ClearFocus() here.
              -- Commit must only happen on Enter / FocusLost (v1.4).
              if eb and eb.SetText then
                eb:SetText(tostring(opt.id or ""))
                if eb.SetFocus then eb:SetFocus() end
                drawer._suppressModelFileCommit = false
              end
            end
            UIDropDownMenu_AddButton(info, level)
          end
          if #presets == 0 then
            local info = UIDropDownMenu_CreateInfo()
            info.text = _L("PLACEHOLDER")
            info.notCheckable = true
            info.func = function() end
            UIDropDownMenu_AddButton(info, level)
          end
        end
      end)

      btn:SetScript("OnClick", function(self)
        local mode = drawer._modelMode or "unit"
        if mode ~= "unit" and mode ~= "file" then return end
        if mode == "file" then
          -- Prevent focus-lost commit caused by clicking the dropdown button/menu.
          drawer._suppressModelFileCommit = true
          if C_Timer and C_Timer.After then
            C_Timer.After(0.2, function()
              drawer._suppressModelFileCommit = false
            end)
          end
        end
        UIDropDownMenu_SetWidth(dropdown, controls.modelValue:GetWidth() - 22)
        ToggleDropDownMenu(1, nil, dropdown, controls.modelValue, 0, 0)
      end)
    end
  end

  -- Facing numericbox (v2.18.84)
  if controls.facing then
    local eb = controls.facing

    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      local raw = (self.GetText and self:GetText()) or ""
      local n = tonumber(raw)
      if n then
        _Commit("facing", n)
      end
    end)
    eb:SetScript("OnEditFocusLost", function(self)
      local raw = (self.GetText and self:GetText()) or ""
      local n = tonumber(raw)
      if n then
        _Commit("facing", n)
      end
    end)
  end

  -- Facing slider (v2.18.84)
  if controls.facingSlider then
    local slider = controls.facingSlider
    slider:SetScript("OnMouseUp", function(self)
      local v = self:GetValue()
      _Commit("facing", v)
    end)
  end

  -- Animation sequence pager (v2.18.87)
  if controls.animSequence then
    local pager = controls.animSequence
    -- Input box: commit on Enter or focus lost
    if pager._editbox then
      pager._editbox:SetScript("OnEnterPressed", function(self)
        local txt = self:GetText()
        local n = tonumber(txt)
        if n then
          _Commit("animSequence", n)
        end
        self:ClearFocus()
      end)
      pager._editbox:SetScript("OnEditFocusLost", function(self)
        local txt = self:GetText()
        local n = tonumber(txt)
        if n then
          _Commit("animSequence", n)
        end
      end)
    end
    -- Prev button: decrement
    if pager._prev then
      pager._prev:SetScript("OnClick", function()
        local cur = tonumber(pager:GetText()) or 0
        local new = math.max(0, cur - 1)
        _Commit("animSequence", new)
      end)
    end
    -- Next button: increment
    if pager._next then
      pager._next:SetScript("OnClick", function()
        local cur = tonumber(pager:GetText()) or 0
        local new = math.min(1499, cur + 1)
        _Commit("animSequence", new)
      end)
    end
  end
end

-- Wire Actions specific events (UI-only; no commit logic yet)
function DT:_WireActionsEvents(drawer, controls)
  -- Keep ultra-safe: no commits, no DB writes, no Move calls.
  -- Dropdown menus are initialized during Refresh (spec-driven).
  -- Future: when Actions execution lands, this becomes the single legal wiring point.
end

-- Wire CustomMat specific events
function DT:_WireCustomMatEvents(drawer, controls)
  local Gate = Bre.Gate
  local UI = Bre.UI
  
  -- Helper: Get bound node ID
  local function _GetNodeId()
    local f = UI and UI.frame
    return f and f._selectedId
  end
  
  -- Helper: Check if CustomMat module is enabled
  local function _CMEnabled()
    return Gate and Gate.Has and Gate:Has("CustomMat")
  end
  
  -- Helper: Commit via CustomMat module
  local function _CommitCustomMat()
    if not _CMEnabled() then return end
    
    local EG = Gate:Get('EditGuard')
    if EG and EG.IsGuarded and EG:IsGuarded() then return end
    
    local id = _GetNodeId()
    if not id then return end
    
    local GetData = Bre.GetData
    if type(GetData) ~= "function" then return end
    local data = GetData(id)
    if type(data) ~= "table" then return end
    
    local CM = Gate:Get("CustomMat")
    if not (CM and CM.CommitFromUI) then return end
    
    CM:CommitFromUI({
      id = id,
      data = data,
      textureText = (controls.texturePath and controls.texturePath._editbox and controls.texturePath._editbox:GetText()) or "",
      useColor = false, -- always false now, color is always applied via colorBtn
      previewTex = (controls.preview and controls.preview._texture),
    })
  end
  
  -- Texture path editbox
  if controls.texturePath and controls.texturePath._editbox then
    controls.texturePath._editbox:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      _CommitCustomMat()
      if UI and UI.RefreshRight then UI:RefreshRight() end
    end)
    
    controls.texturePath._editbox:SetScript("OnEditFocusLost", function(self)
      _CommitCustomMat()
      if UI and UI.RefreshRight then UI:RefreshRight() end
    end)
  end
  
  -- Mirror checkbox
  if controls.mirror and controls.mirror._checkbox then
    controls.mirror._checkbox:SetScript("OnClick", function(self)
      local id = _GetNodeId()
      if not id then return end
      
      local PS = Gate:Get('PropertyService')
      if PS and PS.Set then
        local ok, data = PS:Set(id, 'mirror', self:GetChecked() and true or false)
      end
      if UI and UI.RefreshRight then UI:RefreshRight() end
    end)
  end
  
  -- Fade checkbox
  if controls.fade and controls.fade._checkbox then
    controls.fade._checkbox:SetScript("OnClick", function(self)
      local id = _GetNodeId()
      if not id then return end
      
      local PS = Gate:Get('PropertyService')
      if PS and PS.Set then
        local ok, data = PS:Set(id, 'fade', self:GetChecked() and true or false)
      end
      if UI and UI.RefreshRight then UI:RefreshRight() end
    end)
  end
  
  -- Color button (Step10.2: Color picker integration)
  if controls.colorBtn then
    controls.colorBtn:SetScript("OnClick", function(self)
      if not _CMEnabled() then return end
      
      local id = _GetNodeId()
      if not id then return end
      
      local GetData = Bre.GetData
      if type(GetData) ~= "function" then return end
      local data = GetData(id)
      if type(data) ~= "table" then return end
      
      -- Ensure region.color exists
      data.region = type(data.region) == "table" and data.region or {}
      data.region.color = type(data.region.color) == "table" and data.region.color or {r=1, g=1, b=1, a=1}
      local c = data.region.color
      
      -- Save current color for restore
      local r, g, b, a = c.r or 1, c.g or 1, c.b or 1, c.a or 1
      
      -- Helper: Commit color changes
      local function _CommitColor(newR, newG, newB, newA)
        if not _CMEnabled() then return end
        
        local EG = Gate:Get('EditGuard')
        if EG and EG.IsGuarded and EG:IsGuarded() then return end
        
        local CM = Gate:Get("CustomMat")
        if not (CM and CM.CommitColorFromUI) then return end
        
        -- Refresh data in case it changed
        local freshData = GetData(id)
        if type(freshData) ~= "table" then return end
        
        CM:CommitColorFromUI({
          id = id,
          data = freshData,
          r = newR,
          g = newG,
          b = newB,
          a = newA or 1,
          previewTex = (controls.preview and controls.preview._texture),
        })
      end
      
      -- Open WoW's built-in color picker
      local info = {
        r = r,
        g = g,
        b = b,
        opacity = a,
        hasOpacity = true,
        swatchFunc = function()
          local newR, newG, newB = ColorPickerFrame:GetColorRGB()
          local newA = ColorPickerFrame:GetColorAlpha()
          _CommitColor(newR, newG, newB, newA)
          -- Update button color immediately
          if controls.colorBtn and controls.colorBtn.SetColor then
            controls.colorBtn:SetColor(newR, newG, newB, newA)
          end
        end,
        opacityFunc = function()
          local newR, newG, newB = ColorPickerFrame:GetColorRGB()
          local newA = ColorPickerFrame:GetColorAlpha()
          _CommitColor(newR, newG, newB, newA)
          -- Update button color immediately
          if controls.colorBtn and controls.colorBtn.SetColor then
            controls.colorBtn:SetColor(newR, newG, newB, newA)
          end
        end,
        cancelFunc = function()
          -- Restore original color on cancel
          _CommitColor(r, g, b, a)
          if controls.colorBtn and controls.colorBtn.SetColor then
            controls.colorBtn:SetColor(r, g, b, a)
          end
        end,
      }
      
      ColorPickerFrame:SetupColorPickerAndShow(info)
    end)
  end
end

-- Wire ProgressMat specific events
-- TODO: Step2 implementation
function DT:_WireProgressMatEvents(drawer, controls)
  local Gate = Bre.Gate
  local UI = Bre.UI
  
  -- Helper: Get bound node ID
  local function _GetNodeId()
    local f = UI and UI.frame
    return f and f._selectedId
  end
  
  -- Helper: Check EditGuard
  local function _IsGuarded()
    local EG = Gate and Gate:Get("EditGuard")
    return EG and EG.IsGuarded and EG:IsGuarded()
  end
  
  -- Helper: Localize text
  local function _L(key)
    if Bre and Bre.L then return Bre.L(key) end
    return key
  end
  
  if not controls then return end
  
  -- ===== Foreground Material (combo_input) - REQUIRED =====
  if controls.foreground and controls.foreground._editbox then
    local eb = controls.foreground._editbox
    local btn = controls.foreground._button

    -- EditBox events (UI -> data only; no preview/render side effects)
    eb:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      if _IsGuarded() then return end
      local id = _GetNodeId()
      if not id then return end
      local text = self:GetText() or ""
      local PS = Gate:Get("PropertyService")
      if PS and PS.Set then
        PS:Set(id, "foreground", text ~= "" and text or nil)
      end
      if UI and UI.RefreshRight then UI:RefreshRight() end
    end)

    eb:SetScript("OnEditFocusLost", function(self)
      if _IsGuarded() then return end
      local id = _GetNodeId()
      if not id then return end
      local text = self:GetText() or ""
      local PS = Gate:Get("PropertyService")
      if PS and PS.Set then
        PS:Set(id, "foreground", text ~= "" and text or nil)
      end
      if UI and UI.RefreshRight then UI:RefreshRight() end
    end)

    -- Button dropdown - Blizzard preset fill textures as quick picks.
    -- Note: EditBox remains the single source of truth.
    if btn then
      local dropdownName = "BreProgressMatForegroundDropdown"
      local dropdown = _G[dropdownName] or CreateFrame("Frame", dropdownName, nil, "UIDropDownMenuTemplate")

      UIDropDownMenu_Initialize(dropdown, function(self, level)
        if level ~= 1 then return end
        local presets = {
          { text = "UI-StatusBar", value = "Interface\\TARGETINGFRAME\\UI-StatusBar" },
          { text = "UI-StatusBar (Raid)", value = "Interface\\RAIDFRAME\\Raid-Bar-Hp-Fill" },
          { text = "UI-StatusBar (Party)", value = "Interface\\PARTYFRAME\\UI-PartyHealthBar" },
          { text = "UI-StatusBar (Vehicle)", value = "Interface\\VEHICLEFRAME\\UI-Vehicle-HealthBar" },
        }

        for _, opt in ipairs(presets) do
          local info = UIDropDownMenu_CreateInfo()
          info.text = opt.text
          info.notCheckable = true
          info.func = function()
            if eb and eb.SetText then
              eb:SetText(opt.value)
              eb:ClearFocus() -- triggers OnEditFocusLost commit
            end
          end
          UIDropDownMenu_AddButton(info, level)
        end
      end)

      btn:SetScript("OnClick", function(self)
        UIDropDownMenu_SetWidth(dropdown, controls.foreground:GetWidth() - 22)
        ToggleDropDownMenu(1, nil, dropdown, controls.foreground, 0, 0)
      end)
    end
  end

-- ===== Background Material (combo_input) - OPTIONAL =====
  if controls.background and controls.background._editbox then
    local eb = controls.background._editbox
    local btn = controls.background._button
    
    -- EditBox events
    eb:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      if _IsGuarded() then return end
      local id = _GetNodeId()
      if not id then return end
      local text = self:GetText() or ""
      local PS = Gate:Get("PropertyService")
      if PS and PS.Set then
        PS:Set(id, "background", text ~= "" and text or nil)
      end
      if UI and UI.RefreshRight then UI:RefreshRight() end
    end)
    
    eb:SetScript("OnEditFocusLost", function(self)
      if _IsGuarded() then return end
      local id = _GetNodeId()
      if not id then return end
      local text = self:GetText() or ""
      local PS = Gate:Get("PropertyService")
      if PS and PS.Set then
        PS:Set(id, "background", text ~= "" and text or nil)
      end
      if UI and UI.RefreshRight then UI:RefreshRight() end
    end)
    
    -- Button dropdown
    if btn then
      local dropdownName = "BreProgressMatBackgroundDropdown"
      local dropdown = _G[dropdownName] or CreateFrame("Frame", dropdownName, nil, "UIDropDownMenuTemplate")
      
      UIDropDownMenu_Initialize(dropdown, function(self, level)
        if level ~= 1 then return end

        local presets = {
          { text = "(清空)", value = "" },
          { text = "UI-StatusBar", value = "Interface\\TARGETINGFRAME\\UI-StatusBar" },
          { text = "UI-StatusBar (Raid)", value = "Interface\\RAIDFRAME\\Raid-Bar-Hp-Fill" },
          { text = "UI-StatusBar (Party)", value = "Interface\\PARTYFRAME\\UI-PartyHealthBar" },
          { text = "UI-StatusBar (Vehicle)", value = "Interface\\VEHICLEFRAME\\UI-Vehicle-HealthBar" },
        }

        for _, opt in ipairs(presets) do
          local info = UIDropDownMenu_CreateInfo()
          info.text = opt.text
          info.notCheckable = true
          info.func = function()
            if eb and eb.SetText then
              eb:SetText(opt.value)
              eb:ClearFocus()
            end
          end
          UIDropDownMenu_AddButton(info, level)
        end
      end)
      
      btn:SetScript("OnClick", function(self)
        UIDropDownMenu_SetWidth(dropdown, controls.background:GetWidth() - 22)
        ToggleDropDownMenu(1, nil, dropdown, controls.background, 0, 0)
      end)
    end
  end
  
  -- ===== Mask Material (combo_input) - OPTIONAL =====
  if controls.mask and controls.mask._editbox then
    local eb = controls.mask._editbox
    local btn = controls.mask._button
    
    -- EditBox events
    eb:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      if _IsGuarded() then return end
      local id = _GetNodeId()
      if not id then return end
      local text = self:GetText() or ""
      local PS = Gate:Get("PropertyService")
      if PS and PS.Set then
        PS:Set(id, "mask", text ~= "" and text or nil)
      end
      if UI and UI.RefreshRight then UI:RefreshRight() end
    end)
    
    eb:SetScript("OnEditFocusLost", function(self)
      if _IsGuarded() then return end
      local id = _GetNodeId()
      if not id then return end
      local text = self:GetText() or ""
      local PS = Gate:Get("PropertyService")
      if PS and PS.Set then
        PS:Set(id, "mask", text ~= "" and text or nil)
      end
      if UI and UI.RefreshRight then UI:RefreshRight() end
    end)
    
    -- Button dropdown
    if btn then
      local dropdownName = "BreProgressMatMaskDropdown"
      local dropdown = _G[dropdownName] or CreateFrame("Frame", dropdownName, nil, "UIDropDownMenuTemplate")
      
      UIDropDownMenu_Initialize(dropdown, function(self, level)
        if level ~= 1 then return end

        -- Mask is usually a custom texture path; provide only clear option here.
        local info = UIDropDownMenu_CreateInfo()
        info.text = "(清空)"
        info.notCheckable = true
        info.func = function()
          if eb and eb.SetText then
            eb:SetText("")
            eb:ClearFocus()
          end
        end
        UIDropDownMenu_AddButton(info, level)

        local info2 = UIDropDownMenu_CreateInfo()
        info2.text = "(无预设)"
        info2.disabled = true
        info2.notCheckable = true
        UIDropDownMenu_AddButton(info2, level)
      end)
      
      btn:SetScript("OnClick", function(self)
        UIDropDownMenu_SetWidth(dropdown, controls.mask:GetWidth() - 22)
        ToggleDropDownMenu(1, nil, dropdown, controls.mask, 0, 0)
      end)
    end
  end
  
  -- ===== Progress Type Dropdown - OPTIONAL (with empty and power types) =====
  -- ===== Material Type Dropdown (NEW) =====
  if controls.materialType then
    UIDropDownMenu_Initialize(controls.materialType, function(self, level)
      if level ~= 1 then return end
      
      local function _choose(v)
        if _IsGuarded() then return end
        local id = _GetNodeId()
        if not id then return end
        UIDropDownMenu_SetText(controls.materialType, _L(v == "Custom" and "PROG_MAT_MATERIAL_CUSTOM" or "PROG_MAT_MATERIAL_BLIZZARD"))
        local PS = Gate:Get("PropertyService")
        if PS and PS.Set then
          PS:Set(id, "materialType", v)
        end
        -- Refresh to update direction options and visibility
        if UI and UI.RefreshRight then UI:RefreshRight() end
      end
      
      -- Material type options
      local materialTypes = {
        {value = "Custom", textKey = "PROG_MAT_MATERIAL_CUSTOM"},
        {value = "Blizzard", textKey = "PROG_MAT_MATERIAL_BLIZZARD"},
      }
      
      for _, opt in ipairs(materialTypes) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = _L(opt.textKey)
        info.value = opt.value
        info.func = function() _choose(opt.value) end
        UIDropDownMenu_AddButton(info, level)
      end
    end)
  end
  
  -- ===== Progress Type Dropdown =====
  if controls.type then
    UIDropDownMenu_Initialize(controls.type, function(self, level)
      if level ~= 1 then return end
      
      local function _choose(v)
        if _IsGuarded() then return end
        local id = _GetNodeId()
        if not id then return end
        UIDropDownMenu_SetText(controls.type, _L(v))
        local PS = Gate:Get("PropertyService")
        if PS and PS.Set then
          PS:Set(id, "progressType", v)
        end
        if UI and UI.RefreshRight then UI:RefreshRight() end
      end
      
      -- v2.0.6: Power types + Health
      local powerTypes = {
        {value = "PROG_TYPE_HEALTH", textKey = "PROG_TYPE_HEALTH"},
        {value = "PROG_TYPE_CLASS_POWER", textKey = "PROG_TYPE_CLASS_POWER"},
        {value = "PROG_TYPE_MANA", textKey = "PROG_TYPE_MANA"},
        {value = "PROG_TYPE_ENERGY", textKey = "PROG_TYPE_ENERGY"},
        {value = "PROG_TYPE_RAGE", textKey = "PROG_TYPE_RAGE"},
        {value = "PROG_TYPE_FOCUS", textKey = "PROG_TYPE_FOCUS"},
        {value = "PROG_TYPE_RUNIC_POWER", textKey = "PROG_TYPE_RUNIC_POWER"},
        {value = "PROG_TYPE_INSANITY", textKey = "PROG_TYPE_INSANITY"},
        {value = "PROG_TYPE_LUNAR_POWER", textKey = "PROG_TYPE_LUNAR_POWER"},
        {value = "PROG_TYPE_FURY", textKey = "PROG_TYPE_FURY"},
        {value = "PROG_TYPE_MAELSTROM", textKey = "PROG_TYPE_MAELSTROM"},
        {value = "PROG_TYPE_CHI", textKey = "PROG_TYPE_CHI"},
      }
      
      for _, opt in ipairs(powerTypes) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = _L(opt.textKey)
        info.value = opt.value
        info.func = function() _choose(opt.value) end
        UIDropDownMenu_AddButton(info, level)
      end
    end)
  end
  
  -- ===== Progress Unit Dropdown =====
  if controls.progressUnit then
    UIDropDownMenu_Initialize(controls.progressUnit, function(self, level)
      if level ~= 1 then return end

      local function _choose(v)
        if _IsGuarded() then return end
        local id = _GetNodeId()
        if not id then return end

        local uMap = {
          player = "PROG_UNIT_PLAYER",
          target = "PROG_UNIT_TARGET",
          focus  = "PROG_UNIT_FOCUS",
          pet    = "PROG_UNIT_PET",
        }
        local textKey = uMap[v] or v
        UIDropDownMenu_SetText(controls.progressUnit, _L(textKey))

        local PS = Gate:Get("PropertyService")
        if PS and PS.Set then
          PS:Set(id, "progressUnit", v)
        end
        if UI and UI.RefreshRight then UI:RefreshRight() end
      end

      local units = {
        { value = "player", textKey = "PROG_UNIT_PLAYER" },
        { value = "target", textKey = "PROG_UNIT_TARGET" },
        { value = "focus",  textKey = "PROG_UNIT_FOCUS"  },
        { value = "pet",    textKey = "PROG_UNIT_PET"    },
      }

      for _, opt in ipairs(units) do
        local info = UIDropDownMenu_CreateInfo()
        info.text  = _L(opt.textKey)
        info.value = opt.value
        info.func  = function() _choose(opt.value) end
        UIDropDownMenu_AddButton(info, level)
      end
    end)
  end

  -- ===== Progress Direction Dropdown - NO empty option, Chinese labels =====
  if controls.progressDirection then
    UIDropDownMenu_Initialize(controls.progressDirection, function(self, level)
      if level ~= 1 then return end
      
      local function _choose(v)
        if _IsGuarded() then return end
        local id = _GetNodeId()
        if not id then return end
        
        -- Update dropdown display text
        local dirMap = {
          LeftToRight = "PROG_DIR_LTR",
          RightToLeft = "PROG_DIR_RTL",
          TopToBottom = "PROG_DIR_TTB",
          BottomToTop = "PROG_DIR_BTT",
          Clockwise = "PROG_DIR_CW",
          Anticlockwise = "PROG_DIR_CCW",
        }
        local textKey = dirMap[v] or "PROG_DIR_LTR"
        UIDropDownMenu_SetText(controls.progressDirection, _L(textKey))
        
        local PS = Gate:Get("PropertyService")
        if PS and PS.Set then
          PS:Set(id, "progressDirection", v)
        end
        if UI and UI.RefreshRight then UI:RefreshRight() end
      end
      
      -- Linear-only (MaskTexture route): 4 directions only
      local directions = {
        {value = "BottomToTop", textKey = "PROG_DIR_BTT"},
        {value = "TopToBottom", textKey = "PROG_DIR_TTB"},
        {value = "LeftToRight", textKey = "PROG_DIR_LTR"},
        {value = "RightToLeft", textKey = "PROG_DIR_RTL"},
      }
      
      for _, opt in ipairs(directions) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = _L(opt.textKey)
        info.value = opt.value
        info.func = function() _choose(opt.value) end
        UIDropDownMenu_AddButton(info, level)
      end
    end)
  end
  
  -- ===== Foreground Color Button =====
  if controls.fgColor then
    controls.fgColor:SetScript("OnClick", function(self)
      if _IsGuarded() then return end
      local id = _GetNodeId()
      if not id then return end
      
      local GetData = Bre.GetData
      if type(GetData) ~= "function" then return end
      local data = GetData(id)
      if type(data) ~= "table" then return end
      
      -- Ensure fgColor exists
      data.fgColor = type(data.fgColor) == "table" and data.fgColor or {r=1, g=1, b=1, a=1}
      local c = data.fgColor
      
      local r, g, b, a = c.r or 1, c.g or 1, c.b or 1, c.a or 1
      
      local function _CommitColor(newR, newG, newB, newA)
        if _IsGuarded() then return end
        local PS = Gate:Get("PropertyService")
        if PS and PS.Set then
          PS:Set(id, "fgColor", {r=newR, g=newG, b=newB, a=newA})
        end
        if UI and UI.RefreshRight then UI:RefreshRight() end
      end
      
      local info = {
        r = r, g = g, b = b,
        opacity = a,
        hasOpacity = true,
        swatchFunc = function()
          local newR, newG, newB = ColorPickerFrame:GetColorRGB()
          local newA = ColorPickerFrame:GetColorAlpha()
          _CommitColor(newR, newG, newB, newA)
          if controls.fgColor and controls.fgColor.SetColor then
            controls.fgColor:SetColor(newR, newG, newB, newA)
          end
        end,
        opacityFunc = function()
          local newR, newG, newB = ColorPickerFrame:GetColorRGB()
          local newA = ColorPickerFrame:GetColorAlpha()
          _CommitColor(newR, newG, newB, newA)
          if controls.fgColor and controls.fgColor.SetColor then
            controls.fgColor:SetColor(newR, newG, newB, newA)
          end
        end,
        cancelFunc = function()
          _CommitColor(r, g, b, a)
          if controls.fgColor and controls.fgColor.SetColor then
            controls.fgColor:SetColor(r, g, b, a)
          end
        end,
      }
      ColorPickerFrame:SetupColorPickerAndShow(info)
    end)
  end
  
  -- ===== Background Color Button =====
  if controls.bgColor then
    controls.bgColor:SetScript("OnClick", function(self)
      if _IsGuarded() then return end
      local id = _GetNodeId()
      if not id then return end
      
      local GetData = Bre.GetData
      if type(GetData) ~= "function" then return end
      local data = GetData(id)
      if type(data) ~= "table" then return end
      
      -- Ensure bgColor exists
      data.bgColor = type(data.bgColor) == "table" and data.bgColor or {r=1, g=1, b=1, a=1}
      local c = data.bgColor
      
      local r, g, b, a = c.r or 1, c.g or 1, c.b or 1, c.a or 1
      
      local function _CommitColor(newR, newG, newB, newA)
        if _IsGuarded() then return end
        local PS = Gate:Get("PropertyService")
        if PS and PS.Set then
          PS:Set(id, "bgColor", {r=newR, g=newG, b=newB, a=newA})
        end
        if UI and UI.RefreshRight then UI:RefreshRight() end
      end
      
      local info = {
        r = r, g = g, b = b,
        opacity = a,
        hasOpacity = true,
        swatchFunc = function()
          local newR, newG, newB = ColorPickerFrame:GetColorRGB()
          local newA = ColorPickerFrame:GetColorAlpha()
          _CommitColor(newR, newG, newB, newA)
          if controls.bgColor and controls.bgColor.SetColor then
            controls.bgColor:SetColor(newR, newG, newB, newA)
          end
        end,
        opacityFunc = function()
          local newR, newG, newB = ColorPickerFrame:GetColorRGB()
          local newA = ColorPickerFrame:GetColorAlpha()
          _CommitColor(newR, newG, newB, newA)
          if controls.bgColor and controls.bgColor.SetColor then
            controls.bgColor:SetColor(newR, newG, newB, newA)
          end
        end,
        cancelFunc = function()
          _CommitColor(r, g, b, a)
          if controls.bgColor and controls.bgColor.SetColor then
            controls.bgColor:SetColor(r, g, b, a)
          end
        end,
      }
      ColorPickerFrame:SetupColorPickerAndShow(info)
    end)
  end
end

-- Wire attribute section events (built-in)
function DT:_WireAttributeEvents(drawer, controls)
  local Gate = Bre.Gate
  local UI = Bre.UI
  
  -- Helper: Get bound node ID
  local function _GetNodeId()
    local f = UI and UI.frame
    return f and f._selectedId
  end
  
  -- Helper: Check EditGuard
  local function _IsGuarded()
    local EG = Gate and Gate:Get("EditGuard")
    return EG and EG.IsGuarded and EG:IsGuarded()
  end
  
  if not controls then return end
  
  -- ===== Alpha Slider + NumericBox =====
  if controls.alphaSlider and controls.alphaNum then
    local slider = controls.alphaSlider
    local numBox = controls.alphaNum
    drawer._updatingAlpha = false
    
    local function _previewAlpha(val)
      if _IsGuarded() then return end
      local id = _GetNodeId()
      if not id then return end
      local PS = Gate:Get("PropertyService")
      if PS and PS.PreviewSet then
        PS:PreviewSet(id, "alpha", val)
      end
    end
    
    local function _commitAlpha(val)
      if _IsGuarded() then return end
      local id = _GetNodeId()
      if not id then return end
      local PS = Gate:Get("PropertyService")
      if PS and PS.CommitAlpha then
        PS:CommitAlpha(id, val)
      elseif PS and PS.Set then
        PS:Set(id, "alpha", val)
      end
      if UI and UI.RefreshRight then UI:RefreshRight() end
    end
    
    -- Slider events
    slider:SetScript("OnValueChanged", function(self)
      if drawer._updatingAlpha then return end
      local val = self:GetValue()
      _previewAlpha(val)
      -- Sync to numBox
      drawer._updatingAlpha = true
      numBox:SetText(string.format("%.2f", val))
      drawer._updatingAlpha = false
    end)
    
    slider:SetScript("OnMouseUp", function(self)
      _commitAlpha(self:GetValue())
    end)
    
    -- NumBox events
    local function _applyNumBox()
      if drawer._updatingAlpha then return end
      local v = tonumber(numBox:GetText())
      if not v then v = slider:GetValue() or 1 end
      if v < 0 then v = 0 elseif v > 1 then v = 1 end
      drawer._updatingAlpha = true
      slider:SetValue(v)
      numBox:SetText(string.format("%.2f", v))
      drawer._updatingAlpha = false
      _commitAlpha(v)
    end
    
    numBox:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      _applyNumBox()
    end)
    numBox:SetScript("OnEditFocusLost", _applyNumBox)
  end
  
  -- ===== Rotation Slider + NumericBox =====
  if controls.rotSlider and controls.rotNum then
    local slider = controls.rotSlider
    local numBox = controls.rotNum
    drawer._updatingRot = false
    
    local function _previewRot(val)
      if _IsGuarded() then return end
      local id = _GetNodeId()
      if not id then return end
      local PS = Gate:Get("PropertyService")
      if PS and PS.PreviewSet then
        PS:PreviewSet(id, "rotation", val)
      end
    end
    
    local function _commitRot(val)
      if _IsGuarded() then return end
      local id = _GetNodeId()
      if not id then return end
      local PS = Gate:Get("PropertyService")
      if PS and PS.Set then
        PS:Set(id, "rotation", val)
      end
      if UI and UI.RefreshRight then UI:RefreshRight() end
    end
    
    slider:SetScript("OnValueChanged", function(self)
      if drawer._updatingRot then return end
      local val = self:GetValue()
      _previewRot(val)
      drawer._updatingRot = true
      numBox:SetText(_FmtOffset(val))
      drawer._updatingRot = false
    end)
    
    slider:SetScript("OnMouseUp", function(self)
      _commitRot(self:GetValue())
    end)
    
    local function _applyNumBox()
      if drawer._updatingRot then return end
      local v = tonumber(numBox:GetText())
      if not v then v = slider:GetValue() or 0 end
      if v < -180 then v = -180 elseif v > 180 then v = 180 end
      drawer._updatingRot = true
      slider:SetValue(v)
      numBox:SetText(_FmtOffset(v))
      drawer._updatingRot = false
      _commitRot(v)
    end
    
    numBox:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      _applyNumBox()
    end)
    numBox:SetScript("OnEditFocusLost", _applyNumBox)
  end
  
  -- ===== Blend Mode Dropdown =====
  if controls.blendDD then
    UIDropDownMenu_Initialize(controls.blendDD, function(self, level)
      if level ~= 1 then return end
      local function _choose(v)
        if _IsGuarded() then return end
        local id = _GetNodeId()
        if not id then return end
        UIDropDownMenu_SetText(controls.blendDD, v)
        local PS = Gate:Get("PropertyService")
        if PS and PS.Set then
          PS:Set(id, "blendMode", v)
        end
        if UI and UI.RefreshRight then UI:RefreshRight() end
      end
      
      for _, v in ipairs({"BLEND", "ADD", "MOD", "ALPHAKEY"}) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = v
        info.value = v
        info.func = function() _choose(v) end
        UIDropDownMenu_AddButton(info, level)
      end
    end)
  end
  
  -- ===== Fold Dropdown (placeholder) =====
  if controls.foldDD then
    UIDropDownMenu_Initialize(controls.foldDD, function(self, level)
      if level ~= 1 then return end
      local function _choose(v)
        if _IsGuarded() then return end
        local id = _GetNodeId()
        if not id then return end
        UIDropDownMenu_SetText(controls.foldDD, v)
        local PS = Gate:Get("PropertyService")
        if PS and PS.Set then
          PS:Set(id, "fold", v)
        end
        if UI and UI.RefreshRight then UI:RefreshRight() end
      end
      
      -- Placeholder options
      for _, v in ipairs({"NONE", "HORIZONTAL", "VERTICAL"}) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = v
        info.value = v
        info.func = function() _choose(v) end
        UIDropDownMenu_AddButton(info, level)
      end
    end)
  end
  
  -- ===== Height/Width Sliders =====
  if controls.hSlider and controls.hNum then
    local slider = controls.hSlider
    local numBox = controls.hNum
    drawer._updatingHeight = false
    
    local function _commitSize(w, h)
      if _IsGuarded() then return end
      local id = _GetNodeId()
      if not id then return end
      local PS = Gate:Get("PropertyService")
      if PS and PS.CommitSize then
        PS:CommitSize(id, w, h)
      elseif PS and PS.Set then
        PS:Set(id, "sizeW", w)
        PS:Set(id, "sizeH", h)
      end
      if UI and UI.RefreshRight then UI:RefreshRight() end
    end
    
    slider:SetScript("OnMouseUp", function(self)
      local h = self:GetValue()
      local w = controls.wSlider and controls.wSlider:GetValue() or 300
      _commitSize(w, h)
    end)
    
    slider:SetScript("OnValueChanged", function(self)
      if drawer._updatingHeight then return end
      drawer._updatingHeight = true
      numBox:SetText(_FmtOffset(self:GetValue()))
      drawer._updatingHeight = false
    end)
    
    local function _applyNumBox()
      if drawer._updatingHeight then return end
      local v = tonumber(numBox:GetText())
      if not v then v = slider:GetValue() or 300 end
      if v < 1 then v = 1 elseif v > 2048 then v = 2048 end
      drawer._updatingHeight = true
      slider:SetValue(v)
      numBox:SetText(_FmtOffset(v))
      drawer._updatingHeight = false
      local w = controls.wSlider and controls.wSlider:GetValue() or 300
      _commitSize(w, v)
    end
    
    numBox:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      _applyNumBox()
    end)
    numBox:SetScript("OnEditFocusLost", _applyNumBox)
  end
  
  if controls.wSlider and controls.wNum then
    local slider = controls.wSlider
    local numBox = controls.wNum
    drawer._updatingWidth = false
    
    local function _commitSize(w, h)
      if _IsGuarded() then return end
      local id = _GetNodeId()
      if not id then return end
      local PS = Gate:Get("PropertyService")
      if PS and PS.CommitSize then
        PS:CommitSize(id, w, h)
      elseif PS and PS.Set then
        PS:Set(id, "sizeW", w)
        PS:Set(id, "sizeH", h)
      end
      if UI and UI.RefreshRight then UI:RefreshRight() end
    end
    
    slider:SetScript("OnMouseUp", function(self)
      local w = self:GetValue()
      local h = controls.hSlider and controls.hSlider:GetValue() or 300
      _commitSize(w, h)
    end)
    
    slider:SetScript("OnValueChanged", function(self)
      if drawer._updatingWidth then return end
      drawer._updatingWidth = true
      numBox:SetText(_FmtOffset(self:GetValue()))
      drawer._updatingWidth = false
    end)
    
    local function _applyNumBox()
      if drawer._updatingWidth then return end
      local v = tonumber(numBox:GetText())
      if not v then v = slider:GetValue() or 300 end
      if v < 1 then v = 1 elseif v > 2048 then v = 2048 end
      drawer._updatingWidth = true
      slider:SetValue(v)
      numBox:SetText(_FmtOffset(v))
      drawer._updatingWidth = false
      local h = controls.hSlider and controls.hSlider:GetValue() or 300
      _commitSize(v, h)
    end
    
    numBox:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      _applyNumBox()
    end)
    numBox:SetScript("OnEditFocusLost", _applyNumBox)
  end
end

-- Wire position section events (built-in)
function DT:_WirePositionEvents(drawer, controls)
  local Gate = Bre.Gate
  local UI = Bre.UI
  
  local function _GetNodeId()
    local f = UI and UI.frame
    return f and f._selectedId
  end
  
  local function _IsGuarded()
    local EG = Gate and Gate:Get("EditGuard")
    return EG and EG.IsGuarded and EG:IsGuarded()
  end
  
  if not controls then return end
  
  -- ===== AlignTo Dropdown =====
  if controls.alignDD then
    UIDropDownMenu_Initialize(controls.alignDD, function(self, level)
      if level ~= 1 then return end
      
      local function _L(key)
        if Bre and Bre.L then return Bre.L(key) end
        return key
      end
      
      local function _choose(v)
        if _IsGuarded() then return end
        local id = _GetNodeId()
        if not id then return end
        local PS = Gate:Get("PropertyService")
        if PS and PS.Set then
          PS:Set(id, "anchorTarget", v)
        end
        if UI and UI.RefreshRight then UI:RefreshRight() end
      end
      
      local options = {
        {value = "SCREEN_CENTER", text = _L("ELEM_MAT_ALIGN_TO_SCREEN_CENTER")},
      }
      
      for _, opt in ipairs(options) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = opt.text
        info.value = opt.value
        info.func = function() _choose(opt.value) end
        UIDropDownMenu_AddButton(info, level)
      end
    end)
  end
  
  -- ===== FrameStrata Dropdown =====
  local strataDD = controls.strataDD or controls.levelDD
  if strataDD then
    UIDropDownMenu_Initialize(strataDD, function(self, level)
      if level ~= 1 then return end
      
      local function _L(key)
        if Bre and Bre.L then return Bre.L(key) end
        return key
      end
      
      local function _choose(v)
        if _IsGuarded() then return end
        local id = _GetNodeId()
        if not id then return end
        local PS = Gate:Get("PropertyService")
        if PS and PS.CommitFrameStrata then
          PS:CommitFrameStrata(id, v)
        elseif PS and PS.Set then
          PS:Set(id, "frameStrata", v)
        end
        if UI and UI.RefreshRight then UI:RefreshRight() end
      end
      
      local options = {
        {value = "AUTO", text = _L("ELEM_MAT_FRAME_LEVEL_AUTO")},
        {value = "BACKGROUND", text = _L("ELEM_MAT_FRAME_LEVEL_BACKGROUND")},
        {value = "LOW", text = _L("ELEM_MAT_FRAME_LEVEL_LOW")},
        {value = "MEDIUM", text = _L("ELEM_MAT_FRAME_LEVEL_MEDIUM")},
        {value = "HIGH", text = _L("ELEM_MAT_FRAME_LEVEL_HIGH")},
        {value = "DIALOG", text = _L("ELEM_MAT_FRAME_LEVEL_DIALOG")},
        {value = "FULLSCREEN", text = _L("ELEM_MAT_FRAME_LEVEL_FULLSCREEN")},
        {value = "FULLSCREEN_DIALOG", text = _L("ELEM_MAT_FRAME_LEVEL_FULLSCREEN_DIALOG")},
        {value = "TOOLTIP", text = _L("ELEM_MAT_FRAME_LEVEL_TOOLTIP")},
      }
      
      for _, opt in ipairs(options) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = opt.text
        info.value = opt.value
        info.func = function() _choose(opt.value) end
        UIDropDownMenu_AddButton(info, level)
      end
    end)
  end
  
  -- ===== X/Y Offset Sliders =====
  if controls.xSlider and controls.xNum then
    local slider = controls.xSlider
    local numBox = controls.xNum
    drawer._updatingXOffset = false
    
    local function _commitOffset(x, y)
      if _IsGuarded() then return end
      local id = _GetNodeId()
      if not id then return end

      local PS = Gate:Get("PropertyService")
      if PS and PS.CommitOffsets then
        PS:CommitOffsets(id, x, y)
      elseif PS and PS.Set then
        -- Fallback (should be rare): keep behavior reasonable
        PS:Set(id, "xOffset", x)
        PS:Set(id, "yOffset", y)
      end

      if UI and UI.RefreshRight then UI:RefreshRight() end
    end

    slider:SetScript("OnMouseUp", function(self)
      local x = self:GetValue()
      local y = controls.ySlider and controls.ySlider:GetValue() or 0
      _commitOffset(x, y)
    end)
    
    slider:SetScript("OnValueChanged", function(self)
      if drawer._updatingXOffset then return end
      drawer._updatingXOffset = true
      numBox:SetText(_FmtOffset(self:GetValue()))
      drawer._updatingXOffset = false
    end)
    
    local function _applyNumBox()
      if drawer._updatingXOffset then return end
      local v = tonumber(numBox:GetText())
      if not v then v = slider:GetValue() or 0 end
      if v < -4096 then v = -4096 elseif v > 4096 then v = 4096 end
      drawer._updatingXOffset = true
      slider:SetValue(v)
      numBox:SetText(_FmtOffset(v))
      drawer._updatingXOffset = false
      local y = controls.ySlider and controls.ySlider:GetValue() or 0
      _commitOffset(v, y)
    end
    
    numBox:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      _applyNumBox()
    end)
    numBox:SetScript("OnEditFocusLost", _applyNumBox)
  end
  
  if controls.ySlider and controls.yNum then
    local slider = controls.ySlider
    local numBox = controls.yNum
    drawer._updatingYOffset = false
    
    local function _commitOffset(x, y)
      if _IsGuarded() then return end
      local id = _GetNodeId()
      if not id then return end
      -- Use Move.CommitOffsets instead of PropertyService.Set
      -- This ensures props.xOffset/yOffset, position.x/y, and anchor.x/y are all updated
      local Move = Gate:Get("Move")
      if Move and Move.CommitOffsets then
        Move:CommitOffsets({ id = id, xOffset = x, yOffset = y })
        
        -- Force Move to update the visual position of the drag handle
        if Move.ShowForElement then
          local data = Bre.GetData and Bre.GetData(id)
          if data then
            Move:ShowForElement(id, data)
          end
        end
      end
      
      if UI and UI.RefreshRight then UI:RefreshRight() end
    end
    
    slider:SetScript("OnMouseUp", function(self)
      local y = self:GetValue()
      local x = controls.xSlider and controls.xSlider:GetValue() or 0
      _commitOffset(x, y)
    end)
    
    slider:SetScript("OnValueChanged", function(self)
      if drawer._updatingYOffset then return end
      drawer._updatingYOffset = true
      numBox:SetText(_FmtOffset(self:GetValue()))
      drawer._updatingYOffset = false
    end)
    
    local function _applyNumBox()
      if drawer._updatingYOffset then return end
      local v = tonumber(numBox:GetText())
      if not v then v = slider:GetValue() or 0 end
      if v < -4096 then v = -4096 elseif v > 4096 then v = 4096 end
      drawer._updatingYOffset = true
      slider:SetValue(v)
      numBox:SetText(_FmtOffset(v))
      drawer._updatingYOffset = false
      local x = controls.xSlider and controls.xSlider:GetValue() or 0
      _commitOffset(x, v)
    end
    
    numBox:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      _applyNumBox()
    end)
    numBox:SetScript("OnEditFocusLost", _applyNumBox)
  end
end

--[[
  Spec Format:
  {
    drawerId = "CustomMat",           -- unique drawer ID
    title = "ELEM_MAT_TITLE",         -- language key for title
    
    -- Specific content section (drawer-specific controls)
    specificContent = {
      {
        type = "label",
        text = "ELEM_MAT_TEXTURE",
        x = 18, y = -20,
      },
      {
        type = "editbox",
        id = "texturePath",
        x = 18, y = -42,
        width = "full",               -- special: span full width minus scrollbar
      },
      -- ... more controls
    },
    
    -- Attribute section configuration
    attributes = "default",            -- use built-in attribute section
    -- OR: attributes = { ... }        -- custom attribute section spec
    
    -- Position section configuration
    position = "default",              -- use built-in position section
    -- OR: position = { ... }          -- custom position section spec
  }
]]

return DT
