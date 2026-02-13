-- Bre/Core/LoadState.lua
-- Pure computation helpers for BrA-like tri-state "loaded" (true/false/nil).
--
-- Definitions (aligned to BrA semantics):
--   nil   => NotLoaded / Unloaded (hard-unloaded; appears in 'Unloaded' section)
--   false => Standby (loadable but currently not running)
--   true  => Loaded (running)
--
-- Derivation rules (BrA-like):
--   0) If any ancestor (including self) has load.never == true => tri = nil (hard-unloaded; cascades)
--   1) Else if runtimeLoaded[id] == true OR node._runtimeLoaded == true => tri = true
--   2) Else => tri = false
--
-- Contract (Step1):
--   - NO DB writes.
--   - NO View changes.
--   - NO Move/Render calls.
--   - Only exports: GetTri(), IsHardUnloaded().

local addonName, Bre = ...
Bre = Bre or {}
Bre.LoadState = Bre.LoadState or {}
local LS = Bre.LoadState

-- Optional read-only node accessor (best-effort).
-- We keep this local and side-effect free to preserve existing callers that don't pass getNode().
local function _DefaultGetNode(id)
  if type(id) ~= "string" or id == "" then return nil end

  -- Preferred: runtime DB object (read-only)
  if Bre.DB and type(Bre.DB.GetNode) == "function" then
    return Bre.DB:GetNode(id)
  end

  -- Fallback: saved variables (read-only)
  if BreSaved and BreSaved.displays and type(BreSaved.displays[id]) == "table" then
    return BreSaved.displays[id]
  end

  return nil
end

-- Public: get tri-state for node (true/false/nil)
-- getNode: optional function(id)->node, used to resolve ancestors for cascade checks.
-- runtimeLoaded: optional table[id]=true when actually running (session-only, read-only).
function LS:GetTri(id, node, getNode, runtimeLoaded)
  if type(id) ~= "string" or id == "" then return false end
  getNode = getNode or _DefaultGetNode

  node = node or (getNode and getNode(id)) or nil
  if type(node) ~= "table" then
    -- Unknown nodes default to Standby (safer than hard-unloaded)
    return false
  end

  -- BrA-style cascade: parent 'never' makes descendants hard-unloaded.
  -- Walk up by parent pointers (best-effort; guards against cycles).
  local curId = id
  local hop = 0
  while type(curId) == "string" and curId ~= "" and hop < 50 do
    local n = (curId == id) and node or (getNode and getNode(curId)) or nil
    if type(n) ~= "table" then break end
    if n.load and n.load.never == true then
      return nil
    end
    curId = n.parent
    hop = hop + 1
  end

  if (runtimeLoaded and runtimeLoaded[id] == true) or (node._runtimeLoaded == true) then
    return true
  end

  return false
end

-- Convenience: hard-unloaded predicate (matches Tree 'Unloaded' section)
function LS:IsHardUnloaded(id, node, getNode, runtimeLoaded)
  return LS:GetTri(id, node, getNode, runtimeLoaded) == nil
end

return LS
