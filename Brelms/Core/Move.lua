-- Bre/Core/Move.lua
-- Move system base (core). v2.15.50
-- Provides a minimal runtime "mover body" for selected element so user can drag on screen.
-- Does not change existing editor logic unless UI calls these APIs.
-- Changes v2.15.50: Support 3 foreground textures for circular progress bars

local addonName, Bre = ...
Bre = Bre or {}

local Gate = Bre.Gate
local function _UI() return Gate and Gate.Get and Gate:Get('UI') end
local function _API() return Gate:Get('API_Data') end
local function _TreeIndex() return Gate:Get('TreeIndex') end
local function GetData(id)
  local API = _API()
  if API and API.GetData then return API:GetData(id) end
  if Bre.GetData then return Bre.GetData(id) end
  return nil
end

local function SetData(id, data)
  local API = _API()
  if API and API.SetData then return API:SetData(id, data) end
  if Bre.SetData then return Bre.SetData(id, data) end
  return nil
end

Bre.Move = Bre.Move or {}

local M = Bre.Move

-- ------------------------------------------------------------
-- Output Actions: Rotate (runtime continuous) - minimal always-rotate driver
-- NOTE: This is runtime-only visual update. No DB writes. No commits.
-- Data source: el.actions.rotate (written via PropertyService).
-- ------------------------------------------------------------
M._rotating = M._rotating or nil -- [id] -> { angleDeg=number, speedDegPerSec=number, dir=1|-1, lastT=number }

local function _getRotateTex(frame)
  if not frame then return nil end
  if frame._tex then return frame._tex end
  if frame._statusBar and frame._statusBar.GetStatusBarTexture then
    return frame._statusBar:GetStatusBarTexture()
  end
  return nil
end

local function _dirSign(dir)
  if dir == -1 or dir == "-1" then return -1 end
  if type(dir) == "string" then
    local s = dir:upper()
    if s == "CCW" or s == "LEFT" or s == "COUNTER" or s == "COUNTERCLOCKWISE" then return -1 end
  end
  return 1
end

local function _ensureRotateDriver(self)
  if self._rotateDriver then return end
  local d = CreateFrame("Frame", nil, UIParent)
  d:Hide()
  d._acc = 0
  d:SetScript("OnUpdate", function(_, elapsed)
    if not M._rotating then d:Hide() return end
    -- Use GetTime() to make dt stable across frame spikes.
    local now = GetTime and GetTime() or 0
    for id, st in pairs(M._rotating) do
      local frame = (M._regions and M._regions[id]) or nil
      local tex = _getRotateTex(frame)
      if not (frame and tex and tex.SetRotation) then
        M._rotating[id] = nil
      else
        local lastT = st.lastT or now
        local dt = now - lastT
        if dt < 0 then dt = 0 end
        st.lastT = now
        local spd = tonumber(st.speedDegPerSec) or 0
        local ang = tonumber(st.angleDeg) or 0
        ang = ang + (spd * dt * (st.dir or 1))
        -- keep bounded to avoid float drift
        if ang > 360000 or ang < -360000 then
          ang = ang % 360
        end
        st.angleDeg = ang
        tex:SetRotation((ang or 0) * math.pi / 180)
      end
    end
    -- stop if emptied
    if not next(M._rotating) then
      M._rotating = nil
      d:Hide()
    end
  end)
  self._rotateDriver = d
end

local function _syncRotateRuntime(self, id, el)
  if type(id) ~= "string" then return end
  local a = (type(el) == "table" and type(el.actions) == "table" and type(el.actions.rotate) == "table") and el.actions.rotate or nil
  local enabled = (a and a.enabled) and true or false
  if not enabled then
    if self._rotating and self._rotating[id] then
      self._rotating[id] = nil
      if self._rotating and (not next(self._rotating)) then self._rotating = nil end
    end
    return
  end

  _ensureRotateDriver(self)

  self._rotating = self._rotating or {}
  local st = self._rotating[id] or {}
  st.speedDegPerSec = tonumber(a.speed) or 90
  st.dir = _dirSign(a.dir)
  -- Use angle as initial / current if first time
  if st.angleDeg == nil then
    st.angleDeg = tonumber(a.angle) or 0
  end
  st.lastT = GetTime and GetTime() or 0
  self._rotating[id] = st

  if self._rotateDriver then self._rotateDriver:Show() end
end


-- ------------------------------------------------------------
-- Editor-facing commits (via Gate)
-- ------------------------------------------------------------

-- Commit anchor target intent to node.props.anchorTarget.
-- This is a STRUCTURE-LEVEL change request and must be called through Gate:Get('Move').
-- payload: { id = <nodeId>, value = 'SCREEN_CENTER' | 'SELECTED_NODE' }
function M:CommitAnchorTarget(payload)
  if type(payload) ~= "table" then return end
  local id = payload.id
  local v = payload.value
  if type(id) ~= "string" or id == "" then return end
  if v ~= "SCREEN_CENTER" and v ~= "SELECTED_NODE" then return end

  local data = GetData(id)
  if type(data) ~= "table" then return end

  data.props = type(data.props) == "table" and data.props or {}
  if data.props.anchorTarget == v then return end
  data.props.anchorTarget = v

  -- bookkeeping
  data.meta = type(data.meta) == "table" and data.meta or {}
  if type(time) == "function" then
    data.meta.updatedAt = time()
  end

  SetData(id, data)

  -- Refresh runtime overlays (no side effects when Move is stubbed/off)
  if self.Refresh then
    pcall(function() self:Refresh(id) end)
  end
end


-- Commit XY offsets (align-to-screen-center intent).
-- payload: { id = <nodeId>, xOffset = number, yOffset = number }
-- NOTE: For runtime compatibility, we mirror offsets into el.position.{x,y} (and anchor.{x,y}).
function M:CommitOffsets(payload)
  if type(payload) ~= "table" then return end
  local id = payload.id
  if type(id) ~= "string" or id == "" then return end

  local xo = tonumber(payload.xOffset)
  local yo = tonumber(payload.yOffset)
  if not xo then xo = 0 end
  if not yo then yo = 0 end
  xo = math.floor(xo + 0.5)
  yo = math.floor(yo + 0.5)
  if xo < -4096 then xo = -4096 end
  if xo > 4096 then xo = 4096 end
  if yo < -4096 then yo = -4096 end
  if yo > 4096 then yo = 4096 end

  local data = GetData(id)
  if type(data) ~= "table" then return end

  data.props = type(data.props) == "table" and data.props or {}
  local changed = false
  if data.props.xOffset ~= xo then data.props.xOffset = xo; changed = true end
  if data.props.yOffset ~= yo then data.props.yOffset = yo; changed = true end
  if not changed then return end

  -- mirror to runtime position (CENTER relative to UIParent)
  data.position = type(data.position) == "table" and data.position or {}
  data.position.x, data.position.y = xo, yo

  data.anchor = type(data.anchor) == "table" and data.anchor or {}
  data.anchor.x, data.anchor.y = xo, yo

  -- bookkeeping
  data.meta = type(data.meta) == "table" and data.meta or {}
  if type(time) == "function" then
    data.meta.updatedAt = time()
  end

  SetData(id, data)

  if self.Refresh then
    pcall(function() self:Refresh(id) end)
  end
end


-- Commit frame level intent to node.props.frameLevelMode.
-- STRUCTURE-LEVEL change request routed through Gate:Get('Move').
-- payload: { id = <nodeId>, value = 'AUTO' | 'ABOVE_PARENT' | 'BELOW_PARENT' }
function M:CommitFrameLevelMode(payload)
  if type(payload) ~= "table" then return end
  local id = payload.id
  local v = payload.value
  if type(id) ~= "string" or id == "" then return end
  if v ~= "AUTO" and v ~= "ABOVE_PARENT" and v ~= "BELOW_PARENT" then return end

  local data = GetData(id)
  if type(data) ~= "table" then return end

  data.props = type(data.props) == "table" and data.props or {}
  if data.props.frameLevelMode == v then return end
  data.props.frameLevelMode = v

  data.meta = type(data.meta) == "table" and data.meta or {}
  if type(time) == "function" then
    data.meta.updatedAt = time()
  end

  SetData(id, data)

  if self.Refresh then
    pcall(function() self:Refresh(id) end)
  end
end

-- Commit frame strata intent to node.props.frameStrata.
-- STRUCTURE-LEVEL change request routed through Gate:Get('Move').
-- payload: { id = <nodeId>, value = 'AUTO' | 'BACKGROUND' | 'LOW' | 'MEDIUM' | 'HIGH' | 'DIALOG' | 'FULLSCREEN' | 'FULLSCREEN_DIALOG' | 'TOOLTIP' }
function M:CommitFrameStrata(payload)
  if type(payload) ~= "table" then return end
  local id = payload.id
  local v = payload.value
  if type(id) ~= "string" or id == "" then return end
  if v ~= "AUTO" and v ~= "BACKGROUND" and v ~= "LOW" and v ~= "MEDIUM" and v ~= "HIGH" and v ~= "DIALOG" and v ~= "FULLSCREEN" and v ~= "FULLSCREEN_DIALOG" and v ~= "TOOLTIP" then
    return
  end

  local data = GetData(id)
  if type(data) ~= "table" then return end

  data.props = type(data.props) == "table" and data.props or {}
  if data.props.frameStrata == v then return end
  data.props.frameStrata = v

  data.meta = type(data.meta) == "table" and data.meta or {}
  if type(time) == "function" then
    data.meta.updatedAt = time()
  end

  SetData(id, data)

  if self.Refresh then
    pcall(function() self:Refresh(id) end)
  end
end


-- Commit load.never (Load/Unload) to node.load.never.
-- payload: { id = <nodeId>, value = true|false|nil }
--   true  => never load (hard-unloaded; appears in Unloaded section)
--   nil   => clear never (loadable again)
--   false => treated as clear (legacy)
function M:CommitLoadNever(payload)
  if type(payload) ~= "table" then return end
  local id = payload.id
  local v = payload.value
  if type(id) ~= "string" or id == "" then return end
  if v ~= nil and type(v) ~= "boolean" then return end

  local data = GetData(id)
  if type(data) ~= "table" then return end

  data.load = type(data.load) == "table" and data.load or {}

  -- Legacy: value=false is equivalent to clearing never.
  if v == false then v = nil end

  if data.load.never == v then return end
  data.load.never = v

  -- Cleanup empty load table to keep savedvars tidy.
  if data.load.never == nil and next(data.load) == nil then
    data.load = nil
  end

  data.meta = type(data.meta) == "table" and data.meta or {}
  if type(time) == "function" then
    data.meta.updatedAt = time()
  end

  SetData(id, data)

  -- IMPORTANT: load.never cascades through the parent chain (hard-unloaded).
  -- When toggling load/unload on a group/container, descendants must refresh immediately
  -- so runtime visibility updates without requiring /reload.
  if self.RefreshSubtree then
    pcall(function() self:RefreshSubtree(id, nil, true) end)
  elseif self.Refresh then
    pcall(function() self:Refresh(id) end)
  end
