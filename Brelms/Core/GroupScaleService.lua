-- Bre/Core/GroupScaleService.lua
-- L1: GroupScaleService - apply group scale to descendants (event-driven, passive).
-- v2.19.10: group.scale is LOCAL per-group; element effective scale = product of ancestor group scales.
--           Parent/child group scales no longer overwrite each other.

local addonName, Bre = ...
Bre = Bre or {}

Bre.GroupScaleService = Bre.GroupScaleService or {}
local GS = Bre.GroupScaleService

local Gate = Bre.Gate

local function _GetData(id)
  if type(Bre.GetData) == 'function' then
    return Bre.GetData(id)
  end
  return nil
end

local function _IsGroup(data)
  if type(data) ~= 'table' then return false end
  local rt = tostring(data.regionType or '')
  return (rt == 'group' or rt == 'dynamicgroup')
end

local function _GetCenterXY(data)
  if type(data) ~= 'table' then return 0, 0 end
  local pos = type(data.position) == 'table' and data.position or nil
  if pos and type(pos.x) == 'number' and type(pos.y) == 'number' then
    return pos.x, pos.y
  end
  local props = type(data.props) == 'table' and data.props or {}
  return tonumber(props.xOffset) or 0, tonumber(props.yOffset) or 0
end

local function _ClampScale(v)
  v = tonumber(v) or 1
  if v < 0.6 then v = 0.6 end
  if v > 1.4 then v = 1.4 end
  -- Keep one decimal step (0.1)
  v = math.floor(v * 10 + 0.5) / 10
  return v
end

local function _GetParentId(data)
  if type(data) ~= 'table' then return nil end
  local p = data.parent
  if type(p) == 'string' and p ~= '' then return p end
  return nil
end

local function _CollectDescendants(rootId, out)
  local root = _GetData(rootId)
  if type(root) ~= 'table' then return out end
  local kids = type(root.controlledChildren) == 'table' and root.controlledChildren or {}
  for _, cid in ipairs(kids) do
    if type(cid) == 'string' and cid ~= '' then
      local cdata = _GetData(cid)
      if type(cdata) == 'table' then
        table.insert(out, cid)
        if _IsGroup(cdata) then
          _CollectDescendants(cid, out)
        end
      end
    end
  end
  return out
end

local function _GetLocalGroupScale(groupId)
  local g = _GetData(groupId)
  if type(g) ~= 'table' then return 1 end
  local gs = 1
  if type(g.group) == 'table' then
    gs = tonumber(g.group.scale) or 1
  end
  return _ClampScale(gs)
end

-- Ensure the top-level group's center is a stable, persisted pivot.
-- If the group has never been positioned, pin its center to the current
-- descendant elements' bbox center (one-time) to avoid drifting towards (0,0).
local function _EnsureGroupCenterPinned(groupId)
  if type(groupId) ~= 'string' or groupId == '' then return 0, 0 end
  local g = _GetData(groupId)
  if type(g) ~= 'table' then return 0, 0 end
  if not _IsGroup(g) then
    return _GetCenterXY(g)
  end

  g.group = type(g.group) == 'table' and g.group or {}
  if g.group.__centerPinned then
    return _GetCenterXY(g)
  end

  local ids = _CollectDescendants(groupId, {})
  local minx, maxx, miny, maxy
  for _, id in ipairs(ids) do
    local d = _GetData(id)
    if type(d) == 'table' and (not _IsGroup(d)) then
      local x, y = _GetCenterXY(d)
      if type(x) == 'number' and type(y) == 'number' then
        if minx == nil or x < minx then minx = x end
        if maxx == nil or x > maxx then maxx = x end
        if miny == nil or y < miny then miny = y end
        if maxy == nil or y > maxy then maxy = y end
      end
    end
  end

  local cx, cy
  if minx ~= nil then
    cx = (minx + maxx) / 2
    cy = (miny + maxy) / 2
  else
    cx, cy = _GetCenterXY(g)
  end

  local Move = Gate and Gate.Get and Gate:Get('Move') or nil
  if Move and Move.CommitOffsets then
    pcall(function() Move:CommitOffsets({ id = groupId, xOffset = cx, yOffset = cy }) end)
  end

  g = _GetData(groupId) or g
  g.group = type(g.group) == 'table' and g.group or {}
  g.group.__centerPinned = true
  if type(Bre.SetData) == 'function' then
    pcall(function() Bre.SetData(groupId, g) end)
  end

  return cx, cy
end

-- Effective scale for a node = product of ALL ancestor group local scales.
function GS:GetEffectiveScaleFor(nodeId)
  if type(nodeId) ~= 'string' or nodeId == '' then return 1 end
  local curId = nodeId
  local eff = 1
  local guard = 0
  while curId and guard < 120 do
    guard = guard + 1
    local d = _GetData(curId)
    if type(d) ~= 'table' then break end
    local pid = _GetParentId(d)
    if not pid then break end
    local pd = _GetData(pid)
    if type(pd) == 'table' and _IsGroup(pd) then
      eff = eff * _GetLocalGroupScale(pid)
    end
    curId = pid
  end
  return _ClampScale(eff)
end

local function _CollectSubtree(rootId, out)
  out = out or {}
  if type(rootId) ~= 'string' or rootId == '' then return out end
  table.insert(out, rootId)
  local root = _GetData(rootId)
  if type(root) ~= 'table' then return out end
  if _IsGroup(root) then
    _CollectDescendants(rootId, out)
  end
  return out
end

