-- Bre/Core/SelectionService.lua
-- L1: SelectionService - unified selection state (single/multi).
-- Step3 (v2.12.2): wired into Tree/UI selection flow (UI mirrors service state).

local addonName, Bre = ...
Bre = Bre or {}

Bre.SelectionService = Bre.SelectionService or {}

local SS = Bre.SelectionService

SS.state = SS.state or {
  active = nil,
  set = {}, -- [nodeId]=true
}

local function _normalizeSet(nodeIdList)
  local set = {}
  if type(nodeIdList) == "table" then
    for _, nid in ipairs(nodeIdList) do
      if nid then set[nid] = true end
    end
  end
  return set
end

local function _firstInSet(set)
  if type(set) ~= "table" then return nil end
  for nid, on in pairs(set) do
    if on then return nid end
  end
  return nil
end

function SS:GetState()
  return SS.state
end

function SS:GetActive()
  return SS.state and SS.state.active or nil
end

function SS:IsSelected(nodeId)
  return SS.state and SS.state.set and SS.state.set[nodeId] and true or false
end

function SS:Clear(reason)
  local st = SS.state
  if not st then return false end
  if st.active == nil and (type(st.set) ~= "table" or next(st.set) == nil) then
    return false
  end
  st.active = nil
  st.set = {}
  return true
end

function SS:SetActive(nodeId, reason)
  if not nodeId then
    return self:Clear(reason)
  end

  local st = SS.state
  st = st or { active = nil, set = {} }
  SS.state = st

  local changed = false
  if st.active ~= nodeId then
    st.active = nodeId
    changed = true
  end

  if type(st.set) ~= "table" then st.set = {} end
  if next(st.set) ~= nil then
    -- ensure single-select set
    if not (st.set[nodeId] and (next(st.set, nodeId) == nil and next(st.set) == nodeId)) then
      st.set = { [nodeId] = true }
      changed = true
    end
  else
    st.set[nodeId] = true
    changed = true
  end

  return changed
end

-- Set active without mutating selection set.
function SS:SetActiveRaw(nodeId, reason)
  local st = SS.state
  st = st or { active = nil, set = {} }
  SS.state = st
  if st.active == nodeId then return false end
  st.active = nodeId
  return true
end

-- Set active while preserving current set (if nodeId is already selected).
-- If nodeId is not in set, fall back to SetActive (single select).
function SS:SetActiveInSet(nodeId, reason)
  if not nodeId then return self:Clear(reason) end
  local st = SS.state
  st = st or { active = nil, set = {} }
  SS.state = st
  if type(st.set) == "table" and st.set[nodeId] then
    if st.active == nodeId then return false end
    st.active = nodeId
    return true
  end
  return self:SetActive(nodeId, reason)
end

function SS:SetSet(nodeIdList, reason)
  local st = SS.state
  st = st or { active = nil, set = {} }
  SS.state = st

  local newSet = _normalizeSet(nodeIdList)
  local changed = false

  -- compare sets (cheap)
  local oldSet = st.set or {}
  for k, v in pairs(oldSet) do
    if v and not newSet[k] then changed = true break end
  end
  if not changed then
    for k, v in pairs(newSet) do
      if v and not oldSet[k] then changed = true break end
    end
  end

  st.set = newSet

  -- keep active stable if still selected, otherwise pick first
  if st.active and newSet[st.active] then
    -- ok
  else
    local na = _firstInSet(newSet)
    if st.active ~= na then
      st.active = na
      changed = true
    end
  end

  return changed
end

function SS:Toggle(nodeId, reason)
  if not nodeId then return false end
  local st = SS.state
  st = st or { active = nil, set = {} }
  SS.state = st
  if type(st.set) ~= "table" then st.set = {} end

  local changed = false
  if st.set[nodeId] then
    st.set[nodeId] = nil
    changed = true
    if st.active == nodeId then
      st.active = _firstInSet(st.set)
      changed = true
    end
  else
    st.set[nodeId] = true
    st.active = nodeId
    changed = true
  end

  return changed
end

-- Unified click handler for Tree rows (ctrl/shift rules live here).
-- p = {
--   clickedId=string,
--   selectable=boolean,
--   isRootGroup=boolean,
--   descendantIds=table|nil, -- for root groups
--   parentId=string|nil,     -- parent of clicked row (for shift-range)
--   rowOrder=table|nil,      -- visible row order
--   rowMeta=table|nil,       -- meta map: [id]={parent=..., selectable=true}
--   shift=boolean, ctrl=boolean,
-- }
SS._anchor = SS._anchor or { id=nil, parent=nil }

local function _rangeIds(anchorId, clickedId, parentId, rowOrder, rowMeta)
  if type(rowOrder) ~= "table" or type(rowMeta) ~= "table" then
    return { clickedId }
  end
  local candidates = {}
  for _, nid in ipairs(rowOrder) do
    local m = rowMeta[nid]
    if m and m.parent == parentId and m.selectable then
      candidates[#candidates+1] = nid
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
  local sIdx = math.min(aIdx, cIdx)
  local eIdx = math.max(aIdx, cIdx)
  local out = {}
  for i = sIdx, eIdx do out[#out+1] = candidates[i] end
  return out
end

function SS:OnTreeClick(p)
  if type(p) ~= "table" or not p.clickedId then return false end
  local id = p.clickedId

  if p.selectable == false and p.isRootGroup then
    local ids = p.descendantIds or {}
    local changed = false
    if self.SetSet then changed = self:SetSet(ids, "root") or changed end
    if self.SetActiveRaw then changed = self:SetActiveRaw(id, "root") or changed end
    SS._anchor.id, SS._anchor.parent = nil, nil
    return changed
  end

  local shift = p.shift and true or false
  local ctrl  = p.ctrl and true or false

  if shift then
    local a = SS._anchor or { id=nil, parent=nil }
    if not a.id or a.parent ~= p.parentId then
      local changed = self:SetActive(id, "shift_degrade")
      SS._anchor.id, SS._anchor.parent = id, p.parentId
      return changed
    end
    local ids = _rangeIds(a.id, id, p.parentId, p.rowOrder, p.rowMeta)
    local changed = false
    changed = (self.SetSet and self:SetSet(ids, "shift")) or changed
    changed = (self.SetActiveInSet and self:SetActiveInSet(id, "shift")) or changed
    SS._anchor.id, SS._anchor.parent = id, p.parentId
    return changed
  end

  if ctrl then
    local changed = self:Toggle(id, "ctrl")
    if self:IsSelected(id) then
      SS._anchor.id, SS._anchor.parent = id, p.parentId
    end
    return changed
  end

  local changed = self:SetActive(id, "single")
  SS._anchor.id, SS._anchor.parent = id, p.parentId
  return changed
end

-- Module exported via Bre.SelectionService