end

local function normPos(el)
  el.position = el.position or {}
  if type(el.position.x) ~= "number" then el.position.x = 0 end
  if type(el.position.y) ~= "number" then el.position.y = 0 end
end

local function normPath(el)
  if not el or type(el) ~= "table" then return "" end
  -- StopMotion: prefer explicit stopmotion.path
  if type(el.stopmotion) == "table" and type(el.stopmotion.path) == "string" then
    local sp = el.stopmotion.path:gsub("^%s+",""):gsub("%s+$","")
    if sp ~= "" then
      sp = sp:gsub("/", "\\")
      return sp
    end
  end
  local p = (el.material and el.material.path) or (el.region and el.region.texture)
  if type(p) ~= "string" then return "" end
  p = p:gsub("/", "\\")
  return p
end

-- StopMotion slicing: compute texcoord for a given frame index (1-based).
-- Returns l,r,t,b (all numbers) or nil if slicing is not active.
local function _getStopMotionTexCoord(el, frameIndex)
  if type(el) ~= "table" then return nil end
  local sm = el.stopmotion
  if type(sm) ~= "table" then return nil end

  local rows = tonumber(sm.rows) or 0
  local cols = tonumber(sm.cols) or 0
  local frames = tonumber(sm.frames) or 0
  local useAdvanced = sm.useAdvanced and true or false
  local fileW = tonumber(sm.fileW) or 0
  local fileH = tonumber(sm.fileH) or 0
  local frameW = tonumber(sm.frameW) or 0
  local frameH = tonumber(sm.frameH) or 0

  -- If advanced slicing is enabled, allow deriving rows/cols from pixel sizes even when rows/cols are 0.
  if useAdvanced and fileW > 0 and fileH > 0 and frameW > 0 and frameH > 0 then
    if cols <= 0 then cols = math.floor(fileW / frameW) end
    if rows <= 0 then rows = math.floor(fileH / frameH) end
    if cols < 0 then cols = 0 end
    if rows < 0 then rows = 0 end
    local maxF = rows * cols
    if maxF > 0 then
      if frames <= 0 then
        frames = maxF
      elseif frames > maxF then
        frames = maxF
      end
    end
  end

  if frames <= 0 then return nil end

  -- Advanced pixel slicing (fileW/fileH/frameW/frameH) is used only when stopmotion.useAdvanced is true.
  local fileW = tonumber(sm.fileW) or 0
  local fileH = tonumber(sm.fileH) or 0
  local frameW = tonumber(sm.frameW) or 0
  local frameH = tonumber(sm.frameH) or 0

  local wFrac, hFrac
  if sm.useAdvanced and fileW > 0 and fileH > 0 and frameW > 0 and frameH > 0 then
    local pCols = math.floor(fileW / frameW)
    local pRows = math.floor(fileH / frameH)
    if pCols > 0 and pRows > 0 then
      cols = pCols
      rows = pRows
      wFrac = frameW / fileW
      hFrac = frameH / fileH
    end
  end

  if rows <= 0 or cols <= 0 then return nil end
  if not wFrac then wFrac = 1 / cols end
  if not hFrac then hFrac = 1 / rows end

  local maxFrames = rows * cols
  if frames > maxFrames then frames = maxFrames end

  local i = tonumber(frameIndex) or 1
  i = math.floor(i)
  if i < 1 then i = 1 end
  if i > frames then i = frames end

  local k = i - 1
  local r = math.floor(k / cols)
  local c = k % cols
  if r < 0 or c < 0 or r >= rows or c >= cols then return nil end

  local l = c * wFrac
  local rr = (c + 1) * wFrac
  local t = r * hFrac
  local b = (r + 1) * hFrac
  return l, rr, t, b, frames
end


-- StopMotion runtime player: drive per-element frame index and update texcoord.
local function _stopMotionCancel(f)
  if not f then return end
  if f._smTicker and f._smTicker.Cancel then
    pcall(f._smTicker.Cancel, f._smTicker)
  end
  f._smTicker = nil
  f._smCfg = nil
  f._smFrame = nil
  f._smDir = nil
end

