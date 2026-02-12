-- Bre/Core/PropertyService.lua
-- L1: PropertyService - unified entry for attribute/property changes.
-- Step1 (v2.12.0): skeleton only; not yet wired into UI.

local addonName, Bre = ...
Bre = Bre or {}

Bre.PropertyService = Bre.PropertyService or {}

local PS = Bre.PropertyService

local function _getData(id)
  if type(Bre.GetData) == 'function' then
    return Bre.GetData(id)
  end
  return nil
end

local function _setData(id, data)
  if type(Bre.SetData) == 'function' then
    return Bre.SetData(id, data)
  end
  return nil
end

local function _ensureRegion(data)
  data.region = type(data.region) == 'table' and data.region or {}
  return data
end

local function _ensureSize(data)
  data.size = type(data.size) == 'table' and data.size or {}
  return data
end

local function _ensureProps(data)
  data.props = type(data.props) == 'table' and data.props or {}
  return data
end


local function _ensureActions(data)
  data.actions = type(data.actions) == 'table' and data.actions or {}
  data.actions.rotate = type(data.actions.rotate) == 'table' and data.actions.rotate or {}
  return data
end

-- API: Normalize/Validate (pure)
function PS:Normalize(propKey, value)
  if propKey == 'group.scale' then
    local v = tonumber(value)
    if not v then return 1 end
    if v < 0.6 then v = 0.6 end
    if v > 1.4 then v = 1.4 end
    -- keep one decimal step
    v = math.floor(v * 10 + 0.5) / 10
    return v
  end

  if propKey == 'group.iconPath' then
    local v = tostring(value or "")
    -- trim
    v = v:gsub("^%s+", ""):gsub("%s+$", "")
    return v
  end

  if propKey == 'stopmotion.path' then
    local v = tostring(value or "")
    v = v:gsub("^%s+", ""):gsub("%s+$", "")
    return v
  end

  if propKey == 'stopmotion.fps' then
    local v = tonumber(value)
    if not v then return 1 end
    v = math.floor(v)
    if v < 1 then v = 1 end
    if v > 60 then v = 60 end
    return v
  end

  if propKey == 'stopmotion.mode' then
    local v = tostring(value or 'loop')
    if v ~= 'loop' and v ~= 'once' and v ~= 'bounce' then
      v = 'loop'
    end
    return v
  end

  if propKey == 'stopmotion.inverse' then
    return value and true or false
  end

  if propKey == 'stopmotion.useAdvanced' then
    return value and true or false
  end

  if propKey == 'stopmotion.fileW' or propKey == 'stopmotion.fileH' or propKey == 'stopmotion.frameW' or propKey == 'stopmotion.frameH' then
    local v = tonumber(value)
    if not v then return 0 end
    v = math.floor(v)
    if v < 0 then v = 0 end
    return v
  end

  if propKey == 'scale' then
    local v = tonumber(value)
    if not v then return 1 end
    if v < 0.1 then v = 0.1 end
    if v > 5.0 then v = 5.0 end
    v = math.floor(v * 100 + 0.5) / 100
    return v
  end

  if propKey == 'alpha' then
    local v = tonumber(value)
    if not v then return 1 end
    if v < 0 then v = 0 end
    if v > 1 then v = 1 end
    return v
  end

  if propKey == 'rotation' or propKey == 'region.rotation' then
    local v = tonumber(value)
    if not v then return 0 end
    -- Keep degrees in a predictable range (avoid huge values)
    if v > 360 then v = 360 end
    if v < -360 then v = -360 end
    return v
  end

  if propKey == 'mirror' or propKey == 'region.mirror' then
    return value and true or false
  end

  if propKey == 'fade' or propKey == 'desaturate' or propKey == 'region.desaturate' then
    return value and true or false
  end

  if propKey == 'blendMode' or propKey == 'region.blendMode' then
    local v = tostring(value or 'BLEND')
    -- Accept only known WoW blend modes
    if v ~= 'BLEND' and v ~= 'ADD' and v ~= 'MOD' and v ~= 'ALPHAKEY' then
      v = 'BLEND'
    end
    return v
  end

  if propKey == 'sizeW' or propKey == 'size.width' then
    local v = tonumber(value)
    if not v then return nil end
    v = math.floor(v + 0.5)
    if v < 1 then v = 1 end
    if v > 2048 then v = 2048 end
    return v
  end

  if propKey == 'sizeH' or propKey == 'size.height' then
    local v = tonumber(value)
    if not v then return nil end
    v = math.floor(v + 0.5)
    if v < 1 then v = 1 end
    if v > 2048 then v = 2048 end
    return v
  end


  if propKey == 'modelMode' then
    local v = tostring(value or 'unit')
    if v ~= 'unit' and v ~= 'file' then v = 'unit' end
    return v
  end

  if propKey == 'modelUnit' then
    local v = tostring(value or 'player')
    if v ~= 'player' and v ~= 'target' and v ~= 'focus' then v = 'player' end
    return v
  end

  if propKey == 'modelFileID' then
    local n = tonumber(value)
    if not n or n < 0 then return nil end
    return math.floor(n + 0.5)
  end

  if propKey == 'facing' then
    local v = tonumber(value)
    if not v then return 0 end
    -- Normalize to 0-360 range
    v = v % 360
    if v < 0 then v = v + 360 end
    return v
  end

  if propKey == 'animSequence' then
    local v = tonumber(value)
    if not v then return 0 end
    -- Clamp to 0-1499 range (WA convention)
    if v < 0 then v = 0 end
    if v > 1499 then v = 1499 end
    return math.floor(v)
  end

  return value
