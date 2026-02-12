-- Bre/Core/TargetService.lua
-- Step M5: Align/target selection consolidation (no behavior change outside routing).
-- L1 connector: UI must not touch DB/Move directly for align targets.

local addonName, Bre = ...
Bre = Bre or {}

local Gate = Bre.Gate
local Registry = Bre.Registry

local TargetService = { __id = "TargetService" }

local function _API()
  return Gate and Gate.Get and Gate:Get("API_Data")
end

local function _Move()
  return Gate and Gate.Get and Gate:Get("Move")
end

local function _TreeIndex()
  return Gate and Gate.Get and Gate:Get("TreeIndex")
end

local function _ResolveTargetFrame()
  return Gate and Gate.Get and Gate:Get("ResolveTargetFrame")
end

local function _PS()
  return Gate and Gate.Get and Gate:Get("PropertyService")
end

local function _IterAllNodeIds()
  -- Prefer DB-backed TreeIndex when available; fall back to BrelmsSaved.displays.
  local T = _TreeIndex()
  if T and type(T.Build) == "function" then
    local idx = T:Build() or {}
    local seen = {}
    return coroutine.wrap(function()
      local function walk(id)
        if not id or seen[id] then return end
        seen[id] = true
        coroutine.yield(id)
        local kids = idx.childrenMap and idx.childrenMap[id]
        if type(kids) == "table" then
          for _, cid in ipairs(kids) do walk(cid) end
        end
      end
      if type(idx.roots) == "table" then
        for _, rid in ipairs(idx.roots) do walk(rid) end
      end
      -- Also yield any displays not present in index (safety)
      if BrelmsSaved and type(BrelmsSaved.displays) == "table" then
        for id, _ in pairs(BrelmsSaved.displays) do
          if type(id) == "string" and not seen[id] then coroutine.yield(id) end
        end
      end
    end)
  end

  return coroutine.wrap(function()
    if BrelmsSaved and type(BrelmsSaved.displays) == "table" then
      for id, _ in pairs(BrelmsSaved.displays) do
        if type(id) == "string" then coroutine.yield(id) end
      end
    end
  end)
end

local function _isRectCapable(obj)
  if not obj then return false end
  local ok, l, b, w, h = pcall(obj.GetRect, obj)
  return ok and l and b and w and h and w > 0 and h > 0
end

-- ----------------------------
-- Public API
-- ----------------------------

function TargetService:GetId()
  return self.__id
end

-- Align-to mode commit (structure-level field; execution stays in Move for now)
function TargetService:CommitAlignToMode(nodeId, mode)
  if type(nodeId) ~= "string" or nodeId == "" then return end
  mode = tostring(mode or "")
  local PS = _PS()
  if PS and type(PS.CommitAlignToMode) == "function" then
    PS:CommitAlignToMode(nodeId, mode)
    return
  end
  -- Fallback (older builds): still route via Move
  local Move = _Move()
  if Move and type(Move.CommitAnchorTarget) == "function" then
    Move:CommitAnchorTarget({ id = nodeId, value = mode })
  end
end

-- Commit selected anchor targetId into props.anchor (data-field normalization)
function TargetService:CommitAnchorTargetId(nodeId, targetId)
  if type(nodeId) ~= "string" or nodeId == "" then return end
  if type(targetId) ~= "string" or targetId == "" then return end

  local PS = _PS()
  if PS and type(PS.CommitAnchorTargetId) == "function" then
    PS:CommitAnchorTargetId(nodeId, targetId)
    return
  end

  -- Fallback (older builds): direct DB patch
  local API = _API()
  if not API or type(API.GetData) ~= "function" or type(API.SetData) ~= "function" then return end
  local d = API:GetData(nodeId)
  if type(d) ~= "table" then return end
  d.props = type(d.props) == "table" and d.props or {}
  d.props.anchor = type(d.props.anchor) == "table" and d.props.anchor or {}
  d.props.anchor.mode = "TARGET"
  d.props.anchor.targetId = targetId
  d.props.anchor.selfPoint = d.props.anchor.selfPoint or "CENTER"
  d.props.anchor.targetPoint = d.props.anchor.targetPoint or "CENTER"
  API:SetData(nodeId, d)
  local Move = _Move()
  if Move and type(Move.Refresh) == "function" then Move:Refresh(nodeId) end