local function _stopMotionCfgEqual(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  for _, k in ipairs({ "rows","cols","frames","useAdvanced","fileW","fileH","frameW","frameH","fps","mode","inverse","path","mirror" }) do
    if a[k] ~= b[k] then return false end
  end
  return true
end

local function _stopMotionEnsureTicker(self, id, el, f)
  if not (self and id and type(el) == "table" and f) then return end
  local sm = type(el.stopmotion) == "table" and el.stopmotion or nil
  if not sm then
    _stopMotionCancel(f)
    return
  end

  local useAdvanced = sm.useAdvanced and true or false

  local rows = tonumber(sm.rows) or 0
  local cols = tonumber(sm.cols) or 0
  local frames = tonumber(sm.frames) or 0

  -- Advanced slicing can be the true source: derive rows/cols (and default frames)
  local fileW = tonumber(sm.fileW) or 0
  local fileH = tonumber(sm.fileH) or 0
  local frameW = tonumber(sm.frameW) or 0
  local frameH = tonumber(sm.frameH) or 0
  if useAdvanced and fileW > 0 and fileH > 0 and frameW > 0 and frameH > 0 then
    cols = math.floor(fileW / frameW)
    rows = math.floor(fileH / frameH)
    if cols < 0 then cols = 0 end
    if rows < 0 then rows = 0 end
    if frames <= 0 and rows > 0 and cols > 0 then
      frames = rows * cols
    end
  end

  local fps = tonumber(sm.fps) or 0
  local mode = tostring(sm.mode or "loop")
  local inverse = sm.inverse and true or false
  local path = (type(sm.path) == "string" and sm.path) or ""
  local region = type(el.region) == "table" and el.region or {}
  local mirror = region.mirror and true or false

  if rows <= 0 or cols <= 0 or frames <= 0 or fps <= 0 then
    _stopMotionCancel(f)
    return
  end

  fps = math.floor(fps)
  if fps < 1 then fps = 1 end
  if fps > 60 then fps = 60 end

  if mode ~= "loop" and mode ~= "once" and mode ~= "bounce" then
    mode = "loop"
  end

  local cfg = { rows = rows, cols = cols, frames = frames, useAdvanced = useAdvanced, fileW = fileW, fileH = fileH, frameW = frameW, frameH = frameH, fps = fps, mode = mode, inverse = inverse, path = path, mirror = mirror }

  local needReset = false
  if not f._smCfg or not _stopMotionCfgEqual(f._smCfg, cfg) then
    needReset = true
  end
  f._smCfg = cfg

  -- Init frame + direction
  if needReset or type(f._smFrame) ~= "number" then
    if inverse then
      f._smFrame = frames
      f._smDir = -1
    else
      f._smFrame = 1
      f._smDir = 1
    end
  end

  -- Rebuild ticker if needed
  local interval = 1 / fps
  if interval < 0.016 then interval = 0.016 end

  if f._smTicker and f._smTicker._brelmsInterval and math.abs(f._smTicker._brelmsInterval - interval) < 0.0001 then
    return
  end

  _stopMotionCancel(f)

  if C_Timer and C_Timer.NewTicker then
    local ticker = C_Timer.NewTicker(interval, function()
      -- Element may be deleted or hidden; bail safely.
      -- NOTE: the parent frame may be hidden even while its texture is visible (depending on the render pipeline),
      -- so we gate on the actual texture visibility instead of f:IsShown().
      local tex0 = f and f._tex
      if not (f and tex0) then
        _stopMotionCancel(f)
        return
      end
      if tex0.IsVisible and not tex0:IsVisible() then
        _stopMotionCancel(f)
        return
      elseif tex0.IsShown and not tex0:IsShown() then
        _stopMotionCancel(f)
        return
      end
      local cur = GetData and GetData(id) or el
      if type(cur) ~= "table" then
        _stopMotionCancel(f)
        return
      end

      -- Re-ensure ticker config if changed via live edit.
      _stopMotionEnsureTicker(self, id, cur, f)
      local cfg2 = f._smCfg
      if not cfg2 then return end

      local total = tonumber(cfg2.frames) or 0
      if total <= 1 then return end

      local frame = tonumber(f._smFrame) or 1
      local dir = tonumber(f._smDir) or 1

      -- advance by 1 frame per tick (fps-driven interval)
      frame = frame + dir

      if cfg2.mode == "loop" then
        if frame > total then frame = 1 end
        if frame < 1 then frame = total end
      elseif cfg2.mode == "once" then
        if frame > total then frame = total end
        if frame < 1 then frame = 1 end
        -- stop when reached end
        if (dir > 0 and frame >= total) or (dir < 0 and frame <= 1) then
          f._smFrame = frame
          _stopMotionCancel(f)
        end
      elseif cfg2.mode == "bounce" then
        if frame > total then
          frame = total - 1
          dir = -1
        elseif frame < 1 then
          frame = 2
          dir = 1
        end
      end

      f._smFrame = frame
      f._smDir = dir

      -- Apply texcoord (and custom material if enabled)
      local tex = f._tex
      if not tex then return end
      local l,r,t,b = _getStopMotionTexCoord(cur, frame)
      if not l then return end

      local Gate = Bre.Gate
      local CM = (Gate and Gate.Get) and Gate:Get("CustomMat") or nil
      if CM and CM.ApplyToTexture then
        local rr = {}
        local rg = type(cur.region) == "table" and cur.region or {}
        for k, v in pairs(rg) do rr[k] = v end
        rr.texture = normPath(cur)
        rr.stopmotionTexCoord = { l, r, t, b }
        pcall(CM.ApplyToTexture, CM, tex, rr, tonumber(cur.alpha) or 1)
      end

      -- Always apply texcoord on the live texture so playback is never blocked by CustomMat caching.
      if tex.SetTexCoord then
        if cfg2.mirror then
          tex:SetTexCoord(r, l, t, b)
        else
          tex:SetTexCoord(l, r, t, b)
        end
      end
    end)
    ticker._brelmsInterval = interval
    f._smTicker = ticker
  end
end

-- Small center marker for alignment: a tiny circle + a dot.
-- Used by both the single-element mover and the group selection box.
local function EnsureCenterMark(frame, r, g, b, a)
  if not frame then return end
  a = a or 1

  -- If a previous version created a circle texture, hide it and keep only the dot.
  if frame._centerMark then
    local m = frame._centerMark
    if m.circle then
      m.circle:Hide()
      m.circle = nil
    end
    if m.dot then
      m.dot:SetVertexColor(r, g, b, a)
      m.dot:Show()
      return
    end
  end

  local dot = frame:CreateTexture(nil, "OVERLAY")
  dot:SetPoint("CENTER", frame, "CENTER", 0, 0)
  dot:SetSize(2, 2)
  dot:SetTexture("Interface/Buttons/WHITE8x8")
  dot:SetVertexColor(r, g, b, a)

  frame._centerMark = { dot = dot }
end


-- ------------------------------------------------------------
-- Runtime bodies (BrA-style): core-owned, restored on login/reload
-- ------------------------------------------------------------

local function getXY(el)
  -- Backward compat:
  -- - prefer el.position.{x,y} if present
  -- - else use schema anchor.{x,y}
  if el and type(el.position) == "table" then
    if type(el.position.x) == "number" and type(el.position.y) == "number" then
      return el.position.x, el.position.y
    end
  end
  if el and type(el.anchor) == "table" then
    return tonumber(el.anchor.x) or 0, tonumber(el.anchor.y) or 0
  end
  return 0, 0
end

local function setXY(el, x, y)
  x, y = tonumber(x) or 0, tonumber(y) or 0
  el.position = el.position or {}
  el.position.x, el.position.y = x, y
  el.anchor = el.anchor or {}
  el.anchor.x, el.anchor.y = x, y
end

function M:EnsureRuntimeRoot()
  if self._runtimeRoot then return self._runtimeRoot end

  local root = CreateFrame("Frame", "BrelmsFrame", UIParent)
  root:SetAllPoints(UIParent)
  root:SetFrameStrata("MEDIUM")
  root:SetFrameLevel(1)
  root:Show()

  self._runtimeRoot = root
  self._regions = self._regions or {}
  return root
end

function M:EnsureRegion(id)
  if type(id) ~= "string" then return nil end
  self._regions = self._regions or {}
  if self._regions[id] then return self._regions[id] end

  local root = self:EnsureRuntimeRoot()
  local safeId = tostring(id):gsub("[^%w_]", "_")
  local f = CreateFrame("Frame", "BrelmsRegion_"..safeId, root)
  f:SetSize(64, 64)
  f:SetFrameStrata("MEDIUM")
  f:SetFrameLevel(2)
  -- NOTE (Layering/Strata Step1):
  -- This frame `f` is the *actual* runtime carrier for the element's visual.
  -- All future per-element frame strata application must target THIS frame,
  -- and must be performed in ApplyElement/Refresh (not just saved in DB).
  f:Show()

  -- Check element kind for specialized runtime region body
  local data = GetData and GetData(id)
  local regionType = (type(data) == "table" and tostring(data.regionType)) or ""
  local isProgress = (regionType == "progress")
  local isModel = (regionType == "model")
  
  if isProgress then
    -- v2.16.4: StatusBar + independent foreground texture + mask (WA style)
    local statusBar = CreateFrame("StatusBar", nil, f)
    statusBar:SetAllPoints(f)
    statusBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    statusBar:GetStatusBarTexture():SetAlpha(0)  -- Hide native statusbar texture
    statusBar:SetMinMaxValues(0, 100)
    statusBar:SetValue(60)
    statusBar:SetOrientation("VERTICAL")
    f._statusBar = statusBar
    
    -- Background texture
    local bgTex = statusBar:CreateTexture(nil, "BACKGROUND")
    bgTex:SetAllPoints(statusBar)
    bgTex:SetTexture("Interface\\Buttons\\WHITE8X8")
    bgTex:SetVertexColor(0.3, 0.3, 0.3, 1)
    bgTex:Hide()
    f._bgTex = bgTex
    -- Mask texture (will be set up by ProgressMat)
    f._fgMask = nil  -- Created on-demand when mask path provided
    
    
    -- DEPRECATED v2.15.x: Old texture array system
    --[[
    local bgTex = f:CreateTexture(nil, "BACKGROUND")
    bgTex:SetAllPoints()
    bgTex:SetColorTexture(0, 0, 0, 0)
    f._bgTex = bgTex
    
    --]]
  elseif isModel then
    -- Model element: PlayerModel body
    local pm = CreateFrame("PlayerModel", nil, f)
    pm:SetAllPoints(f)
    pm:SetFrameLevel(3)
    if pm.SetKeepModelOnHide then
      pm:SetKeepModelOnHide(true)
    end
    pm:Show()
    f._model = pm
  else
    -- Regular element: single texture
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    f._tex = tex
  end

  self._regions[id] = f
  return f
end

-- v2.11.9: read-only access for TargetResolver
-- MUST NOT create frames or cause any movement.
function M:GetRuntimeRegion(id)
  if type(id) ~= "string" then return nil end
  return (self._regions and self._regions[id]) or nil
end


-- ------------------------------------------------------------
-- Public region lifecycle APIs (C-step1)
-- ------------------------------------------------------------
-- These APIs are the ONLY supported way for other modules (including L1 services)
-- to request region rebuild/refresh. Do NOT access private tables like `_regions`.

-- Invalidate a runtime region frame so it will be rebuilt on next EnsureRegion/Refresh.
-- Safe to call even if region does not exist.
function M:InvalidateRegion(id)
  if type(id) ~= "string" or id == "" then return end
  if not (self and self._regions) then return end
  local r = self._regions[id]
  if not r then return end
  -- Best-effort teardown; never allow errors to propagate.
  pcall(function()
    if type(r.Hide) == "function" then r:Hide() end
    if type(r.SetParent) == "function" then r:SetParent(nil) end
  end)
  self._regions[id] = nil
end

-- Rebuild a runtime region frame immediately and refresh its visuals.
-- This is a best-effort helper for cases where a structural/visual change requires
-- tearing down old frame state (e.g., switching between progress vs non-progress).
function M:RebuildRegion(id)
  if type(id) ~= "string" or id == "" then return end
  pcall(function()
    self:InvalidateRegion(id)
    self:EnsureRegion(id)
    if self.Refresh then self:Refresh(id) end
  end)
end


-- ------------------------------------------------------------
-- Visibility (BrA-style): core state + effective hidden via parent chain
-- ------------------------------------------------------------
function M:IsNodeHidden(id)
  if not GetData then return false end
  local curId = id
  local guard = 0
  while curId and guard < 200 do
    guard = guard + 1
    local el = GetData(curId)
    if type(el) ~= "table" then break end
    if el.hidden == true then return true end
    curId = el.parent
  end
  return false
end

local function _forEachChild(el, fn)
  if type(el) ~= "table" then return end
  local ch = el.controlledChildren
  if type(ch) ~= "table" then return end
  for _, cid in ipairs(ch) do
    if type(cid) == "string" then
      fn(cid)
    end
  end
end

local function _buildIndex()
  local TI = _TreeIndex()
  if TI and TI.Build then
    return TI:Build() or { childrenMap = {} }
  end
  return { childrenMap = {} }
end

local function _forEachDescByIndex(id, fn, idx)
  idx = idx or _buildIndex()
  local map = idx.childrenMap or {}
  local stack = { id }
  local guard = 0
  while #stack > 0 and guard < 500 do
    guard = guard + 1
    local cur = table.remove(stack)
    local kids = map[cur]
    if type(kids) == "table" then
      for i = #kids, 1, -1 do
        local cid = kids[i]
        if type(cid) == "string" and cid ~= "" then
          fn(cid)
          table.insert(stack, cid)
        end
      end
    end
  end
  return idx
end

function M:SetHidden(id, hidden, recursive)
  if not GetData then return end
  local el = GetData(id)
  if type(el) ~= "table" then return end
  el.hidden = hidden and true or false

  local idx
  if recursive then
    idx = _forEachDescByIndex(id, function(cid)
      local cel = GetData(cid)
      if type(cel) == "table" then
        cel.hidden = hidden and true or false
      end
    end)
  end

  -- apply runtime
  self:Refresh(id)
  if recursive then
    _forEachDescByIndex(id, function(cid) self:Refresh(cid) end, idx)
  end
end


-- Refresh subtree runtime visibility without mutating child hidden flags.
-- Used for "parent eye acts as overlay" rule: parent hidden affects descendants via parent chain.
function M:RefreshSubtree(id, idx, includeSelf)
  if type(id) ~= "string" then return end
  includeSelf = (includeSelf ~= false)
  idx = idx or _buildIndex()
  if includeSelf then self:Refresh(id) end
  _forEachDescByIndex(id, function(cid) self:Refresh(cid) end, idx)
end

-- ------------------------------------------------------------
-- Auto frame-level layering inside a single strata by Tree order
-- NOTE: No DB writes. Runtime-only. Called after Tree rebuild.
-- ------------------------------------------------------------
function M:RefreshAutoLevelsByTree(targetStrata, idx)
  targetStrata = targetStrata or "BACKGROUND"
  if targetStrata ~= "BACKGROUND" then return end
  if not GetData then return end
  idx = idx or _buildIndex()
  local map = idx.childrenMap or {}
  if type(map) ~= "table" then return end

  -- For each parent, compute sibling rank -> 3 buckets (bg1/bg2/bg3)
  for parentId, kids in pairs(map) do
    if type(kids) == "table" and #kids > 0 then
      -- collect eligible children in display order (kids are already ordered)
      local elig = {}
      for i = 1, #kids do
        local cid = kids[i]
        if type(cid) == "string" and cid ~= "" then
          local el = GetData(cid)
          if type(el) == "table" then
            local props = type(el.props) == "table" and el.props or {}
            local fs = props.frameStrata or "AUTO"
            if fs == "BACKGROUND" then
              table.insert(elig, cid)
            end
          end
        end
      end

      local n = #elig
      if n > 0 then
        for i = 1, n do
          local cid = elig[i]
          local f = self._regions and self._regions[cid] or nil
          if f and f.SetFrameLevel and f.GetFrameLevel then
            -- i: top->bottom order in Tree; higher should be on top
            -- bucket: 1..3 (bottom/mid/top) but computed so top gets 3
            local bucket = 1
            if n == 1 then
              bucket = 2
            else
              local ratio = i / n
              if ratio <= (1/3) then bucket = 3
              elseif ratio <= (2/3) then bucket = 2
              else bucket = 1 end
            end

            -- base + bucket separation + stable order
            local lvl = 200 + (bucket * 100) + i
            pcall(f.SetFrameLevel, f, lvl)
          end
        end
      end
    end
  end
end



function M:ApplyElement(id, el)
  if type(id) ~= "string" or type(el) ~= "table" then return end
  -- skip groups / containers (no body)
  local isGroup = (el.kind == "group") or (el.type == "group") or (el.regionType == "group") or (el.regionType == "dynamicgroup")
  -- NOTE: Schema 默认会给所有元素塞一个 controlledChildren = {}，
  -- 不能仅凭“存在 table”就判定为 group，否则普通元素会被误判为容器而直接 Hide 并 return。
  if not isGroup and type(el.controlledChildren) == "table" and next(el.controlledChildren) ~= nil then
    isGroup = true
  end
  if isGroup then
    if self._regions and self._regions[id] then
      do local rf = self._regions[id]; _stopMotionCancel(rf); rf:Hide() end
    end
    return
  end


  -- hard-unloaded (BrA-like): loaded tri-state == nil => do not run / do not render.
  -- NOTE: This is runtime gating for elements only. Groups are handled above and return early.
  local LS = Bre and Bre.LoadState
  if LS and LS.IsHardUnloaded and LS:IsHardUnloaded(id, el, GetData) then
    if self._regions and self._regions[id] then do local rf = self._regions[id]; _stopMotionCancel(rf); rf:Hide() end end
    return
  end

  -- effective hidden (self or any parent)
  if self:IsNodeHidden(id) then
    if self._regions and self._regions[id] then do local rf = self._regions[id]; _stopMotionCancel(rf); rf:Hide() end end
    return
  end

  local f = self:EnsureRegion(id)
  -- NOTE (Layering/Strata Step1):
  -- Identified the single authoritative apply-point for per-element runtime changes.
  -- FrameStrata must be applied here (post-EnsureRegion) so it takes effect immediately
  -- on selection refresh / tree refresh, and remains compatible with RefreshRight silent UI.
  -- frame strata intent (data.props.frameStrata)
  do
    local props = type(el.props) == "table" and el.props or {}
    local fs = props.frameStrata or "AUTO"
    if fs == "AUTO" or fs == nil or fs == "" then
      local parent = (f.GetParent and f:GetParent()) or nil
      if parent and parent.GetFrameStrata then
        fs = parent:GetFrameStrata()
      else
        fs = "MEDIUM"
      end
    end
    if fs ~= "BACKGROUND" and fs ~= "LOW" and fs ~= "MEDIUM" and fs ~= "HIGH" and fs ~= "DIALOG" and fs ~= "FULLSCREEN" and fs ~= "FULLSCREEN_DIALOG" and fs ~= "TOOLTIP" then
      fs = "MEDIUM"
    end
    if f.SetFrameStrata then
      pcall(f.SetFrameStrata, f, fs)
    end
  end

  local w = (el.size and tonumber(el.size.width)) or 64
  local h = (el.size and tonumber(el.size.height)) or 64
  local scale = tonumber(el.scale) or 1
  if scale <= 0 then scale = 1 end
  w = w * scale
  h = h * scale
  f:SetSize(w, h)

  -- Step4 (v2.11.12): BrA-style anchor apply (no DB writes here).
  -- Default remains CENTER relative to UIParent using props.xOffset/yOffset.
  local props2 = type(el.props) == "table" and el.props or {}
  local xo = tonumber(props2.xOffset) or 0
  local yo = tonumber(props2.yOffset) or 0

  local selfPoint = "CENTER"
  local relPoint = "CENTER"
  local relTo = UIParent

  local function _validPoint(p)
    if p == "TOPLEFT" or p == "TOP" or p == "TOPRIGHT" or p == "LEFT" or p == "CENTER" or p == "RIGHT" or p == "BOTTOMLEFT" or p == "BOTTOM" or p == "BOTTOMRIGHT" then
      return p
    end
    return "CENTER"
  end

  local a = type(props2.anchor) == "table" and props2.anchor or nil
  if a and a.mode == "TARGET" and type(a.targetId) == "string" and a.targetId ~= "" then
    selfPoint = _validPoint(a.selfPoint)
    relPoint = _validPoint(a.targetPoint)

    local AR = Gate and Gate.Get and Gate:Get("AnchorRetry")
    local targetFrame = nil
    if AR and AR.GetResolved then
      targetFrame = AR:GetResolved()[id]
    end

    if not targetFrame then
      local Resolve = Gate and Gate.Get and Gate:Get("ResolveTargetFrame")
      if Resolve then
        local ok, fr = pcall(function() return Resolve(a.targetId) end)
        if ok and fr ~= nil then
          targetFrame = fr
          -- cache as resolved for this activeId (BrA-style)
          if AR and AR.resolved then
            AR.resolved[id] = fr
          end
          if AR and AR.pending then
            AR.pending[id] = nil
          end
        end
      end
    end

    if targetFrame then
      relTo = targetFrame
    else
      -- Target not born yet: postpone + retry. Fallback render to UIParent.
      if AR and AR.Postpone then
        pcall(function() AR:Postpone(id, a.targetId) end)
      end
    end
  end

  f:ClearAllPoints()
  f:SetPoint(selfPoint, relTo, relPoint, xo, yo)

  -- Check if this is a progress element
  local isProgress = (el.regionType == "progress")
  
  if isProgress then
    -- v2.16.4: Progress elements use StatusBar + independent fg texture
    local statusBar = f._statusBar
    local bgTex = f._bgTex

    if not statusBar then
      if Bre.DEBUG then
        print("[Move] ApplyElement: statusBar missing for progress element")
      end
      return
    end
    
    -- Get progress values based on progressType (v2.18.12)
    local PD = (Gate and Gate.Get) and Gate:Get("ProgressData") or nil
    local cur, max = 60, 100  -- Fallback
    local progressUnit = el.progressUnit or "player"
    local progressType = el.progressType or "PROG_TYPE_HEALTH"
    
    -- Map progressType to sourceType and powerType
    local sourceType = "Health"  -- Default
    local powerType = nil
    
    -- Map PROG_TYPE_* to sourceType
    local typeMap = {
      PROG_TYPE_HEALTH = "Health",
      PROG_TYPE_MANA = "Mana",
      PROG_TYPE_ENERGY = "Energy",
      PROG_TYPE_RAGE = "Rage",
      PROG_TYPE_FOCUS = "Focus",
      PROG_TYPE_RUNIC_POWER = "RunicPower",
      PROG_TYPE_INSANITY = "Insanity",
      PROG_TYPE_LUNAR_POWER = "LunarPower",
      PROG_TYPE_FURY = "Fury",
      PROG_TYPE_PAIN = "Pain",
      PROG_TYPE_MAELSTROM = "Maelstrom",
    }
    
    -- Map sourceType to Enum.PowerType index
    local powerTypeMap = {
      Mana = 0,
      Energy = 3,
      Rage = 1,
      Focus = 2,
      RunicPower = 6,
      Insanity = 13,
      LunarPower = 8,
      Fury = 17,
      Pain = 18,
      Maelstrom = 11,
    }
    
    sourceType = typeMap[progressType] or "Health"
    
    if PD then
      if sourceType == "Health" and PD.GetHealthValues then
        cur, max = PD:GetHealthValues(progressUnit)
      elseif sourceType ~= "Health" and PD.GetPowerValues then
        powerType = powerTypeMap[sourceType] or 0
        cur, max = PD:GetPowerValues(progressUnit, powerType)
      end
      
      -- Auto-subscribe for real-time updates
      if PD.Subscribe and id then
        pcall(PD.Subscribe, PD, id, sourceType, progressUnit)
        if Bre.DEBUG then
          print(string.format("[Move] Subscribed %s to %s %s", id, sourceType, progressUnit))
        end
      end
    end
    
    -- Setup StatusBar via ProgressMat
    local PM = (Gate and Gate.Get) and Gate:Get("ProgressMat") or nil
    if PM and PM.SetupStatusBar then
      pcall(PM.SetupStatusBar, PM, statusBar, bgTex, el, cur, max)
    end
  elseif el.regionType == "model" then
    _stopMotionCancel(f)
    -- Model element: render PlayerModel (unit or fileID)
    -- Ensure model body exists (older regions may have been created as texture)
    if not f._model then
      if f._tex then
        f._tex:Hide()
      end
      local pm = CreateFrame("PlayerModel", nil, f)
      pm:SetAllPoints(f)
      pm:SetFrameLevel(3)
      if pm.SetKeepModelOnHide then
        pm:SetKeepModelOnHide(true)
      end
      pm:Show()
      f._model = pm
    end
    if f._tex then
      f._tex:Hide()
    end

    local pm = f._model
    if pm then
      local mode = tostring(el.modelMode or "unit")
      local unit = tostring(el.modelUnit or "player")
      local fid = tonumber(el.modelFileID)

      -- Reset event wiring when unit changes
      if f._modelMode ~= mode or f._modelUnit ~= unit then
        f:UnregisterAllEvents()
        f._modelMode = mode
        f._modelUnit = unit
        if mode == "unit" then
          if unit == "target" then
            f:RegisterEvent("PLAYER_TARGET_CHANGED")
            f:RegisterEvent("UNIT_MODEL_CHANGED")
          elseif unit == "focus" then
            f:RegisterEvent("PLAYER_FOCUS_CHANGED")
            f:RegisterEvent("UNIT_MODEL_CHANGED")
          elseif unit == "player" then
            f:RegisterEvent("UNIT_MODEL_CHANGED")
          end
          f:SetScript("OnEvent", function(self, event, arg1)
            if self._model and self._modelMode == "unit" then
              local u = self._modelUnit or "player"
              if event == "UNIT_MODEL_CHANGED" and arg1 and arg1 ~= u then return end
              pcall(self._model.SetUnit, self._model, u)
            end
          end)
        else
          f:SetScript("OnEvent", nil)
        end
      end

      -- Apply source
      if mode == "file" then
        if fid and fid > 0 then
          if pm.SetModelByFileID then
            pcall(pm.SetModelByFileID, pm, fid)
          elseif pm.SetModel then
            pcall(pm.SetModel, pm, fid)
          end
        end
      else
        if pm.SetUnit then
          pcall(pm.SetUnit, pm, unit)
        end
      end

      -- Alpha
      if pm.SetAlpha then
        pm:SetAlpha(tonumber(el.alpha) or 1)
      end

      -- Facing rotation (v2.18.86)
      -- Reference: WeakAuras ConfigureModel - ClearTransform → SetPosition → SetFacing
      local facing = tonumber(el.facing) or 0
      if pm.ClearTransform and pm.SetPosition and pm.SetFacing then
        pcall(pm.ClearTransform, pm)
        pcall(pm.SetPosition, pm, 0, 0, 0)
        local radians = facing * math.pi / 180
        pcall(pm.SetFacing, pm, radians)
      end

      -- Animation sequence (v2.18.87)
      -- Reference: WeakAuras ConfigureModel - SetAnimation after SetFacing
      local animSeq = tonumber(el.animSequence) or 0
      if pm.SetAnimation then
        if animSeq > 0 then
          pcall(pm.SetAnimation, pm, animSeq)
        else
          pcall(pm.SetAnimation, pm, 0)  -- 0 = stand/default animation
        end
      end
    end

  elseif f._tex then
    -- Regular element: use single texture
    local tex = f._tex
    if not tex then
f:Show()
      return
    end
    
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

    local region = type(el.region) == "table" and el.region or {}
    -- Ensure StopMotion playback runtime (fps/mode/inverse). Safe no-op if disabled.
    _stopMotionEnsureTicker(self, id, el, f)
    local smL, smR, smT, smB = _getStopMotionTexCoord(el, (f and f._smFrame) or 1)
    local CM = (Gate and Gate.Get) and Gate:Get("CustomMat") or nil
    if CM and CM.ApplyToTexture then
      local rr = {}
      for k, v in pairs(region) do rr[k] = v end
      rr.texture = p
      if smL then
        rr.stopmotionTexCoord = { smL, smR, smT, smB }
      end
      CM:ApplyToTexture(tex, rr, tonumber(el.alpha) or 1)
    else
      -- defaults (no CustomMat module)
      if tex.SetTexCoord then
        if smL then
          -- Honor mirror on sliced texcoord.
          if region.mirror then
            tex:SetTexCoord(smR, smL, smT, smB)
          else
            tex:SetTexCoord(smL, smR, smT, smB)
          end
        else
          tex:SetTexCoord(0,1,0,1)
        end
      end
      if tex.SetDesaturated then
        tex:SetDesaturated(false)
      elseif tex.SetDesaturation then
        tex:SetDesaturation(0)
      end
      if tex.SetVertexColor then tex:SetVertexColor(1,1,1,1) end
      if region.blendMode and tex.SetBlendMode then
        pcall(tex.SetBlendMode, tex, region.blendMode)
      end
      if tex.SetAlpha then tex:SetAlpha(tonumber(el.alpha) or 1) end
      if tex.SetRotation and region.rotation then
        local deg = tonumber(region.rotation) or 0
        tex:SetRotation(deg * math.pi / 180)
      end
    end
  end



  -- Output Actions: rotate runtime (continuous)
  _syncRotateRuntime(self, id, el)
  f:Show()
end

function M:RestoreAll()
  self:EnsureRuntimeRoot()
  if not BrelmsSaved or type(BrelmsSaved.displays) ~= "table" then return end
  for id, el in pairs(BrelmsSaved.displays) do
    if type(id) == "string" and type(el) == "table" then
      pcall(self.ApplyElement, self, id, el)
    end
  end
end

function M:Refresh(id)
  if not GetData then return end
  local el = GetData(id)
  if not el then return end

  -- C-step3: Move owns region rebuild semantics.
  -- If a commit path marked this element as requiring a rebuild, honor it here
  -- using the public region lifecycle APIs, and clear the flag in persisted data.
  if type(el) == "table" and el._needsRegionRebuild then
    el._needsRegionRebuild = nil
    pcall(function() SetData(id, el) end)
    if self.InvalidateRegion then
      pcall(function() self:InvalidateRegion(id) end)
    end
  end

  self:ApplyElement(id, el)
end

function M:EnsureMoverFrame()
  if self._mover then return self._mover end

  local f = CreateFrame("Frame", "BrelmsMoverBody", UIParent, "BackdropTemplate")
  f:SetSize(80, 80)
  f:SetFrameStrata("DIALOG")
  f:SetFrameLevel(9999)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:Hide()

  -- only a border/handle (visual + drag). Real element rendering is in Render module.
  f:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  f:SetBackdropColor(0,0,0,0)
  f:SetBackdropBorderColor(1,0.82,0,0.80)

  -- Center mark for alignment (small circle + dot)
  EnsureCenterMark(f, 1, 0.82, 0, 0.90)


-- XY nudge controls (Step1): show current X/Y and allow small adjustments.
-- Style is intentionally minimal; values are applied through Move (this module) and reflected immediately.
f._nudgeStep = 1
f._updatingXY = false

local function _applyXYFromControls(newX, newY)
  local id = M._activeElementId
  if not id then return end
  local el = GetData(id)
  if not el then return end
  normPos(el)
  setXY(el, newX, newY)

  -- 1) Move the mover itself
  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "CENTER", newX, newY)

  -- 2) Lightweight move for runtime region to avoid visual trails:
  -- Do NOT fully re-ApplyElement() on every nudge; just move the existing frame.
  local r = (M._regions and M._regions[id]) or nil
  if r then
    r:ClearAllPoints()
    r:SetPoint("CENTER", UIParent, "CENTER", newX, newY)
  else
    -- fallback: if runtime not present yet, do a full refresh once
    pcall(M.Refresh, M, id)
  end

  -- 3) Optional render preview sync
  local Render = Bre.Gate and Bre.Gate.Get and Bre.Gate:Get("Render")
  if Render and Render.SetCenterByMover then
    pcall(Render.SetCenterByMover, Render, f)
  end

  -- 4) Notify UI / persistence hooks
    local UI = _UI()
  if UI and UI._OnElementMoved then
        pcall(UI._OnElementMoved, UI, id)
  end