end

-- API: Read (no side effects)
function PS:Get(nodeId, propKey)
  if not nodeId then return nil end
  local data = _getData(nodeId)
  if type(data) ~= 'table' then return nil end

  if propKey == 'group.scale' then
    local g = type(data.group) == 'table' and data.group or {}
    return tonumber(g.scale) or 1
  end

  if propKey == 'scale' then
    return tonumber(data.scale) or 1
  end

  if propKey == 'alpha' then
    return tonumber(data.alpha) or 1
  end
  if propKey == 'rotation' or propKey == 'region.rotation' then
    local region = type(data.region) == 'table' and data.region or {}
    return tonumber(region.rotation) or 0
  end

  if propKey == 'mirror' or propKey == 'region.mirror' then
    local region = type(data.region) == 'table' and data.region or {}
    return region.mirror and true or false
  end

  if propKey == 'fade' or propKey == 'desaturate' or propKey == 'region.desaturate' then
    local region = type(data.region) == 'table' and data.region or {}
    return region.desaturate and true or false
  end

  if propKey == 'blendMode' or propKey == 'region.blendMode' then
    local region = type(data.region) == 'table' and data.region or {}
    return tostring(region.blendMode or 'BLEND')
  end

  if propKey == 'sizeW' or propKey == 'size.width' then
    local size = type(data.size) == 'table' and data.size or {}
    return tonumber(size.width) or 200
  end

  if propKey == 'sizeH' or propKey == 'size.height' then
    local size = type(data.size) == 'table' and data.size or {}
    return tonumber(size.height) or 200
  end


  if propKey == 'modelMode' then
    return tostring(data.modelMode or 'unit')
  end
  if propKey == 'modelUnit' then
    return tostring(data.modelUnit or 'player')
  end
  if propKey == 'modelFileID' then
    return tonumber(data.modelFileID)
  end
  if propKey == 'facing' then
    return tonumber(data.facing) or 0
  end
  if propKey == 'animSequence' then
    return tonumber(data.animSequence) or 0
  end

  if propKey == 'stopmotion.path' then
    if type(data.stopmotion) == 'table' then
      return tostring(data.stopmotion.path or "")
    end
    return ""
  end

  return nil