function GS:ApplyEffectiveScaleOnly(rootId)
  if type(rootId) ~= 'string' or rootId == '' then return false end
  local PS = Gate and Gate.Get and Gate:Get('PropertyService') or nil
  if not (PS and PS.Set) then return false end

  local ids = _CollectSubtree(rootId, {})
  for _, id in ipairs(ids) do
    local d = _GetData(id)
    if type(d) == 'table' and (not _IsGroup(d)) then
      local target = self:GetEffectiveScaleFor(id)
      pcall(function() PS:Set(id, 'scale', target) end)
    end
  end
  return true
end

-- Apply a LOCAL scale change to all descendants of a group, around the group's center.
-- oldScale/newScale are the group's local scales (ratio k = new/old) for position compensation.
function GS:ApplyTopGroupScale(groupId, oldScale, newScale)
  if type(groupId) ~= 'string' or groupId == '' then return false end
  local g = _GetData(groupId)
  if type(g) ~= 'table' then return false end
  if not _IsGroup(g) then return false end

  oldScale = _ClampScale(oldScale)
  newScale = _ClampScale(newScale)
  if oldScale == 0 then oldScale = 1 end
  if newScale == oldScale then return true end

  local gx, gy = _EnsureGroupCenterPinned(groupId)
  local k = newScale / oldScale

  local Move = Gate and Gate.Get and Gate:Get('Move') or nil
  local PS = Gate and Gate.Get and Gate:Get('PropertyService') or nil
  if not Move or not Move.CommitOffsets then
    return false
  end

  local ids = _CollectDescendants(groupId, {})
  for _, id in ipairs(ids) do
    local d = _GetData(id)
    if type(d) == 'table' then
      local x, y = _GetCenterXY(d)
      local nx = gx + (x - gx) * k
      local ny = gy + (y - gy) * k

      -- 1) Position compensation (always, including nested groups)
      pcall(function() Move:CommitOffsets({ id = id, xOffset = nx, yOffset = ny }) end)

      -- 2) Element size scale (effective, multiplicative; only for non-group nodes)
      if not _IsGroup(d) then
        if PS and PS.Set then
          local target = self:GetEffectiveScaleFor(id)
          pcall(function() PS:Set(id, 'scale', target) end)
        end
      end
    end
  end

  return true
end


-- ------------------------------------------------------------
-- Step7 (v2.19.3): Structure-change trigger support
-- Apply scaling + XY compensation for a moved subtree when its
-- top-level group membership changes.
-- ------------------------------------------------------------

-- Return the TOP-LEVEL group id for a node (nil if none).
function GS:GetTopGroupIdFor(nodeId)
  if type(nodeId) ~= 'string' or nodeId == '' then return nil end
  local curId = nodeId
  local lastGroupId = nil
  local guard = 0
  while curId and guard < 100 do
    guard = guard + 1
    local d = _GetData(curId)
    if type(d) ~= 'table' then break end
    if _IsGroup(d) then
      lastGroupId = curId
    end
    curId = _GetParentId(d)
  end
  -- lastGroupId is the highest group in the chain, but we only accept TOP-LEVEL (no parent).
  if lastGroupId then
    local gd = _GetData(lastGroupId)
    local gp = _GetParentId(gd)
    if gp == nil then
      return lastGroupId
    end
  end
  return nil
end

-- Apply membership transform for a moved subtree when moving between top-level groups.
-- - oldTopId / newTopId can be nil
-- - Elements in subtree receive scale (newScale or 1); group nodes do not.
-- - Positions are transformed by:
--   undo old scale around old center, then apply new scale around new center.
function GS:ApplyNodeBetweenTopGroups(rootId, oldTopId, newTopId)
  if type(rootId) ~= 'string' or rootId == '' then return false end

  local oldScale = oldTopId and _GetLocalGroupScale(oldTopId) or 1
  local newScale = newTopId and _GetLocalGroupScale(newTopId) or 1

  if (oldTopId == newTopId) and (oldScale == newScale) then
    return true
  end

  local ogx, ogy = 0, 0
  if oldTopId then
    ogx, ogy = _EnsureGroupCenterPinned(oldTopId)
  end

  local ngx, ngy = 0, 0
  if newTopId then
    ngx, ngy = _EnsureGroupCenterPinned(newTopId)
  end

  local Move = Gate and Gate.Get and Gate:Get('Move') or nil
  local PS = Gate and Gate.Get and Gate:Get('PropertyService') or nil
  if not Move or not Move.CommitOffsets then return false end

  local ids = _CollectSubtree(rootId, {})
  for _, id in ipairs(ids) do
    local d = _GetData(id)
    if type(d) == 'table' then
      local x, y = _GetCenterXY(d)

      -- 1) Undo old scale around old top group center
      if oldTopId and oldScale and oldScale ~= 0 and oldScale ~= 1 then
        local k1 = 1 / oldScale
        x = ogx + (x - ogx) * k1
        y = ogy + (y - ogy) * k1
      end

      -- 2) Apply new scale around new top group center
      if newTopId and newScale and newScale ~= 1 then
        local k2 = newScale
        x = ngx + (x - ngx) * k2
        y = ngy + (y - ngy) * k2
      end

      pcall(function() Move:CommitOffsets({ id = id, xOffset = x, yOffset = y }) end)

      if not _IsGroup(d) then
        if PS and PS.Set then
          local target = self:GetEffectiveScaleFor(id)
          pcall(function() PS:Set(id, 'scale', target) end)
        end
      end
    end
  end

  return true
end