end

local function _readCurrentXY()
  local id = M._activeElementId
  if not id then return 0, 0 end
  local el = GetData(id)
  if not el then return 0, 0 end
  normPos(el)
  return getXY(el)
end

local function _fmt1(v)
  v = tonumber(v) or 0
  local s = 1
  if v < 0 then s = -1; v = -v end
  local one = math.floor(v * 10 + 1e-6) / 10
  one = one * s
  if one == 0 then return "0" end
  return string.format("%.1f", one)
end

local function _fitBoxWidth(eb, minW)
  if not eb then return end
  local w = (eb.GetTextWidth and eb:GetTextWidth()) or 0
  w = math.max(minW or 44, math.floor(w + 14))
  if eb:GetWidth() ~= w then
    eb:SetWidth(w)
  end
end

local function _syncXYToControls()
  if not f._xBox or not f._yBox then return end
  local x, y = _readCurrentXY()
  f._updatingXY = true
  f._xBox:SetText(_fmt1(x))
  f._yBox:SetText(_fmt1(y))
  _fitBoxWidth(f._xBox, 70)
  _fitBoxWidth(f._yBox, 44)
  f._updatingXY = false
end

local function _styleEditBox(eb)
  eb:SetAutoFocus(false)
  eb:SetJustifyH("CENTER")
  eb:SetFontObject("GameFontNormalSmall")
  eb:SetTextInsets(4, 4, 2, 2)
  eb:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Buttons/WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  eb:SetBackdropColor(0,0,0,0.55)
  eb:SetBackdropBorderColor(1,0.82,0,0.65)
