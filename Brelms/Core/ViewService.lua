-- Bre/Core/ViewService.lua
-- BrA-like "eye/view" visibility service (0/1/2) behind Gate.
-- UI must ONLY call Gate:Get('View') (no direct Move/TreeIndex access).

local addonName, Bre = ...
Bre = Bre or {}

Bre.View = Bre.View or {}
local V = Bre.View

local Gate = Bre.Gate
local PT = Bre.PreviewTypes

-- Preview providers (L2 registers via Gate; ViewService aggregates; read-only)
V._previewProviders = V._previewProviders or {} -- moduleId -> { fn=function(id)->desc, prio=number }

function V:RegisterPreviewProvider(moduleId, fn, prio)
  if type(moduleId) ~= "string" or moduleId == "" then return end
  if type(fn) ~= "function" then return end
  prio = tonumber(prio) or 0
  V._previewProviders[moduleId] = { fn = fn, prio = prio }
end

function V:UnregisterPreviewProvider(moduleId)
  if type(moduleId) ~= "string" or moduleId == "" then return end
  V._previewProviders[moduleId] = nil
end

local function _sortedProviders()
  local arr = {}
  for mid, v in pairs(V._previewProviders or {}) do
    if v and type(v.fn) == "function" then
      arr[#arr+1] = { id = mid, fn = v.fn, prio = tonumber(v.prio) or 0 }
    end
  end
  table.sort(arr, function(a,b) return (a.prio or 0) > (b.prio or 0) end)
  return arr
end

-- In TreeIndex-off (fixture) mode, we keep a local visibility map so the eye can be tested
-- without touching DB/Move. This map is session-only and is intentionally NOT persisted.
V._fixtureHidden = V._fixtureHidden or {}  -- id -> bool

local function _isFixtureMode()
  return Gate and Gate.Has and (not Gate:Has('TreeIndex'))
end

-- NOTE: Unified entry only. No fallback direct module access.
local function _Move() return (Gate and Gate:Get('Move')) or {} end
local function _TreeIndex() return (Gate and Gate:Get('TreeIndex')) or {} end

local function _buildIndex()
  local TI = _TreeIndex()
  if TI and TI.Build then
    return TI:Build() or { parentMap = {}, childrenMap = {}, roots = {} }
  end
  return { parentMap = {}, childrenMap = {}, roots = {} }
end

local function _childrenOf(id, idx)
  idx = idx or _buildIndex()
  local map = idx.childrenMap or {}
  local arr = map[id]
  if type(arr) ~= "table" then return idx, {} end
  return idx, arr
end


local function _isHiddenFixture(id, idx)
  if not id then return false end
  idx = idx or _buildIndex()
  local pmap = idx.parentMap or {}
  local cur = id
  local guard = 0
  while cur and guard < 200 do
    guard = guard + 1
    if V._fixtureHidden[cur] then return true end
    cur = pmap[cur]
  end
  return false
end


local function _hasChildren(id, idx)
  idx, ch = _childrenOf(id, idx)
  return idx, (type(ch) == "table" and #ch > 0)
end

local function _forEachDesc(id, fn, idx)
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

-- Public: get view state for node id.
-- 0 = hidden, 1 = mixed, 2 = shown
-- Public: get view state for node id.
-- 0 = hidden, 1 = mixed, 2 = shown
function V:GetState(id, idx)
  if type(id) ~= "string" then return 2 end

  -- Fixture mode: compute from local map + fixture tree structure
  if _isFixtureMode() then
    local hidden = _isHiddenFixture(id, idx) and true or false
    idx = idx or _buildIndex()
    local map = idx.childrenMap or {}
    local kids = map[id]
    if type(kids) ~= "table" or #kids == 0 then
      return hidden and 0 or 2
    end

    local anyShown, anyHidden = false, false
    for _, cid in ipairs(kids) do
      local h = _isHiddenFixture(cid, idx) and true or false
      if h then anyHidden = true else anyShown = true end
    end
    if (not anyShown) and anyHidden then return 0 end
    if anyShown and (not anyHidden) then return 2 end
    return 1
  end

  -- Normal mode: consult Move's hidden flag in data
  local M = _Move()
  if not (M and M.IsNodeHidden) then return 2 end

  local idxLocal = idx or _buildIndex()
  local hiddenSelf = (M and M.IsNodeHidden and M:IsNodeHidden(id)) or false

  local map = idxLocal.childrenMap or {}
  local kids = map[id]
  if type(kids) ~= "table" or #kids == 0 then
    return hiddenSelf and 0 or 2
  end

  local anyShown, anyHidden = false, false
  _forEachDesc(id, function(cid)
    local h = (M and M.IsNodeHidden and M:IsNodeHidden(cid)) or false
    if h then anyHidden = true else anyShown = true end
  end, idxLocal)

  if (not anyShown) and anyHidden then return 0 end
  if anyShown and (not anyHidden) then return 2 end
  return 1
end


-- Public: toggle view state (BrA PriorityShow/Hide simplified)
-- - If current state is 2 (shown): hide (recursive if has children)
-- - Else (0/1): show (recursive if has children)
-- Public: toggle view state (BrA PriorityShow/Hide simplified)
-- - If current state is 2 (shown): hide (recursive if has children)
-- - Else (0/1): show (recursive if has children)
function V:Toggle(id, idx)
  if type(id) ~= "string" then return end
  idx = idx or _buildIndex()
  local cur = self:GetState(id, idx)
  local _, hasKids = _hasChildren(id, idx)

  -- IMPORTANT: parent eye must be clickable even in mixed state.
  -- Toggle ONLY this node's own hidden flag (do NOT rewrite children).
  local selfHidden = nil

  -- Fixture mode: session-only map stores *self* hidden.
  if _isFixtureMode() then
    selfHidden = (V._fixtureHidden[id] == true)
    V._fixtureHidden[id] = (not selfHidden)
    return
  end

  -- Normal mode: read raw data to get *self* hidden, not effective state.
  local el = (Bre and Bre.GetData and Bre.GetData(id)) or nil
  if type(el) == "table" then
    selfHidden = (el.hidden == true)
  end

  -- Fallback: if data missing, fall back to previous behavior based on tri-state.
  if selfHidden == nil then
    selfHidden = (cur ~= 2)
  end

  local targetHidden = (not selfHidden)

  -- Delegate to Move
  local M = _Move()
  if not (M and M.SetHidden) then return end
  M:SetHidden(id, targetHidden, false)
  if hasKids and M.RefreshSubtree then
    M:RefreshSubtree(id, idx, false)
  end
end


-- Public: returns a preview descriptor for a node (static; no live updates in current phase).
-- Must be read-only. UI may call this to render preview box.
function V:GetNodePreview(id)
  if type(id) ~= "string" then
    return (PT and PT.None and PT.None()) or { kind = "none" }
  end

  -- Query L2 providers (registered through Gate). First non-none wins.
  local providers = _sortedProviders()
  for _, p in ipairs(providers) do
    local ok, desc = pcall(p.fn, id)
    if ok and type(desc) == "table" then
      local k = desc.kind
      if k == PT.KIND_TEXTURE or k == "texture" then
        return desc
      end
    end
  end

  return (PT and PT.None and PT.None()) or { kind = "none" }
end


-- Public: sync on-screen visibility/preview overlays for current UI selection.
-- M4: UI must NOT directly call Render/Move show/hide; all "visible/invisible" routing goes through View.
--
-- Expected UI frame fields:
--   f:IsShown()-- Selection truth source is SelectionService.
function V:SyncSelection(f)
  local Render = (Gate and Gate:Get('Render')) or {}
  local Move   = (Gate and Gate:Get('Move')) or {}
  local SS     = (Gate and Gate:Get('SelectionService')) or nil
  local sel    = (SS and SS.GetState and SS:GetState()) or nil

  if not f or not f.IsShown or not f:IsShown() then
    if Render.Hide then Render:Hide() end
    if Move.Hide then Move:Hide() end
    if Move.HideGroupBox then Move:HideGroupBox() end
    return
  end

  local id = (sel and sel.active)
  if not id or not (Bre and Bre.GetData) then
    if Render.Hide then Render:Hide() end
    if Move.Hide then Move:Hide() end
    if Move.HideGroupBox then Move:HideGroupBox() end
    return
  end

  local d = Bre.GetData(id)
  if not d then
    if Render.Hide then Render:Hide() end
    if Move.Hide then Move:Hide() end
    if Move.HideGroupBox then Move:HideGroupBox() end
    return
  end

  -- Group selection: hide element overlays, but show group box if available.
  -- NOTE: selectable group click may set sel.set = { [groupId]=true } (single),
  -- which contains no runtime regions. In that case we must derive descendant leaf ids
  -- to compute group bounds without changing Selection semantics.
  local function _CollectDescendantLeafIds(groupId, out, visited)
    if type(out) ~= "table" then return out end
    visited = visited or {}
    if visited[groupId] then return out end
    visited[groupId] = true

    local gd = Bre.GetData and Bre.GetData(groupId)
    if type(gd) ~= "table" then return out end
    local children = gd.controlledChildren
    if type(children) ~= "table" then return out end

    for _, cid in ipairs(children) do
      if type(cid) == "string" then
        local cd = Bre.GetData and Bre.GetData(cid)
        if type(cd) == "table" then
          if cd.regionType == "group" then
            _CollectDescendantLeafIds(cid, out, visited)
          else
            out[#out + 1] = cid
          end
        end
      end
    end
    return out
  end

  if d.regionType == 'group' then
    if Render.Hide then Render:Hide() end
    if Move.Hide then Move:Hide() end

    local ids = {}
    local seen = {}
    local set = (sel and sel.set)
    if type(set) == 'table' then
      for nid, on in pairs(set) do
        if on and type(nid) == "string" and not seen[nid] then
          seen[nid] = true
          local nd = Bre.GetData and Bre.GetData(nid)
          if type(nd) == "table" and nd.regionType == "group" then
            _CollectDescendantLeafIds(nid, ids, {})
          else
            ids[#ids + 1] = nid
          end
        end
      end
    end

    -- Fallback: single selectable group click often yields set={groupId}; derive descendants to show bounds.
    if #ids == 0 then
      _CollectDescendantLeafIds(id, ids, {})
    end

    if Move.ShowGroupBox then Move:ShowGroupBox(ids) end
    return
  else
    if Move.HideGroupBox then Move:HideGroupBox() end
  end

  -- Respect View state (hidden -> hide overlays).
  local st = 2
  if self.GetState then
    st = self:GetState(id)
  end
  if st == 0 then
    if Render.Hide then Render:Hide() end
    if Move.Hide then Move:Hide() end
    return
  end

  -- Avoid double-render: when runtime regions exist (from Move runtime root), do not also draw Render body.
  -- Render is kept as a fallback when runtime region is missing (e.g. during migration or when Move is stubbed).
  local hasRuntime = (Move and Move.GetRuntimeRegion and Move:GetRuntimeRegion(id)) and true or false

  if hasRuntime then
    if Render.Hide then Render:Hide() end
  else
    if Render.ShowForElement then Render:ShowForElement(id, d) end
  end
  if Move.ShowForElement then Move:ShowForElement(id, d) end
end

-- Module exported via Bre.ViewService
