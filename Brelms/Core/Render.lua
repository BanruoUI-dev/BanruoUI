-- Bre/Core/Render.lua
-- Element renderer (on-screen body). Independent from Move.
-- When Move is disabled, elements should still be visible; only the mover handle disappears.

local addonName, Bre = ...
Bre = Bre or {}

local Gate = Bre.Gate
Bre.Render = Bre.Render or {}

local R = Bre.Render

local function getXY(el)
  if type(el) ~= "table" then return 0,0 end
  local p = el.position or {}
  local x = tonumber(p.x) or 0
  local y = tonumber(p.y) or 0
  return x,y
end

local function normPath(el)
  -- StopMotion: prefer explicit stopmotion.path (do not rely on region.texture)
  local sm = type(el.stopmotion) == "table" and el.stopmotion or nil
  if sm and type(sm.path) == "string" and sm.path:gsub("^%s+",""):gsub("%s+$","") ~= "" then
    local p = sm.path:gsub("^%s+",""):gsub("%s+$","")
    p = p:gsub("/", "\\")
    return p
  end
  local region = type(el.region) == "table" and el.region or {}
  local p = region.texture or region.path or region.file or ""
  if type(p) ~= "string" then return "" end
  p = p:gsub("^%s+", ""):gsub("%s+$", "")
  if p == "" then return "" end
  p = p:gsub("/", "\\")
  return p
end

function R:EnsureFrame()
  if self._frame then return self._frame end

  -- ========================================
  -- v2.16.0: StatusBar + MaskTexture (WoW 12.0 compatible)
  -- ========================================
  local f = CreateFrame("Frame", "BrelmsElementBody", UIParent)
  f:SetSize(72,72)
  f:SetFrameStrata("DIALOG")
  f:SetFrameLevel(9998)
  f:EnableMouse(false)
  f:Hide()

  -- Single texture for custom materials (non-progress)
  local tex = f:CreateTexture(nil, "ARTWORK")
  tex:SetAllPoints()
  tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
  f._tex = tex

  -- StatusBar for progress (WoW 12.0 secret value compatible)
  local statusBar = CreateFrame("StatusBar", nil, f)
  statusBar:SetAllPoints(f)  -- Follow parent frame size
  statusBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
  statusBar:SetMinMaxValues(0, 100)
  statusBar:SetValue(60)
  statusBar:SetOrientation("VERTICAL")
  statusBar:Hide()
  f._statusBar = statusBar
  
  -- Background texture for StatusBar
  local bgTex = statusBar:CreateTexture(nil, "BACKGROUND")
  bgTex:SetAllPoints(statusBar)  -- Fill entire statusBar
  bgTex:SetTexture("Interface\\Buttons\\WHITE8X8")
  bgTex:SetVertexColor(0.3, 0.3, 0.3, 1)
  bgTex:Hide()
  f._bgTex = bgTex
  
  -- PlayerModel for 3D model preview (v2.18.78)
  local pm = CreateFrame("PlayerModel", nil, f)
  pm:SetAllPoints(f)
  pm:EnableMouse(false)
  pm:SetFrameStrata(f:GetFrameStrata())
  pm:SetFrameLevel(f:GetFrameLevel() + 1)
  pm:SetKeepModelOnHide(true)
  pm:Hide()
  f._playerModel = pm
  
  -- Event frame for unit-model refresh (target/focus)
  local ef = CreateFrame("Frame", nil, f)
  ef:Hide()
  f._modelEventFrame = ef
  
  -- Mask texture (for circular health bar)
  -- Will be attached to statusBar's fill texture
  f._maskTex = nil  -- Created on-demand in ProgressMat

  -- ========================================
  -- DEPRECATED (v2.15.x): Old TextureCoords system
  -- Kept for reference, not used in v2.16.0+
  -- ========================================
  --[[
  f._fgTex = {}
  for i = 1, 3 do
    local fgTex = f:CreateTexture(nil, "ARTWORK", nil, 1)
    fgTex:SetAllPoints()
    fgTex:SetBlendMode("BLEND")
    fgTex:SetColorTexture(0, 0, 0, 0)
    fgTex:SetSnapToPixelGrid(false)
    fgTex:SetTexelSnappingBias(0)
    f._fgTex[i] = fgTex
  end
  --]]

  self._frame = f
  return f
end