end

local function _styleBtn(btn)
  btn:SetSize(18, 18)
  btn:SetNormalTexture("Interface/Buttons/UI-ScrollBar-ScrollUpButton-Up")
  btn:SetPushedTexture("Interface/Buttons/UI-ScrollBar-ScrollUpButton-Down")
  btn:SetHighlightTexture("Interface/Buttons/UI-ScrollBar-ScrollUpButton-Highlight")
end

-- X control (bottom)
local xWrap = CreateFrame("Frame", nil, f)
-- Keep wrap width tight so the two arrows stay centered under the selection box.
-- Make X-arrow spacing match Y-arrow spacing (Y uses yBox height=18 + gap*2).
-- btn(18) + gap(4) + box(18) + gap(4) + btn(18) = 62
xWrap:SetSize(56, 22)
xWrap:SetPoint("TOP", f, "BOTTOM", 0, -6)
xWrap:Hide()

local xLeft = CreateFrame("Button", nil, xWrap)
_styleBtn(xLeft)
xLeft:SetPoint("CENTER", xWrap, "CENTER", -9.5, 0)
  xLeft:GetNormalTexture():SetRotation(math.rad(90))
  xLeft:GetPushedTexture():SetRotation(math.rad(90))
  xLeft:GetHighlightTexture():SetRotation(math.rad(90))
local xBox = CreateFrame("EditBox", nil, xWrap, "BackdropTemplate")
xBox:SetSize(18, 18)
  xBox:ClearAllPoints()
  xBox:SetPoint("CENTER", xWrap, "CENTER", 0, 0)
_styleEditBox(xBox)

xBox:Hide(); xBox:EnableMouse(false); xBox:SetEnabled(false)
local xRight = CreateFrame("Button", nil, xWrap)
_styleBtn(xRight)
  xRight:SetPoint("LEFT", xLeft, "RIGHT", 1, 0)
  xRight:GetNormalTexture():SetRotation(math.rad(-90))
  xRight:GetPushedTexture():SetRotation(math.rad(-90))
  xRight:GetHighlightTexture():SetRotation(math.rad(-90))
-- Y control (right)
local yWrap = CreateFrame("Frame", nil, f)
yWrap:SetSize(22, 56)
yWrap:SetPoint("LEFT", f, "RIGHT", 6, 0)
yWrap:Hide()

local yUp = CreateFrame("Button", nil, yWrap)
_styleBtn(yUp)
yUp:SetPoint("CENTER", yWrap, "CENTER", 0, 9.5)

local yBox = CreateFrame("EditBox", nil, yWrap, "BackdropTemplate")
yBox:SetSize(18, 18)
  yBox:ClearAllPoints()
  yBox:SetPoint("CENTER", yWrap, "CENTER", 0, 0)
_styleEditBox(yBox)
yBox:Hide(); yBox:EnableMouse(false); yBox:SetEnabled(false)
yBox:SetMaxLetters(16)

local yDown = CreateFrame("Button", nil, yWrap)
_styleBtn(yDown)
  yDown:SetPoint("TOP", yUp, "BOTTOM", 0, -1)
yDown:GetNormalTexture():SetRotation(math.rad(180))
yDown:GetPushedTexture():SetRotation(math.rad(180))
yDown:GetHighlightTexture():SetRotation(math.rad(180))

-- Behaviors

local function _applyFromBoxes()
  if f._updatingXY then return end
  local x = tonumber(xBox:GetText())
  local y = tonumber(yBox:GetText())
  if x == nil or y == nil then
    _syncXYToControls()
    return
  end
  _applyXYFromControls(x, y)
  _syncXYToControls()
end