end

-- Screen picking overlay (UI delegates here)
function TargetService:BeginPickTarget(activeId, onDone)
  if type(activeId) ~= "string" or activeId == "" then return end

  self._pickActiveId = activeId
  self._pickHoverId = nil
  self._pickOnDone = (type(onDone) == "function") and onDone or nil

  local ov = self:_EnsurePickOverlay()
  if ov then ov:Show() end
end

function TargetService:CancelPickTarget()
  if self._pickOverlay then self._pickOverlay:Hide() end
  if self._pickHL then self._pickHL:Hide() end
  self._pickActiveId = nil
  self._pickHoverId = nil
  self._pickOnDone = nil
end

-- ----------------------------
-- Internal: overlay + hover resolve
-- ----------------------------

function TargetService:_EnsurePickOverlay()
  if self._pickOverlay then return self._pickOverlay end

  local ov = CreateFrame("Button", "Brelms_PickOverlay", UIParent, "BackdropTemplate")
  ov:SetAllPoints(UIParent)
  ov:SetFrameStrata("TOOLTIP")
  ov:SetFrameLevel(9999)
  ov:EnableMouse(true)
  ov:SetAlpha(0.01)
  ov:Hide()

  local hl = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  hl:SetFrameStrata("TOOLTIP")
  hl:SetFrameLevel(9998)
  hl:SetBackdrop({ edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 12 })
  hl:SetBackdropBorderColor(1, 1, 0, 0.95)
  hl:Hide()

  self._pickOverlay = ov
  self._pickHL = hl

  ov:SetScript("OnUpdate", function()
    local a = self._pickActiveId
    if not a then return end
    local hid = self:_ResolveHoverTargetId(a)
    if hid ~= self._pickHoverId then
      self._pickHoverId = hid
      if hl then
        if hid then
          local rf = _ResolveTargetFrame()
          local f = rf and rf(hid)
          if f then
            hl:ClearAllPoints()
            hl:SetAllPoints(f)
            hl:Show()
          else
            hl:Hide()
          end
        else
          hl:Hide()
        end
      end
    end
  end)

  ov:SetScript("OnMouseUp", function()
    local a = self._pickActiveId
    local t = self._pickHoverId
    if a and t then
      self:CommitAnchorTargetId(a, t)
      if self._pickOnDone then pcall(self._pickOnDone, a, t) end
    end
    self:CancelPickTarget()
  end)

  return ov
end

function TargetService:_ResolveHoverTargetId(activeId)
  local rf = _ResolveTargetFrame()
  if not rf or type(rf) ~= "function" then return nil end

  local cx, cy = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  cx, cy = cx / scale, cy / scale

  local bestId, bestLvl
  for id in _IterAllNodeIds() do
    if id ~= activeId then
      local frame = rf(id)
      if frame and frame.IsShown and frame:IsShown() and _isRectCapable(frame) then
        local ok, l, b, w, h = pcall(frame.GetRect, frame)
        if ok and l and b and w and h and cx >= l and cx <= (l + w) and cy >= b and cy <= (b + h) then
          local lvl = 0
          local ok2, fl = pcall(frame.GetFrameLevel, frame)
          if ok2 and fl then lvl = fl end
          if not bestId or lvl >= (bestLvl or -1) then
            bestId, bestLvl = id, lvl
          end
        end
      end
    end
  end
  return bestId
end

-- -------------------------------------------------------------------
-- Registry / Gate exposure

local function _stub()
  return {
    CommitAlignToMode = function() end,
    CommitAnchorTargetId = function() end,
    BeginPickTarget = function() end,
    CancelPickTarget = function() end,
  }
end

if Registry and Registry.Register then
  Registry:Register({
    id = "TargetService",
    layer = "L1",
    desc = "Align/anchor target selection service",
    exports = { "TargetService" },
    defaults = {
      { iface = "TargetService", policy = "no-op", stub = _stub() },
    },
    init = function()
      return TargetService
    end,
  })
end

Bre.TargetService = TargetService
return TargetService