function R:Hide()
  if self._frame then self._frame:Hide() end
  self._activeElementId = nil
end

function R:_ModelNormalizeUnit(u)
  u = tostring(u or "player")
  if u ~= "player" and u ~= "target" and u ~= "focus" then u = "player" end
  return u
end

function R:_DisableModelEvents(f)
  if not f or not f._modelEventFrame then return end
  local ef = f._modelEventFrame
  ef:UnregisterAllEvents()
  ef:SetScript("OnEvent", nil)
  ef:Hide()
  self._modelEventUnit = nil
end

function R:_EnableModelEvents(f, unit)
  if not f or not f._modelEventFrame then return end
  unit = self:_ModelNormalizeUnit(unit)
  local ef = f._modelEventFrame

  ef:UnregisterAllEvents()
  if unit == "target" then
    ef:RegisterEvent("PLAYER_TARGET_CHANGED")
    ef:RegisterEvent("UNIT_MODEL_CHANGED")
  elseif unit == "focus" then
    ef:RegisterEvent("PLAYER_FOCUS_CHANGED")
    ef:RegisterEvent("UNIT_MODEL_CHANGED")
  else
    self:_DisableModelEvents(f)
    return
  end

  self._modelEventUnit = unit
  ef:SetScript("OnEvent", function(_, event, arg1)
    if event == "UNIT_MODEL_CHANGED" then
      if arg1 ~= unit then return end
    end
    local id = self._activeElementId
    if not id then return end
    local GetData = Bre.GetData
    if type(GetData) ~= "function" then return end
    local el = GetData(id)
    if type(el) ~= "table" then return end
    if el.regionType ~= "model" then return end
    if tostring(el.modelMode or "unit") ~= "unit" then return end
    if self:_ModelNormalizeUnit(el.modelUnit) ~= unit then return end
    self:_ScheduleApplyModel(f, id, el)
  end)
  ef:Show()
end

function R:_ApplyModelNow(f, id, el)
  if not (f and f._playerModel) then return end
  local pm = f._playerModel
  if type(el) ~= "table" then return end

  pm:Show()
  pm:SetKeepModelOnHide(true)
  if pm.ClearModel then pcall(pm.ClearModel, pm) end

  local mode = tostring(el.modelMode or "unit")
  if mode ~= "unit" and mode ~= "file" then mode = "unit" end

  if mode == "unit" then
    local unit = self:_ModelNormalizeUnit(el.modelUnit)
    pcall(pm.SetUnit, pm, unit)
  else
    local fid = tonumber(el.modelFileID)
    if fid and fid > 0 then
      if pm.SetModelByFileID then
        pcall(pm.SetModelByFileID, pm, fid)
      elseif pm.SetModel then
        pcall(pm.SetModel, pm, fid)
      end
    end
  end

  -- Apply facing rotation (v2.18.84)
  local facing = tonumber(el.facing) or 0
  local radians = facing * math.pi / 180
  if pm.SetFacing then
    pcall(pm.SetFacing, pm, radians)
  end
end

function R:_ScheduleApplyModel(f, id, el)
  self._modelApplyToken = (tonumber(self._modelApplyToken) or 0) + 1
  local token = self._modelApplyToken

  C_Timer.After(0, function()
    if token ~= self._modelApplyToken then return end
    if self._activeElementId ~= id then return end
    self:_ApplyModelNow(f, id, el)
  end)
end