xBox:SetMaxLetters(16)
xBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
xBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); _applyFromBoxes() end)
xBox:SetScript("OnEditFocusLost", function(self) _applyFromBoxes() end)

yBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); _applyFromBoxes() end)
yBox:SetScript("OnEditFocusLost", function(self) _applyFromBoxes() end)

xBox:SetScript("OnEnterPressed", nil)
xBox:SetScript("OnEditFocusLost", nil)
xBox:SetScript("OnTextChanged", nil)
yBox:SetScript("OnEnterPressed", nil)
yBox:SetScript("OnEditFocusLost", nil)
yBox:SetScript("OnTextChanged", nil)
xLeft:SetScript("OnClick", function()
  local x, y = _readCurrentXY()
  _applyXYFromControls((tonumber(x) or 0) - (f._nudgeStep or 1), y)
  _syncXYToControls()
end)
xRight:SetScript("OnClick", function()
  local x, y = _readCurrentXY()
  _applyXYFromControls((tonumber(x) or 0) + (f._nudgeStep or 1), y)
  _syncXYToControls()
end)
yUp:SetScript("OnClick", function()
  local x, y = _readCurrentXY()
  _applyXYFromControls(x, (tonumber(y) or 0) + (f._nudgeStep or 1))
  _syncXYToControls()
end)
yDown:SetScript("OnClick", function()
  local x, y = _readCurrentXY()
  _applyXYFromControls(x, (tonumber(y) or 0) - (f._nudgeStep or 1))
  _syncXYToControls()
end)

f._xWrap, f._yWrap = xWrap, yWrap
f._xBox, f._yBox = xBox, yBox
f._syncXYToControls = _syncXYToControls


  local function syncAllToMover()
    -- 1) Sync Render preview (optional module)
    local Render = Bre.Gate and Bre.Gate.Get and Bre.Gate:Get("Render")
    if Render and Render.SetCenterByMover then
      Render:SetCenterByMover(f)
    end

    -- 2) Sync the REAL runtime region while dragging to avoid "ghost" at old position.
    local id = M._activeElementId
    if id and M._regions and M._regions[id] then
      local r = M._regions[id]
      local cx, cy = f:GetCenter()
      local ux, uy = UIParent:GetCenter()
      if cx and cy and ux and uy then
        r:ClearAllPoints()
        r:SetPoint("CENTER", UIParent, "CENTER", cx - ux, cy - uy)
      end
    end
  end

  f:SetScript("OnDragStart", function(self)
    self:StartMoving()
    -- while dragging, keep both preview + real runtime region in sync
    self:SetScript("OnUpdate", syncAllToMover)
  end)

  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self:SetScript("OnUpdate", nil)
    syncAllToMover()

    local id = M._activeElementId
    if id and Bre.GetData then
      local cx, cy = self:GetCenter()
      local ux, uy = UIParent:GetCenter()
      if cx and cy and ux and uy then
        -- Commit final offsets on MouseUp (single source of truth: data.props.xOffset/yOffset)
        M:CommitOffsets({ id = id, xOffset = (cx - ux), yOffset = (cy - uy) })
      end
      -- Refresh right panel display (must be silent; Step3 isolation prevents accidental commits)
            local UI = _UI()
      if UI and UI.RefreshRight then
                pcall(UI.RefreshRight, UI)
      end
    end
  end)

  self._mover = f
  return f
end


-- ------------------------------------------------------------
-- Group selection box (non-draggable in Step2)
-- ------------------------------------------------------------
function M:EnsureGroupBox()
  if self._groupBox then return self._groupBox end

  local f = CreateFrame("Frame", "BrelmsGroupBox", UIParent, "BackdropTemplate")
  f:SetSize(40, 40)
  f:SetFrameStrata("DIALOG")
  f:SetFrameLevel(9998)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetClampedToScreen(false)
  f:Hide()

  f:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  f:SetBackdropColor(0,0,0,0)
  f:SetBackdropBorderColor(0, 0.85, 1, 0.90)

  -- Center mark for alignment (small circle + dot)
  EnsureCenterMark(f, 0, 0.85, 1, 0.90)

  -- ------------------------------------------------------------
  -- X/Y micro-adjust controls for group box
  -- ------------------------------------------------------------
  local function _fmt1g(v)
    v = tonumber(v) or 0
    if v == 0 then return "0" end
    return string.format("%.1f", v)
  end

  local function _fitBoxWidthG(eb, minW)
    if not eb then return end
    local w = (eb.GetTextWidth and eb:GetTextWidth()) or 0
    w = math.max(minW or 44, math.floor(w + 14))
    if eb:GetWidth() ~= w then eb:SetWidth(w) end
  end

  local function _styleEditBoxG(eb)
    eb:SetAutoFocus(false)
    eb:SetJustifyH("CENTER")
    eb:SetFontObject("GameFontNormalSmall")
    eb:SetTextInsets(4, 4, 2, 2)
    eb:SetBackdrop({
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      edgeFile = "Interface/Buttons/WHITE8x8",
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    eb:SetBackdropColor(0,0,0,0.55)
    eb:SetBackdropBorderColor(0,0.85,1,0.70)
  end

  local function _styleBtnG(btn)
    btn:SetSize(18, 18)
    btn:SetNormalTexture("Interface/Buttons/UI-ScrollBar-ScrollUpButton-Up")
    btn:SetPushedTexture("Interface/Buttons/UI-ScrollBar-ScrollUpButton-Down")
    btn:SetHighlightTexture("Interface/Buttons/UI-ScrollBar-ScrollUpButton-Highlight")
  end

  local xWrap = CreateFrame("Frame", nil, f)
  -- Keep wrap width tight so the two arrows stay visually centered under the box.
  -- Make X-arrow spacing match Y-arrow spacing (Y uses yBox height=18 + gap*2).
  -- btn(18) + gap(4) + box(18) + gap(4) + btn(18) = 62
  xWrap:SetSize(56, 22)
  xWrap:SetPoint("TOP", f, "BOTTOM", 0, -6)
  xWrap:Hide()

  local xLeft = CreateFrame("Button", nil, xWrap)
  _styleBtnG(xLeft)
  xLeft:SetPoint("CENTER", xWrap, "CENTER", -9.5, 0)
  xLeft:GetNormalTexture():SetRotation(math.rad(90))
  xLeft:GetPushedTexture():SetRotation(math.rad(90))
  xLeft:GetHighlightTexture():SetRotation(math.rad(90))
  local xBox = CreateFrame("EditBox", nil, xWrap, "BackdropTemplate")
  xBox:SetSize(18, 18)
  xBox:ClearAllPoints()
  xBox:SetPoint("CENTER", xWrap, "CENTER", 0, 0)
  _styleEditBoxG(xBox)
xBox:Hide(); xBox:EnableMouse(false); xBox:SetEnabled(false)
  xBox:SetMaxLetters(16)

  local xRight = CreateFrame("Button", nil, xWrap)
  _styleBtnG(xRight)
  xRight:SetPoint("LEFT", xLeft, "RIGHT", 1, 0)
  xRight:GetNormalTexture():SetRotation(math.rad(-90))
  xRight:GetPushedTexture():SetRotation(math.rad(-90))
  xRight:GetHighlightTexture():SetRotation(math.rad(-90))
  local yWrap = CreateFrame("Frame", nil, f)
  yWrap:SetSize(22, 56)
  yWrap:SetPoint("LEFT", f, "RIGHT", 6, 0)
  yWrap:Hide()

  local yUp = CreateFrame("Button", nil, yWrap)
  _styleBtnG(yUp)
  yUp:SetPoint("CENTER", yWrap, "CENTER", 0, 9.5)

  local yBox = CreateFrame("EditBox", nil, yWrap, "BackdropTemplate")
  yBox:SetSize(18, 18)
  yBox:ClearAllPoints()
  yBox:SetPoint("CENTER", yWrap, "CENTER", 0, 0)
  _styleEditBoxG(yBox)
yBox:Hide(); yBox:EnableMouse(false); yBox:SetEnabled(false)
  yBox:SetMaxLetters(16)

  local yDown = CreateFrame("Button", nil, yWrap)
  _styleBtnG(yDown)
  yDown:SetPoint("TOP", yUp, "BOTTOM", 0, -1)
  yDown:GetNormalTexture():SetRotation(math.rad(180))
  yDown:GetPushedTexture():SetRotation(math.rad(180))
  yDown:GetHighlightTexture():SetRotation(math.rad(180))

  local function _readGroupXY()
    local cx, cy = f:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not (cx and cy and ux and uy) then return 0, 0 end
    return (cx - ux), (cy - uy)
  end

  local function _syncXYToControlsG()
    if not f._xBoxG then return end
    local x, y = _readGroupXY()
    f._updatingXYG = true
    f._xBoxG:SetText(_fmt1g(x))
    f._yBoxG:SetText(_fmt1g(y))
    _fitBoxWidthG(f._xBoxG, 70)
    _fitBoxWidthG(f._yBoxG, 44)
    f._updatingXYG = false
  end

  local function _applyGroupXY(targetX, targetY)
    targetX = tonumber(targetX) or 0
    targetY = tonumber(targetY) or 0
    local curX, curY = _readGroupXY()
    local dx, dy = targetX - (curX or 0), targetY - (curY or 0)
    if dx == 0 and dy == 0 then return end

    -- Move the group box itself
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", targetX, targetY)

    -- Apply delta to all selected descendant elements
    if f._ids and GetData then
      for _, id in ipairs(f._ids) do
        local el = GetData(id)
        if el then
          normPos(el)
          local x, y = getXY(el)
          setXY(el, (x or 0) + dx, (y or 0) + dy)

          -- lightweight runtime move (avoid trails)
          local r = (M._regions and M._regions[id]) or nil
          if r then
            r:ClearAllPoints()
            r:SetPoint("CENTER", UIParent, "CENTER", (x or 0) + dx, (y or 0) + dy)
          else
            pcall(M.Refresh, M, id)
          end

            local UI = _UI()
  if UI and UI._OnElementMoved then
                pcall(UI._OnElementMoved, UI, id)
          end
        end
      end
    end
  end

  local function _applyFromBoxesG()
    if f._updatingXYG then return end
    local x = tonumber(xBox:GetText())
    local y = tonumber(yBox:GetText())
    if x == nil or y == nil then
      _syncXYToControlsG()
      return
    end
    _applyGroupXY(x, y)
    _syncXYToControlsG()
  end

  xBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  xBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); _applyFromBoxesG() end)
  xBox:SetScript("OnEditFocusLost", function(self) _applyFromBoxesG() end)

  yBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); _applyFromBoxesG() end)
  yBox:SetScript("OnEditFocusLost", function(self) _applyFromBoxesG() end)