end

-- API: Set (commit-intent)
function PS:Set(nodeId, propKey, value, opts)
  
  if not nodeId or not propKey then
    return false
  end
  local Gate = Bre.Gate
  local EG = Gate and Gate.Get and Gate:Get('EditGuard') or nil
  if EG and EG.IsGuarded and EG:IsGuarded() then
    return false
  end

  local data = _getData(nodeId)
  if type(data) ~= 'table' then return false end
  local v = self:Normalize(propKey, value)

  if propKey == 'group.scale' then
    -- Only groups use this prop; store in data.group.scale
    local old = 1
    if type(data.group) == 'table' and type(data.group.scale) == 'number' then
      old = data.group.scale
    elseif type(data.group) == 'table' then
      old = tonumber(data.group.scale) or 1
    end
    old = self:Normalize('group.scale', old)
    data.group = type(data.group) == 'table' and data.group or {}
    data.group.scale = v
    _setData(nodeId, data)

    -- Notify GroupScaleService (event-driven). No UI side effects.
    local Gate = Bre.Gate
    local GS = Gate and Gate.Get and Gate:Get('GroupScaleService') or nil
    if GS and GS.ApplyTopGroupScale then
      pcall(function() GS:ApplyTopGroupScale(nodeId, old, v) end)
    end
    return true
  end

  if propKey == 'stopmotion.path' then
    data.stopmotion = type(data.stopmotion) == 'table' and data.stopmotion or {}
    data.stopmotion.path = v or ""
    _setData(nodeId, data)

    -- Live refresh: ensure runtime element updates immediately (no /reload required).
    local Gate = Bre.Gate
    local Move = Gate and Gate.Get and Gate:Get('Move') or nil
    if Move and Move.Refresh then
      pcall(Move.Refresh, Move, nodeId)
    end
    return true
  end

  -- StopMotion basic slicing params (v2.19.28): rows/cols/frames
  -- Store under data.stopmotion.* so DrawerSpec_StopMotion:Refresh can backfill.
  if propKey == 'stopmotion.rows' or propKey == 'stopmotion.cols' or propKey == 'stopmotion.frames' then
    data.stopmotion = type(data.stopmotion) == 'table' and data.stopmotion or {}
    -- Allow 0 as "unset" but persist the number so UI does not clear unexpectedly.
    data.stopmotion[propKey:sub(#'stopmotion.' + 1)] = tonumber(v) or 0
    _setData(nodeId, data)

    -- Live refresh: slice params must update runtime visuals immediately.
    local Gate = Bre.Gate
    local Move = Gate and Gate.Get and Gate:Get('Move') or nil
    if Move and Move.Refresh then
      pcall(Move.Refresh, Move, nodeId)
    end
    return true
  end


  -- StopMotion advanced slicing params (v2.19.36): fileW/fileH/frameW/frameH
  if propKey == 'stopmotion.fileW' or propKey == 'stopmotion.fileH' or propKey == 'stopmotion.frameW' or propKey == 'stopmotion.frameH' then
    data.stopmotion = type(data.stopmotion) == 'table' and data.stopmotion or {}
    local k = propKey:sub(#'stopmotion.' + 1)
    data.stopmotion[k] = tonumber(v) or 0
    _setData(nodeId, data)

    -- Live refresh: advanced slicing affects texcoord, refresh runtime immediately.
    local Gate = Bre.Gate
    local Move = Gate and Gate.Get and Gate:Get('Move') or nil
    if Move and Move.Refresh then
      pcall(Move.Refresh, Move, nodeId)
    end
    return true
  end

  -- StopMotion playback params (v2.19.33): fps / mode / inverse
  if propKey == 'stopmotion.fps' or propKey == 'stopmotion.mode' or propKey == 'stopmotion.inverse' then
    data.stopmotion = type(data.stopmotion) == 'table' and data.stopmotion or {}
    local k = propKey:sub(#'stopmotion.' + 1)
    if k == 'fps' then
      data.stopmotion.fps = tonumber(v) or 1
    elseif k == 'mode' then
      data.stopmotion.mode = tostring(v or 'loop')
    elseif k == 'inverse' then
      data.stopmotion.inverse = v and true or false
    end
    _setData(nodeId, data)

    -- Live refresh: playback params must update runtime immediately.
    local Gate = Bre.Gate
    local Move = Gate and Gate.Get and Gate:Get('Move') or nil
    if Move and Move.Refresh then
      pcall(Move.Refresh, Move, nodeId)
    end
    return true
  end

  -- StopMotion source-of-truth toggle (v2.19.38): useAdvanced
  if propKey == 'stopmotion.useAdvanced' then
    data.stopmotion = type(data.stopmotion) == 'table' and data.stopmotion or {}
    data.stopmotion.useAdvanced = v and true or false
    _setData(nodeId, data)

    -- Live refresh: switching slicing source affects texcoord, refresh runtime immediately.
    local Gate = Bre.Gate
    local Move = Gate and Gate.Get and Gate:Get('Move') or nil
    if Move and Move.Refresh then
      pcall(Move.Refresh, Move, nodeId)
    end
    return true
  end


  if propKey == 'group.iconPath' then
    -- Only groups; store in data.group.iconPath (string). Empty means "inherit".
    if type(data.type) == 'string' and data.type ~= 'group' then
      return false
    end
    data.group = data.group or {}
    data.group.iconPath = v or ""
    _setData(nodeId, data)
    return true
  end

  if propKey == 'stopmotion.path' then
    -- StopMotion: store in data.stopmotion.path (string)
    data.stopmotion = type(data.stopmotion) == 'table' and data.stopmotion or {}
    data.stopmotion.path = v or ""
    _setData(nodeId, data)
    return true
  end

  if propKey == 'scale' then
    data.scale = v
    _setData(nodeId, data)
    -- Render will pick it up; no extra side effects here.
    return true
  end

  if propKey == 'alpha' then
    data.alpha = v
  elseif propKey == 'rotation' or propKey == 'region.rotation' then
    data = _ensureRegion(data)
    data.region.rotation = v
  elseif propKey == 'mirror' or propKey == 'region.mirror' then
    data = _ensureRegion(data)
    data.region.mirror = v
  elseif propKey == 'fade' or propKey == 'desaturate' or propKey == 'region.desaturate' then
    data = _ensureRegion(data)
    data.region.desaturate = v
  elseif propKey == 'blendMode' or propKey == 'region.blendMode' then
    data = _ensureRegion(data)
    data.region.blendMode = v
  elseif propKey == 'sizeW' or propKey == 'size.width' then
    data = _ensureSize(data)
    if v ~= nil then data.size.width = v end
  elseif propKey == 'sizeH' or propKey == 'size.height' then
    data = _ensureSize(data)
    if v ~= nil then data.size.height = v end
  -- ProgressMat properties (v2.15.9)
  elseif propKey == 'foreground' then
    local wasEmpty = (not data.foreground or data.foreground == "")
    data.foreground = v
    if Bre.DEBUG then print("[PropertyService] Set foreground: " .. tostring(v)) end
    
    -- If this is the first time setting foreground (new progress element),
    -- we need to force Move to rebuild the region to ensure proper texture initialization
    if wasEmpty and v and v ~= "" and data.regionType == "progress" then
      if Bre.DEBUG then print("[PropertyService] First foreground set detected, will force region rebuild") end
      -- Mark that we need to rebuild region after SetData
      data._needsRegionRebuild = true
    end
  elseif propKey == 'background' then
    data.background = v
    if Bre.DEBUG then print("[PropertyService] Set background: " .. tostring(v)) end
  elseif propKey == 'mask' then
    data.mask = v
  elseif propKey == 'materialType' then
    data.materialType = v
    if Bre.DEBUG then print("[PropertyService] Set materialType: " .. tostring(v)) end
  elseif propKey == 'progressType' then
    data.progressType = v
  elseif propKey == 'progressUnit' then
    data.progressUnit = v
  elseif propKey == 'progressAlgorithm' then
    data.progressAlgorithm = v
    if Bre.DEBUG then print("[PropertyService] Set progressAlgorithm: " .. tostring(v)) end
  elseif propKey == 'progressShape' then
    -- Legacy support: redirect to progressAlgorithm
    data.progressAlgorithm = v
    if Bre.DEBUG then print("[PropertyService] Set progressShape (legacy) -> progressAlgorithm: " .. tostring(v)) end
  elseif propKey == 'progressDirection' then
    data.progressDirection = v
    if Bre.DEBUG then print("[PropertyService] Set progressDirection: " .. tostring(v)) end
  elseif propKey == 'fgColor' then
    data.fgColor = v
  elseif propKey == 'bgColor' then
    data.bgColor = v
  elseif propKey == 'xOffset' then
    data = _ensureProps(data)
    data.props.xOffset = v
  elseif propKey == 'yOffset' then
    data = _ensureProps(data)
    data.props.yOffset = v
  elseif propKey == 'frameStrata' then
    data = _ensureProps(data)
    data.props.frameStrata = v
    if Bre.DEBUG then print("[PropertyService] Set frameStrata: " .. tostring(v)) end
  elseif propKey == 'anchorTarget' then
    data = _ensureProps(data)
    data.props.anchorTarget = v
    if Bre.DEBUG then print("[PropertyService] Set anchorTarget: " .. tostring(v)) end

  -- Output Actions: rotate (v2.18.58)
  elseif propKey:match('^actions%.rotate%.') then
    data = _ensureActions(data)
    local key = propKey:sub(#'actions.rotate.' + 1)
    if key == 'enabled' then data.actions.rotate.enabled = v
    elseif key == 'loop' then data.actions.rotate.loop = v
    elseif key == 'duration' then data.actions.rotate.duration = v
    elseif key == 'speed' then data.actions.rotate.speed = v
    elseif key == 'delay' then data.actions.rotate.delay = v
    elseif key == 'angle' then data.actions.rotate.angle = v
    elseif key == 'dir' then data.actions.rotate.dir = v
    elseif key == 'anchor' then data.actions.rotate.anchor = v
    elseif key == 'endState' then data.actions.rotate.endState = v
    else
      return false
    end


  -- Model properties (v2.18.78)
  elseif propKey == 'modelMode' then
    data.modelMode = v
  elseif propKey == 'modelUnit' then
    data.modelUnit = v
  elseif propKey == 'modelFileID' then
    data.modelFileID = v
  elseif propKey == 'facing' then
    data.facing = v
  elseif propKey == 'animSequence' then
    data.animSequence = v

  else
    return false
  end

  _setData(nodeId, data)

  local Move = Gate and Gate.Get and Gate:Get('Move') or nil
  -- Region rebuild is handled by Move:Refresh (via the public region lifecycle API).

  -- Now Move supports progress textures, so we can use Move.Refresh for all elements
  if Move and Move.Refresh then
    pcall(Move.Refresh, Move, nodeId)
  end
  
  return true
end

  -- API: PreviewSet (no DB write, no commit)
-- Used for live UI preview while dragging sliders.
function PS:PreviewSet(nodeId, propKey, value, opts)
  if not nodeId or not propKey then return false end
  local Gate = Bre.Gate
  local EG = Gate and Gate.Get and Gate:Get('EditGuard') or nil
  if EG and EG.IsGuarded and EG:IsGuarded() then
    return false
  end

  local data = _getData(nodeId)
  if type(data) ~= 'table' then return false end

  -- shallow copy is enough (we only patch nested sub-tables we touch)
  local tmp = {}
  for k, v in pairs(data) do tmp[k] = v end

  local v = self:Normalize(propKey, value)

  if propKey == 'alpha' then
    tmp.alpha = v
  elseif propKey == 'rotation' or propKey == 'region.rotation' then
    tmp = _ensureRegion(tmp)
    tmp.region.rotation = v
  elseif propKey == 'mirror' or propKey == 'region.mirror' then
    tmp = _ensureRegion(tmp)
    tmp.region.mirror = v
  elseif propKey == 'fade' or propKey == 'desaturate' or propKey == 'region.desaturate' then
    tmp = _ensureRegion(tmp)
    tmp.region.desaturate = v
  elseif propKey == 'blendMode' or propKey == 'region.blendMode' then
    tmp = _ensureRegion(tmp)
    tmp.region.blendMode = v
  elseif propKey == 'sizeW' or propKey == 'size.width' then
    tmp = _ensureSize(tmp)
    if v ~= nil then tmp.size.width = v end
  elseif propKey == 'sizeH' or propKey == 'size.height' then
    tmp = _ensureSize(tmp)
    if v ~= nil then tmp.size.height = v end

  -- Output Actions: rotate (v2.18.58)
  elseif propKey:match('^actions%.rotate%.') then
    tmp = _ensureActions(tmp)
    local key = propKey:sub(#'actions.rotate.' + 1)
    if key == 'enabled' then tmp.actions.rotate.enabled = v
    elseif key == 'loop' then tmp.actions.rotate.loop = v
    elseif key == 'duration' then tmp.actions.rotate.duration = v
    elseif key == 'speed' then tmp.actions.rotate.speed = v
    elseif key == 'delay' then tmp.actions.rotate.delay = v
    elseif key == 'angle' then
      tmp.actions.rotate.angle = v
      -- preview effect: map to region.rotation (degrees) for immediate visual feedback
      tmp = _ensureRegion(tmp)
      local dir = tmp.actions.rotate.dir or 'cw'
      local sign = (dir == 'ccw') and -1 or 1
      tmp.region.rotation = (tonumber(v) or 0) * sign
    elseif key == 'dir' then
      tmp.actions.rotate.dir = v
      -- preview effect: update region.rotation sign using current angle
      tmp = _ensureRegion(tmp)
      local angle = tonumber(tmp.actions.rotate.angle) or 0
      local sign = (v == 'ccw') and -1 or 1
      tmp.region.rotation = angle * sign
    elseif key == 'anchor' then tmp.actions.rotate.anchor = v
    elseif key == 'endState' then tmp.actions.rotate.endState = v
    else
      return false
    end

  else
    return false
  end

  -- Preview should not double-render. Prefer updating the runtime region via Move (no DB write),
  -- fallback to Render-only preview when runtime renderer is unavailable.
  local Move = Gate and Gate.Get and Gate:Get('Move') or nil
  if Move and Move.ApplyElement then
    pcall(Move.ApplyElement, Move, nodeId, tmp)
  else
    local Render = Gate and Gate.Get and Gate:Get('Render') or nil
    if Render and Render.ShowForElement then
      pcall(Render.ShowForElement, Render, nodeId, tmp)
    end
  end

  return true, tmp
end

-- ------------------------------------------------------------
-- Anchor / Align (Step11)
-- Centralize anchor-target data writes here so that UI and other
-- L1 connectors do not touch DB/Move directly.
-- ------------------------------------------------------------

-- Align-to mode commit: execution stays in Move for now.
function PS:CommitAlignToMode(nodeId, mode)
  if type(nodeId) ~= "string" or nodeId == "" then return false end
  mode = tostring(mode or "")
  local Gate = Bre.Gate
  local Move = Gate and Gate.Get and Gate:Get('Move') or nil
  if Move and type(Move.CommitAnchorTarget) == "function" then
    pcall(Move.CommitAnchorTarget, Move, { id = nodeId, value = mode })
    return true
  end
  return false
end

-- Commit selected anchor target and points into props.anchor.
-- This is a data-field update + refresh (no special execution).
function PS:CommitAnchorTargetId(nodeId, targetId, selfPoint, targetPoint)
  if type(nodeId) ~= "string" or nodeId == "" then return false end
  if type(targetId) ~= "string" or targetId == "" then return false end

  local data = _getData(nodeId)
  if type(data) ~= 'table' then return false end

  data.props = type(data.props) == 'table' and data.props or {}
  data.props.anchor = type(data.props.anchor) == 'table' and data.props.anchor or {}

  data.props.anchor.mode = 'TARGET'
  data.props.anchor.targetId = targetId
  data.props.anchor.selfPoint = selfPoint or data.props.anchor.selfPoint or 'CENTER'
  data.props.anchor.targetPoint = targetPoint or data.props.anchor.targetPoint or 'CENTER'

  _setData(nodeId, data)

  local Gate = Bre.Gate
  local Move = Gate and Gate.Get and Gate:Get('Move') or nil
  if Move and Move.Refresh then
    pcall(Move.Refresh, Move, nodeId)
  end
  return true
end

-- API: PreviewApply (batch; no DB write, no commit)
function PS:PreviewApply(nodeId, patch, opts)
  if type(patch) == "table" then
    for k, v in pairs(patch) do
      print("  " .. tostring(k) .. " = " .. tostring(v))
    end
  end
  
  if type(patch) ~= 'table' then return false end
  local Gate = Bre.Gate
  local EG = Gate and Gate.Get and Gate:Get('EditGuard') or nil
  if EG and EG.IsGuarded and EG:IsGuarded() then
    return false
  end

  local data = _getData(nodeId)
  if type(data) ~= 'table' then return false end

  local tmp = {}
  for k, v in pairs(data) do tmp[k] = v end

  local okAny = false
  for k, v in pairs(patch) do
    local vv = self:Normalize(k, v)
    if k == 'alpha' then
      tmp.alpha = vv
      okAny = true
    elseif k == 'rotation' or k == 'region.rotation' then
      tmp = _ensureRegion(tmp)
      tmp.region.rotation = vv
      okAny = true
    elseif k == 'blendMode' or k == 'region.blendMode' then
      tmp = _ensureRegion(tmp)
      tmp.region.blendMode = vv
      okAny = true
    elseif k == 'mirror' or k == 'region.mirror' then
      tmp = _ensureRegion(tmp)
      tmp.region.mirror = vv
      okAny = true
    elseif k == 'fade' or k == 'desaturate' or k == 'region.desaturate' then
      tmp = _ensureRegion(tmp)
      tmp.region.desaturate = vv
      okAny = true
    elseif k == 'sizeW' or k == 'size.width' then
      tmp = _ensureSize(tmp)
      if vv ~= nil then tmp.size.width = vv end
      okAny = true
    elseif k == 'sizeH' or k == 'size.height' then
      tmp = _ensureSize(tmp)
      if vv ~= nil then tmp.size.height = vv end
      okAny = true
    elseif k == 'foreground' then
      tmp.foreground = vv
      okAny = true
    elseif k == 'background' then
      tmp.background = vv
      okAny = true
    elseif k == 'mask' then
      tmp.mask = vv
      okAny = true
    end
  end

  if okAny then
    -- For progress bar elements, always use Render (Move doesn't support progress textures)
    local data = _getData(nodeId)
    local isProgress = (data and data.regionType == "progress")
    
    
    if isProgress then
      local Render = Gate and Gate.Get and Gate:Get('Render') or nil
      if Render and Render.ShowForElement then
        pcall(Render.ShowForElement, Render, nodeId, tmp)
      else
      end
    else
      local Move = Gate and Gate.Get and Gate:Get('Move') or nil
      if Move and Move.ApplyElement then
        pcall(Move.ApplyElement, Move, nodeId, tmp)
      else
        local Render = Gate and Gate.Get and Gate:Get('Render') or nil
        if Render and Render.ShowForElement then
          pcall(Render.ShowForElement, Render, nodeId, tmp)
        end
      end
    end
    return true, tmp
  end

  return false
end

-- API: Apply (batch)
function PS:Apply(nodeId, patch, opts)
  if type(patch) ~= 'table' then return false end
  local okAny = false
  local lastData = nil
  for k, v in pairs(patch) do
    local ok, data = self:Set(nodeId, k, v, opts)
    if ok then
      okAny = true
      lastData = data
    end
  end
  return okAny, lastData
end

-- Module is exported via Bre.PropertyService (already defined at top)
if Bre.PropertyService then
end

-- API: CommitOffsets (specialized commit path)
-- Used by DrawerTemplate position controls to update x/y offsets via the unified L1 edit入口.
function PS:CommitOffsets(nodeId, xOffset, yOffset)
  if not nodeId then return false end
  local Gate = Bre and Bre.Gate
  local Move = Gate and Gate.Get and Gate:Get('Move') or nil
  if not Move or not Move.CommitOffsets then return false end

  -- Normalize
  xOffset = tonumber(xOffset) or 0
  yOffset = tonumber(yOffset) or 0

  return Move:CommitOffsets({ id = nodeId, xOffset = xOffset, yOffset = yOffset })
end

-- API: CommitAlpha (specialized commit path)
-- Used by DrawerTemplate alpha controls to update element alpha via the unified L1 edit入口.
function PS:CommitAlpha(nodeId, alpha)
  if not nodeId then return false end
  local Gate = Bre and Bre.Gate
  local EG = Gate and Gate.Get and Gate:Get('EditGuard') or nil
  if EG and EG.IsGuarded and EG:IsGuarded() then return false end

  alpha = tonumber(alpha) or 1
  if alpha < 0 then alpha = 0 elseif alpha > 1 then alpha = 1 end

  local ok = self:Set(nodeId, 'alpha', alpha)
  return ok and true or false
end


-- API: CommitSize (specialized commit path)
-- Used by DrawerTemplate size controls to update element width/height via the unified L1 edit入口.
function PS:CommitSize(nodeId, sizeW, sizeH)
  if not nodeId then return false end
  local Gate = Bre and Bre.Gate
  local EG = Gate and Gate.Get and Gate:Get('EditGuard') or nil
  if EG and EG.IsGuarded and EG:IsGuarded() then return false end

  sizeW = tonumber(sizeW) or 300
  sizeH = tonumber(sizeH) or 300
  if sizeW < 1 then sizeW = 1 elseif sizeW > 2048 then sizeW = 2048 end
  if sizeH < 1 then sizeH = 1 elseif sizeH > 2048 then sizeH = 2048 end

  -- Keep behavior stable: two sets (applies twice) but safe/minimal change for Step10.
  local okW = self:Set(nodeId, 'sizeW', sizeW)
  local okH = self:Set(nodeId, 'sizeH', sizeH)
  return (okW or okH) and true or false
end

-- API: CommitFrameStrata (specialized commit path)
-- Used by DrawerTemplate position controls to update frame strata via the unified L1 edit入口.
function PS:CommitFrameStrata(nodeId, frameStrata)
  if not nodeId then return false end
  local Gate = Bre and Bre.Gate
  local EG = Gate and Gate.Get and Gate:Get('EditGuard') or nil
  if EG and EG.IsGuarded and EG:IsGuarded() then return false end

  frameStrata = frameStrata or "AUTO"
  return self:Set(nodeId, 'frameStrata', frameStrata) and true or false
end