function R:ShowForElement(id, el)
  local f = self:EnsureFrame()
  self._activeElementId = id

  if type(el) ~= "table" then
    f:Hide()
    return
  end
  
  -- Debug output (v2.15.9)
  if Bre.DEBUG then
    print("[Render] ShowForElement called:")
    print("  id: " .. tostring(id))
    print("  regionType: " .. tostring(el.regionType))
    if el.regionType == "progress" then
      print("  foreground: " .. tostring(el.foreground))
    end
  end

  -- size
  local w = (el.size and tonumber(el.size.width)) or 72
  local h = (el.size and tonumber(el.size.height)) or 72
  local scale = tonumber(el.scale) or 1
  if scale <= 0 then scale = 1 end
  w = w * scale
  h = h * scale
  f:SetSize(w, h)

  -- position (offset from screen center)
  local x,y = getXY(el)
  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "CENTER", x, y)

  
  -- apply texture/progress/model preview + params
  local isProgress = (el.regionType == "progress")
  local isModel = (el.regionType == "model")
  local tex = f._tex
  local statusBar = f._statusBar
  local bgTex = f._bgTex
  local pm = f._playerModel

  if isProgress then
    -- ========================================
    -- v2.16.0: StatusBar + Secret Value
    -- ========================================
    if tex then tex:Hide() end
    if pm then pm:Hide() end
    self:_DisableModelEvents(f)
    
    -- Use ProgressMat module to setup StatusBar (符合宪法：通过Gate访问L2模块)
    if Gate and Gate.Get then
      local PM = Gate:Get("ProgressMat")
      if PM and PM.SetupStatusBar then
        -- Get health data from ProgressData
        local PD = Gate:Get("ProgressData")
        local cur, max = 60, 100  -- Fallback values
        
        if PD and PD.GetHealthValues then
          local progressUnit = el.progressUnit or "player"
          -- Get secret values (UnitHealth/UnitHealthMax)
          cur, max = PD:GetHealthValues(progressUnit)
          
          -- Auto-subscribe for real-time updates
          if PD.Subscribe and id then
            pcall(PD.Subscribe, PD, id, "Health", progressUnit)
          end
        end
        
        -- Setup StatusBar with secret values
        pcall(PM.SetupStatusBar, PM, statusBar, bgTex, el, cur, max)
      else
        -- Fallback: show white statusbar
        statusBar:Show()
        statusBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        statusBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)
        statusBar:SetMinMaxValues(0, 100)
        statusBar:SetValue(60)
      end
    end
    
    -- ========================================
    -- DEPRECATED (v2.15.x): Old texture array system
    -- ========================================
    --[[
    for i = 1, 3 do
      if fgTexArray[i] then fgTexArray[i]:Show() end
    end
    
    local PM = Gate:Get("ProgressMat")
    if PM and PM.ApplyToTextures then
      local progress = tonumber(el.progressValue) or 0.6
      local PD = Gate:Get("ProgressData")
      if PD and PD.GetValue then
        local progressType = "Health"
        local progressUnit = el.progressUnit or "player"
        if PD.Subscribe and id then
          pcall(PD.Subscribe, PD, id, progressType, progressUnit)
        end
        local realValue = PD:GetValue(progressType, progressUnit)
        if realValue ~= nil then
          progress = realValue
        end
      end
      pcall(PM.ApplyToTextures, PM, fgTexArray, bgTex, el, progress)
    end
    --]]
  elseif isModel then
    -- 3D Model: hide textures/statusbars, show PlayerModel
    if tex then tex:Hide() end
    if statusBar then statusBar:Hide() end
    if bgTex then bgTex:Hide() end

    if pm then
      -- schedule apply after one frame for stability
      self:_ScheduleApplyModel(f, id, el)
    end

    -- Event-driven refresh for target/focus in unit mode
    if tostring(el.modelMode or "unit") == "unit" then
      self:_EnableModelEvents(f, el.modelUnit)
    else
      self:_DisableModelEvents(f)
    end

  else
    -- Custom material: hide progress, show single texture
    if statusBar then statusBar:Hide() end
    if pm then pm:Hide() end
    self:_DisableModelEvents(f)
    if bgTex then bgTex:Hide() end
    if tex then tex:Show() end

    local p = normPath(el)
    local ok = true
    if p ~= "" then
      ok = pcall(tex.SetTexture, tex, p)
    else
      ok = false
    end
    if not ok then
      tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    -- alpha
    if tex.SetAlpha then
      tex:SetAlpha(tonumber(el.alpha) or 1)
    end

    -- rotation (degrees)
    if tex.SetRotation then
      local deg = tonumber(el.rotation) or 0
      tex:SetRotation(deg * math.pi / 180)
    end
  end
f:Show()
end

-- Called by Move overlay while dragging, to keep rendered element in sync with mover frame center.
function R:SetCenterByMover(moverFrame)
  if not moverFrame or not moverFrame.GetCenter then return end
  local f = self._frame
  if not f or not f.IsShown or not f:IsShown() then return end

  local cx, cy = moverFrame:GetCenter()
  local ux, uy = UIParent:GetCenter()
  if not cx or not cy or not ux or not uy then return end

  local x = cx - ux
  local y = cy - uy
  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "CENTER", x, y)
end