xBox:SetScript("OnEnterPressed", nil)
xBox:SetScript("OnEditFocusLost", nil)
xBox:SetScript("OnTextChanged", nil)
yBox:SetScript("OnEnterPressed", nil)
yBox:SetScript("OnEditFocusLost", nil)
yBox:SetScript("OnTextChanged", nil)
  xLeft:SetScript("OnClick", function()
    local x, y = _readGroupXY()
    _applyGroupXY((tonumber(x) or 0) - (f._nudgeStep or 1), y)
    _syncXYToControlsG()
  end)
  xRight:SetScript("OnClick", function()
    local x, y = _readGroupXY()
    _applyGroupXY((tonumber(x) or 0) + (f._nudgeStep or 1), y)
    _syncXYToControlsG()
  end)
  yUp:SetScript("OnClick", function()
    local x, y = _readGroupXY()
    _applyGroupXY(x, (tonumber(y) or 0) + (f._nudgeStep or 1))
    _syncXYToControlsG()
  end)
  yDown:SetScript("OnClick", function()
    local x, y = _readGroupXY()
    _applyGroupXY(x, (tonumber(y) or 0) - (f._nudgeStep or 1))
    _syncXYToControlsG()
  end)

  f._xWrapG, f._yWrapG = xWrap, yWrap
  f._xBoxG, f._yBoxG = xBox, yBox
  f._syncXYToControlsG = _syncXYToControlsG

  -- Step3: drag whole group (apply delta to all selected descendant elements)
  f._ids = nil
  f._drag = nil

  local function _getCenterDelta(box)
    if not box._drag then return 0, 0 end
    local cx, cy = box:GetCenter()
    local sx, sy = box._drag.sx, box._drag.sy
    if not (cx and cy and sx and sy) then return 0, 0 end
    return (cx - sx), (cy - sy)
  end

  local function _previewMove(box)
    if not (box._ids and box._drag and M._regions) then return end
    local dx, dy = _getCenterDelta(box)
    local ux, uy = UIParent:GetCenter()
    if not (ux and uy) then return end

    for _, id in ipairs(box._ids) do
      local r = M._regions[id]
      local o = box._drag.orig and box._drag.orig[id]
      if r and o then
        r:ClearAllPoints()
        r:SetPoint("CENTER", UIParent, "CENTER", (o.rx or 0) + dx, (o.ry or 0) + dy)
      end
    end
  end

  f:SetScript("OnDragStart", function(self)
    if not (self._ids and type(self._ids) == "table") then return end
    local sx, sy = self:GetCenter()
    if not (sx and sy) then return end

    self._drag = { sx = sx, sy = sy, orig = {} }

    -- cache original runtime offsets (relative to UIParent center)
    local ux, uy = UIParent:GetCenter()
    if not (ux and uy) then ux, uy = 0, 0 end
    for _, id in ipairs(self._ids) do
      local r = M._regions and M._regions[id]
      if r and r.GetCenter then
        local cx, cy = r:GetCenter()
        if cx and cy then
          self._drag.orig[id] = { rx = cx - ux, ry = cy - uy }
        end
      end
    end

    self:StartMoving()
    self:SetScript("OnUpdate", _previewMove)
  end)

  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self:SetScript("OnUpdate", nil)
    _previewMove(self)

    if not (self._ids and GetData) then
      self._drag = nil
      return
    end

    local dx, dy = _getCenterDelta(self)
    if dx ~= 0 or dy ~= 0 then
      for _, id in ipairs(self._ids) do
        local el = GetData(id)
        if el then
          el.props = type(el.props) == "table" and el.props or {}
          local xo = tonumber(el.props.xOffset)
          local yo = tonumber(el.props.yOffset)
          if xo == nil or yo == nil then
            -- fallback to mirrored runtime position (legacy fields)
            local x, y = getXY(el)
            xo = xo == nil and (tonumber(x) or 0) or xo
            yo = yo == nil and (tonumber(y) or 0) or yo
          end
          M:CommitOffsets({ id = id, xOffset = (xo or 0) + dx, yOffset = (yo or 0) + dy })
        end
      end
            local UI = _UI()
      if UI and UI.RefreshRight then
                pcall(UI.RefreshRight, UI)
      end
    end

    self._drag = nil
  end)

  self._groupBox = f
  return f
end

function M:HideGroupBox()
  if self._groupBox then
    self._groupBox._ids = nil
    self._groupBox._drag = nil
    if self._groupBox._xWrapG then self._groupBox._xWrapG:Hide() end
    if self._groupBox._yWrapG then self._groupBox._yWrapG:Hide() end
    self._groupBox:Hide()
  end
end

local function _calcBoundsFromFrames(frames)
  local minL, minB = math.huge, math.huge
  local maxR, maxT = -math.huge, -math.huge
  local count = 0

  for _, rf in ipairs(frames) do
    if rf and rf.IsShown and rf:IsShown() then
      local l = rf:GetLeft()
      local r = rf:GetRight()
      local t = rf:GetTop()
      local b = rf:GetBottom()
      if l and r and t and b then
        if l < minL then minL = l end
        if b < minB then minB = b end
        if r > maxR then maxR = r end
        if t > maxT then maxT = t end
        count = count + 1
      end
    end
  end

  if count == 0 then return nil end
  return minL, minB, maxR, maxT
end

function M:ShowGroupBox(ids)
  -- ids: array of descendant element ids (leaf nodes)
  if self._mover then
    if self._mover._xWrap then self._mover._xWrap:Hide() end
    if self._mover._yWrap then self._mover._yWrap:Hide() end
    self._mover:Hide()
  end
  self:EnsureRuntimeRoot()
  local box = self:EnsureGroupBox()

  box._ids = ids

  -- Build frame list from runtime regions
  local frames = {}
  if type(ids) == "table" then
    for _, id in ipairs(ids) do
      if type(id) == "string" then
        local rf = self._regions and self._regions[id]
        if rf then frames[#frames + 1] = rf end
      end
    end
  end

  local l, b, r, t = _calcBoundsFromFrames(frames)
  if not l then
      box._ids = nil
box:Hide()
    return
  end

  -- pad a bit
  local pad = 2
  l, b, r, t = l - pad, b - pad, r + pad, t + pad

  box:ClearAllPoints()
  box:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)
  box:SetSize((r - l), (t - b))
  box:Show()

  if box._xWrapG and box._yWrapG then
    box._xWrapG:Show()
    box._yWrapG:Show()
  end
  if box._syncXYToControlsG then
    pcall(box._syncXYToControlsG)
  end
end

function M:ShowForElement(id, el)
  self:HideGroupBox()
  local f = self:EnsureMoverFrame()
  self._activeElementId = id

  if not el then
    f:Hide()
    return
  end

  -- Resize mover to match element's configured size (so border hugs the texture/frame edge)
  local w = (el.size and tonumber(el.size.width)) or nil
  local h = (el.size and tonumber(el.size.height)) or nil
  if (not w or not h) and self._regions and self._regions[id] then
    w, h = self._regions[id]:GetSize()
  end
  w = tonumber(w) or 80
  h = tonumber(h) or 80
  if w < 8 then w = 8 end
  if h < 8 then h = 8 end
  f:SetSize(w, h)

  normPos(el)
  f:ClearAllPoints()
  local x,y = getXY(el)
  f:SetPoint("CENTER", UIParent, "CENTER", x, y)
  f:Show()
  if f._xWrap and f._yWrap then
    f._xWrap:Show()
    f._yWrap:Show()
  end
  if f._syncXYToControls then
    pcall(f._syncXYToControls)
  end
end

function M:Hide()
  if self._mover then
    if self._mover._xWrap then self._mover._xWrap:Hide() end
    if self._mover._yWrap then self._mover._yWrap:Hide() end
    self._mover:Hide()
  end
  self:HideGroupBox()
  self._activeElementId = nil
end


-- Align: screen center
function M:AlignToScreenCenter(id)
  if not GetData then return end
  local el = GetData(id)
  if not el then return end
  normPos(el)
  el.position.x, el.position.y = 0, 0
    local UI = _UI()
  if UI and UI._OnElementMoved then
        pcall(UI._OnElementMoved, UI, id)
  end
end

-- Align: to reference element center (first selected)
function M:AlignToElement(id, refId)
  if not GetData then return end
  local el = GetData(id)
  local ref = GetData(refId)
  if not el or not ref then return end
  normPos(el); normPos(ref)
  el.position.x = ref.position.x or 0
  el.position.y = ref.position.y or 0
    local UI = _UI()
  if UI and UI._OnElementMoved then
        pcall(UI._OnElementMoved, UI, id)
  end
end

-- ------------------------------------------------------------
-- Tree mutation ops (L1): Rename / Copy / Delete
-- Must be called via Gate:Get('Move')
-- ------------------------------------------------------------
local function _deepcopy(v, seen)
  if type(v) ~= "table" then return v end
  if seen and seen[v] then return seen[v] end
  seen = seen or {}
  local out = {}
  seen[v] = out
  for k, vv in pairs(v) do
    out[_deepcopy(k, seen)] = _deepcopy(vv, seen)
  end
  return out
end

local function _trim(s)
  if type(s) ~= "string" then return "" end
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- "A" -> ("A", nil)
-- "A2" / "A 2" -> ("A", 2)
local function _splitBaseAndNum(name)
  name = _trim(name)
  if name == "" then return "", nil end
  local base, num = name:match("^(.-)%s*(%d+)$")
  if not base or base == "" then
    return name, nil
  end
  base = _trim(base)
  if base == "" then return name, nil end
  return base, tonumber(num)
end

local function _nextCopyNameLikeWA(sourceName, siblingIds, API)
  local base, cur = _splitBaseAndNum(sourceName)
  base = _trim(base)
  if base == "" then base = "Untitled" end

  local maxN = 1
  if type(siblingIds) == "table" and API and type(API.GetData) == "function" then
    for _, sid in ipairs(siblingIds) do
      local sd = API:GetData(sid)
      local nm = sd and sd.name
      if type(nm) == "string" and nm ~= "" then
        local b, n = _splitBaseAndNum(nm)
        if _trim(b) == base then
          if type(n) == "number" then
            if n > maxN then maxN = n end
          else
            -- exact base name counts as 1
            if 1 > maxN then maxN = 1 end
          end
        end
      end
    end
  end

  local start = (type(cur) == "number" and cur or 1)
  local nextN = (maxN > start) and (maxN + 1) or (start + 1)
  return base .. " " .. tostring(nextN)
end

local function _ensureRootChildren()
  BrelmsSaved = BrelmsSaved or { displays = {}, rootChildren = {} }
  BrelmsSaved.rootChildren = BrelmsSaved.rootChildren or {}
  return BrelmsSaved.rootChildren
end

local function _genId(prefix)
  prefix = prefix or "node"
  local API = _API()
  local exists = function(id)
    if API and API.GetData then return API:GetData(id) ~= nil end
    return GetData(id) ~= nil
  end
  local base = tostring(prefix):gsub("%s+", "_")
  for i=1, 50 do
    local id = string.format("%s_%d_%d", base, time(), math.random(1000, 9999))
    if not exists(id) then return id end
  end
  return string.format("%s_%d", base, time())
end

local function _buildIndex()
  local TI = _TreeIndex()
  if TI and TI.Build then return TI:Build() end
  return { parentMap = {}, childrenMap = {}, roots = {} }
end

local function _subtreeIds(rootId, idx)
  idx = idx or _buildIndex()
  local childrenMap = idx.childrenMap or {}
  local out = {}
  local function walk(id)
    table.insert(out, id)
    local kids = childrenMap[id]
    if type(kids) == "table" then
      for _, cid in ipairs(kids) do walk(cid) end
    end
  end
  walk(rootId)
  return out
end

local function _removeFromArray(arr, id)
  if type(arr) ~= "table" then return end
  for i=#arr,1,-1 do
    if arr[i] == id then table.remove(arr, i) end
  end
end
-- Reorder within siblings (parent's controlledChildren or rootChildren).
-- dir: -1 (up) or +1 (down)
function M:MoveSibling(id, dir)
  if type(id) ~= "string" then return false end
  dir = tonumber(dir) or 0
  if dir ~= -1 and dir ~= 1 then return false end
  local API = _API()
  if not (API and API.GetData and API.SetData) then return false end

  local idx = _buildIndex()
  local pid = (idx.parentMap and idx.parentMap[id]) or nil

  local arr, ownerId, ownerData
  if type(pid) == "string" and pid ~= "" then
    ownerId = pid
    ownerData = API:GetData(pid)
    if type(ownerData) ~= "table" then return false end
    ownerData.controlledChildren = ownerData.controlledChildren or {}
    arr = ownerData.controlledChildren
    -- If missing, seed with current children order from index
    if type(arr) ~= "table" or #arr == 0 then
      local kids = (idx.childrenMap and idx.childrenMap[pid]) or {}
      arr = {}
      for _, cid in ipairs(kids) do
        if type(cid) == "string" and cid ~= "" then
          arr[#arr+1] = cid
        end
      end
      ownerData.controlledChildren = arr
    end
  else
    -- root order
    arr = _ensureRootChildren()
  end

  -- ensure id exists in arr
  local pos
  for i, v in ipairs(arr) do
    if v == id then pos = i break end
  end
  if not pos then
    arr[#arr+1] = id
    pos = #arr
  end

  local j = pos + dir
  if j < 1 or j > #arr then return false end
  arr[pos], arr[j] = arr[j], arr[pos]

  if ownerId and ownerData then
    API:SetData(ownerId, ownerData)
  end
  return true
end

-- Move node to new parent (or root when newParentId is nil/empty) at a given index.
-- Does NOT allow cycles; caller should prevent invalid moves.
function M:SetParentAt(id, newParentId, insertIndex)
  if type(id) ~= "string" then 
    return false 
  end
  local API = _API()
  if not (API and API.GetData and API.SetData) then 
    return false 
  end

  local idx = _buildIndex()
  local node = API:GetData(id)
  if type(node) ~= "table" then 
    return false 
  end

  local oldPid = (idx.parentMap and idx.parentMap[id]) or node.parent

  -- remove from old parent order
  if type(oldPid) == "string" and oldPid ~= "" then
    local pd = API:GetData(oldPid)
    if type(pd) == "table" and type(pd.controlledChildren) == "table" then
      _removeFromArray(pd.controlledChildren, id)
      API:SetData(oldPid, pd)
    end
  else
    local roots = _ensureRootChildren()
    _removeFromArray(roots, id)
  end

  -- set new parent field
  if type(newParentId) == "string" and newParentId ~= "" then
    node.parent = newParentId
  else
    node.parent = nil
    newParentId = nil
  end
  API:SetData(id, node)

  -- insert into new parent order
  local targetArr, targetOwnerId, targetOwnerData
  if type(newParentId) == "string" and newParentId ~= "" then
    targetOwnerId = newParentId
    targetOwnerData = API:GetData(newParentId)
    if type(targetOwnerData) ~= "table" then 
      return false 
    end
    targetOwnerData.controlledChildren = targetOwnerData.controlledChildren or {}
    targetArr = targetOwnerData.controlledChildren
  else
    targetArr = _ensureRootChildren()
  end

  insertIndex = tonumber(insertIndex) or (#targetArr + 1)
  if insertIndex < 1 then insertIndex = 1 end
  if insertIndex > #targetArr + 1 then insertIndex = #targetArr + 1 end
  table.insert(targetArr, insertIndex, id)

  if targetOwnerId and targetOwnerData then
    API:SetData(targetOwnerId, targetOwnerData)
  end

  -- ------------------------------------------------------------
  -- v2.19.10: Group scale attach/detach rule (passive)
  -- - Element scale is always the EFFECTIVE scale (product of ancestor group local scales).
  -- Notes:
  -- - This does not attempt to reverse XY compensation; visual position stays.
  -- ------------------------------------------------------------
  do
    local Gate = Bre.Gate
    local PS = Gate and Gate.Get and Gate:Get('PropertyService') or nil
    local GS = Gate and Gate.Get and Gate:Get('GroupScaleService') or nil
    if PS and PS.Set and GS and GS.GetEffectiveScaleFor then
      local d = API:GetData(id)
      local rt = tostring((type(d) == 'table' and d.regionType) or '')
      local isGroup = (rt == 'group' or rt == 'dynamicgroup')
      if not isGroup then
        local eff = 1
        pcall(function() eff = GS:GetEffectiveScaleFor(id) end)
        pcall(function() PS:Set(id, 'scale', eff) end)
      end
    end
  end

  return true
end

-- Detach node: move it to its parent's parent (or root).
function M:DetachFromParent(id)
  if type(id) ~= "string" then return false end
  local API = _API()
  if not (API and API.GetData) then return false end
  local idx = _buildIndex()
  local pid = (idx.parentMap and idx.parentMap[id]) or nil
  if type(pid) ~= "string" or pid == "" then
    return false
  end
  local p = API:GetData(pid)
  local newPid = (type(p) == "table" and p.parent) or nil
  return self:SetParentAt(id, newPid, nil)
end


function M:RenameNode(id, newName)
  if type(id) ~= "string" or type(newName) ~= "string" then return false end
  local API = _API()
  if not (API and API.GetData and API.SetData) then return false end
  local d = API:GetData(id)
  if type(d) ~= "table" then return false end
  d.name = newName
  API:SetData(id, d)
  return true
end

function M:DeleteSubtree(rootId)
  if type(rootId) ~= "string" then return false end
  local API = _API()
  if not (API and API.GetData and API.Delete and API.SetData) then return false end

  local idx = _buildIndex()
  local ids = _subtreeIds(rootId, idx)

  -- detach root from parent order
  local pid = idx.parentMap and idx.parentMap[rootId] or nil
  if type(pid) == "string" then
    local pd = API:GetData(pid)
    if type(pd) == "table" and type(pd.controlledChildren) == "table" then
      _removeFromArray(pd.controlledChildren, rootId)
      API:SetData(pid, pd)
    end
  else
    local roots = _ensureRootChildren()
    _removeFromArray(roots, rootId)
  end

  -- delete nodes bottom-up
  for i = #ids, 1, -1 do
    local id = ids[i]
    -- hide runtime region if exists
    if self._regions and self._regions[id] and type(self._regions[id].Hide) == "function" then
      pcall(function() do local rf = self._regions[id]; _stopMotionCancel(rf); rf:Hide() end end)
      self._regions[id] = nil
    end
    API:Delete(id)
  end

  return true
end

function M:DuplicateSubtree(sourceId)
  if type(sourceId) ~= "string" then return nil end
  local API = _API()
  if not (API and API.GetData and API.SetData) then return nil end

  local idx = _buildIndex()
  local ids = _subtreeIds(sourceId, idx)
  local map = {}

  -- generate new ids
  for _, id in ipairs(ids) do
    map[id] = _genId("copy")
  end

  -- create copies
  for _, id in ipairs(ids) do
    local d = API:GetData(id)
    if type(d) == "table" then
      local nd = _deepcopy(d)
      nd.id = map[id]
      -- parent remap
      local pid = nd.parent
      if type(pid) == "string" and map[pid] then
        nd.parent = map[pid]
      end
      -- children remap
      if type(nd.controlledChildren) == "table" then
        local newCC = {}
        for _, cid in ipairs(nd.controlledChildren) do
          if map[cid] then table.insert(newCC, map[cid]) end
        end
        nd.controlledChildren = newCC
      end
      -- name hint
      if id == sourceId and type(nd.name) == "string" then
        -- Only rename the duplicated ROOT node. Keep children names unchanged.
        local sourceData = API:GetData(sourceId)
        local pid = sourceData and sourceData.parent or nil
        local siblings
        if type(pid) == "string" then
          local pd = API:GetData(pid)
          siblings = (type(pd) == "table" and type(pd.controlledChildren) == "table") and pd.controlledChildren or nil
        else
          siblings = _ensureRootChildren()
        end
        nd.name = _nextCopyNameLikeWA(nd.name, siblings, API)
      end
      API:SetData(nd.id, nd)
    end
  end

  -- insert new root next to source in parent's order
  local sourceData = API:GetData(sourceId)
  local pid = sourceData and sourceData.parent or nil
  local newRootId = map[sourceId]

  if type(pid) == "string" then
    local pd = API:GetData(pid)
    pd = pd or { id = pid, controlledChildren = {} }
    pd.controlledChildren = pd.controlledChildren or {}
    local inserted = false
    for i, cid in ipairs(pd.controlledChildren) do
      if cid == sourceId then
        table.insert(pd.controlledChildren, i+1, newRootId)
        inserted = true
        break
      end
    end
    if not inserted then table.insert(pd.controlledChildren, newRootId) end
    API:SetData(pid, pd)
  else
    local roots = _ensureRootChildren()
    local inserted = false
    for i, rid in ipairs(roots) do
      if rid == sourceId then
        table.insert(roots, i+1, newRootId)
        inserted = true
        break
      end
    end
    if not inserted then table.insert(roots, newRootId) end
  end

  return newRootId
end
